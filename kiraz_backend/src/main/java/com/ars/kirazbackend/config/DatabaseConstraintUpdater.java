package com.ars.kirazbackend.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@Order(1)
@RequiredArgsConstructor
public class DatabaseConstraintUpdater implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        updateUsersRoleCheckConstraint();
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onApplicationReady() {
        updateUsersRoleCheckConstraint();
    }

    /**
     * PostgreSQL 'users' tablosunda Hibernate tarafından otomatik oluşturulmuş
     * 'users_role_check' constraint'ini düşürür ve 'AGENT' rolünü de kapsayacak
     * şekilde günceller.
     */
    public void updateUsersRoleCheckConstraint() {
        try {
            log.info("[DatabaseConstraintUpdater] 'users_role_check' kısıtlaması güncelleniyor...");
            // Önce varsa eski kısıtlamayı kaldır
            jdbcTemplate.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;");

            // AGENT rolünü de kapsayacak şekilde yeni kısıtlamayı ekle
            jdbcTemplate.execute("ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('LANDLORD', 'TENANT', 'AGENT'));");
            log.info("[DatabaseConstraintUpdater] 'users_role_check' kısıtlaması 'AGENT' rolünü içerecek şekilde başarıyla güncellendi.");
        } catch (Exception e) {
            log.warn("[DatabaseConstraintUpdater] Kısıtlama güncellenirken not/uyarı alındı: {}", e.getMessage());
            try {
                // Eğer ekleme syntax/diyalekt farkından hata verirse en azından DROP edilmiş olmasını garantiye al
                jdbcTemplate.execute("ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;");
                log.info("[DatabaseConstraintUpdater] 'users_role_check' kısıtlaması başarıyla kaldırıldı (DROP).");
            } catch (Exception ex) {
                log.warn("[DatabaseConstraintUpdater] 'users_role_check' kaldırılamadı (tablo henüz oluşmamış veya farklı DB olabilir): {}", ex.getMessage());
            }
        }

        // Kira dönemleri için olası enum constraint kontrolü
        try {
            jdbcTemplate.execute("ALTER TABLE rent_periods DROP CONSTRAINT IF EXISTS rent_periods_status_check;");
        } catch (Exception ignored) {
        }
    }
}
