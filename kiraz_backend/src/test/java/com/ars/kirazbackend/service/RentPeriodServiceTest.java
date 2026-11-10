package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PaymentSummaryResponse;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptUploadedEvent;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RentPeriodServiceTest {

    @Mock
    private RentPeriodRepository rentPeriodRepository;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private KafkaProducerService kafkaProducerService;

    @Mock
    private NotificationService notificationService;

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private PropertyDelegationService propertyDelegationService;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private RentPeriodService rentPeriodService;

    private User landlord;
    private User agent;
    private User tenant;
    private Property property;
    private LeaseAgreement lease;

    @BeforeEach
    void setUp() {
        landlord = User.builder().id(1L).fullName("Ev Sahibi").role(RoleType.LANDLORD).build();
        agent = User.builder().id(2L).fullName("Vekil Emlakçı").role(RoleType.AGENT).build();
        tenant = User.builder().id(3L).fullName("Kiracı").role(RoleType.TENANT).build();

        property = Property.builder().id(10L).title("Beşiktaş 1+1").landlord(landlord).build();
        lease = LeaseAgreement.builder().id(100L).property(property).tenant(tenant).build();
    }

    @Test
    void testMarkOverduePeriods_UpdatesPendingWithoutReceipt() {
        RentPeriod period1 = RentPeriod.builder()
                .id(1L)
                .leaseAgreement(lease)
                .month(10)
                .year(2026)
                .paymentDate(LocalDate.now().minusDays(5))
                .status(PaymentStatus.PENDING)
                .receiptImageUrl(null)
                .build();

        RentPeriod period2WithReceipt = RentPeriod.builder()
                .id(2L)
                .leaseAgreement(lease)
                .month(10)
                .year(2026)
                .paymentDate(LocalDate.now().minusDays(3))
                .status(PaymentStatus.PENDING)
                .receiptImageUrl("http://example.com/receipt.jpg")
                .build();

        when(rentPeriodRepository.findPendingOverduePeriods(eq(PaymentStatus.PENDING), any(LocalDate.class)))
                .thenReturn(List.of(period1, period2WithReceipt));

        int updatedCount = rentPeriodService.markOverduePeriods();

        assertEquals(1, updatedCount);
        assertEquals(PaymentStatus.OVERDUE, period1.getStatus());
        assertEquals(PaymentStatus.PENDING, period2WithReceipt.getStatus());
        verify(rentPeriodRepository, times(1)).saveAll(anyList());
        verify(notificationService, atLeastOnce()).createNotification(eq(3L), any(), any(), eq("OVERDUE"), eq(100L));
    }

    @Test
    void testMarkAsLegalProcess_SuccessByLandlord() {
        RentPeriod period = RentPeriod.builder()
                .id(10L)
                .leaseAgreement(lease)
                .month(9)
                .year(2026)
                .status(PaymentStatus.OVERDUE)
                .build();

        when(rentPeriodRepository.findById(10L)).thenReturn(Optional.of(period));
        when(userRepository.findById(1L)).thenReturn(Optional.of(landlord));
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(i -> i.getArgument(0));

        RentPeriod updated = rentPeriodService.markAsLegalProcess(10L, 1L, "3 aydır ödeme yapılmadı, icra başlatıldı");

        assertEquals(PaymentStatus.IN_LEGAL_PROCESS, updated.getStatus());
        verify(auditLogService, times(1)).record(
                eq("RENT_PERIOD"), eq(10L), eq("LEGAL_PROCESS_INITIATED"), eq(landlord), any()
        );
        verify(notificationService, times(1)).createNotification(
                eq(3L), contains("Hukuki Süreç"), any(), eq("LEGAL_PROCESS"), eq(100L)
        );
    }

    @Test
    void testMarkAsLegalProcess_SuccessByDelegatedAgent() {
        RentPeriod period = RentPeriod.builder()
                .id(10L)
                .leaseAgreement(lease)
                .month(9)
                .year(2026)
                .status(PaymentStatus.OVERDUE)
                .build();

        when(rentPeriodRepository.findById(10L)).thenReturn(Optional.of(period));
        when(userRepository.findById(2L)).thenReturn(Optional.of(agent));
        when(propertyDelegationService.hasActiveDelegation(10L, 2L)).thenReturn(true);
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(i -> i.getArgument(0));

        RentPeriod updated = rentPeriodService.markAsLegalProcess(10L, 2L, "Emlakçı tarafından avukatlık icra süreci başlatıldı");

        assertEquals(PaymentStatus.IN_LEGAL_PROCESS, updated.getStatus());
        verify(auditLogService, times(1)).record(
                eq("RENT_PERIOD"), eq(10L), eq("LEGAL_PROCESS_INITIATED"), eq(agent), any()
        );
    }

    @Test
    void testMarkAsLegalProcess_FailsForAgentWithoutActiveDelegation() {
        RentPeriod period = RentPeriod.builder()
                .id(10L)
                .leaseAgreement(lease)
                .status(PaymentStatus.OVERDUE)
                .build();

        when(rentPeriodRepository.findById(10L)).thenReturn(Optional.of(period));
        when(userRepository.findById(2L)).thenReturn(Optional.of(agent));
        when(propertyDelegationService.hasActiveDelegation(10L, 2L)).thenReturn(false);

        RuntimeException ex = assertThrows(RuntimeException.class,
                () -> rentPeriodService.markAsLegalProcess(10L, 2L, "Deneme"));
        assertTrue(ex.getMessage().contains("aktif emlakçı vekaletiniz"));
    }

    @Test
    void testGetTenantPaymentSummary_Success() {
        lease.setMonthlyRentAmount(BigDecimal.valueOf(5000));

        LocalDate today = LocalDate.now();

        RentPeriod paidPeriod = RentPeriod.builder()
                .id(1L)
                .leaseAgreement(lease)
                .month(8)
                .year(2026)
                .status(PaymentStatus.PAID)
                .periodStart(today.minusMonths(2))
                .paymentDate(today.minusMonths(2))
                .build();

        RentPeriod overduePeriod = RentPeriod.builder()
                .id(2L)
                .leaseAgreement(lease)
                .month(9)
                .year(2026)
                .status(PaymentStatus.OVERDUE)
                .periodStart(today.minusMonths(1))
                .paymentDate(today.minusMonths(1))
                .build();

        RentPeriod nextPendingPeriod = RentPeriod.builder()
                .id(3L)
                .leaseAgreement(lease)
                .month(10)
                .year(2026)
                .status(PaymentStatus.PENDING)
                .periodStart(today.plusDays(5))
                .paymentDate(today.plusDays(5))
                .build();

        when(rentPeriodRepository.findByTenantId(3L))
                .thenReturn(List.of(paidPeriod, overduePeriod, nextPendingPeriod));

        PaymentSummaryResponse summary = rentPeriodService.getTenantPaymentSummary(3L);

        assertNotNull(summary);
        assertEquals(0, BigDecimal.valueOf(5000).compareTo(summary.totalPaid()));
        assertEquals(0, BigDecimal.valueOf(5000).compareTo(summary.totalDebt()));
        assertEquals(today.plusDays(5), summary.nextPaymentDate());
        assertEquals(0, BigDecimal.valueOf(5000).compareTo(summary.nextPaymentAmount()));
    }

    @Test
    void testGetTenantPaymentSummary_PendingDueTodayOrPast_CountsAsDebt() {
        lease.setMonthlyRentAmount(BigDecimal.valueOf(4000));

        LocalDate today = LocalDate.now();

        RentPeriod pendingDueToday = RentPeriod.builder()
                .id(1L)
                .leaseAgreement(lease)
                .status(PaymentStatus.PENDING)
                .periodStart(today)
                .paymentDate(today)
                .build();

        RentPeriod pendingFuture = RentPeriod.builder()
                .id(2L)
                .leaseAgreement(lease)
                .status(PaymentStatus.PENDING)
                .periodStart(today.plusMonths(1))
                .paymentDate(today.plusMonths(1))
                .build();

        when(rentPeriodRepository.findByTenantId(3L))
                .thenReturn(List.of(pendingDueToday, pendingFuture));

        PaymentSummaryResponse summary = rentPeriodService.getTenantPaymentSummary(3L);

        assertNotNull(summary);
        assertEquals(0, BigDecimal.ZERO.compareTo(summary.totalPaid()));
        assertEquals(0, BigDecimal.valueOf(4000).compareTo(summary.totalDebt())); // pendingDueToday counted as debt
        assertEquals(today, summary.nextPaymentDate()); // today is the closest pending date
        assertEquals(0, BigDecimal.valueOf(4000).compareTo(summary.nextPaymentAmount()));
    }

    @Test
    void testUploadReceipt_SetsWaitingApprovalAndNotifiesLandlord() {
        RentPeriod period = RentPeriod.builder()
                .id(10L)
                .leaseAgreement(lease)
                .month(11)
                .year(2026)
                .status(PaymentStatus.PENDING)
                .build();

        MockMultipartFile file = new MockMultipartFile(
                "file", "dekont.png", "image/png", "dekont_bytes".getBytes()
        );

        when(rentPeriodRepository.findById(10L)).thenReturn(Optional.of(period));
        when(fileStorageService.storeFile(file)).thenReturn("/uploads/receipts/dekont.png");
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(invocation -> invocation.getArgument(0));

        RentPeriod result = rentPeriodService.uploadReceipt(10L, file);

        assertNotNull(result);
        assertEquals(PaymentStatus.WAITING_APPROVAL, result.getStatus());
        assertEquals("/api/files/receipts/10", result.getReceiptImageUrl());

        verify(rentPeriodRepository).save(period);
        verify(auditLogService).record(eq("RENT_PERIOD"), eq(10L), eq("RECEIPT_UPLOADED"), eq(tenant), anyString());
        verify(kafkaProducerService).sendReceiptUploadedEvent(any(ReceiptUploadedEvent.class));
    }

    @Test
    void testUpdateStatus_WhenPaid_SetsPaymentDateAndNotifiesBoth() {
        RentPeriod period = RentPeriod.builder()
                .id(20L)
                .leaseAgreement(lease)
                .month(11)
                .year(2026)
                .status(PaymentStatus.WAITING_APPROVAL)
                .build();

        when(rentPeriodRepository.findById(20L)).thenReturn(Optional.of(period));
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(invocation -> invocation.getArgument(0));

        RentPeriod result = rentPeriodService.updateStatus(20L, "PAID");

        assertNotNull(result);
        assertEquals(PaymentStatus.PAID, result.getStatus());
        assertEquals(LocalDate.now(), result.getPaymentDate());

        verify(rentPeriodRepository).save(period);
        verify(auditLogService).record(eq("RENT_PERIOD"), eq(20L), eq("PAYMENT_APPROVED"), any(), anyString());
        verify(kafkaProducerService).sendPaymentSuccessEvent(any(PaymentSuccessEvent.class));
    }
}
