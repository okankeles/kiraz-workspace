package com.ars.kirazbackend.event;

import java.io.Serializable;
import java.time.LocalDateTime;

public record ReceiptRejectedEvent(
        Long periodId,
        Long tenantId,
        Long leaseAgreementId,
        String propertyTitle,
        String reason,
        Integer month,
        Integer year,
        LocalDateTime timestamp
) implements Serializable {

    public ReceiptRejectedEvent(Long periodId, Long tenantId, String reason) {
        this(periodId, tenantId, null, null, reason, null, null, LocalDateTime.now());
    }

    public ReceiptRejectedEvent(Long periodId, Long tenantId, Long leaseAgreementId, String propertyTitle, String reason, Integer month, Integer year) {
        this(periodId, tenantId, leaseAgreementId, propertyTitle, reason, month, year, LocalDateTime.now());
    }
}
