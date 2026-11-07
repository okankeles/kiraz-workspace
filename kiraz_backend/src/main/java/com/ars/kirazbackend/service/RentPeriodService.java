package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class RentPeriodService {
    private final RentPeriodRepository rentPeriodRepository;
    private final FileStorageService fileStorageService;
    private final NotificationService notificationService;
    private final AuditLogService auditLogService;
    private final PropertyDelegationService propertyDelegationService;
    private final UserRepository userRepository;

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
    public int markOverduePeriods() {
        LocalDate today = LocalDate.now();
        List<RentPeriod> pendingPeriods = rentPeriodRepository.findPendingOverduePeriods(PaymentStatus.PENDING, today);
        List<RentPeriod> toUpdate = new ArrayList<>();

        for (RentPeriod period : pendingPeriods) {
            boolean hasNoReceipt = period.getReceiptImageUrl() == null || period.getReceiptImageUrl().trim().isEmpty();
            if (hasNoReceipt) {
                period.setStatus(PaymentStatus.OVERDUE);
                toUpdate.add(period);

                if (period.getLeaseAgreement() != null) {
                    if (period.getLeaseAgreement().getTenant() != null) {
                        notificationService.createNotification(
                                period.getLeaseAgreement().getTenant().getId(),
                                "Kira Ödemeniz Gecikti",
                                String.format("%s mülkünün %02d/%d dönemi kira ödemesi gecikmeye girmiştir.",
                                        period.getLeaseAgreement().getProperty() != null ? period.getLeaseAgreement().getProperty().getTitle() : "Mülk",
                                        period.getMonth(),
                                        period.getYear()),
                                "OVERDUE",
                                period.getLeaseAgreement().getId()
                        );
                    }
                    if (period.getLeaseAgreement().getProperty() != null &&
                        period.getLeaseAgreement().getProperty().getLandlord() != null) {
                        notificationService.createNotification(
                                period.getLeaseAgreement().getProperty().getLandlord().getId(),
                                "Geciken Kira Ödemesi",
                                String.format("%s mülkünün %02d/%d dönemi kira ödemesi vadesinde ödenmedi.",
                                        period.getLeaseAgreement().getProperty().getTitle(),
                                        period.getMonth(),
                                        period.getYear()),
                                "OVERDUE",
                                period.getLeaseAgreement().getId()
                        );
                    }
                }

                auditLogService.record(
                        "RENT_PERIOD",
                        period.getId(),
                        "RENT_OVERDUE_AUTO",
                        null,
                        String.format("Gece yarısı cron job: %02d/%d dönemi vadesi geçtiği için OVERDUE statüsüne alındı.",
                                period.getMonth(), period.getYear())
                );
            }
        }

        if (!toUpdate.isEmpty()) {
            rentPeriodRepository.saveAll(toUpdate);
        }
        return toUpdate.size();
    }

    @Transactional
    public RentPeriod markAsLegalProcess(Long periodId, Long userId, String notes) {
        RentPeriod period = rentPeriodRepository.findById(periodId)
                .orElseThrow(() -> new RuntimeException("Kira periyodu bulunamadı: " + periodId));

        if (period.getLeaseAgreement() == null || period.getLeaseAgreement().getProperty() == null) {
            throw new RuntimeException("Geçersiz sözleşme veya mülk ilişkisi");
        }

        Property property = period.getLeaseAgreement().getProperty();
        Long landlordId = property.getLandlord().getId();

        User actor = null;
        if (userId != null) {
            actor = userRepository.findById(userId)
                    .orElseThrow(() -> new RuntimeException("Kullanıcı bulunamadı: " + userId));
        } else {
            org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof User) {
                actor = (User) auth.getPrincipal();
            }
        }

        if (actor != null) {
            if (actor.getRole() == RoleType.LANDLORD) {
                if (!landlordId.equals(actor.getId())) {
                    throw new RuntimeException("Yetkisiz işlem: Bu mülk için hukuki süreç başlatma yetkiniz bulunmamaktadır.");
                }
            } else if (actor.getRole() == RoleType.AGENT) {
                if (!propertyDelegationService.hasActiveDelegation(property.getId(), actor.getId())) {
                    throw new RuntimeException("Yetkisiz işlem: Bu mülk için aktif emlakçı vekaletiniz (PropertyDelegation) bulunmamaktadır.");
                }
            } else {
                throw new RuntimeException("Yetkisiz işlem: Kiracılar hukuki süreç başlatamaz.");
            }
        }

        period.setStatus(PaymentStatus.IN_LEGAL_PROCESS);
        RentPeriod savedPeriod = rentPeriodRepository.save(period);

        auditLogService.record(
                "RENT_PERIOD",
                savedPeriod.getId(),
                "LEGAL_PROCESS_INITIATED",
                actor,
                String.format("Kronikleşen kira borcu için hukuki süreç başlatıldı. Not: %s",
                        notes != null ? notes : "Belirtilmedi")
        );

        if (savedPeriod.getLeaseAgreement().getTenant() != null) {
            notificationService.createNotification(
                    savedPeriod.getLeaseAgreement().getTenant().getId(),
                    "Hukuki Süreç Başlatıldı",
                    String.format("'%s' mülküne ait %02d/%d dönemi kira borcunuz için hukuki / icra takibi süreci başlatılmıştır.",
                            property.getTitle(), savedPeriod.getMonth(), savedPeriod.getYear()),
                    "LEGAL_PROCESS",
                    savedPeriod.getLeaseAgreement().getId()
            );
        }

        if (actor != null && actor.getRole() == RoleType.AGENT) {
            notificationService.createNotification(
                    landlordId,
                    "Hukuki Süreç Başlatıldı",
                    String.format("Emlakçınız %s, '%s' mülkünün ödenmeyen kirası için hukuki süreç başlattı.",
                            actor.getFullName(), property.getTitle()),
                    "LEGAL_PROCESS",
                    savedPeriod.getLeaseAgreement().getId()
            );
        }

        return savedPeriod;
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
        } else if ("IN_LEGAL_PROCESS".equals(normalized) || "LEGAL_PROCESS".equals(normalized) || "ICRA".equals(normalized) || "HUKUKİ SÜREÇ".equals(normalized) || "HUKUKI SUREC".equals(normalized)) {
            paymentStatus = PaymentStatus.IN_LEGAL_PROCESS;
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
