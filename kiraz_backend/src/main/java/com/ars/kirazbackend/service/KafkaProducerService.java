package com.ars.kirazbackend.service;

import com.ars.kirazbackend.config.KafkaConfig;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptUploadedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

@Slf4j
@Service
@RequiredArgsConstructor
public class KafkaProducerService {

    private final KafkaTemplate<String, Object> kafkaTemplate;

    public CompletableFuture<SendResult<String, Object>> sendPaymentSuccessEvent(PaymentSuccessEvent event) {
        String key = event.periodId() != null ? String.valueOf(event.periodId()) : null;
        log.info("Sending PaymentSuccessEvent to Kafka: topic={}, key={}, periodId={}, tenantId={}, amount={}, type={}",
                KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event.periodId(), event.tenantId(), event.amount(), event.paymentType());

        return kafkaTemplate.send(KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish PaymentSuccessEvent: periodId={}, error={}",
                                event.periodId(), ex.getMessage(), ex);
                    } else {
                        log.info("PaymentSuccessEvent published successfully: topic={}, partition={}, offset={}",
                                KafkaConfig.PAYMENT_EVENTS_TOPIC,
                                result.getRecordMetadata().partition(),
                                result.getRecordMetadata().offset());
                    }
                });
    }

    public CompletableFuture<SendResult<String, Object>> sendPaymentSuccessEvent(Long periodId, Long tenantId) {
        return sendPaymentSuccessEvent(new PaymentSuccessEvent(periodId, tenantId));
    }

    public CompletableFuture<SendResult<String, Object>> sendReceiptUploadedEvent(ReceiptUploadedEvent event) {
        String key = event.periodId() != null ? String.valueOf(event.periodId()) : null;
        log.info("Sending ReceiptUploadedEvent to Kafka: topic={}, key={}, periodId={}, tenantId={}, imageUrl={}",
                KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event.periodId(), event.tenantId(), event.receiptImageUrl());

        return kafkaTemplate.send(KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish ReceiptUploadedEvent: periodId={}, error={}",
                                event.periodId(), ex.getMessage(), ex);
                    } else {
                        log.info("ReceiptUploadedEvent published successfully: topic={}, partition={}, offset={}",
                                KafkaConfig.PAYMENT_EVENTS_TOPIC,
                                result.getRecordMetadata().partition(),
                                result.getRecordMetadata().offset());
                    }
                });
    }

    public CompletableFuture<SendResult<String, Object>> sendReceiptUploadedEvent(Long periodId, Long tenantId, String receiptImageUrl) {
        return sendReceiptUploadedEvent(new ReceiptUploadedEvent(periodId, tenantId, receiptImageUrl));
    }
}
