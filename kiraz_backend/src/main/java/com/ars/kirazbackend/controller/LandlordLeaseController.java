package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.LeaseService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/landlord/leases")
@RequiredArgsConstructor
@Tag(name = "Landlord - Leases", description = "Ev sahibi sözleşme işlemleri (Kanonik)")
public class LandlordLeaseController {

    private final LeaseService leaseService;
    private final AccessControlService authz;

    /**
     * Ev sahibinin mülklerine bağlı sözleşmeleri listeler (Kanonik uç).
     */
    @GetMapping
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Ev sahibinin sözleşmelerini listele (Kanonik)")
    public ResponseEntity<List<LeaseAgreement>> getLandlordLeases() {
        Long landlordId = authz.getCurrentUserId();
        if (landlordId == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getLeasesForLandlord(landlordId));
    }

    /**
     * Ev sahibinin onayını bekleyen (emlakçılar tarafından oluşturulmuş) sözleşmeleri listeler (Kanonik uç).
     */
    @GetMapping("/pending-approvals")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Ev sahibi onayını bekleyen sözleşmeleri listele (Kanonik)")
    public ResponseEntity<List<LeaseAgreement>> getPendingApprovals() {
        Long landlordId = authz.getCurrentUserId();
        if (landlordId == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(leaseService.getPendingApprovalLeasesForLandlord(landlordId));
    }

    /**
     * Emlakçı tarafından oluşturulan sözleşmeyi onaylar (Kanonik uç).
     */
    @PostMapping("/{id}/approve")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Emlakçının hazırladığı sözleşmeyi onayla (Kanonik)")
    public ResponseEntity<LeaseAgreement> approveLease(@PathVariable Long id) {
        authz.checkCanApproveOrRejectLease(id);
        Long landlordId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.approveLease(id, landlordId));
    }

    /**
     * Emlakçı tarafından oluşturulan sözleşmeyi reddeder (Kanonik uç).
     */
    @PostMapping("/{id}/reject")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Emlakçının hazırladığı sözleşmeyi reddet (Kanonik)")
    public ResponseEntity<LeaseAgreement> rejectLease(
            @PathVariable Long id,
            @RequestParam(required = false) String reason) {
        authz.checkCanApproveOrRejectLease(id);
        Long landlordId = authz.getCurrentUserId();
        return ResponseEntity.ok(leaseService.rejectLease(id, landlordId, reason));
    }
}
