package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PropertyDelegationRequest;
import com.ars.kirazbackend.dto.RevokeDelegationRequest;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.service.PropertyDelegationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/delegations")
@RequiredArgsConstructor
public class PropertyDelegationController {

    private final PropertyDelegationService delegationService;

    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<com.ars.kirazbackend.dto.PropertyDelegationResponse> assignAgent(@RequestBody PropertyDelegationRequest request) {
        PropertyDelegation delegation = delegationService.assignAgent(request);
        return ResponseEntity.ok(com.ars.kirazbackend.dto.PropertyDelegationResponse.fromEntity(delegation));
    }

    @PutMapping("/{id}/revoke")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<PropertyDelegation> revokeDelegation(
            @PathVariable Long id,
            @RequestBody(required = false) RevokeDelegationRequest request,
            @RequestParam(required = false) Long landlordId,
            @RequestParam(required = false) String reason) {

        Long effectiveLandlordId = (request != null && request.getLandlordId() != null)
                ? request.getLandlordId()
                : landlordId;
        String effectiveReason = (request != null && request.getReason() != null)
                ? request.getReason()
                : reason;

        return ResponseEntity.ok(delegationService.revokeDelegation(id, effectiveLandlordId, effectiveReason));
    }

    @GetMapping("/property/{propertyId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT')")
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForProperty(@PathVariable Long propertyId) {
        return ResponseEntity.ok(delegationService.getDelegationsForProperty(propertyId));
    }

    @GetMapping("/agent/{agentId}/active")
    @PreAuthorize("hasRole('AGENT')")
    public ResponseEntity<List<PropertyDelegation>> getActiveDelegationsForAgent(@PathVariable Long agentId) {
        return ResponseEntity.ok(delegationService.getActiveDelegationsForAgent(agentId));
    }

    @GetMapping("/agent/{agentId}")
    @PreAuthorize("hasRole('AGENT')")
    public ResponseEntity<List<PropertyDelegation>> getDelegationHistoryForAgent(@PathVariable Long agentId) {
        return ResponseEntity.ok(delegationService.getDelegationHistoryForAgent(agentId));
    }

    @GetMapping("/landlord/{landlordId}")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForLandlord(@PathVariable Long landlordId) {
        return ResponseEntity.ok(delegationService.getDelegationsGrantedBy(landlordId));
    }
}
