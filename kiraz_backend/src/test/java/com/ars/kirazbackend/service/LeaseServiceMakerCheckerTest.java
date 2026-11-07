package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.LeaseRequest;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.LeaseApprovalStatus;
import com.ars.kirazbackend.enums.LeaseStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LeaseServiceMakerCheckerTest {

    @Mock
    private LeaseAgreementRepository leaseRepository;

    @Mock
    private PropertyRepository propertyRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private RentPeriodRepository rentPeriodRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private NotificationService notificationService;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private EmailService emailService;

    @Mock
    private PropertyDelegationService propertyDelegationService;

    @Mock
    private AuditLogService auditLogService;

    @InjectMocks
    private LeaseService leaseService;

    private User landlord;
    private User agent;
    private User tenant;
    private Property property;

    @BeforeEach
    void setUp() {
        landlord = User.builder()
                .id(1L)
                .fullName("Ahmet Ev Sahibi")
                .email("ahmet@evsahibi.com")
                .role(RoleType.LANDLORD)
                .build();

        agent = User.builder()
                .id(2L)
                .fullName("Mehmet Emlak")
                .email("mehmet@emlak.com")
                .role(RoleType.AGENT)
                .build();

        tenant = User.builder()
                .id(3L)
                .fullName("Can Kiracı")
                .email("can@kiraci.com")
                .role(RoleType.TENANT)
                .build();

        property = Property.builder()
                .id(10L)
                .title("Levent Rezidans")
                .landlord(landlord)
                .build();
    }

    @Test
    void testAgentCreatesLease_WithActiveDelegation_SetsPendingLandlordApproval() {
        LeaseRequest request = LeaseRequest.builder()
                .propertyId(10L)
                .tenantEmail("can@kiraci.com")
                .agentId(2L)
                .monthlyRentAmount(BigDecimal.valueOf(25000))
                .startDate("2026-11-01")
                .endDate(LocalDate.of(2027, 11, 1))
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findByEmail("can@kiraci.com")).thenReturn(Optional.of(tenant));
        when(userRepository.findById(2L)).thenReturn(Optional.of(agent));
        when(propertyDelegationService.hasActiveDelegation(10L, 2L)).thenReturn(true);
        when(leaseRepository.save(any(LeaseAgreement.class)))
                .thenAnswer(invocation -> {
                    LeaseAgreement la = invocation.getArgument(0);
                    la.setId(100L);
                    return la;
                });

        LeaseAgreement createdLease = leaseService.createLease(request);

        assertNotNull(createdLease);
        assertEquals(LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL, createdLease.getApprovalStatus());
        assertEquals(LeaseStatus.PENDING, createdLease.getStatus());
        assertEquals(agent, createdLease.getCreatedBy());

        // Verify landlord notification sent
        verify(notificationService, times(1)).createNotification(
                eq(1L), contains("Onay Bekleyen"), any(), eq("LEASE_APPROVAL_REQUEST"), eq(100L)
        );
        verify(auditLogService, times(1)).record(
                eq("LEASE_AGREEMENT"), eq(100L), eq("LEASE_CREATED_BY_AGENT"), eq(agent), any()
        );
    }

    @Test
    void testAgentCreatesLease_WithoutActiveDelegation_ThrowsSecurityException() {
        LeaseRequest request = LeaseRequest.builder()
                .propertyId(10L)
                .tenantEmail("can@kiraci.com")
                .agentId(2L)
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findByEmail("can@kiraci.com")).thenReturn(Optional.of(tenant));
        when(userRepository.findById(2L)).thenReturn(Optional.of(agent));
        when(propertyDelegationService.hasActiveDelegation(10L, 2L)).thenReturn(false);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> leaseService.createLease(request));
        assertTrue(ex.getMessage().contains("aktif emlakçı vekaletiniz"));
        verify(leaseRepository, never()).save(any());
    }

    @Test
    void testLandlordApproveLease_SetsStatusActive() {
        LeaseAgreement pendingLease = LeaseAgreement.builder()
                .id(200L)
                .property(property)
                .tenant(tenant)
                .createdBy(agent)
                .approvalStatus(LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL)
                .status(LeaseStatus.PENDING)
                .build();

        when(leaseRepository.findById(200L)).thenReturn(Optional.of(pendingLease));
        when(leaseRepository.save(any(LeaseAgreement.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        LeaseAgreement approved = leaseService.approveLease(200L, 1L);

        assertEquals(LeaseApprovalStatus.ACTIVE, approved.getApprovalStatus());
        assertEquals(LeaseStatus.ACTIVE, approved.getStatus());

        // Verify notifications to agent and tenant
        verify(notificationService, times(1)).createNotification(
                eq(2L), contains("Onaylandı"), any(), eq("LEASE_APPROVED"), eq(200L)
        );
        verify(notificationService, times(1)).createNotification(
                eq(3L), contains("Onaylandı"), any(), eq("LEASE_APPROVED"), eq(200L)
        );
        verify(auditLogService, times(1)).record(
                eq("LEASE_AGREEMENT"), eq(200L), eq("LEASE_APPROVED"), eq(landlord), any()
        );
    }

    @Test
    void testLandlordRejectLease_SetsStatusCancelledAndRejected() {
        LeaseAgreement pendingLease = LeaseAgreement.builder()
                .id(200L)
                .property(property)
                .tenant(tenant)
                .createdBy(agent)
                .approvalStatus(LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL)
                .status(LeaseStatus.PENDING)
                .build();

        when(leaseRepository.findById(200L)).thenReturn(Optional.of(pendingLease));
        when(leaseRepository.save(any(LeaseAgreement.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        LeaseAgreement rejected = leaseService.rejectLease(200L, 1L, "Kira bedeli düşük");

        assertEquals(LeaseApprovalStatus.REJECTED, rejected.getApprovalStatus());
        assertEquals(LeaseStatus.CANCELLED, rejected.getStatus());
        assertEquals("Kira bedeli düşük", rejected.getRejectionReason());

        verify(notificationService, times(1)).createNotification(
                eq(2L), contains("Reddedildi"), any(), eq("LEASE_REJECTED"), eq(200L)
        );
        verify(auditLogService, times(1)).record(
                eq("LEASE_AGREEMENT"), eq(200L), eq("LEASE_REJECTED"), eq(landlord), any()
        );
    }
}
