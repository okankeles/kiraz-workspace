package com.ars.kirazbackend.event;

import java.io.Serializable;
import java.time.LocalDateTime;

public record ReceiptUploadedEvent(
        Long periodId,
        Long tenantId,
        Long leaseAgreementId,
        String receiptImageUrl,
        Integer month,
        Integer year,
        LocalDateTime timestamp
) implements Serializable {

    public ReceiptUploadedEvent(Long periodId, Long tenantId, String receiptImageUrl) {
        this(periodId, tenantId, null, receiptImageUrl, null, null, LocalDateTime.now());
    }

    public ReceiptUploadedEvent(Long periodId, Long tenantId, Long leaseAgreementId, String receiptImageUrl, Integer month, Integer year) {
        this(periodId, tenantId, leaseAgreementId, receiptImageUrl, month, year, LocalDateTime.now());
    }
}
