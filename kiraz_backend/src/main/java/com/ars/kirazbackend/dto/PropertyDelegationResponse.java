package com.ars.kirazbackend.dto;

import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.DelegationStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PropertyDelegationResponse {
    private Long id;
    private Property property;
    private User agent;
    private User grantedBy;
    private DelegationStatus status;
    private LocalDate startDate;
    private LocalDate endDate;
    private String referenceCode;
    private String propertyName;
    private String propertyAddress;
    private String propertyCity;
    private String agentName;
    private String agentEmail;
    private String agentPhone;
    private String grantedByName;
    private String grantedByEmail;
    private LocalDateTime createdAt;

    public static PropertyDelegationResponse fromEntity(PropertyDelegation delegation) {
        if (delegation == null) return null;
        return PropertyDelegationResponse.builder()
                .id(delegation.getId())
                .property(delegation.getProperty())
                .agent(delegation.getAgent())
                .grantedBy(delegation.getGrantedBy())
                .status(delegation.getStatus())
                .startDate(delegation.getStartDate())
                .endDate(delegation.getEndDate())
                .referenceCode(delegation.getReferenceCode())
                .propertyName(delegation.getPropertyName())
                .propertyAddress(delegation.getPropertyAddress())
                .propertyCity(delegation.getPropertyCity())
                .agentName(delegation.getAgentName())
                .agentEmail(delegation.getAgentEmail())
                .agentPhone(delegation.getAgentPhone())
                .grantedByName(delegation.getGrantedByName())
                .grantedByEmail(delegation.getGrantedByEmail())
                .createdAt(delegation.getCreatedAt())
                .build();
    }
}
