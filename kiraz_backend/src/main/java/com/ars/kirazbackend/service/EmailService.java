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
}
