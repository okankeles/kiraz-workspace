package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class RentPeriodService {
    private final RentPeriodRepository rentPeriodRepository;
    private final FileStorageService fileStorageService;
    private final NotificationService notificationService;

    @Transactional
    public List<RentPeriod> getPeriodsByLeaseId(Long leaseId) {
        List<RentPeriod> periods = rentPeriodRepository.findByLeaseAgreementIdOrderByPeriodStartAsc(leaseId);
        return checkAndApplyOverdue(periods);
    }

    @Transactional
    public List<RentPeriod> getPeriodsForLease(Long leaseId) {
        return getPeriodsByLeaseId(leaseId);
    }

    @Transactional
    public List<RentPeriod> checkAndApplyOverdue(List<RentPeriod> periods) {
        if (periods == null || periods.isEmpty()) {
            return periods;
        }

        LocalDate today = LocalDate.now();
        List<RentPeriod> toUpdate = new ArrayList<>();

        for (RentPeriod period : periods) {
            LocalDate dueDate = period.getPaymentDate() != null
                    ? period.getPaymentDate()
                    : period.getPeriodStart();

            boolean isPastDue = dueDate != null && dueDate.isBefore(today);
            boolean isPending = period.getStatus() == PaymentStatus.PENDING;
            boolean hasNoReceipt = period.getReceiptImageUrl() == null || period.getReceiptImageUrl().trim().isEmpty();

            if (isPastDue && isPending && hasNoReceipt) {
                period.setStatus(PaymentStatus.OVERDUE);
                toUpdate.add(period);
            }
        }

        if (!toUpdate.isEmpty()) {
            rentPeriodRepository.saveAll(toUpdate);
        }

        return periods;
    }

    @Transactional
    public RentPeriod uploadReceipt(Long periodId, MultipartFile file) {
        RentPeriod period = rentPeriodRepository.findById(periodId)
                .orElseThrow(() -> new RuntimeException("Rent period not found"));

        String fileUrl = fileStorageService.storeFile(file);
        period.setReceiptImageUrl(fileUrl);
        period.setStatus(PaymentStatus.PENDING);

        RentPeriod savedPeriod = rentPeriodRepository.save(period);

        if (savedPeriod.getLeaseAgreement() != null &&
            savedPeriod.getLeaseAgreement().getProperty() != null &&
            savedPeriod.getLeaseAgreement().getProperty().getLandlord() != null) {

            Long landlordId = savedPeriod.getLeaseAgreement().getProperty().getLandlord().getId();
            String tenantName = (savedPeriod.getLeaseAgreement().getTenant() != null &&
                    savedPeriod.getLeaseAgreement().getTenant().getFullName() != null)
                    ? savedPeriod.getLeaseAgreement().getTenant().getFullName()
                    : "Kiracınız";
            String propertyName = (savedPeriod.getLeaseAgreement().getProperty().getTitle() != null)
                    ? savedPeriod.getLeaseAgreement().getProperty().getTitle()
                    : "Taşınmaz";

            notificationService.createNotification(
                    landlordId,
                    "Yeni Dekont Yüklendi",
                    tenantName + " adlı kiracınız " + propertyName + " için dekont yükledi.",
                    "RECEIPT",
                    savedPeriod.getLeaseAgreement().getId()
            );
        }

        return savedPeriod;
    }

    @Transactional
    public RentPeriod updateStatus(Long id, String status) {
        RentPeriod period = rentPeriodRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Rent period not found"));

        String normalized = status != null ? status.trim().toUpperCase() : "";
        PaymentStatus paymentStatus;
        if ("PAID".equals(normalized) || "ÖDENDİ".equals(normalized) || "ODENDI".equals(normalized)) {
            paymentStatus = PaymentStatus.PAID;
        } else if ("REJECTED".equals(normalized) || "REDDEDİLDİ".equals(normalized) || "REDDEDILDI".equals(normalized) || "UNPAID".equals(normalized) || "REJECT".equals(normalized)) {
            paymentStatus = PaymentStatus.REJECTED;
        } else if ("PENDING".equals(normalized) || "BEKLİYOR".equals(normalized) || "BEKLIYOR".equals(normalized)) {
            paymentStatus = PaymentStatus.PENDING;
        } else if ("OVERDUE".equals(normalized) || "GECİKTİ".equals(normalized) || "GECIKTI".equals(normalized)) {
            paymentStatus = PaymentStatus.OVERDUE;
        } else {
            try {
                paymentStatus = PaymentStatus.valueOf(normalized);
            } catch (IllegalArgumentException e) {
                throw new RuntimeException("Invalid payment status: " + status);
            }
        }
        period.setStatus(paymentStatus);
        if (paymentStatus == PaymentStatus.REJECTED) {
            period.setReceiptImageUrl(null); // Clear the invalid receipt so tenant can re-upload
        }
        RentPeriod savedPeriod = rentPeriodRepository.save(period);

        if (paymentStatus == PaymentStatus.PAID) {
            if (savedPeriod.getLeaseAgreement() != null &&
                savedPeriod.getLeaseAgreement().getTenant() != null) {

                Long tenantId = savedPeriod.getLeaseAgreement().getTenant().getId();
                String propertyName = (savedPeriod.getLeaseAgreement().getProperty() != null &&
                        savedPeriod.getLeaseAgreement().getProperty().getTitle() != null)
                        ? savedPeriod.getLeaseAgreement().getProperty().getTitle()
                        : "Taşınmaz";

                notificationService.createNotification(
                        tenantId,
                        "Ödeme Onaylandı",
                        propertyName + " için ödemeniz onaylandı.",
                        "APPROVAL",
                        savedPeriod.getLeaseAgreement().getId()
                );
            }
        } else if (paymentStatus == PaymentStatus.REJECTED) {
            period.setReceiptImageUrl(null); // Clear the invalid receipt so tenant can re-upload
            notificationService.createNotification(
                period.getLeaseAgreement().getTenantId(),
                "Ödeme Reddedildi",
                period.getLeaseAgreement().getProperty().getTitle() + " için yüklediğiniz dekont reddedildi. Lütfen yeni bir dekont yükleyin.",
                "REJECT",
                period.getLeaseAgreement().getId()
            );
        }

        return savedPeriod;
    }

    @Transactional
    public RentPeriod updateStatus(Long id, PaymentStatus status) {
        return updateStatus(id, status != null ? status.name() : null);
    }
}
