package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.DashboardStatsDTO;
import com.ars.kirazbackend.dto.DelegationResponseDto;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.DashboardService;
import com.ars.kirazbackend.service.PropertyDelegationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/manager")
@RequiredArgsConstructor
@Tag(name = "Manager", description = "Mülk yöneticisi / Emlakçı işlemleri (Kanonik)")
public class PropertyManagerController {

    private final PropertyDelegationService propertyDelegationService;
    private final DashboardService dashboardService;
    private final UserRepository userRepository;

    /**
     * Mülk yöneticisinin aktif vekaleti olan mülkleri listeler (Kanonik uç).
     */
    @GetMapping("/properties")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Yöneticinin yetkili olduğu mülkleri listele (Kanonik)")
    public ResponseEntity<List<Property>> getManagerProperties(Authentication authentication) {
        User manager = resolveManager(authentication);
        if (manager == null || manager.getId() == null) {
            log.warn("Could not resolve manager from SecurityContext");
            throw new AuthenticationCredentialsNotFoundException("Mülk yöneticisi kimliği belirlenemedi.");
        }

        log.info("Fetching properties for managerId={}", manager.getId());
        List<Property> properties = propertyDelegationService.getManagerProperties(manager.getId());
        return ResponseEntity.ok(properties);
    }

    /**
     * Mülk yöneticisinin aktif vekaletlerini listeler (Kanonik uç).
     */
    @GetMapping("/delegations/active")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Yöneticinin aktif vekaletlerini listele (Kanonik)")
    public ResponseEntity<List<PropertyDelegation>> getActiveDelegations(Authentication authentication) {
        User manager = resolveManager(authentication);
        if (manager == null || manager.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Mülk yöneticisi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(propertyDelegationService.getActiveDelegationsForAgent(manager.getId()));
    }

    /**
     * Mülk yöneticisinin tüm vekalet geçmişini listeler (Kanonik uç).
     */
    @GetMapping("/delegations")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Yöneticinin tüm vekalet geçmişini listele (Kanonik)")
    public ResponseEntity<List<PropertyDelegation>> getDelegationsHistory(Authentication authentication) {
        User manager = resolveManager(authentication);
        if (manager == null || manager.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Mülk yöneticisi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(propertyDelegationService.getDelegationHistoryForAgent(manager.getId()));
    }

    /**
     * Mülk yöneticisinin gösterge paneli istatistiklerini döner (Kanonik uç).
     */
    @GetMapping("/dashboard")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Yöneticinin dashboard istatistiklerini döner (Kanonik)")
    public ResponseEntity<DashboardStatsDTO> getManagerDashboard(Authentication authentication) {
        User manager = resolveManager(authentication);
        if (manager == null || manager.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Mülk yöneticisi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getAgentStats(manager.getId()));
    }

    private User resolveManager(Authentication auth) {
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

        return null;
    }
}
