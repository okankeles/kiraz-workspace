package com.ars.kirazbackend.security;

import com.ars.kirazbackend.config.InviteRateLimitingFilter;
import com.ars.kirazbackend.dto.LoginRequest;
import com.ars.kirazbackend.dto.PropertyRequest;
import com.ars.kirazbackend.dto.RefreshTokenRequest;
import com.ars.kirazbackend.entity.*;
import com.ars.kirazbackend.enums.*;
import com.ars.kirazbackend.repository.*;
import com.ars.kirazbackend.service.LeaseService;
import com.ars.kirazbackend.support.AuthTestHelper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.startsWith;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Faz 0 / Adım 6: 16 Güvenlik ve Uçtan Uca Yetkilendirme Senaryosunun
 * Tamamını Doğrulayan Entegre Test Sınıfı.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class SecurityValidationEndToEndTest {

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
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private AuditLogRepository auditLogRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private InviteRateLimitingFilter inviteRateLimitingFilter;

    @Autowired
    private ObjectMapper objectMapper;

    @Value("${spring.datasource.url}")
    private String dbUrl;

    @Value("${spring.datasource.username}")
    private String dbUsername;

    @Value("${spring.datasource.password}")
    private String dbPassword;

    private User landlordA;
    private User landlordB;
    private User tenantA;
    private User tenantB;
    private User agentValid;
    private User agentRevoked;

    private Property propertyA;
    private Property propertyB;

    private LeaseAgreement leaseA;
    private RentPeriod periodA;
    private Path testReceiptPath;

    @BeforeEach
    void setUp() throws Exception {
        inviteRateLimitingFilter.resetForTesting();
        auditLogRepository.deleteAll();
        periodRepository.deleteAll();
        delegationRepository.deleteAll();
        leaseRepository.deleteAll();
        propertyRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        // 1. Kullanıcılar (@example.com)
        landlordA = userRepository.save(User.builder()
                .fullName("Ev Sahibi A")
                .email("landlord_a@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.LANDLORD)
                .build());

        landlordB = userRepository.save(User.builder()
                .fullName("Ev Sahibi B")
                .email("landlord_b@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.LANDLORD)
                .build());

        tenantA = userRepository.save(User.builder()
                .fullName("Kiracı A")
                .email("tenant_a@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.TENANT)
                .build());

        tenantB = userRepository.save(User.builder()
                .fullName("Kiracı B")
                .email("tenant_b@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.TENANT)
                .build());

        agentValid = userRepository.save(User.builder()
                .fullName("Yetkili Emlakçı")
                .email("agent_valid@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.AGENT)
                .build());

        agentRevoked = userRepository.save(User.builder()
                .fullName("Yetkisi İptal Emlakçı")
                .email("agent_revoked@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.AGENT)
                .build());

        // 2. Mülkler
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

        // 3. Delegasyonlar
        delegationRepository.save(PropertyDelegation.builder()
                .property(propertyA)
                .agent(agentValid)
                .grantedBy(landlordA)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now().minusDays(5))
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

        // 4. Test dosyası
        Path uploadDir = Paths.get("target/test-uploads/receipts").toAbsolutePath().normalize();
        Files.createDirectories(uploadDir);
        testReceiptPath = uploadDir.resolve("receipt_a.png");
        byte[] pngHeader = new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3};
        Files.write(testReceiptPath, pngHeader);

        // 5. Sözleşme ve Dönem
        leaseA = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(landlordA)
                .monthlyRentAmount(BigDecimal.valueOf(25000))
                .depositAmount(BigDecimal.valueOf(50000))
                .paymentDay(5)
                .startDate(LocalDate.now().minusMonths(1))
                .endDate(LocalDate.now().plusMonths(11))
                .status(LeaseStatus.ACTIVE)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .inviteCode(LeaseService.generateInviteCode())
                .inviteCodeUsed(true)
                .build());

        periodA = periodRepository.save(RentPeriod.builder()
                .leaseAgreement(leaseA)
                .month(11)
                .year(2026)
                .periodStart(LocalDate.now())
                .status(PaymentStatus.WAITING_APPROVAL)
                .receiptFilePath(testReceiptPath.toString())
                .build());
    }

    // -------------------------------------------------------------
    // 1. X-User-Id header'ı ile başka kullanıcıyı taklit → 401
    // -------------------------------------------------------------
    @Test
    @Order(1)
    void scenario01_XUserIdSpoofing_Returns401() throws Exception {
        mockMvc.perform(get("/api/landlord/dashboard")
                        .header("X-User-Id", landlordA.getId().toString()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.error").value("Unauthorized"));
    }

    // -------------------------------------------------------------
    // 2. Ev sahibi A'nın token'ı ile ev sahibi B'nin mülkü ve dönemi → 403 / 404
    // -------------------------------------------------------------
    @Test
    @Order(2)
    void scenario02_LandlordA_CannotAccessPropertyB_Returns404() throws Exception {
        String tokenA = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/properties/" + propertyB.getId())
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // -------------------------------------------------------------
    // 3. Kiracı A'nın token'ı ile kiracı B'nin dönemine dekont yükleme → 403 / 404
    // -------------------------------------------------------------
    @Test
    @Order(3)
    void scenario03_TenantA_CannotUploadReceiptForTenantBPeriod_Returns404() throws Exception {
        String tokenB = AuthTestHelper.generateValidToken(tenantB);
        MockMultipartFile file = new MockMultipartFile("file", "dekont.png", "image/png",
                new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A});

        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(file)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // -------------------------------------------------------------
    // 4. Delegasyonu iptal edilmiş emlakçı ile mülke erişim → 403 / 404
    // -------------------------------------------------------------
    @Test
    @Order(4)
    void scenario04_RevokedAgent_CannotAccessProperty_Returns404() throws Exception {
        String tokenRevoked = AuthTestHelper.generateValidToken(agentRevoked);

        mockMvc.perform(get("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenRevoked))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // -------------------------------------------------------------
    // 5. Süresi dolmuş access token → 401; refresh sonrası aynı istek → 200
    // -------------------------------------------------------------
    @Test
    @Order(5)
    void scenario05_ExpiredAccessToken_Returns401_RefreshSucceeds200() throws Exception {
        // 1. Süresi dolmuş token ile istek -> 401
        String expiredToken = AuthTestHelper.generateExpiredToken(
                tenantA.getId(), tenantA.getEmail(), tenantA.getRole()
        );
        mockMvc.perform(get("/api/tenant/leases")
                        .header("Authorization", "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message", containsString("Token süresi dolmuş")));

        // 2. Login olarak geçerli refresh token al
        LoginRequest loginReq = new LoginRequest(tenantA.getEmail(), "Password123!");
        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andReturn();
        String refreshToken = objectMapper.readTree(loginResult.getResponse().getContentAsString())
                .get("refreshToken").asText();

        // 3. Token yenileme -> 200
        RefreshTokenRequest refreshReq = new RefreshTokenRequest(refreshToken);
        MvcResult refreshResult = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshReq)))
                .andExpect(status().isOk())
                .andReturn();
        String newAccessToken = objectMapper.readTree(refreshResult.getResponse().getContentAsString())
                .get("accessToken").asText();

        // 4. Yeni token ile aynı istek -> 200
        mockMvc.perform(get("/api/tenant/leases")
                        .header("Authorization", "Bearer " + newAccessToken))
                .andExpect(status().isOk());
    }

    // -------------------------------------------------------------
    // 6. Kullanılmış refresh token ile refresh → 401
    // -------------------------------------------------------------
    @Test
    @Order(6)
    void scenario06_ReusedRefreshToken_Returns401() throws Exception {
        LoginRequest loginReq = new LoginRequest(tenantA.getEmail(), "Password123!");
        MvcResult loginRes = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andReturn();
        String originalRefreshToken = objectMapper.readTree(loginRes.getResponse().getContentAsString())
                .get("refreshToken").asText();

        // İlk yenileme başarılı
        RefreshTokenRequest req1 = new RefreshTokenRequest(originalRefreshToken);
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req1)))
                .andExpect(status().isOk());

        // Kullanılmış token ile tekrar yenileme denemesi -> 401
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req1)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message", containsString("Kullanılmış bir refresh token")));
    }

    // -------------------------------------------------------------
    // 7. PayTR callback'ine geçersiz hash ile istek → reddediliyor (400)
    // -------------------------------------------------------------
    @Test
    @Order(7)
    void scenario07_PayTrCallback_InvalidHash_RejectedWith400() throws Exception {
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("merchant_oid", "RENT-16-1700000000");
        params.add("status", "success");
        params.add("total_amount", "25000");
        params.add("hash", "FORGED_HASH_CODE");

        // JWT gerektirmez, fakat geçersiz hash nedeniyle 400 Bad Request döner
        mockMvc.perform(post("/api/payments/paytr-callback")
                        .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                        .params(params))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    // -------------------------------------------------------------
    // 8. Kaldırılan PUT /api/periods/{id}/status → 404 veya 405
    // -------------------------------------------------------------
    @Test
    @Order(8)
    void scenario08_RemovedPeriodStatusEndpoint_Returns404() throws Exception {
        String token = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(put("/api/periods/" + periodA.getId() + "/status")
                        .param("status", "PAID")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------
    // 9. Token olmadan dosya erişimi → 401; Başka kiracının dekontu → 404
    // -------------------------------------------------------------
    @Test
    @Order(9)
    void scenario09_FileAccess_Unauthenticated401_OtherTenant404() throws Exception {
        // Token olmadan dosya stream denemesi -> 401
        mockMvc.perform(get("/api/files/receipts/" + periodA.getId()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));

        // Başka kiracının token'ı ile dekont erişimi -> 404
        String tokenB = AuthTestHelper.generateValidToken(tenantB);
        mockMvc.perform(get("/api/files/receipts/" + periodA.getId())
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // -------------------------------------------------------------
    // 10. Ev sahibi onayı olmayan sözleşmeyi kiracının aktive etmesi → 409
    // -------------------------------------------------------------
    @Test
    @Order(10)
    void scenario10_ActivateWithoutLandlordApproval_Returns409Conflict() throws Exception {
        LeaseAgreement agentLease = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(agentValid)
                .monthlyRentAmount(BigDecimal.valueOf(25000))
                .status(LeaseStatus.PENDING)
                .approvalStatus(LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL)
                .inviteCode(LeaseService.generateInviteCode())
                .build());

        String tenantToken = AuthTestHelper.generateValidToken(tenantA);

        mockMvc.perform(put("/api/leases/" + agentLease.getId() + "/activate")
                        .header("Authorization", "Bearer " + tenantToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message", containsString("Ev sahibi onayı olmadan")));
    }

    // -------------------------------------------------------------
    // 11. Süresi dolmuş veya kullanılmış davet kodu → reddediliyor; hız sınırı aşılınca → 429
    // -------------------------------------------------------------
    @Test
    @Order(11)
    void scenario11_InviteCodeValidation_AndRateLimit429() throws Exception {
        inviteRateLimitingFilter.resetForTesting();

        // 1. Süresi dolmuş davet kodu -> 400 Bad Request
        LeaseAgreement expiredLease = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(landlordA)
                .monthlyRentAmount(BigDecimal.valueOf(20000))
                .status(LeaseStatus.PENDING)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .inviteCode(LeaseService.generateInviteCode())
                .inviteCodeExpiresAt(LocalDateTime.now().minusDays(1))
                .inviteCodeUsed(false)
                .build());

        mockMvc.perform(get("/api/leases/validate-invite")
                        .param("inviteCode", expiredLease.getInviteCode())
                        .with(req -> { req.setRemoteAddr("198.51.100.77"); return req; }))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("süresi dolmuş")));

        // 2. Hız sınırı testi: 10 istek izinli, 11. istek 429
        for (int i = 1; i <= 10; i++) {
            mockMvc.perform(get("/api/leases/validate-invite")
                            .param("inviteCode", "NONEXISTENT_CODE")
                            .with(req -> { req.setRemoteAddr("198.51.100.88"); return req; }))
                    .andExpect(status().isNotFound());
        }

        mockMvc.perform(get("/api/leases/validate-invite")
                        .param("inviteCode", "NONEXISTENT_CODE")
                        .with(req -> { req.setRemoteAddr("198.51.100.88"); return req; }))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.status").value(429));
    }

    // -------------------------------------------------------------
    // 12. Deprecated / Silinmiş uçlar (Adım 5b sonrası) → 404 / 405
    // -------------------------------------------------------------
    @Test
    @Order(12)
    void scenario12_DeprecatedEndpoints_Return404() throws Exception {
        String token = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/properties/landlord").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/api/dashboard/landlord").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/api/leases/pending-approvals").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
        mockMvc.perform(get("/api/payments/summary").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
        mockMvc.perform(post("/api/delegations").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    // -------------------------------------------------------------
    // 13. PUT /api/properties/{id}: sahibi 200; başka ev sahibi 404; emlakçı ve kiracı 403
    // -------------------------------------------------------------
    @Test
    @Order(13)
    void scenario13_PutProperty_AuthorizationMatrix() throws Exception {
        String tokenOwner = AuthTestHelper.generateValidToken(landlordA);
        String tokenOtherLandlord = AuthTestHelper.generateValidToken(landlordB);
        String tokenAgent = AuthTestHelper.generateValidToken(agentValid);
        String tokenTenant = AuthTestHelper.generateValidToken(tenantA);

        PropertyRequest req = new PropertyRequest();
        req.setTitle("Güncellenmiş Başlık");
        req.setAddress("Moda Cad. No:10");
        req.setCity("İstanbul");

        // 1. Sahibi olan ev sahibi -> 200 OK
        mockMvc.perform(put("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenOwner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Güncellenmiş Başlık"));

        // 2. Başka ev sahibi -> 404 Not Found
        mockMvc.perform(put("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenOtherLandlord)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isNotFound());

        // 3. Emlakçı -> 403 Forbidden
        mockMvc.perform(put("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenAgent)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());

        // 4. Kiracı -> 403 Forbidden
        mockMvc.perform(put("/api/properties/" + propertyA.getId())
                        .header("Authorization", "Bearer " + tokenTenant)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    // -------------------------------------------------------------
    // 14. POST /api/landlord/leases/{id}/regenerate-invite: yeni kod çalışıyor, eski reddediliyor, aktifte 409
    // -------------------------------------------------------------
    @Test
    @Order(14)
    void scenario14_RegenerateInviteCode_LifecycleAndRules() throws Exception {
        String tokenLandlord = AuthTestHelper.generateValidToken(landlordA);
        String oldCode = "ARS-OLD11111111111111111111111111111";

        LeaseAgreement pendingLease = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .startDate(LocalDate.now())
                .endDate(LocalDate.now().plusYears(1))
                .monthlyRentAmount(BigDecimal.valueOf(20000))
                .status(LeaseStatus.PENDING)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .inviteCode(oldCode)
                .inviteCodeExpiresAt(LocalDateTime.now().minusDays(1))
                .inviteCodeUsed(false)
                .build());

        // 1. Yeni kod üretimi -> 200 OK
        MvcResult res = mockMvc.perform(post("/api/landlord/leases/" + pendingLease.getId() + "/regenerate-invite")
                        .header("Authorization", "Bearer " + tokenLandlord))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.inviteCode", startsWith("ARS-")))
                .andReturn();

        String newCode = objectMapper.readTree(res.getResponse().getContentAsString()).get("inviteCode").asText();
        assertNotEquals(oldCode, newCode);

        // 2. Eski kod artık geçersiz -> 404
        mockMvc.perform(get("/api/leases/validate-invite").param("inviteCode", oldCode))
                .andExpect(status().isNotFound());

        // 3. Yeni kod doğrulanabilir -> 200
        mockMvc.perform(get("/api/leases/validate-invite").param("inviteCode", newCode))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.leaseId").value(pendingLease.getId()));

        // 4. Kiracısı bağlanmış (ACTIVE) sözleşmede kod yenileme denenirse -> 409 Conflict
        mockMvc.perform(post("/api/landlord/leases/" + leaseA.getId() + "/regenerate-invite")
                        .header("Authorization", "Bearer " + tokenLandlord))
                .andExpect(status().isConflict());
    }

    // -------------------------------------------------------------
    // 15. Sözleşme ve dekont yüklemede yalnızca PDF, JPEG ve PNG kabul ediliyor (WEBP ve TXT → 400)
    // -------------------------------------------------------------
    @Test
    @Order(15)
    void scenario15_FileUploadValidation_OnlyPdfJpegPngAllowed_WebpAndTxtRejected() throws Exception {
        String tokenTenant = AuthTestHelper.generateValidToken(tenantA);
        String tokenLandlord = AuthTestHelper.generateValidToken(landlordA);

        byte[] txtBytes = "Bu duz bir metin dosyasidir".getBytes();
        byte[] webpBytes = "RIFF\u0024\u0000\u0000\u0000WEBPVP8 ".getBytes();
        byte[] pngBytes = new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3};
        byte[] pdfBytes = "%PDF-1.4\n%contract test content".getBytes();

        MockMultipartFile txtFile = new MockMultipartFile("file", "test.txt", "text/plain", txtBytes);
        MockMultipartFile webpFile = new MockMultipartFile("file", "test.webp", "image/webp", webpBytes);
        MockMultipartFile pngFile = new MockMultipartFile("file", "test.png", "image/png", pngBytes);
        MockMultipartFile pdfFile = new MockMultipartFile("file", "test.pdf", "application/pdf", pdfBytes);

        // 1. Dekont: TXT -> 400
        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(txtFile)
                        .header("Authorization", "Bearer " + tokenTenant))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("Yalnızca PDF, JPEG ve PNG")));

        // 2. Dekont: WEBP -> 400
        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(webpFile)
                        .header("Authorization", "Bearer " + tokenTenant))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("Yalnızca PDF, JPEG ve PNG")));

        // 3. Dekont: PNG -> 200
        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(pngFile)
                        .header("Authorization", "Bearer " + tokenTenant))
                .andExpect(status().isOk());

        // 4. Sözleşme: TXT -> 400
        mockMvc.perform(multipart("/api/leases/" + leaseA.getId() + "/contract")
                        .file(txtFile)
                        .header("Authorization", "Bearer " + tokenLandlord))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        // 5. Sözleşme: WEBP -> 400
        mockMvc.perform(multipart("/api/leases/" + leaseA.getId() + "/contract")
                        .file(webpFile)
                        .header("Authorization", "Bearer " + tokenLandlord))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        // 6. Sözleşme: PDF -> 200
        mockMvc.perform(multipart("/api/leases/" + leaseA.getId() + "/contract")
                        .file(pdfFile)
                        .header("Authorization", "Bearer " + tokenLandlord))
                .andExpect(status().isOk());
    }

    // -------------------------------------------------------------
    // 16. Backend, .env'deki DB şifresiyle host'tan TCP üzerinden bağlanarak başlıyor
    // -------------------------------------------------------------
    @Test
    @Order(16)
    void scenario16_TcpPasswordAuthentication_Succeeds() throws Exception {
        String pgUrl = System.getenv().getOrDefault("DB_URL", "jdbc:postgresql://localhost:5433/kiraz_db");
        String pgUser = System.getenv().getOrDefault("DB_USERNAME", "ars_admin");
        String pgPass = System.getenv("DB_PASSWORD");

        if (pgPass == null || pgPass.isBlank()) {
            Path envPath = Paths.get("../.env").toAbsolutePath().normalize();
            if (!Files.exists(envPath)) {
                envPath = Paths.get(".env").toAbsolutePath().normalize();
            }
            if (Files.exists(envPath)) {
                for (String line : Files.readAllLines(envPath)) {
                    line = line.trim();
                    if (line.startsWith("DB_PASSWORD=")) {
                        pgPass = line.substring("DB_PASSWORD=".length()).trim().replaceAll("^\"|\"$|^'|'$", "");
                        break;
                    }
                }
            }
        }

        assertNotNull(pgPass, "DB_PASSWORD .env veya ortam değişkeninde tanımlı olmalıdır");
        assertFalse(pgPass.isBlank(), "DB_PASSWORD boş olamaz");

        // TCP soketi üzerinden PostgreSQL kimlik doğrulaması testi
        try (Connection conn = DriverManager.getConnection(pgUrl, pgUser, pgPass);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT current_user, current_database()")) {

            assertTrue(rs.next(), "Veritabanından sorgu sonucu dönmeli");
            assertEquals(pgUser, rs.getString("current_user"));
            assertEquals("kiraz_db", rs.getString("current_database"));
        }
    }

    @AfterEach
    void tearDown() {
        auditLogRepository.deleteAll();
        periodRepository.deleteAll();
        delegationRepository.deleteAll();
        leaseRepository.deleteAll();
        propertyRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }
}
