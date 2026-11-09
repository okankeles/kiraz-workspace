package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.InviteValidationResponse;
import com.ars.kirazbackend.dto.LeaseRequest;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.LeaseService;
import com.ars.kirazbackend.service.RentPeriodService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/leases")
@RequiredArgsConstructor
public class LeaseController {

    private final LeaseService leaseService;
    private final RentPeriodService rentPeriodService;
    private final AccessControlService authz;

    @PostMapping
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<LeaseAgreement> createLease(@RequestBody LeaseRequest request) {
        User creator = authz.getCurrentUser();
        if (creator == null || creator.getId() == null) {
            throw new RuntimeException("Kullanıcı kimliği belirlenemedi.");
        }

        // Mülk üzerinde işlem yapma yetkisi
        authz.checkCanManageProperty(request.getPropertyId());

        // Body'deki agentId / createdById parametrelerine güvenilmez: kimlik token'dan gelir
        if (creator.getRole() == RoleType.AGENT || creator.getRole() == RoleType.PROPERTY_MANAGER) {
            request.setAgentId(creator.getId());
        } else {
            request.setAgentId(null);
        }
        request.setCreatedById(creator.getId());

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
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForProperty(@PathVariable Long propertyId) {
        authz.checkCanViewProperty(propertyId);
        return ResponseEntity.ok(leaseService.getLeasesForProperty(propertyId));
    }

    @GetMapping("/tenant")
    @PreAuthorize("hasRole('TENANT')")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForTenant() {
        User tenant = authz.getCurrentUser();
        if (tenant == null || tenant.getId() == null) {
            throw new RuntimeException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getLeasesForTenant(tenant.getId()));
    }

    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForLandlord() {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getLeasesForLandlord(landlord.getId()));
    }

    @GetMapping("/pending-approvals")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<LeaseAgreement>> getPendingApprovals() {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getPendingApprovalLeasesForLandlord(landlord.getId()));
    }

    @GetMapping("/{leaseId}/periods")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<List<RentPeriod>> getRentPeriods(@PathVariable Long leaseId) {
        authz.checkCanViewLease(leaseId);
        return ResponseEntity.ok(rentPeriodService.getPeriodsByLeaseId(leaseId));
    }

    @PutMapping("/{id}/activate")
    @PreAuthorize("hasAnyRole('LANDLORD', 'TENANT')")
    public ResponseEntity<LeaseAgreement> activateLease(@PathVariable Long id) {
        authz.checkCanActivateLease(id);
        return ResponseEntity.ok(leaseService.activateLeaseDirectly(id));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<LeaseAgreement> getLeaseById(@PathVariable Long id) {
        authz.checkCanViewLease(id);
        return ResponseEntity.ok(leaseService.getLeaseById(id));
    }

    @PostMapping(value = "/{id}/contract", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<LeaseAgreement> uploadContract(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {
        authz.checkCanUploadContract(id);
        Long userId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.uploadContract(id, file, userId));
    }

    @PutMapping("/{id}/approve")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<LeaseAgreement> approveLease(@PathVariable Long id) {
        authz.checkCanApproveOrRejectLease(id);
        Long landlordId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.approveLease(id, landlordId));
    }

    @PutMapping("/{id}/reject")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<LeaseAgreement> rejectLease(
            @PathVariable Long id,
            @RequestParam(required = false) String reason) {
        authz.checkCanApproveOrRejectLease(id);
        Long landlordId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.rejectLease(id, landlordId, reason));
    }
}
