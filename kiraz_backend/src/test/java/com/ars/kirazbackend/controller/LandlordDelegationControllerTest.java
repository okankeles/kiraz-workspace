package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.config.GlobalExceptionHandler;
import com.ars.kirazbackend.dto.DelegationRequestDto;
import com.ars.kirazbackend.dto.DelegationResponseDto;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.PropertyDelegationService;
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

import java.time.LocalDate;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class LandlordDelegationControllerTest {

    private MockMvc mockMvc;

    @Mock
    private PropertyDelegationService delegationService;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private LandlordDelegationController controller;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private User landlord;
    private DelegationResponseDto sampleDto;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        landlord = User.builder()
                .id(1L)
                .email("landlord@kiraz.app")
                .fullName("Ev Sahibi Ali")
                .role(RoleType.LANDLORD)
                .build();

        sampleDto = new DelegationResponseDto(
                50L,
                "Kadıköy 2+1",
                "Emlakçı Can",
                "can@emlak.com",
                "ACTIVE",
                LocalDate.now()
        );
    }

    @Test
    void testAssignManager_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        DelegationRequestDto request = new DelegationRequestDto(10L, "can@emlak.com");

        when(delegationService.assignManager(eq(request), any(User.class))).thenReturn(sampleDto);

        mockMvc.perform(post("/api/landlord/delegations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(50L))
                .andExpect(jsonPath("$.propertyName").value("Kadıköy 2+1"))
                .andExpect(jsonPath("$.managerEmail").value("can@emlak.com"))
                .andExpect(jsonPath("$.status").value("ACTIVE"));

        verify(delegationService, times(1)).assignManager(eq(request), any(User.class));
    }

    @Test
    void testGetLandlordDelegations_WithAuth_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        when(delegationService.getLandlordDelegations(1L)).thenReturn(List.of(sampleDto));

        mockMvc.perform(get("/api/landlord/delegations")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(50L))
                .andExpect(jsonPath("$[0].propertyName").value("Kadıköy 2+1"));

        verify(delegationService, times(1)).getLandlordDelegations(1L);
    }

    @Test
    void testGetLandlordDelegations_WithoutUser_ReturnsBadRequest() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/landlord/delegations")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Ev sahibi kimliği belirlenemedi."));
    }

    @Test
    void testRevokeDelegation_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                landlord, null, List.of(new SimpleGrantedAuthority("ROLE_LANDLORD"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        DelegationResponseDto revokedDto = new DelegationResponseDto(
                50L,
                "Kadıköy 2+1",
                "Emlakçı Can",
                "can@emlak.com",
                "REVOKED",
                LocalDate.now()
        );

        when(delegationService.revokeDelegationDto(50L, 1L)).thenReturn(revokedDto);

        mockMvc.perform(delete("/api/landlord/delegations/50")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(50L))
                .andExpect(jsonPath("$.status").value("REVOKED"));

        verify(delegationService, times(1)).revokeDelegationDto(50L, 1L);
    }
}
