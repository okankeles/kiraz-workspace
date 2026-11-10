package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.RentPeriodService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/periods")
@RequiredArgsConstructor
@Tag(name = "Periods", description = "Kira dönemi yönetimi uçları")
public class RentPeriodController {

    private final RentPeriodService rentPeriodService;
    private final AccessControlService authz;

    @GetMapping("/lease/{leaseId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Sözleşmeye ait dönemleri listele (Kanonik)")
    public ResponseEntity<List<RentPeriod>> getPeriodsByLeaseId(@PathVariable Long leaseId) {
        authz.checkCanViewLease(leaseId);
        return ResponseEntity.ok(rentPeriodService.getPeriodsByLeaseId(leaseId));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Kira dönemi detayını getir (Kanonik)")
    public ResponseEntity<RentPeriod> getPeriodById(@PathVariable Long id) {
        authz.checkCanViewPeriod(id);
        return ResponseEntity.ok(rentPeriodService.getPeriodById(id));
    }

    @PutMapping("/{id}/legal-process")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Hukuki süreç başlat (Kanonik)")
    public ResponseEntity<RentPeriod> initiateLegalProcess(
            @PathVariable Long id,
            @RequestParam(required = false) String notes) {
        authz.checkCanInitiateLegalProcess(id);
        Long userId = authz.getCurrentUserId();
        return ResponseEntity.ok(rentPeriodService.markAsLegalProcess(id, userId, notes));
    }
}
