package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PendingReceiptDto;
import com.ars.kirazbackend.entity.AuditLog;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.event.ReceiptRejectedEvent;
import com.ars.kirazbackend.repository.AuditLogRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LandlordReceiptServiceTest {

    @Mock
    private RentPeriodRepository rentPeriodRepository;

    @Mock
    private RentPeriodService rentPeriodService;

    @Mock
    private AuditLogRepository auditLogRepository;

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private KafkaProducerService kafkaProducerService;

    @InjectMocks
    private LandlordReceiptService landlordReceiptService;

    private User landlord;
    private User tenant;
    private Property property;
    private LeaseAgreement lease;
    private RentPeriod period;

    @BeforeEach
    void setUp() {
        landlord = User.builder().id(1L).fullName("Ev Sahibi Ali").role(RoleType.LANDLORD).build();
        tenant = User.builder().id(2L).fullName("Kiracı Veli").role(RoleType.TENANT).build();
        property = Property.builder().id(10L).title("Kadıköy 2+1").landlord(landlord).build();

        lease = LeaseAgreement.builder()
                .id(20L)
                .property(property)
                .tenant(tenant)
                .monthlyRentAmount(BigDecimal.valueOf(15000.00))
                .build();

        period = RentPeriod.builder()
                .id(100L)
                .leaseAgreement(lease)
                .month(11)
                .year(2026)
                .periodStart(LocalDate.now().minusDays(3))
                .status(PaymentStatus.WAITING_APPROVAL)
                .receiptImageUrl("http://cloudinary.com/dekont123.jpg")
                .build();
    }

    @Test
    void testGetPendingReceipts_ReturnsMappedDtos() {
        LocalDateTime uploadTime = LocalDateTime.of(2026, 11, 2, 14, 30);
        AuditLog auditLog = AuditLog.builder()
                .id(50L)
                .entityName("RENT_PERIOD")
                .entityId(100L)
                .action("RECEIPT_UPLOADED")
                .createdAt(uploadTime)
                .build();

        when(rentPeriodRepository.findByLandlordIdAndStatus(1L, PaymentStatus.WAITING_APPROVAL))
                .thenReturn(List.of(period));
        when(auditLogRepository.findByEntityNameAndEntityIdOrderByCreatedAtDesc("RENT_PERIOD", 100L))
                .thenReturn(List.of(auditLog));

        List<PendingReceiptDto> result = landlordReceiptService.getPendingReceipts(1L);

        assertNotNull(result);
        assertEquals(1, result.size());

        PendingReceiptDto dto = result.get(0);
        assertEquals(100L, dto.periodId());
        assertEquals("Kadıköy 2+1", dto.propertyName());
        assertEquals("Kiracı Veli", dto.tenantName());
        assertEquals(11, dto.month());
        assertEquals(2026, dto.year());
        assertEquals(BigDecimal.valueOf(15000.00), dto.amount());
        assertEquals("http://cloudinary.com/dekont123.jpg", dto.receiptImageUrl());
        assertEquals(uploadTime, dto.uploadDate());
    }

    @Test
    void testApproveReceipt_DelegatesToRentPeriodService() {
        RentPeriod approvedPeriod = RentPeriod.builder()
                .id(100L)
                .status(PaymentStatus.PAID)
                .build();

        when(rentPeriodService.updateStatus(100L, "PAID")).thenReturn(approvedPeriod);

        RentPeriod result = landlordReceiptService.approveReceipt(100L);

        assertNotNull(result);
        assertEquals(PaymentStatus.PAID, result.getStatus());
        verify(rentPeriodService, times(1)).updateStatus(100L, "PAID");
    }

    @Test
    void testRejectReceipt_WhenPastDue_SetsOverdueAndFiresKafkaEvent() {
        period.setPeriodStart(LocalDate.now().minusDays(5)); // Due date in the past
        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(period));
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(inv -> inv.getArgument(0));

        RentPeriod rejected = landlordReceiptService.rejectReceipt(100L, "Dekont eksik veya hatalı", landlord);

        assertNotNull(rejected);
        assertEquals(PaymentStatus.OVERDUE, rejected.getStatus());
        assertNull(rejected.getReceiptImageUrl());

        // Verify audit log
        verify(auditLogService, times(1)).record(
                eq("RENT_PERIOD"),
                eq(100L),
                eq("RECEIPT_REJECTED"),
                eq(landlord),
                contains("OVERDUE")
        );

        // Verify Kafka event published
        ArgumentCaptor<ReceiptRejectedEvent> eventCaptor = ArgumentCaptor.forClass(ReceiptRejectedEvent.class);
        verify(kafkaProducerService, times(1)).sendReceiptRejectedEvent(eventCaptor.capture());

        ReceiptRejectedEvent publishedEvent = eventCaptor.getValue();
        assertEquals(100L, publishedEvent.periodId());
        assertEquals(2L, publishedEvent.tenantId());
        assertEquals(20L, publishedEvent.leaseAgreementId());
        assertEquals("Kadıköy 2+1", publishedEvent.propertyTitle());
        assertEquals("Dekont eksik veya hatalı", publishedEvent.reason());
        assertEquals(11, publishedEvent.month());
        assertEquals(2026, publishedEvent.year());
    }

    @Test
    void testRejectReceipt_WhenNotPastDue_SetsPending() {
        period.setPeriodStart(LocalDate.now().plusDays(5)); // Due date in future
        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(period));
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(inv -> inv.getArgument(0));

        RentPeriod rejected = landlordReceiptService.rejectReceipt(100L, "Yanlış hesaba yatırılmış", landlord);

        assertNotNull(rejected);
        assertEquals(PaymentStatus.PENDING, rejected.getStatus());
        assertNull(rejected.getReceiptImageUrl());

        verify(auditLogService, times(1)).record(
                eq("RENT_PERIOD"),
                eq(100L),
                eq("RECEIPT_REJECTED"),
                eq(landlord),
                contains("PENDING")
        );
    }

    @Test
    void testRejectReceipt_PeriodNotFound_ThrowsException() {
        when(rentPeriodRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () ->
                landlordReceiptService.rejectReceipt(999L, "Sebep", landlord)
        );

        verify(kafkaProducerService, never()).sendReceiptRejectedEvent(any());
    }
}
