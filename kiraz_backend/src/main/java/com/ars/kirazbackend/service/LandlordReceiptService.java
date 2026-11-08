package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PendingReceiptDto;
import com.ars.kirazbackend.entity.AuditLog;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.event.ReceiptRejectedEvent;
import com.ars.kirazbackend.repository.AuditLogRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class LandlordReceiptService {

    private final RentPeriodRepository rentPeriodRepository;
    private final RentPeriodService rentPeriodService;
    private final AuditLogRepository auditLogRepository;
    private final AuditLogService auditLogService;
    private final KafkaProducerService kafkaProducerService;

    /**
     * Ev sahibinin mülklerine ait, statüsü WAITING_APPROVAL olan tüm kira periyotlarını bulup
     * PendingReceiptDto listesi olarak döner.
     */
    @Transactional(readOnly = true)
    public List<PendingReceiptDto> getPendingReceipts(Long landlordId) {
        log.info("Fetching pending receipts for landlordId={}", landlordId);

        List<RentPeriod> pendingPeriods = rentPeriodRepository.findByLandlordIdAndStatus(
                landlordId, PaymentStatus.WAITING_APPROVAL
        );

        return pendingPeriods.stream().map(period -> {
            List<AuditLog> logs = auditLogRepository.findByEntityNameAndEntityIdOrderByCreatedAtDesc(
                    "RENT_PERIOD", period.getId()
            );

            LocalDateTime uploadDate = logs.stream()
                    .filter(l -> "RECEIPT_UPLOADED".equals(l.getAction()))
                    .map(AuditLog::getCreatedAt)
                    .findFirst()
                    .orElseGet(() -> logs.isEmpty() ? LocalDateTime.now() : logs.get(0).getCreatedAt());

            String propertyName = (period.getLeaseAgreement() != null && period.getLeaseAgreement().getProperty() != null)
                    ? period.getLeaseAgreement().getProperty().getTitle()
                    : "Taşınmaz";

            String tenantName = (period.getLeaseAgreement() != null && period.getLeaseAgreement().getTenant() != null)
                    ? period.getLeaseAgreement().getTenant().getFullName()
                    : "Kiracı";

            BigDecimal amount = (period.getLeaseAgreement() != null && period.getLeaseAgreement().getMonthlyRentAmount() != null)
                    ? period.getLeaseAgreement().getMonthlyRentAmount()
                    : BigDecimal.ZERO;

            return new PendingReceiptDto(
                    period.getId(),
                    propertyName,
                    tenantName,
                    period.getMonth(),
                    period.getYear(),
                    amount,
                    period.getReceiptImageUrl(),
                    uploadDate
            );
        }).toList();
    }

    /**
     * Dekont onaylama işlemi: Halihazırda Kafka event'i fırlatan updateStatus(periodId, "PAID") çağrılır.
     */
    @Transactional
    public RentPeriod approveReceipt(Long periodId) {
        log.info("Approving receipt for periodId={}", periodId);
        return rentPeriodService.updateStatus(periodId, "PAID");
    }

    /**
     * Dekont reddedildiğinde kiranın statüsünü tekrar PENDING (veya vade geçmişse OVERDUE) yapar,
     * receiptImageUrl'i temizler, AuditLog atar ve Kafka üzerinden kiracıya ReceiptRejectedEvent fırlatır.
     */
    @Transactional
    public RentPeriod rejectReceipt(Long periodId, String reason, User landlord) {
        log.info("Rejecting receipt for periodId={}, reason={}", periodId, reason);

        RentPeriod period = rentPeriodRepository.findById(periodId)
                .orElseThrow(() -> new RuntimeException("Kira dönemi bulunamadı: " + periodId));

        LocalDate today = LocalDate.now();
        LocalDate dueDate = period.getPeriodStart();
        boolean isPastDue = dueDate != null && dueDate.isBefore(today);

        // Vade geçmişse OVERDUE, geçmemişse PENDING
        PaymentStatus newStatus = isPastDue ? PaymentStatus.OVERDUE : PaymentStatus.PENDING;
        period.setStatus(newStatus);
        period.setReceiptImageUrl(null);

        RentPeriod savedPeriod = rentPeriodRepository.save(period);

        String reasonText = (reason != null && !reason.trim().isEmpty()) ? reason.trim() : "Ev sahibi tarafından reddedildi.";

        // Audit Log kaydı
        auditLogService.record(
                "RENT_PERIOD",
                savedPeriod.getId(),
                "RECEIPT_REJECTED",
                landlord,
                String.format("%02d/%d dönemi dekontu reddedildi. Yeni statü: %s. Sebep: %s",
                        savedPeriod.getMonth(), savedPeriod.getYear(), newStatus.name(), reasonText)
        );

        // Kafka üzerinden asenkron ReceiptRejectedEvent fırlat
        Long tenantId = (savedPeriod.getLeaseAgreement() != null && savedPeriod.getLeaseAgreement().getTenant() != null)
                ? savedPeriod.getLeaseAgreement().getTenant().getId()
                : null;
        Long leaseId = (savedPeriod.getLeaseAgreement() != null) ? savedPeriod.getLeaseAgreement().getId() : null;
        String propTitle = (savedPeriod.getLeaseAgreement() != null && savedPeriod.getLeaseAgreement().getProperty() != null)
                ? savedPeriod.getLeaseAgreement().getProperty().getTitle()
                : "Mülk";

        kafkaProducerService.sendReceiptRejectedEvent(new ReceiptRejectedEvent(
                savedPeriod.getId(),
                tenantId,
                leaseId,
                propTitle,
                reasonText,
                savedPeriod.getMonth(),
                savedPeriod.getYear()
        ));

        return savedPeriod;
    }

    @Transactional
    public RentPeriod rejectReceipt(Long periodId, String reason) {
        return rejectReceipt(periodId, reason, null);
    }
}
