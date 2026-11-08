package com.ars.kirazbackend.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PendingReceiptDto(
        Long periodId,
        String propertyName,
        String tenantName,
        Integer month,
        Integer year,
        BigDecimal amount,
        String receiptImageUrl,
        LocalDateTime uploadDate
) {}
