package com.ars.kirazbackend.config;

import org.mockito.Mockito;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.mail.javamail.JavaMailSender;

/**
 * Test profilinde gerçek hiçbir SMTP sunucusuna bağlanılmamasını garanti eder.
 * JavaMailSender bean'i Mockito mock'u olarak sağlanır; böylece testler sırasında
 * dış dünyaya veya yerel SMTP portlarına hiçbir ağ soketi açılmaz.
 */
@Configuration
@Profile("test")
public class TestMailConfig {

    @Bean
    @Primary
    public JavaMailSender javaMailSender() {
        return Mockito.mock(JavaMailSender.class);
    }
}
