package com.ars.kirazbackend.service;

import com.ars.kirazbackend.config.PayTrConfig;
import com.ars.kirazbackend.dto.PayTrInitResponse;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Base64;
import java.util.List;
import java.util.Locale;

@Slf4j
@Service
@RequiredArgsConstructor
public class PayTrService {

    private final PayTrConfig payTrConfig;
    private final RentPeriodRepository rentPeriodRepository;
    private final NotificationService notificationService;
    private final AuditLogService auditLogService;
    private final PropertyDelegationService propertyDelegationService;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    private static final String PAYTR_TOKEN_URL = "https://www.paytr.com/odeme/api/get-token";

    /**
     * Kiracının seçtiği kira dönemi için PayTR iFrame Token'ı üretir.
     */
    @Transactional(readOnly = true)
    public PayTrInitResponse initializePayment(Long periodId, String userIp, String userEmail) {
        RentPeriod period = rentPeriodRepository.findById(periodId)
                .orElseThrow(() -> new RuntimeException("Kira dönemi bulunamadı: " + periodId));

        if (period.getStatus() == PaymentStatus.PAID) {
            throw new RuntimeException("Bu kira dönemi zaten ödenmiştir.");
        }

        BigDecimal rentAmount = period.getLeaseAgreement().getMonthlyRentAmount();
        if (rentAmount == null || rentAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("Geçersiz kira bedeli.");
        }

        // PayTR tutarı kuruş cinsinden tam sayı olarak bekler (100.00 TL -> 10000)
        int paymentAmount = rentAmount.multiply(BigDecimal.valueOf(100)).intValue();

        // Benzersiz Sipariş Numarası (PayTR yalnızca alfanümerik [a-zA-Z0-9] karakter kabul eder, özel karakter içeremez)
        String merchantOid = "RENTP" + period.getId() + "T" + System.currentTimeMillis();

        // Kiracı bilgileri
        User tenant = period.getLeaseAgreement().getTenant();
        String email = (userEmail != null && !userEmail.trim().isEmpty())
                ? userEmail.trim()
                : (tenant != null && tenant.getEmail() != null ? tenant.getEmail() : "kiraci@kiraz.app");
        String userName = (tenant != null && tenant.getFullName() != null) ? tenant.getFullName() : "Kiracı";
        String userPhone = (tenant != null && tenant.getPhone() != null && !tenant.getPhone().trim().isEmpty())
                ? tenant.getPhone().trim()
                : "05555555555";

        Property property = period.getLeaseAgreement().getProperty();
        String address = (property != null && property.getAddress() != null && !property.getAddress().trim().isEmpty())
                ? property.getAddress()
                : "İstanbul, Türkiye";

        // Localhost IP düzeltmesi
        String clientIp = userIp;
        if (clientIp == null || "0:0:0:0:0:0:0:1".equals(clientIp) || "localhost".equalsIgnoreCase(clientIp) || clientIp.trim().isEmpty()) {
            clientIp = "127.0.0.1";
        }

        // PayTR Sepet Formatı: [["Ürün Adı", "Fiyat", Adet]] -> JSON -> Base64
        String userBasketBase64;
        try {
            String itemTitle = String.format("Kira Bedeli - %02d/%d (%s)",
                    period.getMonth(), period.getYear(), property != null ? property.getTitle() : "Mülk");
            List<List<Object>> basket = List.of(
                    List.of(itemTitle, String.format(Locale.US, "%.2f", rentAmount), 1)
            );
            String basketJson = objectMapper.writeValueAsString(basket);
            userBasketBase64 = Base64.getEncoder().encodeToString(basketJson.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new RuntimeException("PayTR sepet verisi oluşturulamadı: " + e.getMessage(), e);
        }

        // Taksit Kuralları: no_installment = "0" (taksit açık), max_installment = "12"
        String noInstallment = "0";
        String maxInstallment = "12";
        String currency = "TL";
        String testMode = payTrConfig.testMode() != null ? payTrConfig.testMode() : "1";

        // PayTR Resmi HMAC-SHA256 Token İmzası
        // hash_str = merchant_id + user_ip + merchant_oid + email + payment_amount + user_basket + no_installment + max_installment + currency + test_mode;
        // paytr_token = Base64(HMAC-SHA256(hash_str + merchant_salt, merchant_key))
        String hashStr = payTrConfig.merchantId()
                + clientIp
                + merchantOid
                + email
                + paymentAmount
                + userBasketBase64
                + noInstallment
                + maxInstallment
                + currency
                + testMode;

        String paytrToken = calculateHmacSha256(hashStr + payTrConfig.merchantSalt(), payTrConfig.merchantKey());

        // PayTR API POST İsteği
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);

        MultiValueMap<String, String> requestBody = new LinkedMultiValueMap<>();
        requestBody.add("merchant_id", payTrConfig.merchantId());
        requestBody.add("user_ip", clientIp);
        requestBody.add("merchant_oid", merchantOid);
        requestBody.add("email", email);
        requestBody.add("payment_amount", String.valueOf(paymentAmount));
        requestBody.add("paytr_token", paytrToken);
        requestBody.add("user_basket", userBasketBase64);
        requestBody.add("debug_on", "1");
        requestBody.add("no_installment", noInstallment);
        requestBody.add("max_installment", maxInstallment);
        requestBody.add("user_name", userName);
        requestBody.add("user_address", address);
        requestBody.add("user_phone", userPhone);
        requestBody.add("merchant_ok_url", payTrConfig.okUrl());
        requestBody.add("merchant_fail_url", payTrConfig.failUrl());
        requestBody.add("timeout_limit", payTrConfig.timeoutLimit());
        requestBody.add("currency", currency);
        requestBody.add("test_mode", testMode);

        HttpEntity<MultiValueMap<String, String>> httpEntity = new HttpEntity<>(requestBody, headers);

        try {
            log.info("PayTR Token talebi gönderiliyor: merchantOid={}, amount={}", merchantOid, paymentAmount);
            ResponseEntity<String> response = restTemplate.postForEntity(PAYTR_TOKEN_URL, httpEntity, String.class);

            JsonNode responseJson = objectMapper.readTree(response.getBody());
            String status = responseJson.path("status").asText();

            if ("success".equalsIgnoreCase(status)) {
                String token = responseJson.path("token").asText();
                log.info("PayTR Token başarıyla alındı: merchantOid={}", merchantOid);
                return PayTrInitResponse.builder()
                        .status("success")
                        .token(token)
                        .merchantOid(merchantOid)
                        .iframeUrl("https://www.paytr.com/odeme/guvenli/" + token)
                        .build();
            } else {
                String reason = responseJson.path("reason").asText();
                log.error("PayTR Token alma başarısız: {}", reason);
                throw new RuntimeException("PayTR Token alma başarısız: " + reason);
            }
        } catch (Exception e) {
            log.error("PayTR API iletişim hatası: {}", e.getMessage(), e);
            throw new RuntimeException("PayTR ödeme başlatma hatası: " + e.getMessage(), e);
        }
    }

    /**
     * PayTR Webhook / Bildirim (Callback) metodudur.
     * PayTR ödeme sonucunu POST ettiğinde çalışır, imzayı doğrular, ilgili kirayı PAID yapar ve "OK" döner.
     */
    @Transactional
    public String processCallback(MultiValueMap<String, String> payload) {
        String merchantOid = payload.getFirst("merchant_oid");
        String status = payload.getFirst("status");
        String totalAmount = payload.getFirst("total_amount");
        String incomingHash = payload.getFirst("hash");

        if (merchantOid == null || status == null || totalAmount == null || incomingHash == null) {
            log.error("PayTR callback: Eksik parametreler!");
            throw new RuntimeException("PAYTR notification failed: missing parameters");
        }

        // PayTR Callback Hash Doğrulama Formülü:
        // beklenen_hash = Base64(HMAC-SHA256(merchant_oid + merchant_salt + status + total_amount, merchant_key))
        String hashStr = merchantOid + payTrConfig.merchantSalt() + status + totalAmount;
        String expectedHash = calculateHmacSha256(hashStr, payTrConfig.merchantKey());

        if (!expectedHash.equals(incomingHash)) {
            log.error("PayTR callback: Hash doğrulama başarısız! Oid: {}, Beklenen: {}, Gelen: {}",
                    merchantOid, expectedHash, incomingHash);
            throw new RuntimeException("PAYTR notification failed: bad hash");
        }

        Long periodId = extractPeriodIdFromMerchantOid(merchantOid);
        RentPeriod period = rentPeriodRepository.findById(periodId)
                .orElseThrow(() -> new RuntimeException("Kira dönemi bulunamadı: " + periodId));

        if ("success".equalsIgnoreCase(status)) {
            log.info("PayTR ödeme başarılı onaylandı: merchantOid={}, periodId={}, totalAmount={}",
                    merchantOid, periodId, totalAmount);

            period.setStatus(PaymentStatus.PAID);
            period.setPaymentDate(LocalDate.now());
            RentPeriod savedPeriod = rentPeriodRepository.save(period);

            Property property = savedPeriod.getLeaseAgreement().getProperty();
            String propertyTitle = property != null ? property.getTitle() : "Taşınmaz";
            User tenant = savedPeriod.getLeaseAgreement().getTenant();
            User landlord = property != null ? property.getLandlord() : null;

            // Audit log
            auditLogService.record(
                    "RENT_PERIOD",
                    savedPeriod.getId(),
                    "PAYTR_PAYMENT_SUCCESS",
                    tenant,
                    String.format("PayTR üzerinden online kira ödemesi başarıyla tahsil edildi. Sipariş No: %s, Tutar: %s kuruş",
                            merchantOid, totalAmount)
            );

            // Kiracı, Ev Sahibi ve Emlakçıya ödeme başarı bildirimi gönder
            notificationService.notifyPaymentSuccess(savedPeriod);

        } else {
            String failedMsg = payload.getFirst("failed_reason_msg");
            log.warn("PayTR ödeme başarısız: merchantOid={}, periodId={}, reason={}", merchantOid, periodId, failedMsg);
            auditLogService.record(
                    "RENT_PERIOD",
                    periodId,
                    "PAYTR_PAYMENT_FAILED",
                    null,
                    String.format("PayTR ödeme başarısız bildirimi. Sipariş No: %s, Sebep: %s", merchantOid, failedMsg)
            );
        }

        // PayTR'a işlemin alındığını bildirmek için sadece düz metin "OK" döndürülmelidir
        return "OK";
    }

    private static final java.util.regex.Pattern OID_PATTERN =
            java.util.regex.Pattern.compile("^RENT(?:P|-)?(\\d+)(?:T|-).*$");

    private Long extractPeriodIdFromMerchantOid(String merchantOid) {
        if (merchantOid == null || merchantOid.trim().isEmpty()) {
            throw new IllegalArgumentException("merchant_oid boş olamaz");
        }
        java.util.regex.Matcher matcher = OID_PATTERN.matcher(merchantOid);
        if (matcher.matches()) {
            try {
                return Long.parseLong(matcher.group(1));
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("merchant_oid içinden periodId çözümlenemedi: " + merchantOid);
            }
        }
        throw new IllegalArgumentException("Geçersiz merchant_oid formatı: " + merchantOid);
    }

    /**
     * PayTR HMAC-SHA256 Base64 imza hesaplama fonksiyonu
     */
    public String calculateHmacSha256(String data, String key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKey);
            byte[] rawHmac = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(rawHmac);
        } catch (Exception e) {
            throw new RuntimeException("HMAC-SHA256 hesaplama hatası: " + e.getMessage(), e);
        }
    }
}
