package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.DashboardStatsDTO;
import com.ars.kirazbackend.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;

    @GetMapping("/landlord/{id}")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<DashboardStatsDTO> getLandlordStats(@PathVariable Long id) {
        return ResponseEntity.ok(dashboardService.getLandlordStats(id));
    }

    @GetMapping("/tenant/{id}")
    @PreAuthorize("hasRole('TENANT')")
    public ResponseEntity<DashboardStatsDTO> getTenantStats(@PathVariable Long id) {
        return ResponseEntity.ok(dashboardService.getTenantStats(id));
    }

    @GetMapping("/agent/{id}")
    @PreAuthorize("hasRole('AGENT')")
    public ResponseEntity<DashboardStatsDTO> getAgentStats(@PathVariable Long id) {
        return ResponseEntity.ok(dashboardService.getAgentStats(id));
    }
}
