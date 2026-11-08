package com.ars.kirazbackend.service;

import com.ars.kirazbackend.config.KafkaConfig;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptRejectedEvent;
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

    public CompletableFuture<SendResult<String, Object>> sendReceiptRejectedEvent(ReceiptRejectedEvent event) {
        String key = event.periodId() != null ? String.valueOf(event.periodId()) : null;
        log.info("Sending ReceiptRejectedEvent to Kafka: topic={}, key={}, periodId={}, tenantId={}, reason={}",
                KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event.periodId(), event.tenantId(), event.reason());

        return kafkaTemplate.send(KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish ReceiptRejectedEvent: periodId={}, error={}",
                                event.periodId(), ex.getMessage(), ex);
                    } else {
                        log.info("ReceiptRejectedEvent published successfully: topic={}, partition={}, offset={}",
                                KafkaConfig.PAYMENT_EVENTS_TOPIC,
                                result.getRecordMetadata().partition(),
                                result.getRecordMetadata().offset());
                    }
                });
    }

    public CompletableFuture<SendResult<String, Object>> sendReceiptRejectedEvent(Long periodId, Long tenantId, String reason) {
        return sendReceiptRejectedEvent(new ReceiptRejectedEvent(periodId, tenantId, reason));
    }

    public CompletableFuture<SendResult<String, Object>> sendManagerAssignedEvent(com.ars.kirazbackend.event.ManagerAssignedEvent event) {
        String key = event.propertyId() != null ? String.valueOf(event.propertyId()) : null;
        log.info("Sending ManagerAssignedEvent to Kafka: topic={}, key={}, propertyId={}, managerEmail={}",
                KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event.propertyId(), event.managerEmail());

        return kafkaTemplate.send(KafkaConfig.PAYMENT_EVENTS_TOPIC, key, event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish ManagerAssignedEvent: propertyId={}, error={}",
                                event.propertyId(), ex.getMessage(), ex);
                    } else {
                        log.info("ManagerAssignedEvent published successfully: topic={}, partition={}, offset={}",
                                KafkaConfig.PAYMENT_EVENTS_TOPIC,
                                result.getRecordMetadata().partition(),
                                result.getRecordMetadata().offset());
                    }
                });
    }

    public CompletableFuture<SendResult<String, Object>> sendManagerAssignedEvent(Long propertyId, String propertyName, String managerEmail, String landlordName) {
        return sendManagerAssignedEvent(new com.ars.kirazbackend.event.ManagerAssignedEvent(propertyId, propertyName, managerEmail, landlordName));
    }
}
