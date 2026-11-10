package com.ars.kirazbackend.service;

import com.ars.kirazbackend.config.KafkaConfig;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptUploadedEvent;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class KafkaConsumerServiceTest {

    @Mock
    private NotificationService notificationService;

    @Mock
    private RentPeriodRepository rentPeriodRepository;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private KafkaConsumerService kafkaConsumerService;

    private RentPeriod mockPeriod;

    @BeforeEach
    void setUp() {
        mockPeriod = RentPeriod.builder()
                .id(100L)
                .month(11)
                .year(2026)
                .build();
    }

    @Test
    void testConsume_PaymentSuccessEvent_TriggersNotification() {
        PaymentSuccessEvent event = new PaymentSuccessEvent(100L, 10L, 5L, 12000.0, "PAYTR");
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 1L, "100", event
        );

        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(mockPeriod));

        kafkaConsumerService.consume(record);

        verify(rentPeriodRepository, times(1)).findById(100L);
        verify(notificationService, times(1)).notifyPaymentSuccess(eq(mockPeriod));
        verifyNoMoreInteractions(notificationService);
    }

    @Test
    void testConsume_ReceiptUploadedEvent_TriggersNotification() {
        ReceiptUploadedEvent event = new ReceiptUploadedEvent(100L, 10L, 5L, "http://dekont.png", 11, 2026);
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 2L, "100", event
        );

        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(mockPeriod));

        kafkaConsumerService.consume(record);

        verify(rentPeriodRepository, times(1)).findById(100L);
        verify(notificationService, times(1)).notifyLandlordForReceipt(eq(mockPeriod));
        verifyNoMoreInteractions(notificationService);
    }

    @Test
    void testConsume_PeriodNotFound_DoesNotTriggerNotification() {
        PaymentSuccessEvent event = new PaymentSuccessEvent(999L, 10L);
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 3L, "999", event
        );

        when(rentPeriodRepository.findById(999L)).thenReturn(Optional.empty());

        kafkaConsumerService.consume(record);

        verify(rentPeriodRepository, times(1)).findById(999L);
        verifyNoInteractions(notificationService);
    }

    @Test
    void testConsume_RawJsonPaymentEvent_TriggersNotification() {
        String json = "{\"periodId\":100,\"tenantId\":10,\"amount\":5000.0,\"paymentType\":\"PAYTR\"}";
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 4L, "100", json
        );

        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(mockPeriod));

        kafkaConsumerService.consume(record);

        verify(notificationService, times(1)).notifyPaymentSuccess(eq(mockPeriod));
    }

    @Test
    void testConsume_RawJsonReceiptEvent_TriggersNotification() {
        String json = "{\"periodId\":100,\"tenantId\":10,\"receiptImageUrl\":\"http://dekont.jpg\",\"month\":11,\"year\":2026}";
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 5L, "100", json
        );

        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(mockPeriod));

        kafkaConsumerService.consume(record);

        verify(notificationService, times(1)).notifyLandlordForReceipt(eq(mockPeriod));
    }

    @Test
    void testConsume_ReceiptRejectedEvent_TriggersNotification() {
        com.ars.kirazbackend.event.ReceiptRejectedEvent event =
                new com.ars.kirazbackend.event.ReceiptRejectedEvent(100L, 10L, "Eksik tutar");
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 3L, "100", event
        );

        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(mockPeriod));

        kafkaConsumerService.consume(record);

        verify(rentPeriodRepository, times(1)).findById(100L);
        verify(notificationService, times(1)).notifyReceiptRejected(eq(mockPeriod), eq("Eksik tutar"));
        verifyNoMoreInteractions(notificationService);
    }

    @Test
    void testConsume_RawJsonReceiptRejectedEvent_TriggersNotification() {
        String json = "{\"periodId\":100,\"tenantId\":10,\"reason\":\"Dekont okunaksız\"}";
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 6L, "100", json
        );

        when(rentPeriodRepository.findById(100L)).thenReturn(Optional.of(mockPeriod));

        kafkaConsumerService.consume(record);

        verify(notificationService, times(1)).notifyReceiptRejected(eq(mockPeriod), eq("Dekont okunaksız"));
    }

    @Test
    void testConsume_ManagerAssignedEvent_TriggersNotification() {
        com.ars.kirazbackend.event.ManagerAssignedEvent event =
                new com.ars.kirazbackend.event.ManagerAssignedEvent(400L, "Moda 3+1", "manager@example.com", "Ali Kaya");
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 7L, "400", event
        );

        kafkaConsumerService.consume(record);

        verify(notificationService, times(1)).notifyManagerAssigned(eq(event));
    }

    @Test
    void testConsume_RawJsonManagerAssignedEvent_TriggersNotification() {
        String json = "{\"propertyId\":400,\"propertyName\":\"Moda 3+1\",\"managerEmail\":\"manager@example.com\",\"landlordName\":\"Ali Kaya\"}";
        ConsumerRecord<String, Object> record = new ConsumerRecord<>(
                KafkaConfig.PAYMENT_EVENTS_TOPIC, 0, 8L, "400", json
        );

        kafkaConsumerService.consume(record);

        verify(notificationService, times(1)).notifyManagerAssigned(argThat(event ->
                event.propertyId().equals(400L) &&
                event.propertyName().equals("Moda 3+1") &&
                event.managerEmail().equals("manager@example.com") &&
                event.landlordName().equals("Ali Kaya")
        ));
    }
}
