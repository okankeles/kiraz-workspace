package com.ars.kirazbackend.service;

import com.ars.kirazbackend.config.KafkaConfig;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptRejectedEvent;
import com.ars.kirazbackend.event.ReceiptUploadedEvent;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.TopicPartition;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;

import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class KafkaProducerServiceTest {

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    @InjectMocks
    private KafkaProducerService kafkaProducerService;

    private SendResult<String, Object> mockSendResult;

    @BeforeEach
    void setUp() {
        RecordMetadata metadata = new RecordMetadata(
                new TopicPartition(KafkaConfig.PAYMENT_EVENTS_TOPIC, 0),
                0L, 0, 0L, 0, 0
        );
        mockSendResult = new SendResult<>(null, metadata);
    }

    @Test
    void testSendPaymentSuccessEvent_Success() {
        PaymentSuccessEvent event = new PaymentSuccessEvent(100L, 20L, 5L, 15000.0, "PAYTR");
        CompletableFuture<SendResult<String, Object>> future = CompletableFuture.completedFuture(mockSendResult);

        when(kafkaTemplate.send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("100"), eq(event))).thenReturn(future);

        CompletableFuture<SendResult<String, Object>> result = kafkaProducerService.sendPaymentSuccessEvent(event);

        assertNotNull(result);
        verify(kafkaTemplate, times(1)).send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("100"), eq(event));
    }

    @Test
    void testSendPaymentSuccessEvent_Overload() {
        CompletableFuture<SendResult<String, Object>> future = CompletableFuture.completedFuture(mockSendResult);
        when(kafkaTemplate.send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("101"), any(PaymentSuccessEvent.class)))
                .thenReturn(future);

        CompletableFuture<SendResult<String, Object>> result = kafkaProducerService.sendPaymentSuccessEvent(101L, 21L);

        assertNotNull(result);
        verify(kafkaTemplate, times(1)).send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("101"), any(PaymentSuccessEvent.class));
    }

    @Test
    void testSendReceiptUploadedEvent_Success() {
        ReceiptUploadedEvent event = new ReceiptUploadedEvent(200L, 30L, 8L, "http://dekont.jpg", 11, 2026);
        CompletableFuture<SendResult<String, Object>> future = CompletableFuture.completedFuture(mockSendResult);

        when(kafkaTemplate.send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("200"), eq(event))).thenReturn(future);

        CompletableFuture<SendResult<String, Object>> result = kafkaProducerService.sendReceiptUploadedEvent(event);

        assertNotNull(result);
        verify(kafkaTemplate, times(1)).send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("200"), eq(event));
    }

    @Test
    void testSendReceiptUploadedEvent_Overload() {
        CompletableFuture<SendResult<String, Object>> future = CompletableFuture.completedFuture(mockSendResult);
        when(kafkaTemplate.send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("201"), any(ReceiptUploadedEvent.class)))
                .thenReturn(future);

        CompletableFuture<SendResult<String, Object>> result =
                kafkaProducerService.sendReceiptUploadedEvent(201L, 31L, "http://dekont2.jpg");

        assertNotNull(result);
        verify(kafkaTemplate, times(1)).send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("201"), any(ReceiptUploadedEvent.class));
    }

    @Test
    void testSendReceiptRejectedEvent_Success() {
        ReceiptRejectedEvent event = new ReceiptRejectedEvent(300L, 40L, 9L, "Kadıköy Daire", "Eksik tutar", 11, 2026);
        CompletableFuture<SendResult<String, Object>> future = CompletableFuture.completedFuture(mockSendResult);

        when(kafkaTemplate.send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("300"), eq(event))).thenReturn(future);

        CompletableFuture<SendResult<String, Object>> result = kafkaProducerService.sendReceiptRejectedEvent(event);

        assertNotNull(result);
        verify(kafkaTemplate, times(1)).send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("300"), eq(event));
    }

    @Test
    void testSendReceiptRejectedEvent_Overload() {
        CompletableFuture<SendResult<String, Object>> future = CompletableFuture.completedFuture(mockSendResult);
        when(kafkaTemplate.send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("301"), any(ReceiptRejectedEvent.class)))
                .thenReturn(future);

        CompletableFuture<SendResult<String, Object>> result =
                kafkaProducerService.sendReceiptRejectedEvent(301L, 41L, "Okunamayan dekont");

        assertNotNull(result);
        verify(kafkaTemplate, times(1)).send(eq(KafkaConfig.PAYMENT_EVENTS_TOPIC), eq("301"), any(ReceiptRejectedEvent.class));
    }
}
