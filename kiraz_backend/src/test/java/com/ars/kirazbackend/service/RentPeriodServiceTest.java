package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

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
}
