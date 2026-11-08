package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptUploadedEvent;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class KafkaConsumerService {

    private final NotificationService notificationService;
    private final RentPeriodRepository rentPeriodRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    @KafkaListener(topics = "payment-events", groupId = "kiraz-group")
    public void consume(ConsumerRecord<String, Object> record) {
        Object payload = record.value();
        log.info("Kafka consumer received record from topic '{}', partition={}, offset={}, key={}: {}",
                record.topic(), record.partition(), record.offset(), record.key(), payload);

        if (payload instanceof PaymentSuccessEvent event) {
            handlePaymentSuccess(event);
        } else if (payload instanceof ReceiptUploadedEvent event) {
            handleReceiptUploaded(event);
        } else if (payload instanceof String jsonStr) {
            handleRawJson(jsonStr);
        } else if (payload != null) {
            handleGenericPayload(payload);
        } else {
            log.warn("Received null payload from Kafka topic '{}'", record.topic());
        }
    }

    public void handlePaymentSuccess(PaymentSuccessEvent event) {
        log.info("Handling PaymentSuccessEvent: periodId={}, tenantId={}, amount={}, type={}",
                event.periodId(), event.tenantId(), event.amount(), event.paymentType());

        if (event.periodId() == null) {
            log.warn("PaymentSuccessEvent has no periodId, skipping notification.");
            return;
        }

        RentPeriod period = rentPeriodRepository.findById(event.periodId()).orElse(null);
        if (period != null) {
            notificationService.notifyPaymentSuccess(period);
            log.info("Successfully triggered notifyPaymentSuccess for periodId={}", event.periodId());
        } else {
            log.error("RentPeriod not found for periodId={} in PaymentSuccessEvent", event.periodId());
        }
    }

    public void handleReceiptUploaded(ReceiptUploadedEvent event) {
        log.info("Handling ReceiptUploadedEvent: periodId={}, tenantId={}, imageUrl={}",
                event.periodId(), event.tenantId(), event.receiptImageUrl());

        if (event.periodId() == null) {
            log.warn("ReceiptUploadedEvent has no periodId, skipping notification.");
            return;
        }

        RentPeriod period = rentPeriodRepository.findById(event.periodId()).orElse(null);
        if (period != null) {
            notificationService.notifyLandlordForReceipt(period);
            log.info("Successfully triggered notifyLandlordForReceipt for periodId={}", event.periodId());
        } else {
            log.error("RentPeriod not found for periodId={} in ReceiptUploadedEvent", event.periodId());
        }
    }

    private void handleRawJson(String jsonStr) {
        try {
            JsonNode root = objectMapper.readTree(jsonStr);
            if (root.has("receiptImageUrl") || root.has("ReceiptUploadedEvent")) {
                ReceiptUploadedEvent event = objectMapper.treeToValue(root, ReceiptUploadedEvent.class);
                handleReceiptUploaded(event);
            } else {
                PaymentSuccessEvent event = objectMapper.treeToValue(root, PaymentSuccessEvent.class);
                handlePaymentSuccess(event);
            }
        } catch (Exception e) {
            log.error("Failed to parse raw JSON message from Kafka: {}", jsonStr, e);
        }
    }

    private void handleGenericPayload(Object payload) {
        try {
            JsonNode tree = objectMapper.valueToTree(payload);
            if (tree.has("receiptImageUrl")) {
                ReceiptUploadedEvent event = objectMapper.treeToValue(tree, ReceiptUploadedEvent.class);
                handleReceiptUploaded(event);
            } else {
                PaymentSuccessEvent event = objectMapper.treeToValue(tree, PaymentSuccessEvent.class);
                handlePaymentSuccess(event);
            }
        } catch (Exception e) {
            log.error("Failed to convert generic Kafka payload to event: {}", payload, e);
        }
    }
}
