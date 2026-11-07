package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.AuditLog;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuditLogService {

    private final AuditLogRepository auditLogRepository;

    @Transactional
    public AuditLog record(String entityName, Long entityId, String action, User performedBy, String details) {
        log.info("Audit log: action='{}', entity='{}', entityId='{}', user='{}'",
                action, entityName, entityId, performedBy != null ? performedBy.getEmail() : "SYSTEM");

        AuditLog auditLog = AuditLog.builder()
                .entityName(entityName)
                .entityId(entityId)
                .action(action)
                .performedBy(performedBy)
                .performedByRole(performedBy != null ? performedBy.getRole() : null)
                .details(details)
                .build();

        return auditLogRepository.save(auditLog);
    }

    public List<AuditLog> getLogsForEntity(String entityName, Long entityId) {
        return auditLogRepository.findByEntityNameAndEntityIdOrderByCreatedAtDesc(entityName, entityId);
    }

    public List<AuditLog> getLogsForUser(Long userId) {
        return auditLogRepository.findByPerformedByIdOrderByCreatedAtDesc(userId);
    }
}
