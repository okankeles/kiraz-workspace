package com.ars.kirazbackend.dto;

public record DelegationRequestDto(
        Long propertyId,
        String managerEmail
) {
}
