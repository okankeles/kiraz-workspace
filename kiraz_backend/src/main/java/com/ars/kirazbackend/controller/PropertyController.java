package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PropertyRequest;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PropertyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/properties")
@RequiredArgsConstructor
@Tag(name = "Properties", description = "Mülk yönetimi uçları")
public class PropertyController {

    private final PropertyService propertyService;
    private final AccessControlService authz;

    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Yeni mülk oluştur (Kanonik)")
    public ResponseEntity<Property> createProperty(@RequestBody PropertyRequest request) {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        // İstemcinin gönderdiği landlordId'ye güvenme: Kimlik token'dan gelir
        request.setLandlordId(user.getId());
        return ResponseEntity.ok(propertyService.createProperty(request));
    }


    @GetMapping("/{id:\\d+}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Mülk detayını getir (Kanonik)")
    public ResponseEntity<Property> getPropertyById(@PathVariable Long id) {
        authz.checkCanViewProperty(id);
        return ResponseEntity.ok(propertyService.getPropertyById(id));
    }

    @PutMapping("/{id:\\d+}")
    @PreAuthorize("hasRole('LANDLORD')")
    @Operation(summary = "Mülk bilgilerini güncelle (Kanonik)")
    public ResponseEntity<Property> updateProperty(
            @PathVariable Long id,
            @RequestBody PropertyRequest request) {
        authz.checkCanUpdateProperty(id);
        User user = authz.getCurrentUser();
        return ResponseEntity.ok(propertyService.updateProperty(id, request, user));
    }
}

