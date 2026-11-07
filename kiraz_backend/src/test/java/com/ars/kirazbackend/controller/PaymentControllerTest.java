package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PayTrInitRequest;
import com.ars.kirazbackend.dto.PayTrInitResponse;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.dto.PaymentSummaryResponse;
import com.ars.kirazbackend.service.PayTrService;
import com.ars.kirazbackend.service.RentPeriodService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class PaymentControllerTest {

    private MockMvc mockMvc;

    @Mock
    private PayTrService payTrService;

    @Mock
    private RentPeriodService rentPeriodService;

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

    @Test
    void testGetPaymentSummary_ReturnsSummary() throws Exception {
        LocalDate nextDate = LocalDate.now().plusDays(10);
        PaymentSummaryResponse summaryResponse = PaymentSummaryResponse.builder()
                .totalDebt(BigDecimal.valueOf(1000))
                .totalPaid(BigDecimal.valueOf(5000))
                .nextPaymentDate(nextDate)
                .nextPaymentAmount(BigDecimal.valueOf(1000))
                .build();

        when(rentPeriodService.getTenantPaymentSummary(10L)).thenReturn(summaryResponse);

        mockMvc.perform(get("/api/payments/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalDebt").value(1000))
                .andExpect(jsonPath("$.totalPaid").value(5000))
                .andExpect(jsonPath("$.nextPaymentDate").value(nextDate.toString()))
                .andExpect(jsonPath("$.nextPaymentAmount").value(1000));

        verify(rentPeriodService).getTenantPaymentSummary(10L);
    }

    @Test
    void testUploadReceipt_ReturnsUpdatedPeriod() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "dekont.pdf", "application/pdf", "dummy receipt pdf content".getBytes()
        );

        RentPeriod mockPeriod = RentPeriod.builder()
                .id(50L)
                .month(11)
                .year(2026)
                .receiptImageUrl("/uploads/receipts/dekont.pdf")
                .status(PaymentStatus.WAITING_APPROVAL)
                .build();

        when(rentPeriodService.uploadReceipt(eq(50L), any(MultipartFile.class))).thenReturn(mockPeriod);

        mockMvc.perform(multipart("/api/payments/50/receipt").file(file))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(50))
                .andExpect(jsonPath("$.status").value("WAITING_APPROVAL"))
                .andExpect(jsonPath("$.receiptImageUrl").value("/uploads/receipts/dekont.pdf"));

        verify(rentPeriodService).uploadReceipt(eq(50L), any(MultipartFile.class));
    }
}
