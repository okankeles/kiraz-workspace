package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PayTrInitRequest;
import com.ars.kirazbackend.dto.PayTrInitResponse;
import com.ars.kirazbackend.dto.PaymentSummaryResponse;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.PayTrService;
import com.ars.kirazbackend.service.RentPeriodService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Slf4j
@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
@Tag(name = "Payments", description = "Ödeme ve tahsilat uçları")
public class PaymentController {

    private final PayTrService payTrService;
    private final RentPeriodService rentPeriodService;
    private final AccessControlService authz;

    /**
     * Kiracının belirli bir kira periyodu için PayTR Token talep ettiği endpoint (Kanonik).
     */
    @PostMapping("/paytr/initialize")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "PayTR iFrame token al (Kanonik)")
    public ResponseEntity<PayTrInitResponse> initializePayTr(
            @RequestBody @Valid PayTrInitRequest request,
            HttpServletRequest servletRequest) {

        authz.checkCanPayPeriod(request.getPeriodId());

        String clientIp = resolveClientIp(servletRequest);
        User user = authz.getCurrentUser();
        String email = user != null ? user.getEmail() : request.getUserEmail();

        PayTrInitResponse response = payTrService.initializePayment(request.getPeriodId(), clientIp, email);
        return ResponseEntity.ok(response);
    }

    /**
     * PayTR'ın ödeme sonucunu POST ettiği asenkron webhook endpoint'i (Kanonik).
     * PayTR panelinde kayıtlı resmi tek endpoint /api/payments/paytr-callback'tir.
     */
    @PostMapping(value = "/paytr-callback", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE, produces = MediaType.TEXT_PLAIN_VALUE)
    @Operation(summary = "PayTR webhook callback (Kanonik)")
    public ResponseEntity<String> payTrCallback(@RequestParam MultiValueMap<String, String> payload) {
        log.info("PayTR Callback webhook isteği alındı: oid={}", payload.getFirst("merchant_oid"));
        String response = payTrService.processCallback(payload);
        return ResponseEntity.ok(response);
    }

    /**
     * Kiracının Havale/EFT dekontu yüklediği endpoint (Deprecated - yerine POST /api/tenant/receipts/{periodId} kullanın).
     */
    @Deprecated
    @PostMapping(value = "/{periodId}/receipt", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Havale/EFT dekontu yükle (Deprecated - yerine POST /api/tenant/receipts/{periodId} kullanın)", deprecated = true)
    public ResponseEntity<RentPeriod> uploadReceipt(
            @PathVariable Long periodId,
            @RequestParam("file") MultipartFile file) {

        authz.checkCanUploadReceipt(periodId);

        log.info("Havale/EFT dekontu yükleme isteği alındı: periodId={}", periodId);
        RentPeriod updated = rentPeriodService.uploadReceipt(periodId, file);
        return ResponseEntity.ok(updated);
    }

    /**
     * Kiracının anlık finansal özetini döner (Deprecated - yerine GET /api/tenant/payments/summary kullanın).
     */
    @Deprecated
    @GetMapping("/summary")
    @PreAuthorize("hasRole('TENANT')")
    @Operation(summary = "Kiracı ödeme özeti (Deprecated - yerine GET /api/tenant/payments/summary kullanın)", deprecated = true)
    public ResponseEntity<PaymentSummaryResponse> getPaymentSummary() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kiracı kimliği doğrulanamadı.");
        }
        PaymentSummaryResponse response = rentPeriodService.getTenantPaymentSummary(user.getId());
        return ResponseEntity.ok(response);
    }

    private String resolveClientIp(HttpServletRequest request) {
        String clientIp = request.getHeader("X-Forwarded-For");
        if (clientIp != null && !clientIp.trim().isEmpty() && !"unknown".equalsIgnoreCase(clientIp)) {
            if (clientIp.contains(",")) {
                return clientIp.split(",")[0].trim();
            }
            return clientIp.trim();
        }
        clientIp = request.getHeader("X-Real-IP");
        if (clientIp != null && !clientIp.trim().isEmpty() && !"unknown".equalsIgnoreCase(clientIp)) {
            return clientIp.trim();
        }
        return request.getRemoteAddr();
    }
}
