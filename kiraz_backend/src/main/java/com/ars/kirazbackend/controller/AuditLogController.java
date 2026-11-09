package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.AuditLog;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.AuditLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/audit-logs")
@RequiredArgsConstructor
public class AuditLogController {

    private final AuditLogService auditLogService;
    private final AccessControlService authz;

    @GetMapping
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER')")
    public ResponseEntity<List<AuditLog>> getLogs(
            @RequestParam String entityName,
            @RequestParam Long entityId) {
        authz.checkCanViewEntityAuditLogs(entityName, entityId);
        return ResponseEntity.ok(auditLogService.getLogsForEntity(entityName, entityId));
    }

    @GetMapping("/my-logs")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<List<AuditLog>> getMyLogs() {
        User user = authz.getCurrentUser();
        if (user == null || user.getId() == null) {
            throw new AuthenticationCredentialsNotFoundException("Kullanıcı kimliği belirlenemedi.");
        }
        return ResponseEntity.ok(auditLogService.getLogsForUser(user.getId()));
    }

    @GetMapping("/user")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    public ResponseEntity<List<AuditLog>> getUserLogs() {
        return getMyLogs();
    }
}
