package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptRejectedEvent;
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
        } else if (payload instanceof ReceiptRejectedEvent event) {
            handleReceiptRejected(event);
        } else if (payload instanceof com.ars.kirazbackend.event.ManagerAssignedEvent event) {
            handleManagerAssigned(event);
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

    public void handleReceiptRejected(ReceiptRejectedEvent event) {
        log.info("Handling ReceiptRejectedEvent: periodId={}, tenantId={}, reason={}",
                event.periodId(), event.tenantId(), event.reason());

        if (event.periodId() == null) {
            log.warn("ReceiptRejectedEvent has no periodId, skipping notification.");
            return;
        }

        RentPeriod period = rentPeriodRepository.findById(event.periodId()).orElse(null);
        if (period != null) {
            notificationService.notifyReceiptRejected(period, event.reason());
            log.info("Successfully triggered notifyReceiptRejected for periodId={}", event.periodId());
        } else {
            log.error("RentPeriod not found for periodId={} in ReceiptRejectedEvent", event.periodId());
        }
    }

    public void handleManagerAssigned(com.ars.kirazbackend.event.ManagerAssignedEvent event) {
        log.info("Handling ManagerAssignedEvent: propertyId={}, propertyName={}, managerEmail={}",
                event.propertyId(), event.propertyName(), event.managerEmail());

        notificationService.notifyManagerAssigned(event);
        log.info("Successfully triggered notifyManagerAssigned for propertyId={}, managerEmail={}",
                event.propertyId(), event.managerEmail());
    }

    private void handleRawJson(String jsonStr) {
        try {
            JsonNode root = objectMapper.readTree(jsonStr);
            if (root.has("receiptImageUrl") || root.has("ReceiptUploadedEvent")) {
                ReceiptUploadedEvent event = objectMapper.treeToValue(root, ReceiptUploadedEvent.class);
                handleReceiptUploaded(event);
            } else if (root.has("reason") || root.has("ReceiptRejectedEvent")) {
                ReceiptRejectedEvent event = objectMapper.treeToValue(root, ReceiptRejectedEvent.class);
                handleReceiptRejected(event);
            } else if (root.has("managerEmail") || root.has("ManagerAssignedEvent")) {
                com.ars.kirazbackend.event.ManagerAssignedEvent event =
                        objectMapper.treeToValue(root, com.ars.kirazbackend.event.ManagerAssignedEvent.class);
                handleManagerAssigned(event);
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
            } else if (tree.has("reason")) {
                ReceiptRejectedEvent event = objectMapper.treeToValue(tree, ReceiptRejectedEvent.class);
                handleReceiptRejected(event);
            } else if (tree.has("managerEmail")) {
                com.ars.kirazbackend.event.ManagerAssignedEvent event =
                        objectMapper.treeToValue(tree, com.ars.kirazbackend.event.ManagerAssignedEvent.class);
                handleManagerAssigned(event);
            } else {
                PaymentSuccessEvent event = objectMapper.treeToValue(tree, PaymentSuccessEvent.class);
                handlePaymentSuccess(event);
            }
        } catch (Exception e) {
            log.error("Failed to convert generic Kafka payload to event: {}", payload, e);
        }
    }
}
