package com.ars.kirazbackend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PayTrInitResponse {
    private String status;
    private String token;
    private String merchantOid;
    private String iframeUrl;
    private String reason;
}
