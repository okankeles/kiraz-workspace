package com.ars.kirazbackend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardStatsDTO {
    private BigDecimal totalPaid;
    private BigDecimal upcoming;
    private BigDecimal pendingApproval;
    private BigDecimal overdue;
}
