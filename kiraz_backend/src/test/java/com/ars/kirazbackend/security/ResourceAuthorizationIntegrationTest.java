package com.ars.kirazbackend.security;

import com.ars.kirazbackend.dto.PayTrInitRequest;
import com.ars.kirazbackend.dto.PropertyRequest;
import com.ars.kirazbackend.entity.*;
import com.ars.kirazbackend.enums.*;
import com.ars.kirazbackend.repository.*;
import com.ars.kirazbackend.service.PayTrService;
import com.ars.kirazbackend.support.AuthTestHelper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class ResourceAuthorizationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PropertyRepository propertyRepository;

    @Autowired
    private LeaseAgreementRepository leaseRepository;

    @Autowired
    private RentPeriodRepository periodRepository;

    @Autowired
    private PropertyDelegationRepository delegationRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private PayTrService payTrService;

    private User landlordA;
    private User landlordB;
    private User tenantA;
    private User tenantB;
    private User agentValid;
    private User agentRevoked;
    private User agentExpired;

    private Property propertyA;
    private Property propertyB;

    private LeaseAgreement leaseA;
    private LeaseAgreement leaseB;

    private RentPeriod periodA;
    private RentPeriod periodB;

    private Notification notificationA;

    @BeforeEach
    void setUp() {
        notificationRepository.deleteAll();
        periodRepository.deleteAll();
        delegationRepository.deleteAll();
        leaseRepository.deleteAll();
        propertyRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        // 1. Users
        landlordA = userRepository.save(User.builder()
                .fullName("Ev Sahibi A")
                .email("landlordA@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.LANDLORD)
                .build());

        landlordB = userRepository.save(User.builder()
                .fullName("Ev Sahibi B")
                .email("landlordB@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.LANDLORD)
                .build());

        tenantA = userRepository.save(User.builder()
                .fullName("Kiracı A")
                .email("tenantA@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.TENANT)
                .build());

        tenantB = userRepository.save(User.builder()
                .fullName("Kiracı B")
                .email("tenantB@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.TENANT)
                .build());

        agentValid = userRepository.save(User.builder()
                .fullName("Vekil Emlakçı")
                .email("agentValid@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.AGENT)
                .build());

        agentRevoked = userRepository.save(User.builder()
                .fullName("İptal Edilmiş Emlakçı")
                .email("agentRevoked@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.AGENT)
                .build());

        agentExpired = userRepository.save(User.builder()
                .fullName("Süresi Dolmuş Emlakçı")
                .email("agentExpired@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.AGENT)
                .build());

        // 2. Properties
        propertyA = propertyRepository.save(Property.builder()
                .title("Mülk A - Kadıköy")
                .address("Moda Cad. No:1")
                .city("İstanbul")
                .landlord(landlordA)
                .build());

        propertyB = propertyRepository.save(Property.builder()
                .title("Mülk B - Beşiktaş")
                .address("Çarşı Cad. No:2")
                .city("İstanbul")
                .landlord(landlordB)
                .build());

        // 3. Delegations on Property A
        delegationRepository.save(PropertyDelegation.builder()
                .property(propertyA)
                .agent(agentValid)
                .grantedBy(landlordA)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now().minusDays(10))
                .endDate(LocalDate.now().plusMonths(6))
                .build());

        delegationRepository.save(PropertyDelegation.builder()
                .property(propertyA)
                .agent(agentRevoked)
                .grantedBy(landlordA)
                .status(DelegationStatus.REVOKED)
                .startDate(LocalDate.now().minusDays(30))
                .endDate(LocalDate.now().plusMonths(6))
                .build());

        delegationRepository.save(PropertyDelegation.builder()
                .property(propertyA)
                .agent(agentExpired)
                .grantedBy(landlordA)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now().minusDays(60))
                .endDate(LocalDate.now().minusDays(1)) // Expired yesterday
                .build());

        // 4. Leases
        leaseA = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(landlordA)
                .monthlyRentAmount(BigDecimal.valueOf(15000))
                .depositAmount(BigDecimal.valueOf(30000))
                .startDate(LocalDate.now().minusMonths(1))
                .endDate(LocalDate.now().plusMonths(11))
                .status(LeaseStatus.ACTIVE)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .build());

        leaseB = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyB)
                .tenant(tenantB)
                .createdBy(landlordB)
                .monthlyRentAmount(BigDecimal.valueOf(20000))
                .depositAmount(BigDecimal.valueOf(40000))
                .startDate(LocalDate.now().minusMonths(1))
                .endDate(LocalDate.now().plusMonths(11))
                .status(LeaseStatus.ACTIVE)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .build());

        // 5. Rent Periods
        periodA = periodRepository.save(RentPeriod.builder()
                .leaseAgreement(leaseA)
                .month(11)
                .year(2026)
                .periodStart(LocalDate.now())
                .status(PaymentStatus.PENDING)
                .build());

        periodB = periodRepository.save(RentPeriod.builder()
                .leaseAgreement(leaseB)
                .month(11)
                .year(2026)
                .periodStart(LocalDate.now())
                .status(PaymentStatus.PENDING)
                .build());

        // 6. Notifications
        notificationA = notificationRepository.save(Notification.builder()
                .userId(tenantA.getId())
                .title("Kira Hatırlatması")
                .message("Kasım ayı kiranız yaklaşmaktadır.")
                .isRead(false)
                .build());
    }

    // ==========================================
    // 1. Ev Sahibi A <-> Ev Sahibi B (Mülk IDOR)
    // ==========================================

    @Test
    void testProperty_LandlordA_CanAccessOwn_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(propertyA.getId()))
                .andExpect(jsonPath("$.title").value("Mülk A - Kadıköy"));
    }

    @Test
    void testProperty_LandlordB_CannotAccessPropertyA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(landlordB);

        mockMvc.perform(get("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.error").value("Not Found"));
    }

    @Test
    void testProperty_CreateProperty_ForcesAuthenticatedUserAsLandlord() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(landlordA);

        PropertyRequest request = new PropertyRequest();
        request.setTitle("Yeni Villa");
        request.setAddress("Bağdat Cad. No:5");
        request.setCity("İstanbul");
        request.setLandlordId(landlordB.getId()); // Try to forge landlordB ID in body

        mockMvc.perform(post("/api/properties")
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Yeni Villa"))
                .andExpect(jsonPath("$.landlord.id").value(landlordA.getId())); // Strictly forced to landlordA
    }

    // ==========================================
    // 2. Ev Sahibi A <-> Ev Sahibi B (Sözleşme IDOR)
    // ==========================================

    @Test
    void testLease_LandlordA_CanAccessOwnLease_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/leases/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(leaseA.getId()));
    }

    @Test
    void testLease_LandlordB_CannotAccessLeaseA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(landlordB);

        mockMvc.perform(get("/api/leases/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testLease_LandlordB_CannotApproveLeaseA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(landlordB);

        mockMvc.perform(put("/api/leases/" + leaseA.getId() + "/approve")
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ==========================================
    // 3. Kiracı A <-> Kiracı B (Sözleşme & Dönem IDOR)
    // ==========================================

    @Test
    void testLease_TenantA_CanAccessOwnLease_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(tenantA);

        mockMvc.perform(get("/api/leases/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(leaseA.getId()));
    }

    @Test
    void testLease_TenantB_CannotAccessLeaseA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(tenantB);

        mockMvc.perform(get("/api/leases/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testPeriod_TenantA_CanAccessOwnPeriod_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(tenantA);

        mockMvc.perform(get("/api/periods/" + periodA.getId())
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(periodA.getId()));
    }

    @Test
    void testPeriod_TenantB_CannotAccessPeriodA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(tenantB);

        mockMvc.perform(get("/api/periods/" + periodA.getId())
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ==========================================
    // 4. Ödeme ve Dekont Yetkilendirmesi
    // ==========================================

    @Test
    void testPayment_TenantA_CanInitializePaymentForOwnPeriod_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(tenantA);

        when(payTrService.initializePayment(eq(periodA.getId()), anyString(), anyString()))
                .thenReturn(com.ars.kirazbackend.dto.PayTrInitResponse.builder()
                        .status("success")
                        .token("mock_token")
                        .build());

        PayTrInitRequest request = new PayTrInitRequest(periodA.getId(), tenantA.getEmail());

        mockMvc.perform(post("/api/payments/paytr/initialize")
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("success"));
    }

    @Test
    void testPayment_TenantB_CannotInitializePaymentForPeriodA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(tenantB);

        PayTrInitRequest request = new PayTrInitRequest(periodA.getId(), tenantB.getEmail());

        mockMvc.perform(post("/api/payments/paytr/initialize")
                        .header("Authorization", "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testReceipt_TenantB_CannotUploadReceiptForPeriodA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(tenantB);

        MockMultipartFile file = new MockMultipartFile(
                "file", "dekont.pdf", "application/pdf", "dummy content".getBytes()
        );

        mockMvc.perform(multipart("/api/payments/" + periodA.getId() + "/receipt")
                        .file(file)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testReceipt_LandlordB_CannotApproveReceiptForPeriodA_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(landlordB);

        mockMvc.perform(post("/api/landlord/receipts/" + periodA.getId() + "/approve")
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ==========================================
    // 5. Emlakçı Yetkilendirmesi (Aktif, İptal, Süresi Dolmuş)
    // ==========================================

    @Test
    void testDelegation_ValidAgent_CanAccessPropertyAndLease_Returns200() throws Exception {
        String tokenAgent = AuthTestHelper.generateValidToken(agentValid);

        mockMvc.perform(get("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenAgent))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(propertyA.getId()));

        mockMvc.perform(get("/api/leases/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenAgent))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(leaseA.getId()));
    }

    @Test
    void testDelegation_RevokedAgent_CannotAccessProperty_Returns404() throws Exception {
        String tokenRevoked = AuthTestHelper.generateValidToken(agentRevoked);

        mockMvc.perform(get("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenRevoked))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testDelegation_ExpiredAgent_CannotAccessProperty_Returns404() throws Exception {
        String tokenExpired = AuthTestHelper.generateValidToken(agentExpired);

        mockMvc.perform(get("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenExpired))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ==========================================
    // 6. Bildirimler ve Denetim İzi IDOR
    // ==========================================

    @Test
    void testNotification_TenantA_CanMarkOwnAsRead_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(tenantA);

        mockMvc.perform(put("/api/notifications/" + notificationA.getId() + "/read")
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.read").value(true));
    }

    @Test
    void testNotification_TenantB_CannotMarkNotificationAAsRead_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(tenantB);

        mockMvc.perform(put("/api/notifications/" + notificationA.getId() + "/read")
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testAuditLog_LandlordA_CanViewOwnLogs_Returns200() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/audit-logs")
                        .param("entityName", "PROPERTY")
                        .param("entityId", propertyA.getId().toString())
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk());
    }

    @Test
    void testAuditLog_LandlordB_CannotViewPropertyALogs_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(landlordB);

        mockMvc.perform(get("/api/audit-logs")
                        .param("entityName", "PROPERTY")
                        .param("entityId", propertyA.getId().toString())
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ==========================================
    // 7. Kaldırılan Uç Noktalar (PUT /api/periods/{id}/status)
    // ==========================================

    @Test
    void testRemovedEndpoint_PeriodStatus_IsNotFound() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(put("/api/periods/" + periodA.getId() + "/status")
                        .param("status", "PAID")
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isNotFound()); // Endpoint has been removed completely
    }
}
