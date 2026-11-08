package com.ars.kirazbackend.dto;

import java.math.BigDecimal;
import java.util.List;

public record LandlordDashboardResponse(
        BigDecimal totalMonthlyIncome,
        BigDecimal totalPendingReceivables,
        double occupancyRate,
        List<LeaseSummaryDto> upcomingExpirations,
        List<MonthlyIncomeDto> incomeChartData
) {
    public LandlordDashboardResponse {
        if (totalMonthlyIncome == null) totalMonthlyIncome = BigDecimal.ZERO;
        if (totalPendingReceivables == null) totalPendingReceivables = BigDecimal.ZERO;
        if (upcomingExpirations == null) upcomingExpirations = List.of();
        if (incomeChartData == null) incomeChartData = List.of();
    }
}
