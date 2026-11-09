package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.Notification;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;
    private final AccessControlService authz;

    /**
     * Kullanıcının okunmamış bildirimlerini döner. Kimlik token'dan alınır.
     */
    @GetMapping
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<List<Notification>> getUnreadNotifications() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kullanıcı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(notificationService.getUnreadNotifications(user.getId()));
    }

    /**
     * Kullanıcının okunmamış bildirimlerini döner (alternatif açık yol).
     */
    @GetMapping("/unread")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<List<Notification>> getUnreadNotificationsExplicit() {
        return getUnreadNotifications();
    }

    /**
     * Kullanıcının tüm bildirim geçmişini döner. Kimlik token'dan alınır.
     */
    @GetMapping("/all")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<List<Notification>> getAllNotifications() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new RuntimeException("Kullanıcı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(notificationService.getAllNotifications(user.getId()));
    }

    /**
     * Bildirimi okundu olarak işaretler. Yalnızca bildirimin sahibi işaretleyebilir.
     */
    @PutMapping("/{id}/read")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Notification> markAsRead(@PathVariable Long id) {
        authz.checkCanAccessNotification(id);
        return ResponseEntity.ok(notificationService.markAsRead(id));
    }
}
