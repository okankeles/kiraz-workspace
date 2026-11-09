package com.ars.kirazbackend.config;

import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.JwtService;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Slf4j
@Component
@RequiredArgsConstructor
public class UserAuthenticationFilter extends OncePerRequestFilter {

    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/api/auth/") ||
                path.equals("/api/leases/accept") ||
                path.equals("/api/leases/validate-invite") ||
                path.startsWith("/api/payments/paytr-callback") ||
                path.startsWith("/v3/api-docs") ||
                path.startsWith("/swagger-ui") ||
                path.equals("/error");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            // Bearer token bulunamadı: SecurityContext'e kimlik atamadan zincire devam et
            // Korumalı bir uç noktaya erişilmeye çalışılıyorsa AuthenticationEntryPoint 401 dönecektir.
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7).trim();

        try {
            Long userId = jwtService.extractUserId(token);
            Optional<User> userOpt = userRepository.findById(userId);

            if (userOpt.isEmpty()) {
                writeUnauthorizedResponse(response, "Kullanıcı sistemde bulunamadı.");
                return;
            }

            User user = userOpt.get();
            List<GrantedAuthority> authorities = new ArrayList<>();
            if (user.getRole() != null) {
                authorities.add(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()));
                authorities.add(new SimpleGrantedAuthority(user.getRole().name()));
                if (user.getRole() == com.ars.kirazbackend.enums.RoleType.AGENT ||
                        user.getRole() == com.ars.kirazbackend.enums.RoleType.PROPERTY_MANAGER) {
                    authorities.add(new SimpleGrantedAuthority("ROLE_PROPERTY_MANAGER"));
                    authorities.add(new SimpleGrantedAuthority("PROPERTY_MANAGER"));
                    authorities.add(new SimpleGrantedAuthority("ROLE_AGENT"));
                    authorities.add(new SimpleGrantedAuthority("AGENT"));
                }
            }

            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(user, null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authentication);

            filterChain.doFilter(request, response);

        } catch (ExpiredJwtException e) {
            log.warn("JWT süresi dolmuş: {}", e.getMessage());
            writeUnauthorizedResponse(response, "Token süresi dolmuş. Lütfen tekrar giriş yapın veya token'ı yenileyin.");
        } catch (JwtException | IllegalArgumentException e) {
            log.warn("Geçersiz JWT: {}", e.getMessage());
            writeUnauthorizedResponse(response, "Geçersiz veya bozuk kimlik doğrulama token'ı.");
        }
    }

    private void writeUnauthorizedResponse(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        Map<String, Object> body = Map.of(
                "status", 401,
                "error", "Unauthorized",
                "message", message
        );

        response.getWriter().write(objectMapper.writeValueAsString(body));
    }
}
