package com.ars.kirazbackend.config;

import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.io.IOException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserAuthenticationFilterTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private FilterChain filterChain;

    @InjectMocks
    private UserAuthenticationFilter filter;

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testFilter_AuthenticatesWithUserIdHeader() throws ServletException, IOException {
        User agentUser = User.builder()
                .id(5L)
                .email("agent@test.com")
                .role(RoleType.AGENT)
                .build();

        when(request.getHeader("X-User-Id")).thenReturn("5");
        when(userRepository.findById(5L)).thenReturn(Optional.of(agentUser));

        filter.doFilterInternal(request, response, filterChain);

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(auth);
        assertEquals(agentUser, auth.getPrincipal());
        assertTrue(auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_AGENT")));
        assertTrue(auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("AGENT")));

        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void testFilter_AuthenticatesWithLandlordQueryParam() throws ServletException, IOException {
        User landlordUser = User.builder()
                .id(1L)
                .email("landlord@test.com")
                .role(RoleType.LANDLORD)
                .build();

        when(request.getHeader("X-User-Id")).thenReturn(null);
        when(request.getHeader("X-User-Email")).thenReturn(null);
        when(request.getHeader("Authorization")).thenReturn(null);
        when(request.getParameter("userId")).thenReturn(null);
        when(request.getParameter("landlordId")).thenReturn("1");
        when(userRepository.findById(1L)).thenReturn(Optional.of(landlordUser));

        filter.doFilterInternal(request, response, filterChain);

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        assertNotNull(auth);
        assertEquals(landlordUser, auth.getPrincipal());
        assertTrue(auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_LANDLORD")));

        verify(filterChain, times(1)).doFilter(request, response);
    }
}
