package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PropertyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/landlord/properties")
@RequiredArgsConstructor
@Tag(name = "Landlord - Properties", description = "Ev sahibi mülk işlemleri (Kanonik)")
public class LandlordPropertyController {

    private final PropertyService propertyService;
    private final AccessControlService authz;

    /**
     * Ev sahibinin kendi mülklerini listeler (Kanonik uç).
     */
    @GetMapping
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Ev sahibinin mülklerini listele (Kanonik)")
    public ResponseEntity<List<Property>> getLandlordProperties() {
        Long landlordId = authz.getCurrentUserId();
        if (landlordId == null) {
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(propertyService.getPropertiesByLandlord(landlordId));
    }
}
