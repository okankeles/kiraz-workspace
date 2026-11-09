package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.LandlordDashboardResponse;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.LandlordDashboardService;
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

import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/landlord/dashboard")
@RequiredArgsConstructor
public class LandlordDashboardController {

    private final LandlordDashboardService landlordDashboardService;
    private final UserRepository userRepository;

    @GetMapping
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<LandlordDashboardResponse> getDashboard(
            Authentication authentication
    ) {
        Long resolvedLandlordId = resolveLandlordId(authentication);
        if (resolvedLandlordId == null) {
            log.warn("Could not resolve landlord ID from SecurityContext");
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }

        log.info("Fetching landlord dashboard for landlordId={}", resolvedLandlordId);
        LandlordDashboardResponse response = landlordDashboardService.getDashboardSummary(resolvedLandlordId);
        return ResponseEntity.ok(response);
    }

    private Long resolveLandlordId(Authentication auth) {
        if (auth == null) {
            auth = SecurityContextHolder.getContext().getAuthentication();
        }

        if (auth != null) {
            if (auth.getPrincipal() instanceof User user) {
                return user.getId();
            } else if (auth.getName() != null && !auth.getName().trim().isEmpty()) {
                Optional<User> userOpt = userRepository.findByEmail(auth.getName().trim());
                if (userOpt.isPresent()) {
                    return userOpt.get().getId();
                }
            }
        }

        return null;
    }
}
