package com.ars.kirazbackend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web MVC yapılandırması.
 * Güvenlik gerekçesiyle /uploads/** statik erişimi kaldırılmıştır; tüm dosyalar
 * kaynak bazlı yetkilendirilmiş API uçları (/api/files/...) üzerinden sunulmaktadır.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {
    // Statik dosya sunumu devre dışı bırakıldı.
}
