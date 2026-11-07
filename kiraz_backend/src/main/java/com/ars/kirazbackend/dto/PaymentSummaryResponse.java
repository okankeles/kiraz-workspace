package com.ars.kirazbackend.dto;

import lombok.Builder;

import java.math.BigDecimal;
import java.time.LocalDate;

@Builder
public record PaymentSummaryResponse(
        BigDecimal totalDebt,
        BigDecimal totalPaid,
        LocalDate nextPaymentDate,
        BigDecimal nextPaymentAmount
) {
    public PaymentSummaryResponse {
        if (totalDebt == null) totalDebt = BigDecimal.ZERO;
        if (totalPaid == null) totalPaid = BigDecimal.ZERO;
        if (nextPaymentAmount == null) nextPaymentAmount = BigDecimal.ZERO;
    }
}
