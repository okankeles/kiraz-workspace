package com.ars.kirazbackend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LeaseRequest {
    private Long propertyId;
    private String tenantEmail;
    private String tenantName;
    private Double rentAmount;
    private String startDate;

    // Optional fields for flexibility
    private Long tenantId;
    private LocalDate endDate;
    private BigDecimal monthlyRentAmount;
    private BigDecimal depositAmount;
    private Integer paymentDay;
}
