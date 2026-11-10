package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.DashboardStatsDTO;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.DashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
@Tag(name = "Dashboard (Legacy)", description = "Eski gösterge paneli uçları (Deprecated)")
public class DashboardController {

    private final DashboardService dashboardService;
    private final AccessControlService authz;

    @Deprecated
    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Ev sahibi istatistikleri (Deprecated - yerine GET /api/landlord/dashboard kullanın)", deprecated = true)
    public ResponseEntity<DashboardStatsDTO> getLandlordStats() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getLandlordStats(user.getId()));
    }

    @Deprecated
    @GetMapping("/tenant")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracı istatistikleri (Deprecated - yerine GET /api/tenant/dashboard kullanın)", deprecated = true)
    public ResponseEntity<DashboardStatsDTO> getTenantStats() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getTenantStats(user.getId()));
    }

    @Deprecated
    @GetMapping("/agent")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Emlakçı istatistikleri (Deprecated - yerine GET /api/manager/dashboard kullanın)", deprecated = true)
    public ResponseEntity<DashboardStatsDTO> getAgentStats() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getAgentStats(user.getId()));
    }
}
