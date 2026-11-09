package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PropertyDelegationRequest;
import com.ars.kirazbackend.dto.RevokeDelegationRequest;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PropertyDelegationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/delegations")
@RequiredArgsConstructor
public class PropertyDelegationController {

    private final PropertyDelegationService delegationService;
    private final AccessControlService authz;

    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
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

    @PutMapping("/{id}/revoke")
    @PreAuthorize("hasRole('LANDLORD')")
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
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForProperty(@PathVariable Long propertyId) {
        authz.checkCanViewProperty(propertyId);
        return ResponseEntity.ok(delegationService.getDelegationsForProperty(propertyId));
    }

    @GetMapping("/agent/active")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<List<PropertyDelegation>> getActiveDelegationsForAgent() {
        User agent = authz.getCurrentUser();
        if (agent == null || agent.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(delegationService.getActiveDelegationsForAgent(agent.getId()));
    }

    @GetMapping("/agent")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<List<PropertyDelegation>> getDelegationHistoryForAgent() {
        User agent = authz.getCurrentUser();
        if (agent == null || agent.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(delegationService.getDelegationHistoryForAgent(agent.getId()));
    }

    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForLandlord() {
        User landlord = authz.getCurrentUser();
        if (landlord == null || landlord.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(delegationService.getDelegationsGrantedBy(landlord.getId()));
    }
}
