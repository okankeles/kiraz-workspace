package com.ars.kirazbackend.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@Profile("dev")
@ConditionalOnProperty(name = "kiraz.dev.smtp-verify", havingValue = "true", matchIfMissing = false)
@RequiredArgsConstructor
public class DevSmtpVerifier implements CommandLineRunner {

    private final JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String smtpUsername;

    @Override
    public void run(String... args) {
        if (smtpUsername == null || smtpUsername.trim().isEmpty()) {
            log.warn("SMTP_TEST_RESULT: FAILED: smtpUsername is not configured");
            return;
        }
        log.info("Dev profile active with kiraz.dev.smtp-verify=true: sending SMTP verification test email to configured address");
        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setTo(smtpUsername.trim());
            message.setSubject("kiraZ Dev SMTP Doğrulama Testi");
            message.setText("Bu e-posta kiraZ Faz 0 Adım 2 SMTP kimlik doğrulama doğrulaması için gönderilmiştir.");
            mailSender.send(message);
            log.info("SMTP_TEST_RESULT: SUCCESS - Test email sent successfully");
        } catch (Exception e) {
            String msg = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
            // Sanitize any sensitive details from error message
            String sanitizedMsg = msg.replaceAll("(?i)(password|pwd|secret|key)=\\S+", "$1=***");
            log.error("SMTP_TEST_RESULT: FAILED - {}", sanitizedMsg);
        }
    }
}
