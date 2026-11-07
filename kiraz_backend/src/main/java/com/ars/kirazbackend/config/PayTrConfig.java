package com.ars.kirazbackend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "paytr")
public record PayTrConfig(
    String merchantId,
    String merchantKey,
    String merchantSalt,
    String testMode,
    String okUrl,
    String failUrl,
    String timeoutLimit
) {
    public PayTrConfig {
        if (testMode == null) testMode = "1";
        if (okUrl == null) okUrl = "https://kiraz.app/payment-success";
        if (failUrl == null) failUrl = "https://kiraz.app/payment-fail";
        if (timeoutLimit == null) timeoutLimit = "30";
    }
}
