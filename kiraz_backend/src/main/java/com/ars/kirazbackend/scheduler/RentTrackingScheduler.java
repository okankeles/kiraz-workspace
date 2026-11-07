package com.ars.kirazbackend.scheduler;

import com.ars.kirazbackend.service.RentPeriodService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class RentTrackingScheduler {

    private final RentPeriodService rentPeriodService;

    /**
     * Her gece yarısı (00:00:00) çalışır.
     * Vadesi geçmiş ve henüz ödenmemiş (PENDING) kira periyotlarını otomatik olarak OVERDUE statüsüne çeker.
     */
    @Scheduled(cron = "0 0 0 * * ?")
    public void trackOverdueRentPayments() {
        log.info("[RentTrackingScheduler] Gece yarısı kira gecikme taraması başlatıldı...");
        try {
            int updatedCount = rentPeriodService.markOverduePeriods();
            log.info("[RentTrackingScheduler] Tarama tamamlandı. Toplam {} adet kira dönemi OVERDUE olarak işaretlendi.", updatedCount);
        } catch (Exception e) {
            log.error("[RentTrackingScheduler] Kira gecikme taraması sırasında hata oluştu: ", e);
        }
    }
}
