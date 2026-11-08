package com.ars.kirazbackend.event;

import java.io.Serializable;
import java.time.LocalDateTime;

public record PaymentSuccessEvent(
        Long periodId,
        Long tenantId,
        Long leaseAgreementId,
        Double amount,
        String paymentType,
        LocalDateTime timestamp
) implements Serializable {

    public PaymentSuccessEvent(Long periodId, Long tenantId) {
        this(periodId, tenantId, null, null, null, LocalDateTime.now());
    }

    public PaymentSuccessEvent(Long periodId, Long tenantId, Long leaseAgreementId, Double amount, String paymentType) {
        this(periodId, tenantId, leaseAgreementId, amount, paymentType, LocalDateTime.now());
    }
}
