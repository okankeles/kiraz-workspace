package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.*;
import com.ars.kirazbackend.enums.DelegationStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.exception.ResourceNotFoundException;
import com.ars.kirazbackend.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Slf4j
@Component("authz")
@RequiredArgsConstructor
public class AccessControlService {

    private final PropertyRepository propertyRepository;
    private final LeaseAgreementRepository leaseAgreementRepository;
    private final RentPeriodRepository rentPeriodRepository;
    private final PropertyDelegationRepository propertyDelegationRepository;
    private final NotificationRepository notificationRepository;

    public User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof User user) {
            return user;
        }
        return null;
    }

    public Long getCurrentUserId() {
        User user = getCurrentUser();
        return user != null ? user.getId() : null;
    }

    // ==========================================
    // Property Permissions
    // ==========================================

    @Transactional(readOnly = true)
    public boolean canViewProperty(Long propertyId) {
        User user = getCurrentUser();
        if (user == null || propertyId == null) {
            return false;
        }

        Property property = propertyRepository.findById(propertyId).orElse(null);
        if (property == null) {
            return false;
        }

        // 1. Ev sahibi: Kendi mülkü
        if (property.getLandlord() != null && property.getLandlord().getId().equals(user.getId())) {
            return true;
        }

        // 2. Emlakçı: Aktif ve geçerli vekalet
        if (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER) {
            return hasActiveDelegation(propertyId, user.getId());
        }

        // 3. Kiracı: Bu mülke ait aktif veya bekleyen sözleşmesi varsa
        if (user.getRole() == RoleType.TENANT) {
            List<LeaseAgreement> leases = leaseAgreementRepository.findByPropertyId(propertyId);
            return leases.stream().anyMatch(l -> l.getTenant() != null && l.getTenant().getId().equals(user.getId()));
        }

        return false;
    }

    public void checkCanViewProperty(Long propertyId) {
        if (!canViewProperty(propertyId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + propertyId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canManageProperty(Long propertyId) {
        User user = getCurrentUser();
        if (user == null || propertyId == null) {
            return false;
        }

        Property property = propertyRepository.findById(propertyId).orElse(null);
        if (property == null) {
            return false;
        }

        // Ev sahibi kendi mülkünü yönetebilir
        if (property.getLandlord() != null && property.getLandlord().getId().equals(user.getId())) {
            return true;
        }

        // Aktif vekaleti olan emlakçı mülk üzerinde işlem yapabilir
        if (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER) {
            return hasActiveDelegation(propertyId, user.getId());
        }

        return false;
    }

    public void checkCanManageProperty(Long propertyId) {
        if (!canManageProperty(propertyId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + propertyId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canAssignDelegation(Long propertyId) {
        User user = getCurrentUser();
        if (user == null || propertyId == null) {
            return false;
        }
        Property property = propertyRepository.findById(propertyId).orElse(null);
        if (property == null) {
            return false;
        }
        // Yalnızca mülk sahibi vekalet atayabilir
        return property.getLandlord() != null && property.getLandlord().getId().equals(user.getId());
    }

    public void checkCanAssignDelegation(Long propertyId) {
        if (!canAssignDelegation(propertyId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + propertyId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canUpdateProperty(Long propertyId) {
        User user = getCurrentUser();
        if (user == null || propertyId == null) {
            return false;
        }
        Property property = propertyRepository.findById(propertyId).orElse(null);
        if (property == null) {
            return false;
        }
        // Yalnızca mülkün sahibi olan ev sahibi güncelleyebilir
        return user.getRole() == RoleType.LANDLORD
                && property.getLandlord() != null
                && property.getLandlord().getId().equals(user.getId());
    }

    public void checkCanUpdateProperty(Long propertyId) {
        if (!canUpdateProperty(propertyId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + propertyId);
        }
    }

    // ==========================================
    // Lease Permissions
    // ==========================================

    @Transactional(readOnly = true)
    public boolean canViewLease(Long leaseId) {
        User user = getCurrentUser();
        if (user == null || leaseId == null) {
            return false;
        }

        LeaseAgreement lease = leaseAgreementRepository.findById(leaseId).orElse(null);
        if (lease == null) {
            return false;
        }

        // 1. Ev Sahibi: Mülkün sahibi
        if (lease.getProperty() != null && lease.getProperty().getLandlord() != null
                && lease.getProperty().getLandlord().getId().equals(user.getId())) {
            return true;
        }

        // 2. Kiracı: Sözleşmedeki kiracı
        if (lease.getTenant() != null && lease.getTenant().getId().equals(user.getId())) {
            return true;
        }

        // 3. Emlakçı: Mülk üzerinde aktif vekalet
        if (lease.getProperty() != null && (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER)) {
            return hasActiveDelegation(lease.getProperty().getId(), user.getId());
        }

        return false;
    }

    public void checkCanViewLease(Long leaseId) {
        if (!canViewLease(leaseId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + leaseId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canApproveOrRejectLease(Long leaseId) {
        User user = getCurrentUser();
        if (user == null || leaseId == null) {
            return false;
        }

        LeaseAgreement lease = leaseAgreementRepository.findById(leaseId).orElse(null);
        if (lease == null) {
            return false;
        }

        // Yalnızca mülkün ev sahibi onaylayabilir veya reddedebilir
        return lease.getProperty() != null && lease.getProperty().getLandlord() != null
                && lease.getProperty().getLandlord().getId().equals(user.getId());
    }

    public void checkCanApproveOrRejectLease(Long leaseId) {
        if (!canApproveOrRejectLease(leaseId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + leaseId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canLandlordManageLease(Long leaseId) {
        return canApproveOrRejectLease(leaseId);
    }

    public void checkCanLandlordManageLease(Long leaseId) {
        if (!canLandlordManageLease(leaseId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + leaseId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canUploadContract(Long leaseId) {
        User user = getCurrentUser();
        if (user == null || leaseId == null) {
            return false;
        }

        LeaseAgreement lease = leaseAgreementRepository.findById(leaseId).orElse(null);
        if (lease == null) {
            return false;
        }

        if (lease.getProperty() != null && lease.getProperty().getLandlord() != null
                && lease.getProperty().getLandlord().getId().equals(user.getId())) {
            return true;
        }

        if (lease.getProperty() != null && (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER)) {
            return hasActiveDelegation(lease.getProperty().getId(), user.getId());
        }

        return false;
    }

    public void checkCanUploadContract(Long leaseId) {
        if (!canUploadContract(leaseId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + leaseId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canActivateLease(Long leaseId) {
        User user = getCurrentUser();
        if (user == null || leaseId == null) {
            return false;
        }

        LeaseAgreement lease = leaseAgreementRepository.findById(leaseId).orElse(null);
        if (lease == null) {
            return false;
        }

        // Kiracı veya ev sahibi
        boolean isTenant = lease.getTenant() != null && lease.getTenant().getId().equals(user.getId());
        boolean isLandlord = lease.getProperty() != null && lease.getProperty().getLandlord() != null
                && lease.getProperty().getLandlord().getId().equals(user.getId());

        return isTenant || isLandlord;
    }

    public void checkCanActivateLease(Long leaseId) {
        if (!canActivateLease(leaseId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + leaseId);
        }
    }

    // ==========================================
    // RentPeriod Permissions
    // ==========================================

    @Transactional(readOnly = true)
    public boolean canViewPeriod(Long periodId) {
        User user = getCurrentUser();
        if (user == null || periodId == null) {
            return false;
        }

        RentPeriod period = rentPeriodRepository.findById(periodId).orElse(null);
        if (period == null || period.getLeaseAgreement() == null) {
            return false;
        }

        LeaseAgreement lease = period.getLeaseAgreement();

        // 1. Ev sahibi
        if (lease.getProperty() != null && lease.getProperty().getLandlord() != null
                && lease.getProperty().getLandlord().getId().equals(user.getId())) {
            return true;
        }

        // 2. Kiracı
        if (lease.getTenant() != null && lease.getTenant().getId().equals(user.getId())) {
            return true;
        }

        // 3. Emlakçı
        if (lease.getProperty() != null && (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER)) {
            return hasActiveDelegation(lease.getProperty().getId(), user.getId());
        }

        return false;
    }

    public void checkCanViewPeriod(Long periodId) {
        if (!canViewPeriod(periodId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + periodId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canPayPeriod(Long periodId) {
        User user = getCurrentUser();
        if (user == null || periodId == null) {
            return false;
        }

        RentPeriod period = rentPeriodRepository.findById(periodId).orElse(null);
        if (period == null || period.getLeaseAgreement() == null) {
            return false;
        }

        // Yalnızca o dönemin sözleşmesine kayıtlı kiracı ödeme yapabilir
        LeaseAgreement lease = period.getLeaseAgreement();
        return lease.getTenant() != null && lease.getTenant().getId().equals(user.getId());
    }

    public void checkCanPayPeriod(Long periodId) {
        if (!canPayPeriod(periodId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + periodId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canUploadReceipt(Long periodId) {
        // Dekont yükleme yetkisi ödeme yetkisiyle aynıdır: Yalnızca kiracı
        return canPayPeriod(periodId);
    }

    public void checkCanUploadReceipt(Long periodId) {
        if (!canUploadReceipt(periodId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + periodId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canReviewReceipt(Long periodId) {
        User user = getCurrentUser();
        if (user == null || periodId == null) {
            return false;
        }

        RentPeriod period = rentPeriodRepository.findById(periodId).orElse(null);
        if (period == null || period.getLeaseAgreement() == null) {
            return false;
        }

        LeaseAgreement lease = period.getLeaseAgreement();
        // Dekont onay/red yalnızca mülkün ev sahibi tarafından yapılır
        return lease.getProperty() != null && lease.getProperty().getLandlord() != null
                && lease.getProperty().getLandlord().getId().equals(user.getId());
    }

    public void checkCanReviewReceipt(Long periodId) {
        if (!canReviewReceipt(periodId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + periodId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canInitiateLegalProcess(Long periodId) {
        User user = getCurrentUser();
        if (user == null || periodId == null) {
            return false;
        }

        RentPeriod period = rentPeriodRepository.findById(periodId).orElse(null);
        if (period == null || period.getLeaseAgreement() == null) {
            return false;
        }

        LeaseAgreement lease = period.getLeaseAgreement();
        if (lease.getProperty() == null) {
            return false;
        }

        // Ev sahibi
        if (lease.getProperty().getLandlord() != null && lease.getProperty().getLandlord().getId().equals(user.getId())) {
            return true;
        }

        // Emlakçı: Aktif vekalet
        if (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER) {
            return hasActiveDelegation(lease.getProperty().getId(), user.getId());
        }

        return false;
    }

    public void checkCanInitiateLegalProcess(Long periodId) {
        if (!canInitiateLegalProcess(periodId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + periodId);
        }
    }

    // ==========================================
    // Delegation Permissions
    // ==========================================

    @Transactional(readOnly = true)
    public boolean canViewDelegation(Long delegationId) {
        User user = getCurrentUser();
        if (user == null || delegationId == null) {
            return false;
        }

        PropertyDelegation delegation = propertyDelegationRepository.findById(delegationId).orElse(null);
        if (delegation == null) {
            return false;
        }

        // Ev Sahibi (veren veya mülk sahibi)
        boolean isLandlord = (delegation.getGrantedBy() != null && delegation.getGrantedBy().getId().equals(user.getId())) ||
                (delegation.getProperty() != null && delegation.getProperty().getLandlord() != null &&
                        delegation.getProperty().getLandlord().getId().equals(user.getId()));

        // Emlakçı (atanan)
        boolean isAgent = delegation.getAgent() != null && delegation.getAgent().getId().equals(user.getId());

        return isLandlord || isAgent;
    }

    public void checkCanViewDelegation(Long delegationId) {
        if (!canViewDelegation(delegationId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + delegationId);
        }
    }

    @Transactional(readOnly = true)
    public boolean canRevokeDelegation(Long delegationId) {
        User user = getCurrentUser();
        if (user == null || delegationId == null) {
            return false;
        }

        PropertyDelegation delegation = propertyDelegationRepository.findById(delegationId).orElse(null);
        if (delegation == null) {
            return false;
        }

        // Yalnızca mülk sahibi ev sahibi vekaleti iptal edebilir
        return delegation.getProperty() != null && delegation.getProperty().getLandlord() != null
                && delegation.getProperty().getLandlord().getId().equals(user.getId());
    }

    public void checkCanRevokeDelegation(Long delegationId) {
        if (!canRevokeDelegation(delegationId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + delegationId);
        }
    }

    // ==========================================
    // Notification Permissions
    // ==========================================

    @Transactional(readOnly = true)
    public boolean canAccessNotification(Long notificationId) {
        User user = getCurrentUser();
        if (user == null || notificationId == null) {
            return false;
        }

        Notification notification = notificationRepository.findById(notificationId).orElse(null);
        if (notification == null) {
            return false;
        }

        return notification.getUserId() != null && notification.getUserId().equals(user.getId());
    }

    public void checkCanAccessNotification(Long notificationId) {
        if (!canAccessNotification(notificationId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + notificationId);
        }
    }

    // ==========================================
    // Audit Log Permissions
    // ==========================================

    @Transactional(readOnly = true)
    public boolean canViewEntityAuditLogs(String entityName, Long entityId) {
        if (entityName == null || entityId == null) {
            return false;
        }

        String normalized = entityName.trim().toUpperCase();
        return switch (normalized) {
            case "PROPERTY" -> canViewProperty(entityId);
            case "LEASE_AGREEMENT", "LEASE" -> canViewLease(entityId);
            case "RENT_PERIOD", "PERIOD" -> canViewPeriod(entityId);
            case "PROPERTY_DELEGATION", "DELEGATION" -> canViewDelegation(entityId);
            default -> false;
        };
    }

    public void checkCanViewEntityAuditLogs(String entityName, Long entityId) {
        if (!canViewEntityAuditLogs(entityName, entityId)) {
            throw new ResourceNotFoundException("Kaynak bulunamadı: " + entityId);
        }
    }

    // ==========================================
    // Internal Delegation Helper
    // ==========================================

    private boolean hasActiveDelegation(Long propertyId, Long agentId) {
        if (propertyId == null || agentId == null) {
            return false;
        }

        List<PropertyDelegation> delegations = propertyDelegationRepository.findByAgentIdAndStatus(agentId, DelegationStatus.ACTIVE);
        LocalDate today = LocalDate.now();

        for (PropertyDelegation del : delegations) {
            if (del.getProperty() != null && del.getProperty().getId().equals(propertyId)) {
                if (del.getEndDate() != null && del.getEndDate().isBefore(today)) {
                    return false;
                }
                if (del.getStartDate() != null && del.getStartDate().isAfter(today)) {
                    return false;
                }
                if (del.getRevokedAt() != null) {
                    return false;
                }
                return true;
            }
        }
        return false;
    }
}
