package com.ars.kirazbackend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class InviteValidationResponse {
    private String tenantEmail;
    private String tenantName;
    private Long leaseId;
    private String status;
    private String message;
}
