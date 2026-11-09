package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.LandlordDashboardResponse;
import com.ars.kirazbackend.dto.LeaseSummaryDto;
import com.ars.kirazbackend.dto.MonthlyIncomeDto;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.LandlordDashboardService;
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
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class LandlordDashboardControllerTest {

    private MockMvc mockMvc;

    @Mock
    private LandlordDashboardService landlordDashboardService;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private LandlordDashboardController landlordDashboardController;

    private User landlord;
    private LandlordDashboardResponse mockResponse;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(landlordDashboardController)
                .setControllerAdvice(new com.ars.kirazbackend.config.GlobalExceptionHandler())
                .build();

        landlord = User.builder()
                .id(1L)
                .email("evsahibi@kiraz.app")
                .fullName("Ev Sahibi Ali")
                .role(RoleType.LANDLORD)
                .build();

        mockResponse = new LandlordDashboardResponse(
                BigDecimal.valueOf(25000.00),
                BigDecimal.valueOf(10000.00),
                0.85,
                List.of(new LeaseSummaryDto(
                        10L, 1L, "Kadıköy 2+1", "Ahmet Kiracı", "05551112233",
                        LocalDate.now().minusMonths(11), LocalDate.now().plusDays(25),
                        BigDecimal.valueOf(25000.00), 25
                )),
                List.of(new MonthlyIncomeDto("11/2026", 2026, 11, BigDecimal.valueOf(25000.00)))
        );
    }

    @Test
    void testGetDashboard_WithSecurityContext_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        when(landlordDashboardService.getDashboardSummary(1L)).thenReturn(mockResponse);

        mockMvc.perform(get("/api/landlord/dashboard")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalMonthlyIncome").value(25000.00))
                .andExpect(jsonPath("$.totalPendingReceivables").value(10000.00))
                .andExpect(jsonPath("$.occupancyRate").value(0.85))
                .andExpect(jsonPath("$.upcomingExpirations[0].propertyTitle").value("Kadıköy 2+1"))
                .andExpect(jsonPath("$.upcomingExpirations[0].daysRemaining").value(25))
                .andExpect(jsonPath("$.incomeChartData[0].monthYear").value("11/2026"));

        verify(landlordDashboardService).getDashboardSummary(1L);
    }

    @Test
    void testGetDashboard_WithTokenAuthHelper_ReturnsOk() throws Exception {
        SecurityContextHolder.getContext().setAuthentication(
                com.ars.kirazbackend.support.AuthTestHelper.createAuthentication(landlord)
        );
        when(landlordDashboardService.getDashboardSummary(1L)).thenReturn(mockResponse);

        mockMvc.perform(get("/api/landlord/dashboard")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalMonthlyIncome").value(25000.00));

        verify(landlordDashboardService).getDashboardSummary(1L);
    }

    @Test
    void testGetDashboard_WithOnlyHeaderUserId_Fails() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/landlord/dashboard")
                        .header("X-User-Id", "1")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Ev sahibi kimliği belirlenemedi."));

        verifyNoInteractions(landlordDashboardService);
    }

    @Test
    void testGetDashboard_WithoutUser_ReturnsBadRequest() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/landlord/dashboard")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Ev sahibi kimliği belirlenemedi."));
    }
}
