package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PropertyRequest;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.service.PropertyService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/properties")
@RequiredArgsConstructor
public class PropertyController {
    private final PropertyService propertyService;

    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<Property> createProperty(@RequestBody PropertyRequest request) {
        return ResponseEntity.ok(propertyService.createProperty(request));
    }

    @GetMapping
    public ResponseEntity<List<Property>> getProperties(@RequestParam(required = false) Long landlordId) {
        return ResponseEntity.ok(propertyService.getPropertiesByLandlord(landlordId));
    }

    @GetMapping("/landlord/{landlordId}")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<Property>> getPropertiesByLandlord(@PathVariable Long landlordId) {
        return ResponseEntity.ok(propertyService.getPropertiesByLandlord(landlordId));
    }

    @GetMapping("/agent/{agentId}")
    @PreAuthorize("hasRole('AGENT')")
    public ResponseEntity<List<Property>> getPropertiesByAgent(@PathVariable Long agentId) {
        return ResponseEntity.ok(propertyService.getPropertiesForAgent(agentId));
    }
}
