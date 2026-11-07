package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PayTrInitRequest;
import com.ars.kirazbackend.dto.PayTrInitResponse;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.PayTrService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/api/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PayTrService payTrService;

    /**
     * Kiracının belirli bir kira periyodu için PayTR Token talep ettiği endpoint.
     */
    @PostMapping("/paytr/initialize")
    @PreAuthorize("hasRole('TENANT')")
    public ResponseEntity<PayTrInitResponse> initializePayTr(
            @RequestBody @Valid PayTrInitRequest request,
            HttpServletRequest servletRequest) {

        String clientIp = resolveClientIp(servletRequest);

        String email = request.getUserEmail();
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if ((email == null || email.trim().isEmpty()) && auth != null && auth.getPrincipal() instanceof User user) {
            email = user.getEmail();
        }

        PayTrInitResponse response = payTrService.initializePayment(request.getPeriodId(), clientIp, email);
        return ResponseEntity.ok(response);
    }

    /**
     * PayTR'ın ödeme sonucunu POST ettiği asenkron webhook endpoint'i.
     * PayTR ile anlaşma gereği bu endpoint x-www-form-urlencoded formatında veri tüketir
     * ve sadece "OK" düz metin yanıtı döner.
     */
    @PostMapping(value = "/paytr-callback", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE, produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> payTrCallback(@RequestParam MultiValueMap<String, String> payload) {
        log.info("PayTR Callback webhook isteği alındı: oid={}", payload.getFirst("merchant_oid"));
        String response = payTrService.processCallback(payload);
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
