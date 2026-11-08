package com.ars.kirazbackend.config;

import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Slf4j
@Component
@RequiredArgsConstructor
public class UserAuthenticationFilter extends OncePerRequestFilter {

    private final UserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            resolveUser(request).ifPresent(user -> {
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
            });
        }

        filterChain.doFilter(request, response);
    }

    private Optional<User> resolveUser(HttpServletRequest request) {
        // 1. Check X-User-Id header
        String userIdHeader = request.getHeader("X-User-Id");
        if (userIdHeader != null && !userIdHeader.trim().isEmpty()) {
            try {
                Long id = Long.parseLong(userIdHeader.trim());
                return userRepository.findById(id);
            } catch (NumberFormatException ignored) {
            }
        }

        // 2. Check X-User-Email header
        String userEmailHeader = request.getHeader("X-User-Email");
        if (userEmailHeader != null && !userEmailHeader.trim().isEmpty()) {
            return userRepository.findByEmail(userEmailHeader.trim());
        }

        // 3. Check Authorization header (Bearer <id or email>)
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7).trim();
            try {
                Long id = Long.parseLong(token);
                return userRepository.findById(id);
            } catch (NumberFormatException e) {
                return userRepository.findByEmail(token);
            }
        }

        // 4. Check query or form parameters for landlordId, agentId, or userId
        String userIdParam = request.getParameter("userId");
        if (userIdParam != null && !userIdParam.trim().isEmpty()) {
            try {
                return userRepository.findById(Long.parseLong(userIdParam.trim()));
            } catch (NumberFormatException ignored) {
            }
        }

        String landlordIdParam = request.getParameter("landlordId");
        if (landlordIdParam != null && !landlordIdParam.trim().isEmpty()) {
            try {
                return userRepository.findById(Long.parseLong(landlordIdParam.trim()));
            } catch (NumberFormatException ignored) {
            }
        }

        String agentIdParam = request.getParameter("agentId");
        if (agentIdParam != null && !agentIdParam.trim().isEmpty()) {
            try {
                return userRepository.findById(Long.parseLong(agentIdParam.trim()));
            } catch (NumberFormatException ignored) {
            }
        }

        return Optional.empty();
    }
}
