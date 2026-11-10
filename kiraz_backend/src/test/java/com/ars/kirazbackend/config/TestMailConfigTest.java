package com.ars.kirazbackend.config;

import com.ars.kirazbackend.service.EmailService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;

@SpringBootTest
@ActiveProfiles("test")
public class TestMailConfigTest {

    @Autowired
    private JavaMailSender javaMailSender;

    @Autowired
    private EmailService emailService;

    @Test
    @DisplayName("Test profilinde JavaMailSender Mockito mock'udur; gerçek SMTP bağlantısı açılmaz")
    void testProfileUsesMockJavaMailSender() {
        // 1. Bean'in bir Mockito mock'u olduğu doğrulanır
        assertTrue(Mockito.mockingDetails(javaMailSender).isMock(),
                "Test profilinde JavaMailSender bir Mockito mock nesnesi olmalıdır");

        // 2. EmailService üzerinden e-posta gönderimi çağrıldığında hiçbir gerçek SMTP'ye bağlanılmaz
        assertDoesNotThrow(() -> {
            emailService.sendTenantInviteEmail("tenant@example.com", "Test Tenant", "Kadıköy Daire", "INV-999");
        });

        // 3. Mock üzerinden send metodunun çağrıldığı doğrulanır
        verify(javaMailSender).send(any(SimpleMailMessage.class));
    }
}
