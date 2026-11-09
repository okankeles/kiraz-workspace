package com.ars.kirazbackend.security;

import com.ars.kirazbackend.dto.LoginRequest;
import com.ars.kirazbackend.dto.LogoutRequest;
import com.ars.kirazbackend.dto.RefreshTokenRequest;
import com.ars.kirazbackend.dto.RegisterRequest;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.RefreshTokenRepository;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.support.AuthTestHelper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class JwtAuthenticationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    private User testLandlord;

    @BeforeEach
    void setUp() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        testLandlord = User.builder()
                .fullName("Test Ev Sahibi")
                .email("evsahibi@kiraztest.com")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role(RoleType.LANDLORD)
                .referenceCode("REF12345")
                .phone("05550001122")
                .build();
        testLandlord = userRepository.save(testLandlord);
    }

    @Test
    void testProtectedEndpoint_WithValidToken_Returns200() throws Exception {
        String token = AuthTestHelper.generateValidToken(testLandlord);

        mockMvc.perform(get("/api/landlord/dashboard")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk());
    }

    @Test
    void testProtectedEndpoint_WithoutToken_Returns401() throws Exception {
        mockMvc.perform(get("/api/landlord/dashboard")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.error").value("Unauthorized"));
    }

    @Test
    void testProtectedEndpoint_WithExpiredToken_Returns401() throws Exception {
        String expiredToken = AuthTestHelper.generateExpiredToken(
                testLandlord.getId(), testLandlord.getEmail(), testLandlord.getRole()
        );

        mockMvc.perform(get("/api/landlord/dashboard")
                        .header("Authorization", "Bearer " + expiredToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message", containsString("Token süresi dolmuş")));
    }

    @Test
    void testProtectedEndpoint_WithInvalidSignatureToken_Returns401() throws Exception {
        String forgedToken = AuthTestHelper.generateTokenWithInvalidSignature(
                testLandlord.getId(), testLandlord.getEmail(), testLandlord.getRole()
        );

        mockMvc.perform(get("/api/landlord/dashboard")
                        .header("Authorization", "Bearer " + forgedToken)
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message", containsString("Geçersiz veya bozuk")));
    }

    @Test
    void testProtectedEndpoint_WithOnlyXUserIdHeader_Returns401() throws Exception {
        // Attempt legacy header spoofing
        mockMvc.perform(get("/api/landlord/dashboard")
                        .header("X-User-Id", String.valueOf(testLandlord.getId()))
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401));
    }

    @Test
    void testAuthEndpoints_LoginAndRegisterContract() throws Exception {
        // Register contract test
        RegisterRequest registerReq = RegisterRequest.builder()
                .fullName("Yeni Kiracı")
                .email("yenikiraci@kiraztest.com")
                .password("Password123!")
                .phone("05553334455")
                .role(RoleType.TENANT)
                .build();

        MvcResult regResult = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(registerReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.user.id").isNotEmpty())
                .andExpect(jsonPath("$.user.fullName").value("Yeni Kiracı"))
                .andExpect(jsonPath("$.user.email").value("yenikiraci@kiraztest.com"))
                .andExpect(jsonPath("$.user.role").value("TENANT"))
                .andReturn();

        // Login contract test
        LoginRequest loginReq = LoginRequest.builder()
                .email("yenikiraci@kiraztest.com")
                .password("Password123!")
                .build();

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.user.email").value("yenikiraci@kiraztest.com"))
                .andExpect(jsonPath("$.user.role").value("TENANT"));
    }

    @Test
    void testRefreshToken_Rotation_AndReuseDetection() throws Exception {
        // 1. Login to get initial tokens
        LoginRequest loginReq = LoginRequest.builder()
                .email(testLandlord.getEmail())
                .password("Password123!")
                .build();

        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginJson = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String initialRefreshToken = loginJson.get("refreshToken").asText();

        // 2. Perform valid refresh rotation
        RefreshTokenRequest refreshReq1 = new RefreshTokenRequest(initialRefreshToken);
        MvcResult refreshResult1 = mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshReq1)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andReturn();

        JsonNode refresh1Json = objectMapper.readTree(refreshResult1.getResponse().getContentAsString());
        String newRefreshToken = refresh1Json.get("refreshToken").asText();
        assertNotEquals(initialRefreshToken, newRefreshToken);

        // 3. REUSE initialRefreshToken (which has already been rotated)
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshReq1)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message", containsString("Kullanılmış bir refresh token")));

        // 4. Verify that ALL refresh tokens for this user were revoked due to the reuse attack!
        RefreshTokenRequest refreshReq2 = new RefreshTokenRequest(newRefreshToken);
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshReq2)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testLogout_RevokesRefreshToken_SubsequentRefreshFails() throws Exception {
        // 1. Login
        LoginRequest loginReq = LoginRequest.builder()
                .email(testLandlord.getEmail())
                .password("Password123!")
                .build();

        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginJson = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String refreshToken = loginJson.get("refreshToken").asText();

        // 2. Logout
        LogoutRequest logoutReq = new LogoutRequest(refreshToken);
        mockMvc.perform(post("/api/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(logoutReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Çıkış başarılı. Oturum sonlandırıldı."));

        // 3. Try refreshing with the revoked token -> should fail
        RefreshTokenRequest refreshReq = new RefreshTokenRequest(refreshToken);
        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refreshReq)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testPayTrCallback_DoesNotRequireJwt() throws Exception {
        // Callback endpoint should not require Bearer token
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("merchant_oid", "NONEXISTENT_OID");
        form.add("status", "failed");
        form.add("total_amount", "1000");
        form.add("hash", "BAD_HASH");

        // It should reject with bad hash or fail gracefully, but NEVER return 401 Unauthorized for lack of JWT!
        mockMvc.perform(post("/api/payments/paytr/callback")
                        .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                        .params(form))
                .andExpect(status().isBadRequest()); // Bad hash triggers exception handled by GlobalExceptionHandler -> 400, NOT 401!
    }
}
