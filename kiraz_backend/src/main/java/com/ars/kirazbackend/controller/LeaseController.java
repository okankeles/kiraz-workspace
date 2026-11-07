package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.InviteValidationResponse;
import com.ars.kirazbackend.dto.LeaseRequest;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.service.LeaseService;
import com.ars.kirazbackend.service.RentPeriodService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/leases")
@RequiredArgsConstructor
public class LeaseController {
    private final LeaseService leaseService;
    private final RentPeriodService rentPeriodService;

    @PostMapping
    @org.springframework.security.access.prepost.PreAuthorize("hasAnyRole('LANDLORD', 'AGENT')")
    public ResponseEntity<LeaseAgreement> createLease(@RequestBody LeaseRequest request) {
        return ResponseEntity.ok(leaseService.createLease(request));
    }

    @PostMapping("/accept")
    public ResponseEntity<InviteValidationResponse> acceptLease(
            @RequestParam String inviteCode,
            @RequestParam String newPassword) {
        LeaseAgreement lease = leaseService.acceptLease(inviteCode, newPassword);
        String email = lease.getTenant() != null ? lease.getTenant().getEmail() : null;
        String name = lease.getTenant() != null ? lease.getTenant().getFullName() : null;

        InviteValidationResponse response = InviteValidationResponse.builder()
                .tenantEmail(email)
                .tenantName(name)
                .leaseId(lease.getId())
                .status(lease.getStatus() != null ? lease.getStatus().name() : null)
                .message("Sözleşme başarıyla onaylandı")
                .build();

        return ResponseEntity.ok(response);
    }

    @GetMapping("/validate-invite")
    public ResponseEntity<InviteValidationResponse> validateInvite(@RequestParam String inviteCode) {
        return ResponseEntity.ok(leaseService.validateInvite(inviteCode));
    }

    @GetMapping("/property/{propertyId}")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForProperty(@PathVariable Long propertyId) {
        return ResponseEntity.ok(leaseService.getLeasesForProperty(propertyId));
    }

    @GetMapping("/tenant/{tenantId}")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForTenant(@PathVariable Long tenantId) {
        return ResponseEntity.ok(leaseService.getLeasesForTenant(tenantId));
    }

    @GetMapping("/landlord/{landlordId}")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForLandlord(@PathVariable Long landlordId) {
        return ResponseEntity.ok(leaseService.getLeasesForLandlord(landlordId));
    }

    @GetMapping("/{leaseId}/periods")
    public ResponseEntity<List<RentPeriod>> getRentPeriods(@PathVariable Long leaseId) {
        return ResponseEntity.ok(rentPeriodService.getPeriodsByLeaseId(leaseId));
    }

    @PutMapping("/{id}/activate")
    public ResponseEntity<LeaseAgreement> activateLease(@PathVariable Long id) {
        return ResponseEntity.ok(leaseService.activateLeaseDirectly(id));
    }

    @GetMapping("/{id}")
    public ResponseEntity<LeaseAgreement> getLeaseById(@PathVariable Long id) {
        return ResponseEntity.ok(leaseService.getLeaseById(id));
    }

    @PostMapping(value = "/{id}/contract", consumes = org.springframework.http.MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<LeaseAgreement> uploadContract(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) Long userId) {
        return ResponseEntity.ok(leaseService.uploadContract(id, file, userId));
    }

    @PutMapping("/{id}/approve")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<LeaseAgreement> approveLease(
            @PathVariable Long id,
            @RequestParam(required = false) Long landlordId) {
        return ResponseEntity.ok(leaseService.approveLease(id, landlordId));
    }

    @PutMapping("/{id}/reject")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<LeaseAgreement> rejectLease(
            @PathVariable Long id,
            @RequestParam(required = false) Long landlordId,
            @RequestParam(required = false) String reason) {
        return ResponseEntity.ok(leaseService.rejectLease(id, landlordId, reason));
    }

    @GetMapping("/landlord/{landlordId}/pending-approvals")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<LeaseAgreement>> getPendingApprovals(@PathVariable Long landlordId) {
        return ResponseEntity.ok(leaseService.getPendingApprovalLeasesForLandlord(landlordId));
    }
}
