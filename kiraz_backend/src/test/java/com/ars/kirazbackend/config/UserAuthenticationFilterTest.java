package com.ars.kirazbackend.config;

import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.JwtService;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.security.SignatureException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserAuthenticationFilterTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private JwtService jwtService;

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private FilterChain filterChain;

    @InjectMocks
    private UserAuthenticationFilter filter;

    private StringWriter responseWriter;

    @BeforeEach
    void setUp() throws IOException {
        responseWriter = new StringWriter();
        lenient().when(response.getWriter()).thenReturn(new PrintWriter(responseWriter));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testFilter_WithValidJwtToken_AuthenticatesUser() throws ServletException, IOException {
        User agentUser = User.builder()
                .id(5L)
                .email("agent@test.com")
                .role(RoleType.AGENT)
                .build();

        String token = "valid.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtService.extractUserId(token)).thenReturn(5L);
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
    void testFilter_WithExpiredJwtToken_Returns401() throws ServletException, IOException {
        String token = "expired.jwt.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtService.extractUserId(token)).thenThrow(new ExpiredJwtException(null, null, "Token has expired"));

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(response).setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        assertTrue(responseWriter.toString().contains("Token süresi dolmuş"));
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void testFilter_WithInvalidSignature_Returns401() throws ServletException, IOException {
        String token = "invalid.signature.token";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtService.extractUserId(token)).thenThrow(new SignatureException("JWT signature does not match"));

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(response).setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        assertTrue(responseWriter.toString().contains("Geçersiz veya bozuk"));
        verify(filterChain, never()).doFilter(request, response);
    }

    @Test
    void testFilter_WithOnlyUserIdHeader_DoesNotAuthenticate() throws ServletException, IOException {
        // Old legacy bypass header should be completely ignored
        when(request.getHeader("Authorization")).thenReturn(null);

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(filterChain, times(1)).doFilter(request, response);
    }

    @Test
    void testFilter_WhenUserNotFoundInDb_Returns401() throws ServletException, IOException {
        String token = "valid.token.nonexistent.user";
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);
        when(jwtService.extractUserId(token)).thenReturn(999L);
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        filter.doFilterInternal(request, response, filterChain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(response).setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        assertTrue(responseWriter.toString().contains("Kullanıcı sistemde bulunamadı"));
        verify(filterChain, never()).doFilter(request, response);
    }
}
