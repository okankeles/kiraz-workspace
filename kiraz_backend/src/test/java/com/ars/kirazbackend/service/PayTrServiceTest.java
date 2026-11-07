package com.ars.kirazbackend.service;

import com.ars.kirazbackend.config.PayTrConfig;
import com.ars.kirazbackend.dto.PayTrInitResponse;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.DelegationStatus;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PayTrServiceTest {

    @Mock
    private PayTrConfig payTrConfig;

    @Mock
    private RentPeriodRepository rentPeriodRepository;

    @Mock
    private NotificationService notificationService;

    @Mock
    private AuditLogService auditLogService;

    @Mock
    private PropertyDelegationService propertyDelegationService;

    @Mock
    private RestTemplate restTemplate;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private PayTrService payTrService;

    private User landlord;
    private User tenant;
    private User agent;
    private Property property;
    private LeaseAgreement leaseAgreement;
    private RentPeriod rentPeriod;

    private final String merchantId = "659790";
    private final String merchantKey = "XQTmSzbmBw5YAYzW";
    private final String merchantSalt = "K5uAP8fQ5htrfKd4";

    @BeforeEach
    void setUp() {
        landlord = User.builder().id(1L).fullName("Ahmet Ev Sahibi").email("ahmet@ev.com").role(RoleType.LANDLORD).build();
        tenant = User.builder().id(2L).fullName("Mehmet Kiracı").email("mehmet@kiraci.com").phone("05321112233").role(RoleType.TENANT).build();
        agent = User.builder().id(3L).fullName("Emlak Ofisi").email("emlak@ofis.com").role(RoleType.AGENT).build();

        property = Property.builder().id(10L).title("Kadıköy Daire").landlord(landlord).address("Kadıköy, İstanbul").build();
        leaseAgreement = LeaseAgreement.builder().id(100L).property(property).tenant(tenant).monthlyRentAmount(BigDecimal.valueOf(15000.00)).build();

        rentPeriod = RentPeriod.builder()
                .id(50L)
                .leaseAgreement(leaseAgreement)
                .month(11)
                .year(2026)
                .status(PaymentStatus.PENDING)
                .build();
    }

    @Test
    void testInitializePayment_Success() {
        when(payTrConfig.merchantId()).thenReturn(merchantId);
        when(payTrConfig.merchantKey()).thenReturn(merchantKey);
        when(payTrConfig.merchantSalt()).thenReturn(merchantSalt);
        when(payTrConfig.testMode()).thenReturn("1");
        when(payTrConfig.okUrl()).thenReturn("https://kiraz.app/payment/success");
        when(payTrConfig.failUrl()).thenReturn("https://kiraz.app/payment/fail");
        when(payTrConfig.timeoutLimit()).thenReturn("30");

        when(rentPeriodRepository.findById(50L)).thenReturn(Optional.of(rentPeriod));

        String payTrResponseJson = "{\"status\":\"success\",\"token\":\"mock_paytr_token_abc123\"}";
        when(restTemplate.postForEntity(eq("https://www.paytr.com/odeme/api/get-token"), any(HttpEntity.class), eq(String.class)))
                .thenReturn(new ResponseEntity<>(payTrResponseJson, HttpStatus.OK));

        PayTrInitResponse response = payTrService.initializePayment(50L, "192.168.1.100", "mehmet@kiraci.com");

        assertNotNull(response);
        assertEquals("success", response.getStatus());
        assertEquals("mock_paytr_token_abc123", response.getToken());
        assertTrue(response.getMerchantOid().startsWith("RENTP50T"));
        assertTrue(response.getMerchantOid().matches("^[a-zA-Z0-9]+$"));

        // Capture RestTemplate request to verify rules
        @SuppressWarnings("unchecked")
        ArgumentCaptor<HttpEntity<MultiValueMap<String, String>>> captor = ArgumentCaptor.forClass(HttpEntity.class);
        verify(restTemplate).postForEntity(eq("https://www.paytr.com/odeme/api/get-token"), captor.capture(), eq(String.class));

        MultiValueMap<String, String> body = captor.getValue().getBody();
        assertNotNull(body);
        assertEquals("659790", body.getFirst("merchant_id"));
        assertEquals("1500000", body.getFirst("payment_amount")); // 15000.00 TL -> 1500000 kuruş
        assertEquals("0", body.getFirst("no_installment")); // Taksit açık
        assertEquals("12", body.getFirst("max_installment")); // Maksimum 12 taksit
        assertEquals("TL", body.getFirst("currency"));
        assertEquals("1", body.getFirst("test_mode"));
        assertNotNull(body.getFirst("paytr_token"));
        assertNotNull(body.getFirst("user_basket"));
    }

    @Test
    void testInitializePayment_WhenPeriodAlreadyPaid_ThrowsException() {
        rentPeriod.setStatus(PaymentStatus.PAID);
        when(rentPeriodRepository.findById(50L)).thenReturn(Optional.of(rentPeriod));

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                payTrService.initializePayment(50L, "127.0.0.1", "mehmet@kiraci.com"));

        assertTrue(ex.getMessage().contains("zaten ödenmiştir"));
        verifyNoInteractions(restTemplate);
    }

    @Test
    void testInitializePayment_WhenPayTrReturnsFailed_ThrowsException() {
        when(payTrConfig.merchantId()).thenReturn(merchantId);
        when(payTrConfig.merchantKey()).thenReturn(merchantKey);
        when(payTrConfig.merchantSalt()).thenReturn(merchantSalt);
        when(payTrConfig.testMode()).thenReturn("1");
        when(payTrConfig.okUrl()).thenReturn("https://kiraz.app/payment/success");
        when(payTrConfig.failUrl()).thenReturn("https://kiraz.app/payment/fail");
        when(payTrConfig.timeoutLimit()).thenReturn("30");

        when(rentPeriodRepository.findById(50L)).thenReturn(Optional.of(rentPeriod));

        String payTrFailJson = "{\"status\":\"failed\",\"reason\":\"Merchant IP not allowed\"}";
        when(restTemplate.postForEntity(anyString(), any(HttpEntity.class), eq(String.class)))
                .thenReturn(new ResponseEntity<>(payTrFailJson, HttpStatus.OK));

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                payTrService.initializePayment(50L, "127.0.0.1", null));

        assertTrue(ex.getMessage().contains("PayTR Token alma başarısız") || ex.getMessage().contains("Merchant IP not allowed"));
    }

    @Test
    void testProcessCallback_Success_UpdatesPeriodToPaidAndNotifiesParties() {
        when(payTrConfig.merchantKey()).thenReturn(merchantKey);
        when(payTrConfig.merchantSalt()).thenReturn(merchantSalt);

        String merchantOid = "RENTP50T1700000000";
        String status = "success";
        String totalAmount = "1500000";

        // Calculate expected hash: Base64(HMAC-SHA256(merchant_oid + merchant_salt + status + total_amount, merchant_key))
        String hashStr = merchantOid + merchantSalt + status + totalAmount;
        String validHash = payTrService.calculateHmacSha256(hashStr, merchantKey);

        MultiValueMap<String, String> payload = new LinkedMultiValueMap<>();
        payload.add("merchant_oid", merchantOid);
        payload.add("status", status);
        payload.add("total_amount", totalAmount);
        payload.add("hash", validHash);

        when(rentPeriodRepository.findById(50L)).thenReturn(Optional.of(rentPeriod));
        when(rentPeriodRepository.save(any(RentPeriod.class))).thenAnswer(i -> i.getArgument(0));

        // Mock delegation for agent
        PropertyDelegation delegation = PropertyDelegation.builder()
                .property(property)
                .agent(agent)
                .status(DelegationStatus.ACTIVE)
                .build();
        when(propertyDelegationService.getDelegationsForProperty(10L)).thenReturn(List.of(delegation));

        String result = payTrService.processCallback(payload);

        assertEquals("OK", result);
        assertEquals(PaymentStatus.PAID, rentPeriod.getStatus());
        assertEquals(LocalDate.now(), rentPeriod.getPaymentDate());

        verify(rentPeriodRepository).save(rentPeriod);
        verify(auditLogService).record(eq("RENT_PERIOD"), eq(50L), eq("PAYTR_PAYMENT_SUCCESS"), eq(tenant), anyString());

        // Verify notifications sent to tenant, landlord, and active agent
        verify(notificationService).createNotification(eq(2L), contains("Kira"), anyString(), eq("PAYMENT_SUCCESS"), eq(100L));
        verify(notificationService).createNotification(eq(1L), contains("Kira"), anyString(), eq("PAYMENT_SUCCESS"), eq(100L));
        verify(notificationService).createNotification(eq(3L), contains("Kira"), anyString(), eq("PAYMENT_SUCCESS"), eq(100L));
    }

    @Test
    void testProcessCallback_InvalidHash_ThrowsException() {
        when(payTrConfig.merchantKey()).thenReturn(merchantKey);
        when(payTrConfig.merchantSalt()).thenReturn(merchantSalt);

        MultiValueMap<String, String> payload = new LinkedMultiValueMap<>();
        payload.add("merchant_oid", "RENT-50-1700000000");
        payload.add("status", "success");
        payload.add("total_amount", "1500000");
        payload.add("hash", "FORGED_OR_INVALID_HASH");

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                payTrService.processCallback(payload));

        assertTrue(ex.getMessage().contains("bad hash"));
        verifyNoInteractions(rentPeriodRepository);
        verifyNoInteractions(notificationService);
    }

    @Test
    void testProcessCallback_FailedStatus_RecordsAuditAndReturnsOK() {
        when(payTrConfig.merchantKey()).thenReturn(merchantKey);
        when(payTrConfig.merchantSalt()).thenReturn(merchantSalt);

        String merchantOid = "RENTP50T1700000000";
        String status = "failed";
        String totalAmount = "1500000";
        String hashStr = merchantOid + merchantSalt + status + totalAmount;
        String validHash = payTrService.calculateHmacSha256(hashStr, merchantKey);

        MultiValueMap<String, String> payload = new LinkedMultiValueMap<>();
        payload.add("merchant_oid", merchantOid);
        payload.add("status", status);
        payload.add("total_amount", totalAmount);
        payload.add("hash", validHash);
        payload.add("failed_reason_msg", "Yetersiz bakiye");

        when(rentPeriodRepository.findById(50L)).thenReturn(Optional.of(rentPeriod));

        String result = payTrService.processCallback(payload);

        assertEquals("OK", result);
        assertNotEquals(PaymentStatus.PAID, rentPeriod.getStatus());
        verify(auditLogService).record(eq("RENT_PERIOD"), eq(50L), eq("PAYTR_PAYMENT_FAILED"), isNull(), contains("Yetersiz bakiye"));
        verifyNoInteractions(notificationService);
    }
}
