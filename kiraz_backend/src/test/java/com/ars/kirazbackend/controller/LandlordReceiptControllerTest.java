package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.config.GlobalExceptionHandler;
import com.ars.kirazbackend.dto.PendingReceiptDto;
import com.ars.kirazbackend.dto.RejectReceiptRequest;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.LandlordReceiptService;
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

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class LandlordReceiptControllerTest {

    private MockMvc mockMvc;

    @Mock
    private LandlordReceiptService landlordReceiptService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private com.ars.kirazbackend.service.AccessControlService authz;

    @InjectMocks
    private LandlordReceiptController landlordReceiptController;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private User landlord;
    private PendingReceiptDto sampleDto;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(landlordReceiptController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        landlord = User.builder()
                .id(1L)
                .email("landlord@kiraz.app")
                .fullName("Ev Sahibi Ali")
                .role(RoleType.LANDLORD)
                .build();

        sampleDto = new PendingReceiptDto(
                100L,
                "Kadıköy 2+1",
                "Kiracı Veli",
                11,
                2026,
                BigDecimal.valueOf(18000.00),
                "http://cloudinary.com/dekont.jpg",
                LocalDateTime.of(2026, 11, 2, 12, 0)
        );
    }

    @Test
    void testGetPendingReceipts_WithAuth_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        when(landlordReceiptService.getPendingReceipts(1L)).thenReturn(List.of(sampleDto));

        mockMvc.perform(get("/api/landlord/receipts/pending")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].periodId").value(100L))
                .andExpect(jsonPath("$[0].propertyName").value("Kadıköy 2+1"))
                .andExpect(jsonPath("$[0].tenantName").value("Kiracı Veli"))
                .andExpect(jsonPath("$[0].amount").value(18000.00))
                .andExpect(jsonPath("$[0].receiptImageUrl").value("http://cloudinary.com/dekont.jpg"));

        verify(landlordReceiptService, times(1)).getPendingReceipts(1L);
    }

    @Test
    void testGetPendingReceipts_WithTokenAuthHelper_ReturnsOk() throws Exception {
        SecurityContextHolder.getContext().setAuthentication(
                com.ars.kirazbackend.support.AuthTestHelper.createAuthentication(landlord)
        );
        when(landlordReceiptService.getPendingReceipts(1L)).thenReturn(List.of(sampleDto));

        mockMvc.perform(get("/api/landlord/receipts/pending")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].periodId").value(100L));

        verify(landlordReceiptService, times(1)).getPendingReceipts(1L);
    }

    @Test
    void testGetPendingReceipts_WithOnlyHeaderUserId_Fails() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/landlord/receipts/pending")
                        .header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Ev sahibi kimliği belirlenemedi."));

        verifyNoInteractions(landlordReceiptService);
    }

    @Test
    void testGetPendingReceipts_WithoutLandlord_ReturnsBadRequest() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/landlord/receipts/pending")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.message").value("Ev sahibi kimliği belirlenemedi."));
    }

    @Test
    void testApproveReceipt_ReturnsOk() throws Exception {
        RentPeriod paidPeriod = RentPeriod.builder()
                .id(100L)
                .status(PaymentStatus.PAID)
                .build();

        when(landlordReceiptService.approveReceipt(100L)).thenReturn(paidPeriod);

        mockMvc.perform(post("/api/landlord/receipts/100/approve")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(100L))
                .andExpect(jsonPath("$.status").value("PAID"));

        verify(landlordReceiptService, times(1)).approveReceipt(100L);
    }

    @Test
    void testRejectReceipt_WithReason_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        RentPeriod overduePeriod = RentPeriod.builder()
                .id(100L)
                .status(PaymentStatus.OVERDUE)
                .receiptImageUrl(null)
                .build();

        RejectReceiptRequest request = new RejectReceiptRequest("Dekont üzerindeki isim kiracı ile uyuşmuyor");

        when(landlordReceiptService.rejectReceipt(eq(100L), eq("Dekont üzerindeki isim kiracı ile uyuşmuyor"), any()))
                .thenReturn(overduePeriod);

        mockMvc.perform(post("/api/landlord/receipts/100/reject")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(100L))
                .andExpect(jsonPath("$.status").value("OVERDUE"));

        verify(landlordReceiptService, times(1))
                .rejectReceipt(eq(100L), eq("Dekont üzerindeki isim kiracı ile uyuşmuyor"), any());
    }

    @Test
    void testRejectReceipt_WithoutBody_UsesDefaultReason() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        RentPeriod pendingPeriod = RentPeriod.builder()
                .id(100L)
                .status(PaymentStatus.PENDING)
                .build();

        when(landlordReceiptService.rejectReceipt(eq(100L), eq("Ev sahibi tarafından reddedildi."), any()))
                .thenReturn(pendingPeriod);

        mockMvc.perform(post("/api/landlord/receipts/100/reject")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"));

        verify(landlordReceiptService, times(1))
                .rejectReceipt(eq(100L), eq("Ev sahibi tarafından reddedildi."), any());
    }
}
