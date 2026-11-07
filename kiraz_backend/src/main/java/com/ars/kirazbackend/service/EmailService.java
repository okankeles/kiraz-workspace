package com.ars.kirazbackend.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;

    public void sendTenantInviteEmail(String toEmail, String tenantName, String propertyTitle, String inviteCode) {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            log.warn("Cannot send invite email: toEmail is empty");
            return;
        }
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(toEmail.trim());
            message.setSubject("kiraZ - Yeni Sözleşme Daveti");
            message.setText("Merhaba " + (tenantName != null ? tenantName : "Kiracı") + ",\n\n" +
                    (propertyTitle != null ? propertyTitle : "Taşınmaz") + " mülkü için ev sahibiniz sizi kiracı olarak atadı.\n\n" +
                    "Uygulamaya girip aşağıdaki davet kodunu kullanarak sözleşmenizi görüntüleyebilir ve onaylayabilirsiniz:\n\n" +
                    "Davet Kodu: " + inviteCode + "\n\n" +
                    "kiraZ Ailesi");
            mailSender.send(message);
            log.info("Invite email sent successfully to {}", toEmail);
        } catch (Exception e) {
            log.error("Failed to send invite email to {}", toEmail, e);
        }
    }

    public void sendAgentInviteEmail(String toEmail, String agentName, String propertyTitle, String referenceCode) {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            log.warn("Cannot send agent invite email: toEmail is empty");
            return;
        }
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(toEmail.trim());
            message.setSubject("kiraZ - Emlakçı Yetkilendirme Daveti");
            message.setText("Merhaba " + (agentName != null ? agentName : "Değerli Emlak Danışmanı") + ",\n\n" +
                    (propertyTitle != null ? propertyTitle : "Taşınmaz") + " mülkü için ev sahibi sizi emlakçı olarak yetkilendirdi.\n\n" +
                    "Sisteme kayıt olurken aşağıdaki Referans Kodunu (Davet Kodu) kullanarak hesabınızı oluşturabilir ve yetkilendirildiğiniz mülkleri yönetebilirsiniz:\n\n" +
                    "Referans Kodu: " + referenceCode + "\n\n" +
                    "kiraZ Ailesi");
            mailSender.send(message);
            log.info("Agent invite email sent successfully to {}", toEmail);
        } catch (Exception e) {
            log.error("Failed to send agent invite email to {}", toEmail, e);
        }
    }

    public void sendNotificationEmail(String toEmail, String subject, String body) {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            return;
        }
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(toEmail.trim());
            message.setSubject(subject);
            message.setText(body);
            mailSender.send(message);
            log.info("Notification email sent successfully to {}", toEmail);
        } catch (Exception e) {
            log.warn("Failed to send notification email to {}: {}", toEmail, e.getMessage());
        }
    }
}
