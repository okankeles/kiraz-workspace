package com.ars.kirazbackend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PropertyDelegationRequest {
    private Long propertyId;
    private Long agentId;
    private String agentEmail;
    private String agentName;
    private Long landlordId;
    private LocalDate startDate;
    private LocalDate endDate;
    private String notes;
}
