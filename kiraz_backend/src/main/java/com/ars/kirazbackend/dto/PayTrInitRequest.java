package com.ars.kirazbackend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PayTrInitRequest {

    @NotNull(message = "periodId cannot be null")
    private Long periodId;

    private String userEmail;
}
