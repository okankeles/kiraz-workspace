package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.AuditLog;
import com.ars.kirazbackend.service.AuditLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/audit-logs")
@RequiredArgsConstructor
public class AuditLogController {

    private final AuditLogService auditLogService;

    @GetMapping
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT')")
    public ResponseEntity<List<AuditLog>> getLogs(
            @RequestParam String entityName,
            @RequestParam Long entityId) {
        return ResponseEntity.ok(auditLogService.getLogsForEntity(entityName, entityId));
    }

    @GetMapping("/user/{userId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT')")
    public ResponseEntity<List<AuditLog>> getUserLogs(@PathVariable Long userId) {
        return ResponseEntity.ok(auditLogService.getLogsForUser(userId));
    }
}
