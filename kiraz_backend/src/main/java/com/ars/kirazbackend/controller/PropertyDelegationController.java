package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PropertyDelegationRequest;
import com.ars.kirazbackend.dto.RevokeDelegationRequest;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PropertyDelegationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/delegations")
@RequiredArgsConstructor
@Tag(name = "Delegations", description = "Vekalet ve delegasyon yönetimi uçları")
public class PropertyDelegationController {

    private final PropertyDelegationService delegationService;
    private final AccessControlService authz;

    @Deprecated
    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Vekalet ata (Deprecated - yerine POST /api/landlord/delegations kullanın)", deprecated = true)
    public ResponseEntity<com.ars.kirazbackend.dto.PropertyDelegationResponse> assignAgent(@RequestBody PropertyDelegationRequest request) {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }

        if (request != null && request.getPropertyId() != null) {
            authz.checkCanAssignDelegation(request.getPropertyId());
            request.setLandlordId(landlord.getId());
        }

        PropertyDelegation delegation = delegationService.assignAgent(request);
        return ResponseEntity.ok(com.ars.kirazbackend.dto.PropertyDelegationResponse.fromEntity(delegation));
    }

    @Deprecated
    @PutMapping("/{id}/revoke")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Vekalet iptal et (Deprecated - yerine DELETE /api/landlord/delegations/{id} kullanın)", deprecated = true)
    public ResponseEntity<PropertyDelegation> revokeDelegation(
            @PathVariable Long id,
            @RequestBody(required = false) RevokeDelegationRequest request,
            @RequestParam(required = false) String reason) {

        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }

        authz.checkCanRevokeDelegation(id);

        String effectiveReason = (request != null && request.getReason() != null)
                ? request.getReason()
                : reason;

        return ResponseEntity.ok(delegationService.revokeDelegation(id, landlord.getId(), effectiveReason));
    }

    @GetMapping("/property/{propertyId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Mülke ait vekaletleri listele (Kanonik)")
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForProperty(@PathVariable Long propertyId) {
        authz.checkCanViewProperty(propertyId);
        return ResponseEntity.ok(delegationService.getDelegationsForProperty(propertyId));
    }

    @Deprecated
    @GetMapping("/agent/active")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Emlakçının aktif vekaletleri (Deprecated - yerine GET /api/manager/delegations/active kullanın)", deprecated = true)
    public ResponseEntity<List<PropertyDelegation>> getActiveDelegationsForAgent() {
        User agent = authz.getCurrentUser();
        if (agent == null || agent.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(delegationService.getActiveDelegationsForAgent(agent.getId()));
    }

    @Deprecated
    @GetMapping("/agent")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Emlakçının vekalet geçmişi (Deprecated - yerine GET /api/manager/delegations kullanın)", deprecated = true)
    public ResponseEntity<List<PropertyDelegation>> getDelegationHistoryForAgent() {
        User agent = authz.getCurrentUser();
        if (agent == null || agent.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(delegationService.getDelegationHistoryForAgent(agent.getId()));
    }

    @Deprecated
    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Ev sahibinin verdiği vekaletler (Deprecated - yerine GET /api/landlord/delegations kullanın)", deprecated = true)
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForLandlord() {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(delegationService.getDelegationsGrantedBy(landlord.getId()));
    }
}
