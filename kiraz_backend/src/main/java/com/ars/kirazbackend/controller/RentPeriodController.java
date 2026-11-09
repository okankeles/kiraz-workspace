package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.RentPeriodService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/periods")
@RequiredArgsConstructor
public class RentPeriodController {

    private final RentPeriodService rentPeriodService;
    private final AccessControlService authz;

    @GetMapping("/lease/{leaseId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<List<RentPeriod>> getPeriodsByLeaseId(@PathVariable Long leaseId) {
        authz.checkCanViewLease(leaseId);
        return ResponseEntity.ok(rentPeriodService.getPeriodsByLeaseId(leaseId));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<RentPeriod> getPeriodById(@PathVariable Long id) {
        authz.checkCanViewPeriod(id);
        return ResponseEntity.ok(rentPeriodService.getPeriodById(id));
    }

    @PostMapping(value = "/{id}/receipt", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('TENANT')")
    public ResponseEntity<RentPeriod> uploadReceipt(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {
        authz.checkCanUploadReceipt(id);
        return ResponseEntity.ok(rentPeriodService.uploadReceipt(id, file));
    }

    @PutMapping("/{id}/legal-process")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<RentPeriod> initiateLegalProcess(
            @PathVariable Long id,
            @RequestParam(required = false) String notes) {
        authz.checkCanInitiateLegalProcess(id);
        Long userId = authz.getCurrentUserId();
        return ResponseEntity.ok(rentPeriodService.markAsLegalProcess(id, userId, notes));
    }
}
