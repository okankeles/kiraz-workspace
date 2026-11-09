package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PaymentSummaryResponse;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.event.PaymentSuccessEvent;
import com.ars.kirazbackend.event.ReceiptUploadedEvent;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class RentPeriodService {
    private final RentPeriodRepository rentPeriodRepository;
    private final FileStorageService fileStorageService;
    private final KafkaProducerService kafkaProducerService;
    private final NotificationService notificationService;
    private final AuditLogService auditLogService;
    private final PropertyDelegationService propertyDelegationService;
    private final UserRepository userRepository;

    @Transactional
    public List<RentPeriod> getPeriodsByLeaseId(Long leaseId) {
        List<RentPeriod> periods = rentPeriodRepository.findByLeaseAgreementIdOrderByPeriodStartAsc(leaseId);
        return checkAndApplyOverdue(periods);
    }

    @Transactional(readOnly = true)
    public RentPeriod getPeriodById(Long id) {
        return rentPeriodRepository.findById(id)
                .orElseThrow(() -> new com.ars.kirazbackend.exception.ResourceNotFoundException("Kira dönemi bulunamadı: " + id));
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
                .orElseThrow(() -> new RuntimeException("Kira dönemi bulunamadı: " + periodId));

        String fileUrl = fileStorageService.storeFile(file);
        period.setReceiptImageUrl(fileUrl);
        period.setStatus(PaymentStatus.WAITING_APPROVAL);

        RentPeriod savedPeriod = rentPeriodRepository.save(period);

        User tenant = (savedPeriod.getLeaseAgreement() != null) ? savedPeriod.getLeaseAgreement().getTenant() : null;
        auditLogService.record(
                "RENT_PERIOD",
                savedPeriod.getId(),
                "RECEIPT_UPLOADED",
                tenant,
                String.format("%02d/%d dönemi için Havale/EFT dekontu yüklendi. Onay bekleniyor.",
                        savedPeriod.getMonth(), savedPeriod.getYear())
        );

        Long tenantId = (tenant != null) ? tenant.getId() : null;
        Long leaseId = (savedPeriod.getLeaseAgreement() != null) ? savedPeriod.getLeaseAgreement().getId() : null;
        kafkaProducerService.sendReceiptUploadedEvent(new ReceiptUploadedEvent(
                savedPeriod.getId(),
                tenantId,
                leaseId,
                fileUrl,
                savedPeriod.getMonth(),
                savedPeriod.getYear()
        ));

        return savedPeriod;
    }

    @Transactional
    public RentPeriod updateStatus(Long id, String status) {
        RentPeriod period = rentPeriodRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Kira dönemi bulunamadı: " + id));

        String normalized = status != null ? status.trim().toUpperCase() : "";
        PaymentStatus paymentStatus;
        if ("PAID".equals(normalized) || "ÖDENDİ".equals(normalized) || "ODENDI".equals(normalized)) {
            paymentStatus = PaymentStatus.PAID;
        } else if ("REJECTED".equals(normalized) || "REDDEDİLDİ".equals(normalized) || "REDDEDILDI".equals(normalized) || "UNPAID".equals(normalized) || "REJECT".equals(normalized)) {
            paymentStatus = PaymentStatus.REJECTED;
        } else if ("WAITING_APPROVAL".equals(normalized) || "ONAY_BEKLIYOR".equals(normalized) || "ONAY BEKLİYOR".equals(normalized)) {
            paymentStatus = PaymentStatus.WAITING_APPROVAL;
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
                throw new RuntimeException("Geçersiz ödeme statüsü: " + status);
            }
        }
        period.setStatus(paymentStatus);
        if (paymentStatus == PaymentStatus.REJECTED) {
            period.setReceiptImageUrl(null); // Clear the invalid receipt so tenant can re-upload
        } else if (paymentStatus == PaymentStatus.PAID) {
            period.setPaymentDate(LocalDate.now());
        }

        RentPeriod savedPeriod = rentPeriodRepository.save(period);

        if (paymentStatus == PaymentStatus.PAID) {
            Long tenantId = (savedPeriod.getLeaseAgreement() != null && savedPeriod.getLeaseAgreement().getTenant() != null)
                    ? savedPeriod.getLeaseAgreement().getTenant().getId()
                    : null;
            Long leaseId = (savedPeriod.getLeaseAgreement() != null) ? savedPeriod.getLeaseAgreement().getId() : null;
            Double amount = (savedPeriod.getLeaseAgreement() != null && savedPeriod.getLeaseAgreement().getMonthlyRentAmount() != null)
                    ? savedPeriod.getLeaseAgreement().getMonthlyRentAmount().doubleValue()
                    : null;

            kafkaProducerService.sendPaymentSuccessEvent(new PaymentSuccessEvent(
                    savedPeriod.getId(),
                    tenantId,
                    leaseId,
                    amount,
                    "MANUAL_APPROVAL"
            ));

            User landlord = (savedPeriod.getLeaseAgreement() != null && savedPeriod.getLeaseAgreement().getProperty() != null)
                    ? savedPeriod.getLeaseAgreement().getProperty().getLandlord()
                    : null;
            auditLogService.record(
                    "RENT_PERIOD",
                    savedPeriod.getId(),
                    "PAYMENT_APPROVED",
                    landlord,
                    String.format("%02d/%d dönemi kira ödemesi ev sahibi tarafından onaylandı.",
                            savedPeriod.getMonth(), savedPeriod.getYear())
            );
        } else if (paymentStatus == PaymentStatus.REJECTED) {
            period.setReceiptImageUrl(null); // Clear the invalid receipt so tenant can re-upload
            if (savedPeriod.getLeaseAgreement() != null && savedPeriod.getLeaseAgreement().getTenant() != null) {
                notificationService.createNotification(
                        savedPeriod.getLeaseAgreement().getTenant().getId(),
                        "Ödeme Reddedildi",
                        (savedPeriod.getLeaseAgreement().getProperty() != null ? savedPeriod.getLeaseAgreement().getProperty().getTitle() : "Mülk")
                                + " için yüklediğiniz dekont reddedildi. Lütfen yeni bir dekont yükleyin.",
                        "REJECT",
                        savedPeriod.getLeaseAgreement().getId()
                );
            }
        }

        return savedPeriod;
    }

    @Transactional
    public RentPeriod updateStatus(Long id, PaymentStatus status) {
        return updateStatus(id, status != null ? status.name() : null);
    }

    /**
     * Kiracının anlık finansal özetini (Toplam Borç, Toplam Ödenen, Sıradaki Ödeme) hesaplar.
     */
    @Transactional
    public PaymentSummaryResponse getTenantPaymentSummary(Long tenantId) {
        if (tenantId == null) {
            throw new IllegalArgumentException("Kiracı ID boş olamaz.");
        }

        List<RentPeriod> periods = rentPeriodRepository.findByTenantId(tenantId);
        // Otomatik vadesi geçen kontrollerini uygula
        periods = checkAndApplyOverdue(periods);

        LocalDate today = LocalDate.now();
        BigDecimal totalPaid = BigDecimal.ZERO;
        BigDecimal totalDebt = BigDecimal.ZERO;

        List<RentPeriod> pendingPeriods = new ArrayList<>();

        for (RentPeriod period : periods) {
            BigDecimal rentAmount = (period.getLeaseAgreement() != null && period.getLeaseAgreement().getMonthlyRentAmount() != null)
                    ? period.getLeaseAgreement().getMonthlyRentAmount()
                    : BigDecimal.ZERO;

            PaymentStatus status = period.getStatus();
            LocalDate dueDate = period.getPaymentDate() != null ? period.getPaymentDate() : period.getPeriodStart();

            if (status == PaymentStatus.PAID) {
                totalPaid = totalPaid.add(rentAmount);
            } else if (status == PaymentStatus.OVERDUE || status == PaymentStatus.IN_LEGAL_PROCESS) {
                totalDebt = totalDebt.add(rentAmount);
            } else if (status == PaymentStatus.PENDING) {
                pendingPeriods.add(period);
                if (dueDate != null && !dueDate.isAfter(today)) {
                    totalDebt = totalDebt.add(rentAmount);
                }
            }
        }

        // Statüsü PENDING olanlar arasında tarihi en yakın olanı bulup nextPaymentDate ve nextPaymentAmount set et
        LocalDate nextPaymentDate = null;
        BigDecimal nextPaymentAmount = BigDecimal.ZERO;

        if (!pendingPeriods.isEmpty()) {
            RentPeriod nextPeriod = pendingPeriods.stream()
                    .filter(p -> {
                        LocalDate d = p.getPaymentDate() != null ? p.getPaymentDate() : p.getPeriodStart();
                        return d != null && !d.isBefore(today);
                    })
                    .min(Comparator.comparing(p -> p.getPaymentDate() != null ? p.getPaymentDate() : p.getPeriodStart()))
                    .orElseGet(() -> pendingPeriods.stream()
                            .min(Comparator.comparing(p -> p.getPaymentDate() != null ? p.getPaymentDate() : p.getPeriodStart()))
                            .orElse(null)
                    );

            if (nextPeriod != null) {
                nextPaymentDate = nextPeriod.getPaymentDate() != null ? nextPeriod.getPaymentDate() : nextPeriod.getPeriodStart();
                if (nextPeriod.getLeaseAgreement() != null && nextPeriod.getLeaseAgreement().getMonthlyRentAmount() != null) {
                    nextPaymentAmount = nextPeriod.getLeaseAgreement().getMonthlyRentAmount();
                }
            }
        }

        return PaymentSummaryResponse.builder()
                .totalDebt(totalDebt)
                .totalPaid(totalPaid)
                .nextPaymentDate(nextPaymentDate)
                .nextPaymentAmount(nextPaymentAmount)
                .build();
    }
}
