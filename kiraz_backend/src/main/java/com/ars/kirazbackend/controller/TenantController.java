package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.DashboardStatsDTO;
import com.ars.kirazbackend.dto.PaymentSummaryResponse;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.DashboardService;
import com.ars.kirazbackend.service.LeaseService;
import com.ars.kirazbackend.service.RentPeriodService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/tenant")
@RequiredArgsConstructor
@Tag(name = "Tenant", description = "Kiracı işlemleri (Kanonik)")
public class TenantController {

    private final DashboardService dashboardService;
    private final LeaseService leaseService;
    private final RentPeriodService rentPeriodService;
    private final AccessControlService authz;

    /**
     * Kiracının gösterge paneli istatistiklerini döner (Kanonik uç).
     */
    @GetMapping("/dashboard")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracı gösterge paneli istatistikleri (Kanonik)")
    public ResponseEntity<DashboardStatsDTO> getTenantStats() {
        Long tenantId = authz.getCurrentUserId();
        if (tenantId == null) {
            throw new AuthenticationCredentialsNotFoundException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(dashboardService.getTenantStats(tenantId));
    }

    /**
     * Kiracının sözleşmelerini listeler (Kanonik uç).
     */
    @GetMapping("/leases")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracının sözleşmelerini listele (Kanonik)")
    public ResponseEntity<List<LeaseAgreement>> getTenantLeases() {
        Long tenantId = authz.getCurrentUserId();
        if (tenantId == null) {
            throw new AuthenticationCredentialsNotFoundException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getLeasesForTenant(tenantId));
    }

    /**
     * Kiracının ödeme özetini döner (Kanonik uç).
     */
    @GetMapping("/payments/summary")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracının anlık finansal ve ödeme özeti (Kanonik)")
    public ResponseEntity<PaymentSummaryResponse> getPaymentSummary() {
        Long tenantId = authz.getCurrentUserId();
        if (tenantId == null) {
            throw new AuthenticationCredentialsNotFoundException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(rentPeriodService.getTenantPaymentSummary(tenantId));
    }

    /**
     * Kiracının belirli bir kira dönemi için dekont yüklemesi (Kanonik uç).
     */
    @PostMapping(value = "/receipts/{periodId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracının kira dönemi için dekont yüklemesi (Kanonik)")
    public ResponseEntity<RentPeriod> uploadReceipt(
            @PathVariable Long periodId,
            @RequestParam("file") MultipartFile file) {
        authz.checkCanUploadReceipt(periodId);
        return ResponseEntity.ok(rentPeriodService.uploadReceipt(periodId, file));
    }
}
