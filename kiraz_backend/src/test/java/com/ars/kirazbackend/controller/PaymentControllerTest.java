package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PayTrInitRequest;
import com.ars.kirazbackend.dto.PayTrInitResponse;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.service.PayTrService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class PaymentControllerTest {

    private MockMvc mockMvc;

    @Mock
    private PayTrService payTrService;

    @InjectMocks
    private PaymentController paymentController;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(paymentController).build();

        User tenantUser = User.builder()
                .id(10L)
                .email("kiraci@kiraz.app")
                .role(RoleType.TENANT)
                .build();

        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                tenantUser, null, List.of(new SimpleGrantedAuthority("ROLE_TENANT"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Test
    void testInitializePayTr_ReturnsToken() throws Exception {
        PayTrInitRequest request = new PayTrInitRequest(50L, "kiraci@kiraz.app");

        PayTrInitResponse serviceResponse = PayTrInitResponse.builder()
                .status("success")
                .token("mock_paytr_token_123")
                .merchantOid("RENT-50-999999")
                .iframeUrl("https://www.paytr.com/odeme/guvenli/mock_paytr_token_123")
                .build();

        when(payTrService.initializePayment(eq(50L), anyString(), eq("kiraci@kiraz.app")))
                .thenReturn(serviceResponse);

        mockMvc.perform(post("/api/payments/paytr/initialize")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))
                        .header("X-Forwarded-For", "203.0.113.195"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("success"))
                .andExpect(jsonPath("$.token").value("mock_paytr_token_123"))
                .andExpect(jsonPath("$.iframeUrl").value("https://www.paytr.com/odeme/guvenli/mock_paytr_token_123"))
                .andExpect(jsonPath("$.merchantOid").value("RENT-50-999999"));

        verify(payTrService).initializePayment(eq(50L), eq("203.0.113.195"), eq("kiraci@kiraz.app"));
    }

    @Test
    void testPayTrCallback_ConsumesFormUrlEncoded_ReturnsOK() throws Exception {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("merchant_oid", "RENT-50-999999");
        form.add("status", "success");
        form.add("total_amount", "1500000");
        form.add("hash", "calculated_mock_hash");

        when(payTrService.processCallback(any())).thenReturn("OK");

        mockMvc.perform(post("/api/payments/paytr-callback")
                        .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                        .params(form))
                .andExpect(status().isOk())
                .andExpect(content().string("OK"));

        verify(payTrService).processCallback(any());
    }
}
