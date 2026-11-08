package com.ars.kirazbackend.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record LeaseSummaryDto(
        Long leaseId,
        Long propertyId,
        String propertyTitle,
        String tenantName,
        String tenantPhone,
        LocalDate startDate,
        LocalDate endDate,
        BigDecimal monthlyRentAmount,
        long daysRemaining
) {}
