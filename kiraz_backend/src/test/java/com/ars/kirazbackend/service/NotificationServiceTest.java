package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Notification;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.DelegationStatus;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.NotificationRepository;
import com.ars.kirazbackend.repository.PropertyDelegationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository notificationRepository;

    @Mock
    private PropertyDelegationRepository propertyDelegationRepository;

    @Mock
    private EmailService emailService;

    @Mock
    private com.ars.kirazbackend.repository.UserRepository userRepository;

    @InjectMocks
    private NotificationService notificationService;

    private User landlord;
    private User tenant;
    private User agent;
    private Property property;
    private LeaseAgreement leaseAgreement;
    private RentPeriod rentPeriod;

    @BeforeEach
    void setUp() {
        landlord = User.builder()
                .id(1L)
                .fullName("Ali Kaya")
                .email("ali@kaya.com")
                .role(RoleType.LANDLORD)
                .build();

        tenant = User.builder()
                .id(2L)
                .fullName("Veli Demir")
                .email("veli@demir.com")
                .role(RoleType.TENANT)
                .build();

        agent = User.builder()
                .id(3L)
                .fullName("Emlakçı Can")
                .email("can@emlak.com")
                .role(RoleType.AGENT)
                .build();

        property = Property.builder()
                .id(10L)
                .title("Göztepe 2+1")
                .landlord(landlord)
                .build();

        leaseAgreement = LeaseAgreement.builder()
                .id(100L)
                .property(property)
                .tenant(tenant)
                .build();

        rentPeriod = RentPeriod.builder()
                .id(50L)
                .leaseAgreement(leaseAgreement)
                .month(11)
                .year(2026)
                .status(PaymentStatus.WAITING_APPROVAL)
                .build();

        lenient().when(notificationRepository.save(any(Notification.class))).thenAnswer(i -> i.getArgument(0));
    }

    @Test
    void testNotifyLandlordForReceipt_Success() {
        PropertyDelegation delegation = PropertyDelegation.builder()
                .property(property)
                .agent(agent)
                .status(DelegationStatus.ACTIVE)
                .build();

        when(propertyDelegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE))
                .thenReturn(List.of(delegation));

        notificationService.notifyLandlordForReceipt(rentPeriod);

        // Check landlord notification
        verify(notificationRepository).save(argThat(n ->
                n.getUserId().equals(1L) &&
                n.getTitle().equals("Yeni Dekont Yüklendi") &&
                n.getMessage().contains("Veli Demir") &&
                n.getType().equals("RECEIPT_WAITING_APPROVAL")
        ));

        // Check landlord email
        verify(emailService).sendNotificationEmail(
                eq("ali@kaya.com"),
                contains("Yeni Dekont Yüklendi"),
                contains("Veli Demir")
        );

        // Check agent notification
        verify(notificationRepository).save(argThat(n ->
                n.getUserId().equals(3L) &&
                n.getTitle().equals("Yeni Dekont Yüklendi") &&
                n.getType().equals("RECEIPT_WAITING_APPROVAL")
        ));
    }

    @Test
    void testNotifyPaymentSuccess_Success() {
        PropertyDelegation delegation = PropertyDelegation.builder()
                .property(property)
                .agent(agent)
                .status(DelegationStatus.ACTIVE)
                .build();

        when(propertyDelegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE))
                .thenReturn(List.of(delegation));

        notificationService.notifyPaymentSuccess(rentPeriod);

        // Check tenant notification
        verify(notificationRepository).save(argThat(n ->
                n.getUserId().equals(2L) &&
                n.getTitle().equals("Kira Ödemeniz Alındı") &&
                n.getType().equals("PAYMENT_SUCCESS")
        ));

        // Check tenant email
        verify(emailService).sendNotificationEmail(
                eq("veli@demir.com"),
                contains("Kira Ödemeniz Alındı"),
                contains("Göztepe 2+1")
        );

        // Check landlord notification
        verify(notificationRepository).save(argThat(n ->
                n.getUserId().equals(1L) &&
                n.getTitle().equals("Kira Tahsilatı Yapıldı") &&
                n.getType().equals("PAYMENT_SUCCESS")
        ));

        // Check landlord email
        verify(emailService).sendNotificationEmail(
                eq("ali@kaya.com"),
                contains("Kira Tahsilatı Yapıldı"),
                contains("Göztepe 2+1")
        );

        // Check agent notification
        verify(notificationRepository).save(argThat(n ->
                n.getUserId().equals(3L) &&
                n.getTitle().equals("Kira Tahsilatı Yapıldı") &&
                n.getType().equals("PAYMENT_SUCCESS")
        ));
    }

    @Test
    void testNotifyMethods_SafeWhenPeriodOrLeaseIsNull() {
        notificationService.notifyLandlordForReceipt(null);
        notificationService.notifyPaymentSuccess(null);

        RentPeriod emptyPeriod = new RentPeriod();
        notificationService.notifyLandlordForReceipt(emptyPeriod);
        notificationService.notifyPaymentSuccess(emptyPeriod);

        verifyNoInteractions(emailService);
        verify(notificationRepository, never()).save(any());
    }

    @Test
    void testNotifyManagerAssigned_Success() {
        when(userRepository.findByEmail("can@emlak.com")).thenReturn(java.util.Optional.of(agent));

        com.ars.kirazbackend.event.ManagerAssignedEvent event =
                new com.ars.kirazbackend.event.ManagerAssignedEvent(10L, "Göztepe 2+1", "can@emlak.com", "Ali Kaya");

        notificationService.notifyManagerAssigned(event);

        verify(notificationRepository).save(argThat(n ->
                n.getUserId().equals(3L) &&
                n.getTitle().equals("Yeni Mülk Yetkilendirmesi") &&
                n.getType().equals("MANAGER_ASSIGNED")
        ));

        verify(emailService).sendNotificationEmail(
                eq("can@emlak.com"),
                contains("Yeni Mülk Yetkilendirmesi"),
                contains("Ali Kaya")
        );
    }
}
