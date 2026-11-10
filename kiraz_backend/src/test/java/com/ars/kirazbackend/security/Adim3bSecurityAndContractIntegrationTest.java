package com.ars.kirazbackend.security;

import com.ars.kirazbackend.config.InviteRateLimitingFilter;
import com.ars.kirazbackend.entity.*;
import com.ars.kirazbackend.enums.*;
import com.ars.kirazbackend.repository.*;
import com.ars.kirazbackend.service.LeaseService;
import com.ars.kirazbackend.support.AuthTestHelper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class Adim3bSecurityAndContractIntegrationTest {

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
    private AuditLogRepository auditLogRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private InviteRateLimitingFilter inviteRateLimitingFilter;

    @Autowired
    private ObjectMapper objectMapper;

    private User landlordA;
    private User landlordB;
    private User tenantA;
    private User tenantB;
    private User agentValid;

    private Property propertyA;
    private LeaseAgreement leaseA;
    private RentPeriod periodA;

    private Path testReceiptPath;
    private Path testContractPath;

    @BeforeEach
    void setUp() throws Exception {
        inviteRateLimitingFilter.resetForTesting();

        auditLogRepository.deleteAll();
        notificationRepository.deleteAll();
        periodRepository.deleteAll();
        delegationRepository.deleteAll();
        leaseRepository.deleteAll();
        propertyRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        // 1. Users (@example.com)
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
                .fullName("Kiraci A")
                .email("tenant_a@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.TENANT)
                .build());

        tenantB = userRepository.save(User.builder()
                .fullName("Kiraci B")
                .email("tenant_b@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.TENANT)
                .build());

        agentValid = userRepository.save(User.builder()
                .fullName("Emlakci Aktif")
                .email("agent_valid@example.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.AGENT)
                .build());

        // 2. Mülk ve Delegasyon
        propertyA = propertyRepository.save(Property.builder()
                .title("Kadikoy Daire A")
                .address("Kadikoy")
                .landlord(landlordA)
                .build());

        delegationRepository.save(PropertyDelegation.builder()
                .property(propertyA)
                .agent(agentValid)
                .grantedBy(landlordA)
                .status(DelegationStatus.ACTIVE)
                .startDate(LocalDate.now().minusDays(5))
                .endDate(LocalDate.now().plusDays(30))
                .build());

        // 3. Dosya klasörü ve test dosyaları (target/test-uploads içinde izole)
        Path uploadDir = Paths.get("target/test-uploads/receipts").toAbsolutePath().normalize();
        Files.createDirectories(uploadDir);

        testReceiptPath = uploadDir.resolve("test_receipt_a.png");
        byte[] pngBytes = new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D};
        Files.write(testReceiptPath, pngBytes);

        testContractPath = uploadDir.resolve("test_contract_a.pdf");
        byte[] pdfBytes = "%PDF-1.4\n%test contract file content".getBytes();
        Files.write(testContractPath, pdfBytes);

        // 4. Sözleşme ve Kira Dönemi
        leaseA = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(landlordA)
                .monthlyRentAmount(BigDecimal.valueOf(25000))
                .status(LeaseStatus.ACTIVE)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .inviteCode(LeaseService.generateInviteCode())
                .inviteCodeExpiresAt(LocalDateTime.now().plusDays(7))
                .inviteCodeUsed(false)
                .contractFilePath(testContractPath.toString())
                .build());

        periodA = periodRepository.save(RentPeriod.builder()
                .leaseAgreement(leaseA)
                .month(11)
                .year(2026)
                .status(PaymentStatus.WAITING_APPROVAL)
                .receiptFilePath(testReceiptPath.toString())
                .build());
    }

    // ==========================================
    // 1. Dosya Erişimi ve Güvenli Streaming Testleri
    // ==========================================

    @Test
    void testFileStreaming_TenantA_CanDownloadOwnReceipt_Returns200() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantA);

        mockMvc.perform(get("/api/files/receipts/" + periodA.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG))
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("inline; filename=")));
    }

    @Test
    void testFileStreaming_LandlordA_CanDownloadTenantAReceipt_Returns200() throws Exception {
        String token = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/files/receipts/" + periodA.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG));
    }

    @Test
    void testFileStreaming_AgentWithActiveDelegation_CanDownloadReceipt_Returns200() throws Exception {
        String token = AuthTestHelper.generateValidToken(agentValid);

        mockMvc.perform(get("/api/files/receipts/" + periodA.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG));
    }

    @Test
    void testFileStreaming_TenantB_CannotDownloadTenantAReceipt_Returns404() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantB);

        mockMvc.perform(get("/api/files/receipts/" + periodA.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.error").value("Not Found"));
    }

    @Test
    void testFileStreaming_LandlordB_CannotDownloadTenantAReceipt_Returns404() throws Exception {
        String token = AuthTestHelper.generateValidToken(landlordB);

        mockMvc.perform(get("/api/files/receipts/" + periodA.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void testFileStreaming_Unauthenticated_Returns401() throws Exception {
        mockMvc.perform(get("/api/files/receipts/" + periodA.getId()))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void testContractStreaming_LandlordA_And_TenantA_CanDownload_Returns200() throws Exception {
        String tokenTenant = AuthTestHelper.generateValidToken(tenantA);
        String tokenLandlord = AuthTestHelper.generateValidToken(landlordA);

        mockMvc.perform(get("/api/files/contracts/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenTenant))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_PDF));

        mockMvc.perform(get("/api/files/contracts/" + leaseA.getId())
                        .header("Authorization", "Bearer " + tokenLandlord))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_PDF));
    }

    @Test
    void testContractStreaming_TenantB_Returns404() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantB);

        mockMvc.perform(get("/api/files/contracts/" + leaseA.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    // ==========================================
    // 2. Yükleme Doğrulaması (Magic Bytes ve Boyut) Testleri
    // ==========================================

    @Test
    void testUploadReceipt_ValidPng_Returns200() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantA);
        byte[] validPng = new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3};
        MockMultipartFile file = new MockMultipartFile("file", "valid.png", "image/png", validPng);

        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(file)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptImageUrl").value("/api/files/receipts/" + periodA.getId()));
    }

    @Test
    void testUploadReceipt_ValidJpeg_Returns200() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantA);
        byte[] validJpeg = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 16, 0x4A, 0x46};
        MockMultipartFile file = new MockMultipartFile("file", "dekont.jpg", "image/jpeg", validJpeg);

        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(file)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptImageUrl").value("/api/files/receipts/" + periodA.getId()));
    }

    @Test
    void testUploadReceipt_DisguisedTextFile_FailsMagicBytes_Returns400() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantA);
        byte[] fakeBytes = "Bu aslinda duz bir metin dosyasidir".getBytes();
        MockMultipartFile fakeFile = new MockMultipartFile("file", "sahte_dekont.png", "image/png", fakeBytes);

        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(fakeFile)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.error").value("Bad Request"))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Yalnızca PDF, JPEG ve PNG")));
    }

    @Test
    void testUploadReceipt_ExecutableFile_Returns400() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantA);
        byte[] exeBytes = "MZ\u0090\u0000\u0003\u0000\u0000\u0000".getBytes();
        MockMultipartFile exeFile = new MockMultipartFile("file", "virus.exe", "application/octet-stream", exeBytes);

        mockMvc.perform(multipart("/api/tenant/receipts/" + periodA.getId())
                        .file(exeFile)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    // ==========================================
    // 3. Sözleşme Aktivasyonu & Ev Sahibi Onayı Testleri
    // ==========================================

    @Test
    void testLeaseActivation_ByAgentWithoutLandlordApproval_Returns409Conflict() throws Exception {
        // Emlakçı tarafından oluşturulan ve henüz ev sahibi onayı almamış sözleşme
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

        // Kiracı onaylamaya çalıştığında 409 Conflict almalı
        mockMvc.perform(put("/api/leases/" + agentLease.getId() + "/activate")
                        .header("Authorization", "Bearer " + tenantToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.error").value("Conflict"))
                .andExpect(jsonPath("$.message").value("Ev sahibi onayı olmadan sözleşme aktif edilemez."));
    }

    @Test
    void testLeaseActivation_AfterLandlordApproval_Succeeds200() throws Exception {
        LeaseAgreement agentLease = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(agentValid)
                .monthlyRentAmount(BigDecimal.valueOf(25000))
                .status(LeaseStatus.PENDING)
                .approvalStatus(LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL)
                .inviteCode(LeaseService.generateInviteCode())
                .build());

        String landlordToken = AuthTestHelper.generateValidToken(landlordA);
        String tenantToken = AuthTestHelper.generateValidToken(tenantA);

        // 1. Ev sahibi onaylar (Kanonik uç: POST /api/landlord/leases/{id}/approve)
        mockMvc.perform(post("/api/landlord/leases/" + agentLease.getId() + "/approve")
                        .header("Authorization", "Bearer " + landlordToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.approvalStatus").value("ACTIVE"));

        // 2. Kiracı artık aktive edebilir
        mockMvc.perform(put("/api/leases/" + agentLease.getId() + "/activate")
                        .header("Authorization", "Bearer " + tenantToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    // ==========================================
    // 4. Davet Kodları, Süre, Tek Kullanımlık ve Rate Limit Testleri
    // ==========================================

    @Test
    void testInviteCode_FormatAndLength_128BitEntropy() {
        String code = LeaseService.generateInviteCode();
        assertNotNull(code);
        assertTrue(code.startsWith("ARS-"));
        // Prefix "ARS-" (4) + 32 hex karakter (16 bytes = 128 bit) = 36 karakter
        assertEquals(36, code.length());
    }

    @Test
    void testInviteCode_ValidateAndAccept_SingleUse() throws Exception {
        String code = leaseA.getInviteCode();

        // 1. Doğrulama başarılı
        mockMvc.perform(get("/api/leases/validate-invite").param("inviteCode", code))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Davet kodu geçerli"))
                .andExpect(jsonPath("$.leaseId").value(leaseA.getId()));

        // 2. Kabul etme ve şifre belirleme
        mockMvc.perform(post("/api/leases/accept")
                        .param("inviteCode", code)
                        .param("newPassword", "NewSecretPass123!"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Sözleşme başarıyla onaylandı"));

        // 3. Tekrar doğrulamak istendiğinde kod kullanılmış olmalı -> 400 Bad Request
        mockMvc.perform(get("/api/leases/validate-invite").param("inviteCode", code))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Davet kodu daha önce kullanılmış."));

        // 4. Tekrar kabul edilmeye çalışıldığında -> 400 Bad Request
        mockMvc.perform(post("/api/leases/accept")
                        .param("inviteCode", code)
                        .param("newPassword", "AnotherPass!"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Davet kodu daha önce kullanılmış."));
    }

    @Test
    void testInviteCode_ExpiredCode_Returns400() throws Exception {
        // Süresi dolmuş sözleşme
        LeaseAgreement expiredLease = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(landlordA)
                .monthlyRentAmount(BigDecimal.valueOf(25000))
                .status(LeaseStatus.PENDING)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .inviteCode(LeaseService.generateInviteCode())
                .inviteCodeExpiresAt(LocalDateTime.now().minusDays(1)) // 1 gün önce dolmuş
                .inviteCodeUsed(false)
                .build());

        mockMvc.perform(get("/api/leases/validate-invite").param("inviteCode", expiredLease.getInviteCode()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").value("Davet kodunun süresi dolmuş."));
    }

    @Test
    void testInviteRateLimiting_10RequestsAllowed_11thReturns429() throws Exception {
        inviteRateLimitingFilter.resetForTesting();
        String code = leaseA.getInviteCode();

        // İlk 10 istek başarılı olmalı
        for (int i = 1; i <= 10; i++) {
            mockMvc.perform(get("/api/leases/validate-invite")
                            .param("inviteCode", code)
                            .with(request -> {
                                request.setRemoteAddr("198.51.100.25");
                                return request;
                            }))
                    .andExpect(status().isOk());
        }

        // 11. istek aynı IP'den geldiğinde 429 Too Many Requests dönmeli
        mockMvc.perform(get("/api/leases/validate-invite")
                        .param("inviteCode", code)
                        .with(request -> {
                            request.setRemoteAddr("198.51.100.25");
                            return request;
                        }))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.status").value(429))
                .andExpect(jsonPath("$.error").value("Too Many Requests"))
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Çok fazla istek yapıldı")));
    }

    @Test
    void testInviteRateLimiting_DifferentXForwardedForFromUntrustedProxy_DoesNotBypassLimit_11thReturns429() throws Exception {
        inviteRateLimitingFilter.resetForTesting();
        String code = leaseA.getInviteCode();

        // 10 istek her seferinde farklı bir X-Forwarded-For başlığıyla gönderiliyor ancak remoteAddr aynı
        for (int i = 1; i <= 10; i++) {
            mockMvc.perform(get("/api/leases/validate-invite")
                            .param("inviteCode", code)
                            .header("X-Forwarded-For", "203.0.113." + i)
                            .with(request -> {
                                request.setRemoteAddr("198.51.100.99");
                                return request;
                            }))
                    .andExpect(status().isOk());
        }

        // 11. istekte yine farklı X-Forwarded-For olsa bile gerçek remoteAddr üzerinden 429 Too Many Requests dönmeli
        mockMvc.perform(get("/api/leases/validate-invite")
                        .param("inviteCode", code)
                        .header("X-Forwarded-For", "203.0.113.99")
                        .with(request -> {
                            request.setRemoteAddr("198.51.100.99");
                            return request;
                        }))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.status").value(429));
    }

    @Test
    void testLeaseActivation_DirectLandlordCreatedLease_StartsActiveApproval_TenantCanActivate200() throws Exception {
        // Ev sahibi emlakçı olmadan doğrudan sözleşme oluşturduğunda approvalStatus=ACTIVE başlar
        LeaseAgreement landlordDirectLease = leaseRepository.save(LeaseAgreement.builder()
                .property(propertyA)
                .tenant(tenantA)
                .createdBy(landlordA)
                .monthlyRentAmount(BigDecimal.valueOf(30000))
                .status(LeaseStatus.PENDING)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .inviteCode(LeaseService.generateInviteCode())
                .inviteCodeExpiresAt(LocalDateTime.now().plusDays(7))
                .inviteCodeUsed(false)
                .build());

        String tenantToken = AuthTestHelper.generateValidToken(tenantA);

        // Kiracı sözleşmeyi aktive ettiğinde 200 dönmeli
        mockMvc.perform(put("/api/leases/" + landlordDirectLease.getId() + "/activate")
                        .header("Authorization", "Bearer " + tenantToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.approvalStatus").value("ACTIVE"));
    }

    // ==========================================
    // 5. Kanonik Uçlar ve Deprecated Uçlar Testleri
    // ==========================================

    @Test
    void testCanonicalEndpoints_LandlordPropertiesAndLeases() throws Exception {
        String token = AuthTestHelper.generateValidToken(landlordA);

        // Kanonik: GET /api/landlord/properties
        mockMvc.perform(get("/api/landlord/properties").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(propertyA.getId()));

        // Kanonik: GET /api/landlord/leases
        mockMvc.perform(get("/api/landlord/leases").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(leaseA.getId()));

        // Deprecated (Removed): GET /api/properties/landlord -> 404 Not Found
        mockMvc.perform(get("/api/properties/landlord").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void testCanonicalEndpoints_TenantLeasesAndDashboard() throws Exception {
        String token = AuthTestHelper.generateValidToken(tenantA);

        // Kanonik: GET /api/tenant/leases
        mockMvc.perform(get("/api/tenant/leases").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(leaseA.getId()));

        // Kanonik: GET /api/tenant/dashboard
        mockMvc.perform(get("/api/tenant/dashboard").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        // Kanonik: GET /api/tenant/payments/summary
        mockMvc.perform(get("/api/tenant/payments/summary").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    @Test
    void testCanonicalEndpoints_ManagerPropertiesAndDashboard() throws Exception {
        String token = AuthTestHelper.generateValidToken(agentValid);

        // Kanonik: GET /api/manager/properties
        mockMvc.perform(get("/api/manager/properties").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(propertyA.getId()));

        // Kanonik: GET /api/manager/dashboard
        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    @AfterEach
    void tearDown() {
        auditLogRepository.deleteAll();
        notificationRepository.deleteAll();
        periodRepository.deleteAll();
        delegationRepository.deleteAll();
        leaseRepository.deleteAll();
        propertyRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        try {
            Path testUploads = Paths.get("target/test-uploads").toAbsolutePath().normalize();
            if (Files.exists(testUploads)) {
                try (var stream = Files.walk(testUploads)) {
                    stream.sorted(java.util.Comparator.reverseOrder())
                            .map(Path::toFile)
                            .forEach(java.io.File::delete);
                }
            }
        } catch (Exception ignored) {}
    }
}
