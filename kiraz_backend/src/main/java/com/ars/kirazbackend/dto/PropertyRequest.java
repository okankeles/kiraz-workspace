package com.ars.kirazbackend.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
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
@JsonIgnoreProperties(ignoreUnknown = true)
public class PropertyRequest {
    private Long landlordId;
    private String title;
    private String address;
    private String city;
    private LocalDate daskEndDate;
    private BigDecimal depositAmount;
}

