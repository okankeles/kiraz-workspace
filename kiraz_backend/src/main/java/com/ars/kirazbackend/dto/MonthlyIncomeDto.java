package com.ars.kirazbackend.dto;

import java.math.BigDecimal;

public record MonthlyIncomeDto(
        String monthYear,
        int year,
        int month,
        BigDecimal totalIncome
) {}
