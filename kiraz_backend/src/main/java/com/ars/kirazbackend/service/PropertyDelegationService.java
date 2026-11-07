package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.PropertyDelegationRequest;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.DelegationStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.PropertyDelegationRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PropertyDelegationService {

    private final PropertyDelegationRepository delegationRepository;
    private final PropertyRepository propertyRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final AuditLogService auditLogService;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    @Transactional
    public PropertyDelegation assignAgent(PropertyDelegationRequest request) {
        Property property = propertyRepository.findById(request.getPropertyId())
                .orElseThrow(() -> new RuntimeException("Mülk bulunamadı: " + request.getPropertyId()));

        User agent;
        String agentEmail = request.getAgentEmail() != null ? request.getAgentEmail().trim() : null;

        if (request.getAgentId() != null) {
            agent = userRepository.findById(request.getAgentId())
                    .orElseThrow(() -> new RuntimeException("Emlakçı bulunamadı: " + request.getAgentId()));
            if (agent.getRole() != RoleType.AGENT) {
                throw new RuntimeException("Seçilen kullanıcı bir emlakçı (AGENT) rolüne sahip değil!");
            }
        } else if (agentEmail != null && !agentEmail.isEmpty()) {
            Optional<User> existingUserOpt = userRepository.findByEmail(agentEmail);
            if (existingUserOpt.isPresent()) {
                agent = existingUserOpt.get();
                if (agent.getRole() != RoleType.AGENT) {
                    throw new RuntimeException("Bu e-posta adresine sahip kullanıcı bir emlakçı (AGENT) değil!");
                }
                if (agent.getReferenceCode() == null || agent.getReferenceCode().trim().isEmpty()) {
                    agent.setReferenceCode(generateUniqueAgentReferenceCode());
                    agent = userRepository.save(agent);
                }
            } else {
                // Kayıtlı olmayan emlakçı için davet/referans kodlu placeholder User oluştur
                String refCode = generateUniqueAgentReferenceCode();
                String agentName = (request.getAgentName() != null && !request.getAgentName().trim().isEmpty())
                        ? request.getAgentName().trim()
                        : "Emlakçı";

                User newAgent = User.builder()
                        .email(agentEmail)
                        .fullName(agentName)
                        .role(RoleType.AGENT)
                        .referenceCode(refCode)
                        .passwordHash(passwordEncoder.encode(UUID.randomUUID().toString()))
                        .build();

                agent = userRepository.save(newAgent);
                log.info("Sistemde bulunmayan emlakçı için placeholder kullanıcı oluşturuldu: email={}, referenceCode={}", agentEmail, refCode);

                // Davet e-postası gönder
                emailService.sendAgentInviteEmail(agentEmail, agentName, property.getTitle(), refCode);
            }
        } else {
            throw new RuntimeException("Emlakçı ID veya E-posta adresi belirtilmelidir!");
        }

        Long landlordId = request.getLandlordId() != null
                ? request.getLandlordId()
                : property.getLandlord().getId();

        User landlord = userRepository.findById(landlordId)
                .orElseThrow(() -> new RuntimeException("Ev sahibi bulunamadı: " + landlordId));

        if (!property.getLandlord().getId().equals(landlord.getId())) {
            throw new RuntimeException("Yalnızca mülk sahibi emlakçı vekaleti verebilir!");
        }

        // Tarihçe koruma: Mevcut aktif vekaletleri ezmeden statüsünü REVOKED yap
        List<PropertyDelegation> existingActiveList = delegationRepository.findByPropertyIdAndStatus(
                property.getId(), DelegationStatus.ACTIVE
        );

        for (PropertyDelegation existing : existingActiveList) {
            if (existing.getAgent().getId().equals(agent.getId())) {
                existing.setStatus(DelegationStatus.REVOKED);
                existing.setRevokedAt(LocalDateTime.now());
                existing.setRevocationReason("Vekalet yenilendi veya güncellendi");
            } else {
                existing.setStatus(DelegationStatus.REVOKED);
                existing.setRevokedAt(LocalDateTime.now());
                existing.setRevocationReason("Yeni emlakçı (" + agent.getFullName() + ") atandı");
            }
            delegationRepository.save(existing);
            auditLogService.record(
                    "PROPERTY_DELEGATION",
                    existing.getId(),
                    "DELEGATION_REVOKED_FOR_NEW_ASSIGNMENT",
                    landlord,
                    "Eski vekalet statüsü REVOKED olarak güncellendi. Tarihçe korundu."
            );
        }

        LocalDate start = request.getStartDate() != null ? request.getStartDate() : LocalDate.now();

        PropertyDelegation delegation = PropertyDelegation.builder()
                .property(property)
                .agent(agent)
                .grantedBy(landlord)
                .status(DelegationStatus.ACTIVE)
                .startDate(start)
                .endDate(request.getEndDate())
                .build();

        PropertyDelegation saved = delegationRepository.save(delegation);

        auditLogService.record(
                "PROPERTY_DELEGATION",
                saved.getId(),
                "DELEGATION_ASSIGNED",
                landlord,
                String.format("Emlakçı %s (%s), '%s' mülkü için yetkilendirildi.",
                        agent.getFullName(), agent.getEmail(), property.getTitle())
        );

        notificationService.createNotification(
                agent.getId(),
                "Yeni Mülk Yetkilendirmesi",
                String.format("'%s' mülkü için emlakçı olarak yetkilendirildiniz.", property.getTitle()),
                "DELEGATION",
                saved.getId()
        );

        return saved;
    }

    @Transactional
    public PropertyDelegation revokeDelegation(Long delegationId, Long landlordId, String reason) {
        PropertyDelegation delegation = delegationRepository.findById(delegationId)
                .orElseThrow(() -> new RuntimeException("Vekalet kaydı bulunamadı: " + delegationId));

        if (landlordId != null && !delegation.getProperty().getLandlord().getId().equals(landlordId)) {
            throw new RuntimeException("Yalnızca mülk sahibi vekaleti iptal edebilir!");
        }

        if (delegation.getStatus() != DelegationStatus.ACTIVE) {
            return delegation;
        }

        delegation.setStatus(DelegationStatus.REVOKED);
        delegation.setRevokedAt(LocalDateTime.now());
        delegation.setRevocationReason(reason != null && !reason.trim().isEmpty() ? reason.trim() : "Ev sahibi tarafından vekalet sonlandırıldı");

        PropertyDelegation saved = delegationRepository.save(delegation);

        User landlord = delegation.getGrantedBy();
        auditLogService.record(
                "PROPERTY_DELEGATION",
                saved.getId(),
                "DELEGATION_REVOKED",
                landlord,
                String.format("'%s' mülkünün vekaleti iptal edildi. Sebep: %s",
                        delegation.getProperty().getTitle(), delegation.getRevocationReason())
        );

        notificationService.createNotification(
                delegation.getAgent().getId(),
                "Mülk Yetkisi İptal Edildi",
                String.format("'%s' mülkü üzerindeki vekaletiniz sonlandırıldı.", delegation.getProperty().getTitle()),
                "DELEGATION_REVOKED",
                saved.getId()
        );

        return saved;
    }

    @Transactional
    public List<PropertyDelegation> revokeDelegationsForProperty(Long propertyId, Long landlordId, String reason) {
        List<PropertyDelegation> activeList = delegationRepository.findByPropertyIdAndStatus(propertyId, DelegationStatus.ACTIVE);
        List<PropertyDelegation> revokedList = new ArrayList<>();
        for (PropertyDelegation delegation : activeList) {
            revokedList.add(revokeDelegation(delegation.getId(), landlordId, reason));
        }
        return revokedList;
    }

    @Transactional
    public boolean hasActiveDelegation(Long propertyId, Long agentId) {
        if (propertyId == null || agentId == null) {
            return false;
        }

        List<PropertyDelegation> delegations = delegationRepository.findByAgentIdAndStatus(agentId, DelegationStatus.ACTIVE);
        LocalDate today = LocalDate.now();

        for (PropertyDelegation del : delegations) {
            if (del.getProperty().getId().equals(propertyId)) {
                // Check if expired
                if (del.getEndDate() != null && del.getEndDate().isBefore(today)) {
                    del.setStatus(DelegationStatus.EXPIRED);
                    delegationRepository.save(del);
                    auditLogService.record(
                            "PROPERTY_DELEGATION",
                            del.getId(),
                            "DELEGATION_EXPIRED",
                            null,
                            "Vekalet süresi dolduğu için otomatik olarak EXPIRED statüsüne çekildi."
                    );
                    return false;
                }
                return true;
            }
        }
        return false;
    }

    public List<PropertyDelegation> getDelegationsForProperty(Long propertyId) {
        return delegationRepository.findByPropertyIdOrderByCreatedAtDesc(propertyId);
    }

    @Transactional
    public List<PropertyDelegation> getActiveDelegationsForAgent(Long agentId) {
        List<PropertyDelegation> list = delegationRepository.findByAgentIdAndStatus(agentId, DelegationStatus.ACTIVE);
        LocalDate today = LocalDate.now();
        List<PropertyDelegation> activeValid = new ArrayList<>();

        for (PropertyDelegation del : list) {
            if (del.getEndDate() != null && del.getEndDate().isBefore(today)) {
                del.setStatus(DelegationStatus.EXPIRED);
                delegationRepository.save(del);
            } else {
                activeValid.add(del);
            }
        }
        return activeValid;
    }

    public List<PropertyDelegation> getDelegationHistoryForAgent(Long agentId) {
        return delegationRepository.findByAgentIdOrderByCreatedAtDesc(agentId);
    }

    public List<PropertyDelegation> getDelegationsGrantedBy(Long landlordId) {
        return delegationRepository.findByGrantedByIdOrderByCreatedAtDesc(landlordId);
    }

    private String generateUniqueAgentReferenceCode() {
        String code;
        do {
            code = "AGT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        } while (userRepository.findByReferenceCode(code).isPresent());
        return code;
    }
}
