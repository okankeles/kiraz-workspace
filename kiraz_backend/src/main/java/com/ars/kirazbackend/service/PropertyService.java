package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PropertyRequest;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.LeaseStatus;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class PropertyService {
    private final PropertyRepository propertyRepository;
    private final UserRepository userRepository;
    private final LeaseAgreementRepository leaseAgreementRepository;

    public Property createProperty(PropertyRequest request) {
        User landlord = userRepository.findById(request.getLandlordId())
                .orElseThrow(() -> new RuntimeException("Landlord not found"));

        Property property = Property.builder()
                .landlord(landlord)
                .title(request.getTitle())
                .address(request.getAddress())
                .city(request.getCity())
                .daskEndDate(request.getDaskEndDate())
                .build();
        return propertyRepository.save(property);
    }

    public List<Property> getPropertiesByLandlord(Long landlordId) {
        if (landlordId == null) {
            return java.util.Collections.emptyList();
        }
        List<Property> properties = propertyRepository.findByLandlordId(landlordId);
        properties.forEach(this::populateTenantInfo);
        return properties;
    }

    private void populateTenantInfo(Property property) {
        if (property == null || property.getId() == null) {
            return;
        }
        List<LeaseAgreement> leases = leaseAgreementRepository.findByPropertyId(property.getId());
        LeaseAgreement targetLease = leases.stream()
                .filter(l -> l.getStatus() == LeaseStatus.ACTIVE)
                .findFirst()
                .orElseGet(() -> leases.stream()
                        .filter(l -> l.getStatus() == LeaseStatus.PENDING)
                        .findFirst()
                        .orElse(null));

        if (targetLease != null) {
            if (targetLease.getTenant() != null) {
                property.setTenantName(targetLease.getTenant().getFullName());
                property.setTenantEmail(targetLease.getTenant().getEmail());
                property.setTenantPhone(targetLease.getTenant().getPhone());
            }
            if (targetLease.getDepositAmount() != null) {
                property.setDepositAmount(targetLease.getDepositAmount());
            }
        }
    }
}
