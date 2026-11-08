package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PropertyDelegationRequest;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.DelegationStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.PropertyDelegationRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PropertyDelegationServiceTest {

    @Mock
    private PropertyDelegationRepository delegationRepository;

    @Mock
    private PropertyRepository propertyRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private EmailService emailService;

    @Mock
    private KafkaProducerService kafkaProducerService;

    @InjectMocks
    private PropertyDelegationService delegationService;

    private User landlord;
    private User agent;
    private Property property;

    @BeforeEach
    void setUp() {
        landlord = User.builder()
                .id(1L)
                .fullName("Ev Sahibi")
                .email("landlord@example.com")
                .role(RoleType.LANDLORD)
                .build();

        agent = User.builder()
                .id(2L)
                .fullName("Emlakçı Danışman")
                .email("agent@example.com")
                .role(RoleType.AGENT)
                .referenceCode("AGT-12345678")
                .build();

        property = Property.builder()
                .id(10L)
                .title("Kadıköy 2+1 Daire")
                .landlord(landlord)
                .build();
    }

    @Test
    void testAssignAgent_SuccessWithAgentId() {
        PropertyDelegationRequest request = PropertyDelegationRequest.builder()
                .propertyId(10L)
                .agentId(2L)
                .landlordId(1L)
                .startDate(LocalDate.now())
                .endDate(LocalDate.now().plusMonths(6))
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findById(2L)).thenReturn(Optional.of(agent));
        when(userRepository.findById(1L)).thenReturn(Optional.of(landlord));
        when(delegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE))
                .thenReturn(new ArrayList<>());
        when(delegationRepository.save(any(PropertyDelegation.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        PropertyDelegation result = delegationService.assignAgent(request);

        assertNotNull(result);
        assertEquals(DelegationStatus.ACTIVE, result.getStatus());
        assertEquals(property, result.getProperty());
        assertEquals(agent, result.getAgent());
        assertEquals(landlord, result.getGrantedBy());
        assertEquals("AGT-12345678", result.getReferenceCode());

        verify(auditLogService, times(1)).record(eq("PROPERTY_DELEGATION"), any(), eq("DELEGATION_ASSIGNED"), eq(landlord), any());
        verify(notificationService, times(1)).createNotification(eq(2L), any(), any(), eq("DELEGATION"), any());
    }

    @Test
    void testAssignAgent_WhenAgentDoesNotExist_CreatesPlaceholderAndSendsInviteEmail() {
        PropertyDelegationRequest request = PropertyDelegationRequest.builder()
                .propertyId(10L)
                .agentEmail("newagent@emlak.com")
                .agentName("Yeni Emlak Danışmanı")
                .landlordId(1L)
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findById(1L)).thenReturn(Optional.of(landlord));
        when(userRepository.findByEmail("newagent@emlak.com")).thenReturn(Optional.empty());
        when(userRepository.findByReferenceCode(anyString())).thenReturn(Optional.empty());
        when(passwordEncoder.encode(anyString())).thenReturn("hashed_placeholder_pwd");

        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User u = invocation.getArgument(0);
            u.setId(99L);
            return u;
        });

        when(delegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE))
                .thenReturn(new ArrayList<>());
        when(delegationRepository.save(any(PropertyDelegation.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        PropertyDelegation result = delegationService.assignAgent(request);

        assertNotNull(result);
        assertNotNull(result.getAgent());
        assertEquals(RoleType.AGENT, result.getAgent().getRole());
        assertEquals("newagent@emlak.com", result.getAgent().getEmail());
        assertTrue(result.getAgent().getReferenceCode().startsWith("AGT-"));
        assertEquals(result.getAgent().getReferenceCode(), result.getReferenceCode());

        // Verify invite email sent
        verify(emailService, times(1)).sendAgentInviteEmail(
                eq("newagent@emlak.com"),
                eq("Yeni Emlak Danışmanı"),
                eq("Kadıköy 2+1 Daire"),
                contains("AGT-")
        );
    }

    @Test
    void testAssignAgent_PreservesHistoryWhenExistingActiveDelegationPresent() {
        User oldAgent = User.builder().id(3L).fullName("Eski Emlakçı").role(RoleType.AGENT).build();
        PropertyDelegation oldDelegation = PropertyDelegation.builder()
                .id(99L)
                .property(property)
                .agent(oldAgent)
                .grantedBy(landlord)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now().minusMonths(3))
                .build();

        PropertyDelegationRequest request = PropertyDelegationRequest.builder()
                .propertyId(10L)
                .agentId(2L)
                .landlordId(1L)
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findById(2L)).thenReturn(Optional.of(agent));
        when(userRepository.findById(1L)).thenReturn(Optional.of(landlord));
        when(delegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE))
                .thenReturn(new ArrayList<>(List.of(oldDelegation)));
        when(delegationRepository.save(any(PropertyDelegation.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        PropertyDelegation result = delegationService.assignAgent(request);

        // Verify old delegation status was updated to REVOKED, not deleted or overwritten!
        assertEquals(DelegationStatus.REVOKED, oldDelegation.getStatus());
        assertNotNull(oldDelegation.getRevokedAt());

        // New delegation is active
        assertEquals(DelegationStatus.ACTIVE, result.getStatus());
        assertEquals(agent, result.getAgent());
    }

    @Test
    void testAssignAgent_ThrowsWhenUserIsNotAgent() {
        User tenantUser = User.builder().id(5L).role(RoleType.TENANT).build();
        PropertyDelegationRequest request = PropertyDelegationRequest.builder()
                .propertyId(10L)
                .agentId(5L)
                .landlordId(1L)
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findById(5L)).thenReturn(Optional.of(tenantUser));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> delegationService.assignAgent(request));
        assertTrue(ex.getMessage().contains("AGENT"));
    }

    @Test
    void testRevokeDelegation_Success() {
        PropertyDelegation delegation = PropertyDelegation.builder()
                .id(50L)
                .property(property)
                .agent(agent)
                .grantedBy(landlord)
                .status(DelegationStatus.ACTIVE)
                .build();

        when(delegationRepository.findById(50L)).thenReturn(Optional.of(delegation));
        when(delegationRepository.save(any(PropertyDelegation.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        PropertyDelegation result = delegationService.revokeDelegation(50L, 1L, "Yetki sonlandırıldı");

        assertEquals(DelegationStatus.REVOKED, result.getStatus());
        assertNotNull(result.getRevokedAt());
        assertEquals("Yetki sonlandırıldı", result.getRevocationReason());
        verify(auditLogService, times(1)).record(eq("PROPERTY_DELEGATION"), eq(50L), eq("DELEGATION_REVOKED"), eq(landlord), any());
    }

    @Test
    void testHasActiveDelegation_ExpiredDelegationMarkedExpired() {
        PropertyDelegation expiredDelegation = PropertyDelegation.builder()
                .id(77L)
                .property(property)
                .agent(agent)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now().minusMonths(6))
                .endDate(LocalDate.now().minusDays(1)) // Expired yesterday
                .build();

        when(delegationRepository.findByAgentIdAndStatus(2L, DelegationStatus.ACTIVE))
                .thenReturn(List.of(expiredDelegation));

        boolean hasActive = delegationService.hasActiveDelegation(10L, 2L);

        assertFalse(hasActive);
        assertEquals(DelegationStatus.EXPIRED, expiredDelegation.getStatus());
        verify(delegationRepository, times(1)).save(expiredDelegation);
    }

    @Test
    void testAssignManager_Success() {
        User manager = User.builder()
                .id(15L)
                .email("manager@emlak.com")
                .fullName("Mülk Yöneticisi")
                .role(RoleType.PROPERTY_MANAGER)
                .build();

        when(propertyRepository.findById(10L)).thenReturn(Optional.of(property));
        when(userRepository.findByEmail("manager@emlak.com")).thenReturn(Optional.of(manager));
        when(delegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE))
                .thenReturn(new ArrayList<>());
        when(delegationRepository.save(any(PropertyDelegation.class)))
                .thenAnswer(inv -> {
                    PropertyDelegation pd = inv.getArgument(0);
                    pd.setId(88L);
                    return pd;
                });

        com.ars.kirazbackend.dto.DelegationRequestDto request =
                new com.ars.kirazbackend.dto.DelegationRequestDto(10L, "manager@emlak.com");

        com.ars.kirazbackend.dto.DelegationResponseDto response = delegationService.assignManager(request, landlord);

        assertNotNull(response);
        assertEquals(88L, response.id());
        assertEquals("Kadıköy 2+1 Daire", response.propertyName());
        assertEquals("Mülk Yöneticisi", response.managerName());
        assertEquals("manager@emlak.com", response.managerEmail());
        assertEquals("ACTIVE", response.status());

        assertEquals("DELEGATED", property.getStatus());
        verify(propertyRepository).save(property);
        verify(kafkaProducerService).sendManagerAssignedEvent(any(com.ars.kirazbackend.event.ManagerAssignedEvent.class));
    }

    @Test
    void testRevokeDelegation_RestoresPropertyStatusWhenNoActive() {
        property.setStatus("DELEGATED");
        PropertyDelegation delegation = PropertyDelegation.builder()
                .id(88L)
                .property(property)
                .agent(agent)
                .grantedBy(landlord)
                .status(DelegationStatus.ACTIVE)
                .build();

        when(delegationRepository.findById(88L)).thenReturn(Optional.of(delegation));
        when(delegationRepository.save(any(PropertyDelegation.class))).thenAnswer(inv -> inv.getArgument(0));
        when(delegationRepository.findByPropertyIdAndStatus(10L, DelegationStatus.ACTIVE)).thenReturn(List.of());

        com.ars.kirazbackend.dto.DelegationResponseDto response = delegationService.revokeDelegation(88L);

        assertNotNull(response);
        assertEquals("REVOKED", response.status());
        assertEquals("AVAILABLE", property.getStatus());
        verify(propertyRepository).save(property);
    }

    @Test
    void testGetLandlordDelegations() {
        PropertyDelegation delegation = PropertyDelegation.builder()
                .id(88L)
                .property(property)
                .agent(agent)
                .grantedBy(landlord)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now())
                .build();

        when(delegationRepository.findByGrantedByIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(delegation));

        List<com.ars.kirazbackend.dto.DelegationResponseDto> result = delegationService.getLandlordDelegations(1L);

        assertEquals(1, result.size());
        assertEquals("Kadıköy 2+1 Daire", result.get(0).propertyName());
    }

    @Test
    void testGetManagerProperties() {
        PropertyDelegation delegation = PropertyDelegation.builder()
                .id(88L)
                .property(property)
                .agent(agent)
                .status(DelegationStatus.ACTIVE)
                .build();

        when(delegationRepository.findByAgentIdAndStatus(2L, DelegationStatus.ACTIVE))
                .thenReturn(List.of(delegation));

        List<Property> result = delegationService.getManagerProperties(2L);

        assertEquals(1, result.size());
        assertEquals(10L, result.get(0).getId());
    }
}
