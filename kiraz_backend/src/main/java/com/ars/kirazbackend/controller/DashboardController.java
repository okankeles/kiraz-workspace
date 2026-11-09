package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.DashboardStatsDTO;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;
    private final AccessControlService authz;

    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<DashboardStatsDTO> getLandlordStats() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getLandlordStats(user.getId()));
    }

    @GetMapping("/tenant")
    @PreAuthorize("hasRole('TENANT')")
    public ResponseEntity<DashboardStatsDTO> getTenantStats() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getTenantStats(user.getId()));
    }

    @GetMapping("/agent")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<DashboardStatsDTO> getAgentStats() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getAgentStats(user.getId()));
    }
}
