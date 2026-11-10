package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PropertyDelegationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/delegations")
@RequiredArgsConstructor
@Tag(name = "Delegations", description = "Vekalet ve delegasyon yönetimi uçları")
public class PropertyDelegationController {

    private final PropertyDelegationService delegationService;
    private final AccessControlService authz;

    @GetMapping("/property/{propertyId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    @Operation(summary = "Mülke ait vekaletleri listele (Kanonik)")
    public ResponseEntity<List<PropertyDelegation>> getDelegationsForProperty(@PathVariable Long propertyId) {
        authz.checkCanViewProperty(propertyId);
        return ResponseEntity.ok(delegationService.getDelegationsForProperty(propertyId));
    }
}
