package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.Notification;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
@Tag(name = "Notifications", description = "Bildirim yönetimi uçları")
public class NotificationController {

    private final NotificationService notificationService;
    private final AccessControlService authz;

    /**
     * Kullanıcının okunmamış bildirimlerini döner (Deprecated - yerine GET /api/notifications/unread kullanın).
     */
    @Deprecated
    @GetMapping
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Okunmamış bildirimler (Deprecated - yerine GET /api/notifications/unread kullanın)", deprecated = true)
    public ResponseEntity<List<Notification>> getUnreadNotifications() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kullanıcı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(notificationService.getUnreadNotifications(user.getId()));
    }

    /**
     * Kullanıcının okunmamış bildirimlerini döner (Kanonik uç).
     */
    @GetMapping("/unread")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Okunmamış bildirimleri listele (Kanonik)")
    public ResponseEntity<List<Notification>> getUnreadNotificationsExplicit() {
        return getUnreadNotifications();
    }

    /**
     * Kullanıcının tüm bildirim geçmişini döner (Kanonik uç).
     */
    @GetMapping("/all")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Tüm bildirim geçmişini listele (Kanonik)")
    public ResponseEntity<List<Notification>> getAllNotifications() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kullanıcı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(notificationService.getAllNotifications(user.getId()));
    }

    /**
     * Bildirimi okundu olarak işaretler (Kanonik uç). Yalnızca bildirimin sahibi işaretleyebilir.
     */
    @PutMapping("/{id}/read")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Bildirimi okundu olarak işaretle (Kanonik)")
    public ResponseEntity<Notification> markAsRead(@PathVariable Long id) {
        authz.checkCanAccessNotification(id);
        return ResponseEntity.ok(notificationService.markAsRead(id));
    }
}
