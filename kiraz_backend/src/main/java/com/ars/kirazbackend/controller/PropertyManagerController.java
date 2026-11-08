package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.PropertyDelegationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/manager")
@RequiredArgsConstructor
public class PropertyManagerController {

    private final PropertyDelegationService propertyDelegationService;
    private final UserRepository userRepository;

    @GetMapping("/properties")
    @PreAuthorize("hasRole('PROPERTY_MANAGER')")
    public ResponseEntity<List<Property>> getManagerProperties(
            @RequestParam(required = false) Long managerId,
            HttpServletRequest httpRequest,
            Authentication authentication
    ) {
        User manager = resolveManager(httpRequest, authentication, managerId);
        if (manager == null || manager.getId() == null) {
            log.warn("Could not resolve manager from SecurityContext or request");
            throw new RuntimeException("Mülk yöneticisi kimliği belirlenemedi.");
        }

        log.info("Fetching properties for managerId={}", manager.getId());
        List<Property> properties = propertyDelegationService.getManagerProperties(manager.getId());
        return ResponseEntity.ok(properties);
    }

    private User resolveManager(HttpServletRequest request, Authentication auth, Long paramManagerId) {
        if (auth == null) {
            auth = SecurityContextHolder.getContext().getAuthentication();
        }

        if (auth != null) {
            if (auth.getPrincipal() instanceof User user) {
                return user;
            } else if (auth.getName() != null && !auth.getName().trim().isEmpty()) {
                Optional<User> userOpt = userRepository.findByEmail(auth.getName().trim());
                if (userOpt.isPresent()) {
                    return userOpt.get();
                }
            }
        }

        if (paramManagerId != null) {
            return userRepository.findById(paramManagerId).orElse(null);
        }

        String headerId = request.getHeader("X-User-Id");
        if (headerId != null && !headerId.trim().isEmpty()) {
            try {
                return userRepository.findById(Long.parseLong(headerId.trim())).orElse(null);
            } catch (NumberFormatException ignored) {}
        }

        String headerEmail = request.getHeader("X-User-Email");
        if (headerEmail != null && !headerEmail.trim().isEmpty()) {
            return userRepository.findByEmail(headerEmail.trim()).orElse(null);
        }

        return null;
    }
}
