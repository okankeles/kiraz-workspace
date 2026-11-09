package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.config.GlobalExceptionHandler;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.PropertyDelegationService;
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

import java.util.List;
import java.util.Optional;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class PropertyManagerControllerTest {

    private MockMvc mockMvc;

    @Mock
    private PropertyDelegationService propertyDelegationService;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private PropertyManagerController controller;

    private User manager;
    private Property property;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        manager = User.builder()
                .id(10L)
                .email("manager@emlak.com")
                .fullName("Mülk Yöneticisi Can")
                .role(RoleType.PROPERTY_MANAGER)
                .build();

        property = Property.builder()
                .id(100L)
                .title("Ataşehir 3+1")
                .status("DELEGATED")
                .build();
    }

    @Test
    void testGetManagerProperties_WithAuth_ReturnsOk() throws Exception {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                manager, null, List.of(new SimpleGrantedAuthority("ROLE_PROPERTY_MANAGER"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        when(propertyDelegationService.getManagerProperties(10L)).thenReturn(List.of(property));

        mockMvc.perform(get("/api/manager/properties")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(100L))
                .andExpect(jsonPath("$[0].title").value("Ataşehir 3+1"))
                .andExpect(jsonPath("$[0].status").value("DELEGATED"));

        verify(propertyDelegationService, times(1)).getManagerProperties(10L);
    }

    @Test
    void testGetManagerProperties_WithTokenAuthHelper_ReturnsOk() throws Exception {
        SecurityContextHolder.getContext().setAuthentication(
                com.ars.kirazbackend.support.AuthTestHelper.createAuthentication(manager)
        );
        when(propertyDelegationService.getManagerProperties(10L)).thenReturn(List.of(property));

        mockMvc.perform(get("/api/manager/properties")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(100L));

        verify(propertyDelegationService, times(1)).getManagerProperties(10L);
    }

    @Test
    void testGetManagerProperties_WithOnlyHeaderUserId_Fails() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/manager/properties")
                        .header("X-User-Id", "10")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Mülk yöneticisi kimliği belirlenemedi."));

        verifyNoInteractions(propertyDelegationService);
    }

    @Test
    void testGetManagerProperties_WithoutUser_ReturnsBadRequest() throws Exception {
        SecurityContextHolder.clearContext();

        mockMvc.perform(get("/api/manager/properties")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Mülk yöneticisi kimliği belirlenemedi."));
    }
}
