package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.Notification;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.DelegationStatus;
import com.ars.kirazbackend.repository.NotificationRepository;
import com.ars.kirazbackend.repository.PropertyDelegationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final PropertyDelegationRepository propertyDelegationRepository;
    private final EmailService emailService;
    private final com.ars.kirazbackend.repository.UserRepository userRepository;

    @Transactional
    public Notification createNotification(Long userId, String title, String message, String type, Long referenceId) {
        Notification notification = Notification.builder()
                .userId(userId)
                .title(title)
                .message(message)
                .type(type)
                .referenceId(referenceId)
                .isRead(false)
                .build();
        return notificationRepository.save(notification);
    }

    @Transactional
    public Notification createNotification(Long userId, String title, String message) {
        return createNotification(userId, title, message, null, null);
    }

    public List<Notification> getUnreadNotifications(Long userId) {
        return notificationRepository.findByUserIdAndIsReadFalseOrderByCreatedAtDesc(userId);
    }

    public List<Notification> getAllNotifications(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    @Transactional
    public Notification markAsRead(Long notificationId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new RuntimeException("Bildirim bulunamadı: " + notificationId));
        notification.setRead(true);
        return notificationRepository.save(notification);
    }

    /**
     * Kiracı Havale/EFT dekontu yüklediğinde Ev Sahibine (ve varsa mülke vekil emlakçıya) bildirim gönderir.
     */
    @Transactional
    public void notifyLandlordForReceipt(RentPeriod period) {
        if (period == null || period.getLeaseAgreement() == null) {
            return;
        }

        Property property = period.getLeaseAgreement().getProperty();
        User landlord = property != null ? property.getLandlord() : null;
        User tenant = period.getLeaseAgreement().getTenant();

        String tenantName = (tenant != null && tenant.getFullName() != null) ? tenant.getFullName() : "Kiracınız";
        String propertyTitle = (property != null && property.getTitle() != null) ? property.getTitle() : "Taşınmaz";

        String title = "Yeni Dekont Yüklendi";
        String message = String.format("%s, '%s' mülkünün %02d/%d dönemi kirası için Havale/EFT dekontu yükledi. Onayınız bekleniyor.",
                tenantName, propertyTitle, period.getMonth(), period.getYear());

        if (landlord != null) {
            createNotification(
                    landlord.getId(),
                    title,
                    message,
                    "RECEIPT_WAITING_APPROVAL",
                    period.getLeaseAgreement().getId()
            );

            if (landlord.getEmail() != null && !landlord.getEmail().trim().isEmpty()) {
                emailService.sendNotificationEmail(
                        landlord.getEmail(),
                        "kiraZ - " + title,
                        "Sayın " + landlord.getFullName() + ",\n\n" + message + "\n\nkiraZ Yönetim Sistemi"
                );
            }
        }

        // Mülke atanmış aktif vekil emlakçılar varsa onlara da bildirim ilet
        if (property != null && propertyDelegationRepository != null) {
            List<PropertyDelegation> delegations = propertyDelegationRepository.findByPropertyIdAndStatus(
                    property.getId(), DelegationStatus.ACTIVE);
            for (PropertyDelegation del : delegations) {
                if (del.getAgent() != null) {
                    createNotification(
                            del.getAgent().getId(),
                            title,
                            message,
                            "RECEIPT_WAITING_APPROVAL",
                            period.getLeaseAgreement().getId()
                    );
                }
            }
        }
    }

    /**
     * PayTR ile online veya Ev Sahibinin dekont onayıyla ödeme başarılı olduğunda Kiracıya ve Ev Sahibine bildirim gönderir.
     */
    @Transactional
    public void notifyPaymentSuccess(RentPeriod period) {
        if (period == null || period.getLeaseAgreement() == null) {
            return;
        }

        Property property = period.getLeaseAgreement().getProperty();
        User landlord = property != null ? property.getLandlord() : null;
        User tenant = period.getLeaseAgreement().getTenant();
        String propertyTitle = (property != null && property.getTitle() != null) ? property.getTitle() : "Taşınmaz";

        // 1. Kiracı Bildirimi
        if (tenant != null) {
            String tenantTitle = "Kira Ödemeniz Alındı";
            String tenantMessage = String.format("'%s' mülküne ait %02d/%d dönemi kira ödemeniz başarıyla gerçekleşti.",
                    propertyTitle, period.getMonth(), period.getYear());

            createNotification(
                    tenant.getId(),
                    tenantTitle,
                    tenantMessage,
                    "PAYMENT_SUCCESS",
                    period.getLeaseAgreement().getId()
            );

            if (tenant.getEmail() != null && !tenant.getEmail().trim().isEmpty()) {
                emailService.sendNotificationEmail(
                        tenant.getEmail(),
                        "kiraZ - " + tenantTitle,
                        "Sayın " + tenant.getFullName() + ",\n\n" + tenantMessage + "\n\nkiraZ Yönetim Sistemi"
                );
            }
        }

        // 2. Ev Sahibi Bildirimi
        if (landlord != null) {
            String landlordTitle = "Kira Tahsilatı Yapıldı";
            String landlordMessage = String.format("'%s' mülkünüz için %02d/%d dönemi kira ödemesi başarıyla gerçekleşti.",
                    propertyTitle, period.getMonth(), period.getYear());

            createNotification(
                    landlord.getId(),
                    landlordTitle,
                    landlordMessage,
                    "PAYMENT_SUCCESS",
                    period.getLeaseAgreement().getId()
            );

            if (landlord.getEmail() != null && !landlord.getEmail().trim().isEmpty()) {
                emailService.sendNotificationEmail(
                        landlord.getEmail(),
                        "kiraZ - " + landlordTitle,
                        "Sayın " + landlord.getFullName() + ",\n\n" + landlordMessage + "\n\nkiraZ Yönetim Sistemi"
                );
            }
        }

        // 3. Emlakçı Bildirimi
        if (property != null && propertyDelegationRepository != null) {
            List<PropertyDelegation> delegations = propertyDelegationRepository.findByPropertyIdAndStatus(
                    property.getId(), DelegationStatus.ACTIVE);
            for (PropertyDelegation del : delegations) {
                if (del.getAgent() != null) {
                    createNotification(
                            del.getAgent().getId(),
                            "Kira Tahsilatı Yapıldı",
                            String.format("Yetkili olduğunuz '%s' mülkü için %02d/%d dönemi kirası ödendi.",
                                    propertyTitle, period.getMonth(), period.getYear()),
                            "PAYMENT_SUCCESS",
                            period.getLeaseAgreement().getId()
                    );
                }
            }
        }
    }

    /**
     * Kiracının yüklediği dekont Ev Sahibi tarafından reddedildiğinde Kiracıya bildirim ve e-posta gönderir.
     */
    @Transactional
    public void notifyReceiptRejected(RentPeriod period, String reason) {
        if (period == null || period.getLeaseAgreement() == null) {
            return;
        }

        User tenant = period.getLeaseAgreement().getTenant();
        Property property = period.getLeaseAgreement().getProperty();
        String propertyTitle = (property != null && property.getTitle() != null) ? property.getTitle() : "Taşınmaz";

        String title = "Dekontunuz Reddedildi";
        String reasonText = (reason != null && !reason.trim().isEmpty()) ? reason.trim() : "Ev sahibi tarafından reddedildi.";
        String message = String.format("'%s' mülkünün %02d/%d dönemi kirası için yüklediğiniz dekont reddedildi: %s Lütfen yeni bir dekont yükleyin.",
                propertyTitle, period.getMonth(), period.getYear(), reasonText);

        if (tenant != null) {
            createNotification(
                    tenant.getId(),
                    title,
                    message,
                    "RECEIPT_REJECTED",
                    period.getLeaseAgreement().getId()
            );

            if (tenant.getEmail() != null && !tenant.getEmail().trim().isEmpty()) {
                emailService.sendNotificationEmail(
                        tenant.getEmail(),
                        "kiraZ - " + title,
                        "Sayın " + tenant.getFullName() + ",\n\n" + message + "\n\nkiraZ Yönetim Sistemi"
                );
            }
        }
    }

    /**
     * Emlakçı/Mülk Yöneticisi bir mülke atandığında (ManagerAssignedEvent) bildirim ve e-posta gönderir.
     */
    @Transactional
    public void notifyManagerAssigned(com.ars.kirazbackend.event.ManagerAssignedEvent event) {
        if (event == null || event.managerEmail() == null) {
            return;
        }

        String title = "Yeni Mülk Yetkilendirmesi";
        String landlord = (event.landlordName() != null && !event.landlordName().trim().isEmpty())
                ? event.landlordName()
                : "Ev Sahibi";
        String propTitle = (event.propertyName() != null && !event.propertyName().trim().isEmpty())
                ? event.propertyName()
                : "Taşınmaz";

        String message = String.format("Sayın %s tarafından '%s' mülkünün yönetimi size devredilmiştir.",
                landlord, propTitle);

        if (userRepository != null) {
            userRepository.findByEmail(event.managerEmail().trim()).ifPresent(manager -> {
                createNotification(
                        manager.getId(),
                        title,
                        message,
                        "MANAGER_ASSIGNED",
                        event.propertyId()
                );
            });
        }

        emailService.sendNotificationEmail(
                event.managerEmail().trim(),
                "kiraZ - " + title,
                "Sayın Mülk Yöneticisi,\n\n" + message + "\n\nkiraZ Gayrimenkul Yönetim Sistemi"
        );
    }
}

