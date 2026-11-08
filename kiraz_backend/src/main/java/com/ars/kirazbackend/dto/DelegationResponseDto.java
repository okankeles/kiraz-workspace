package com.ars.kirazbackend.dto;

import com.ars.kirazbackend.entity.PropertyDelegation;

import java.time.LocalDate;

public record DelegationResponseDto(
        Long id,
        String propertyName,
        String managerName,
        String managerEmail,
        String status,
        LocalDate startDate
) {
    public static DelegationResponseDto fromEntity(PropertyDelegation delegation) {
        if (delegation == null) {
            return null;
        }
        String propName = delegation.getProperty() != null ? delegation.getProperty().getTitle() : null;
        String mgrName = delegation.getAgent() != null ? delegation.getAgent().getFullName() : null;
        String mgrEmail = delegation.getAgent() != null ? delegation.getAgent().getEmail() : null;
        String st = delegation.getStatus() != null ? delegation.getStatus().name() : null;
        return new DelegationResponseDto(
                delegation.getId(),
                propName,
                mgrName,
                mgrEmail,
                st,
                delegation.getStartDate()
        );
    }
}
