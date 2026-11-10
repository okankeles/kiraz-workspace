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
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "Leases", description = "Sözleşme yönetimi uçları")
public class LeaseController {

    private final LeaseService leaseService;
    private final RentPeriodService rentPeriodService;
    private final AccessControlService authz;

    @PostMapping
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Yeni sözleşme oluştur (Kanonik)")
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
    @Operation(summary = "Davet kodu ile sözleşmeyi kabul et ve şifre belirle (Kanonik)")
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
    @Operation(summary = "Davet kodunu doğrula (Kanonik)")
    public ResponseEntity<InviteValidationResponse> validateInvite(@RequestParam String inviteCode) {
        return ResponseEntity.ok(leaseService.validateInvite(inviteCode));
    }

    @GetMapping("/property/{propertyId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Mülke ait sözleşmeleri getir (Kanonik)")
    public ResponseEntity<List<LeaseAgreement>> getLeasesForProperty(@PathVariable Long propertyId) {
        authz.checkCanViewProperty(propertyId);
        return ResponseEntity.ok(leaseService.getLeasesForProperty(propertyId));
    }

    @Deprecated
    @GetMapping("/tenant")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracı sözleşmeleri (Deprecated - yerine /api/tenant/leases kullanın)", deprecated = true)
    public ResponseEntity<List<LeaseAgreement>> getLeasesForTenant() {
        User tenant = authz.getCurrentUser();
        if (tenant == null || tenant.getId() == null) {
            throw new RuntimeException("Kiracı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getLeasesForTenant(tenant.getId()));
    }

    @Deprecated
    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Ev sahibi sözleşmeleri (Deprecated - yerine /api/landlord/leases kullanın)", deprecated = true)
    public ResponseEntity<List<LeaseAgreement>> getLeasesForLandlord() {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getLeasesForLandlord(landlord.getId()));
    }

    @Deprecated
    @GetMapping("/pending-approvals")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Onay bekleyen sözleşmeler (Deprecated - yerine /api/landlord/leases/pending-approvals kullanın)", deprecated = true)
    public ResponseEntity<List<LeaseAgreement>> getPendingApprovals() {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getPendingApprovalLeasesForLandlord(landlord.getId()));
    }

    @GetMapping("/{leaseId}/periods")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Sözleşmeye ait kira dönemlerini listele (Kanonik)")
    public ResponseEntity<List<RentPeriod>> getRentPeriods(@PathVariable Long leaseId) {
        authz.checkCanViewLease(leaseId);
        return ResponseEntity.ok(rentPeriodService.getPeriodsByLeaseId(leaseId));
    }

    @PutMapping("/{id}/activate")
    @PreAuthorize("hasAnyRole('LANDLORD', 'TENANT')")
    @Operation(summary = "Sözleşmeyi aktif et (Ev sahibi onayı gerektirir)")
    public ResponseEntity<LeaseAgreement> activateLease(@PathVariable Long id) {
        authz.checkCanActivateLease(id);
        return ResponseEntity.ok(leaseService.activateLeaseDirectly(id));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Sözleşme detayını getir (Kanonik)")
    public ResponseEntity<LeaseAgreement> getLeaseById(@PathVariable Long id) {
        authz.checkCanViewLease(id);
        return ResponseEntity.ok(leaseService.getLeaseById(id));
    }

    @PostMapping(value = "/{id}/contract", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Sözleşme belgesi yükle (Kanonik)")
    public ResponseEntity<LeaseAgreement> uploadContract(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {
        authz.checkCanUploadContract(id);
        Long userId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.uploadContract(id, file, userId));
    }

    @Deprecated
    @PutMapping("/{id}/approve")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Sözleşmeyi onayla (Deprecated - yerine POST /api/landlord/leases/{id}/approve kullanın)", deprecated = true)
    public ResponseEntity<LeaseAgreement> approveLease(@PathVariable Long id) {
        authz.checkCanApproveOrRejectLease(id);
        Long landlordId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.approveLease(id, landlordId));
    }

    @Deprecated
    @PutMapping("/{id}/reject")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Sözleşmeyi reddet (Deprecated - yerine POST /api/landlord/leases/{id}/reject kullanın)", deprecated = true)
    public ResponseEntity<LeaseAgreement> rejectLease(
            @PathVariable Long id,
            @RequestParam(required = false) String reason) {
        authz.checkCanApproveOrRejectLease(id);
        Long landlordId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.rejectLease(id, landlordId, reason));
    }
}
