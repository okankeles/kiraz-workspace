package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PropertyRequest;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PropertyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/properties")
@RequiredArgsConstructor
public class PropertyController {

    private final PropertyService propertyService;
    private final AccessControlService authz;

    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<Property> createProperty(@RequestBody PropertyRequest request) {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        // İstemcinin gönderdiği landlordId'ye güvenme: Kimlik token'dan gelir
        request.setLandlordId(user.getId());
        return ResponseEntity.ok(propertyService.createProperty(request));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<List<Property>> getProperties() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kullanıcı kimliği belirlenemedi.");
        }

        if (user.getRole() == RoleType.LANDLORD) {
            return ResponseEntity.ok(propertyService.getPropertiesByLandlord(user.getId()));
        } else {
            return ResponseEntity.ok(propertyService.getPropertiesForAgent(user.getId()));
        }
    }

    @GetMapping("/landlord")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<Property>> getLandlordProperties() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(propertyService.getPropertiesByLandlord(user.getId()));
    }

    @GetMapping("/agent")
    @PreAuthorize("hasAnyRole('AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<List<Property>> getAgentProperties() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Emlakçı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(propertyService.getPropertiesForAgent(user.getId()));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<Property> getPropertyById(@PathVariable Long id) {
        authz.checkCanViewProperty(id);
        return ResponseEntity.ok(propertyService.getPropertyById(id));
    }
}
