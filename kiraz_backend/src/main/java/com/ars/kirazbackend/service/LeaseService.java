package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.LeaseRequest;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.LeaseStatus;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import com.ars.kirazbackend.enums.LeaseApprovalStatus;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class LeaseService {
    private final LeaseAgreementRepository leaseRepository;
    private final PropertyRepository propertyRepository;
    private final UserRepository userRepository;
    private final RentPeriodRepository rentPeriodRepository;
    private final PasswordEncoder passwordEncoder;
    private final NotificationService notificationService;
    private final FileStorageService fileStorageService;
    private final EmailService emailService;
    private final PropertyDelegationService propertyDelegationService;
    private final AuditLogService auditLogService;

    @Transactional
    public LeaseAgreement createLease(LeaseRequest request) {
        Property property = propertyRepository.findById(request.getPropertyId())
                .orElseThrow(() -> new RuntimeException("Property not found"));

        User tenant;
        if (request.getTenantEmail() != null && !request.getTenantEmail().trim().isEmpty()) {
            String email = request.getTenantEmail().trim();
            tenant = userRepository.findByEmail(email).orElseGet(() -> {
                String fullName = (request.getTenantName() != null && !request.getTenantName().trim().isEmpty())
                        ? request.getTenantName().trim()
                        : "Kiracı";
                User newUser = User.builder()
                        .email(email)
                        .fullName(fullName)
                        .role(RoleType.TENANT)
                        .passwordHash(passwordEncoder.encode(UUID.randomUUID().toString()))
                        .build();
                return userRepository.save(newUser);
            });
            if (tenant.getRole() != RoleType.TENANT) {
                tenant.setRole(RoleType.TENANT);
                tenant = userRepository.save(tenant);
            }
        } else if (request.getTenantId() != null) {
            tenant = userRepository.findById(request.getTenantId())
                    .orElseThrow(() -> new RuntimeException("Tenant not found"));
            if (tenant.getRole() != RoleType.TENANT) {
                tenant.setRole(RoleType.TENANT);
                tenant = userRepository.save(tenant);
            }
        } else {
            throw new RuntimeException("Tenant email or id is required");
        }

        LocalDate start;
        if (request.getStartDate() != null && !request.getStartDate().trim().isEmpty()) {
            try {
                start = LocalDate.parse(request.getStartDate().trim());
            } catch (Exception e) {
                start = LocalDate.now();
            }
        } else {
            start = LocalDate.now();
        }

        LocalDate end = request.getEndDate() != null ? request.getEndDate() : start.plusYears(1);

        BigDecimal rentAmount;
        if (request.getRentAmount() != null) {
            rentAmount = BigDecimal.valueOf(request.getRentAmount());
        } else if (request.getMonthlyRentAmount() != null) {
            rentAmount = request.getMonthlyRentAmount();
        } else {
            rentAmount = BigDecimal.ZERO;
        }

        Integer paymentDay = request.getPaymentDay() != null ? request.getPaymentDay() : start.getDayOfMonth();
        String inviteCode = "ARS-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();

        // Maker-Checker: Determine creator and approval status
        Long creatorId = request.getAgentId() != null ? request.getAgentId() : request.getCreatedById();
        User creator;
        if (creatorId != null) {
            creator = userRepository.findById(creatorId)
                    .orElseThrow(() -> new RuntimeException("Kullanıcı bulunamadı: " + creatorId));
        } else {
            org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof User) {
                creator = (User) auth.getPrincipal();
            } else {
                creator = property.getLandlord();
            }
        }

        LeaseApprovalStatus approvalStatus;
        if (creator.getRole() == RoleType.AGENT) {
            // Güvenlik ve İzin Kontrolü: Agent'ın mülk üzerinde aktif vekaleti olmalı
            if (!propertyDelegationService.hasActiveDelegation(property.getId(), creator.getId())) {
                throw new RuntimeException("Yetkisiz işlem: Bu mülk için aktif emlakçı vekaletiniz (PropertyDelegation) bulunmamaktadır!");
            }
            approvalStatus = LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL;
        } else {
            approvalStatus = LeaseApprovalStatus.ACTIVE;
        }

        LeaseAgreement lease = LeaseAgreement.builder()
                .property(property)
                .tenant(tenant)
                .startDate(start)
                .endDate(end)
                .monthlyRentAmount(rentAmount)
                .depositAmount(request.getDepositAmount())
                .paymentDay(paymentDay)
                .status(LeaseStatus.PENDING)
                .approvalStatus(approvalStatus)
                .createdBy(creator)
                .inviteCode(inviteCode)
                .contractFileUrl(request.getContractFileUrl())
                .build();
        LeaseAgreement savedLease = leaseRepository.save(lease);

        if (creator.getRole() == RoleType.AGENT) {
            notificationService.createNotification(
                    property.getLandlord().getId(),
                    "Onay Bekleyen Kira Sözleşmesi",
                    String.format("Emlakçınız %s, '%s' mülkü için yeni bir sözleşme oluşturdu ve onayınızı bekliyor.",
                            creator.getFullName(), property.getTitle()),
                    "LEASE_APPROVAL_REQUEST",
                    savedLease.getId()
            );
            auditLogService.record(
                    "LEASE_AGREEMENT",
                    savedLease.getId(),
                    "LEASE_CREATED_BY_AGENT",
                    creator,
                    String.format("Emlakçı %s tarafından sözleşme oluşturuldu, onay bekliyor.", creator.getFullName())
            );
        } else {
            auditLogService.record(
                    "LEASE_AGREEMENT",
                    savedLease.getId(),
                    "LEASE_CREATED_BY_LANDLORD",
                    creator,
                    String.format("Ev sahibi %s tarafından sözleşme oluşturuldu.", creator.getFullName())
            );
        }

        List<RentPeriod> periods = new ArrayList<>();
        LocalDate currentDate = savedLease.getStartDate();

        while (!currentDate.isAfter(savedLease.getEndDate().minusMonths(1))) {
            RentPeriod period = new RentPeriod();
            period.setLeaseAgreement(savedLease);
            period.setPeriodStart(currentDate);
            period.setMonth(currentDate.getMonthValue());
            period.setYear(currentDate.getYear());
            period.setStatus(PaymentStatus.PENDING);

            int targetDay = (savedLease.getPaymentDay() != null) ? savedLease.getPaymentDay() : currentDate.getDayOfMonth();
            int day = Math.min(targetDay, currentDate.lengthOfMonth());
            period.setPaymentDate(currentDate.withDayOfMonth(day));

            periods.add(period);
            currentDate = currentDate.plusMonths(1);
        }

        if (!periods.isEmpty()) {
            rentPeriodRepository.saveAll(periods);
        }

        emailService.sendTenantInviteEmail(request.getTenantEmail(), request.getTenantName(), property.getTitle(), inviteCode);

        return savedLease;
    }

    @Transactional
    public LeaseAgreement acceptLease(String inviteCode, String newPassword) {
        LeaseAgreement lease = leaseRepository.findByInviteCode(inviteCode)
                .orElseThrow(() -> new RuntimeException("Geçersiz davet kodu"));

        User tenant = lease.getTenant();
        if (tenant != null && newPassword != null && !newPassword.trim().isEmpty()) {
            tenant.setPasswordHash(passwordEncoder.encode(newPassword.trim()));
            userRepository.save(tenant);
        }

        return leaseRepository.save(lease);
    }

    public List<LeaseAgreement> getLeasesForProperty(Long propertyId) {
        return leaseRepository.findByPropertyId(propertyId);
    }

    public List<LeaseAgreement> getLeasesForTenant(Long tenantId) {
        return leaseRepository.findByTenantId(tenantId);
    }

    public List<LeaseAgreement> getLeasesForLandlord(Long landlordId) {
        return leaseRepository.findByPropertyLandlordId(landlordId);
    }

    @Transactional
    public LeaseAgreement activateLeaseDirectly(Long leaseId) {
        LeaseAgreement lease = leaseRepository.findById(leaseId)
                .orElseThrow(() -> new RuntimeException("Lease not found"));
        lease.setStatus(LeaseStatus.ACTIVE);
        LeaseAgreement savedLease = leaseRepository.save(lease);

        if (savedLease.getProperty() != null && savedLease.getProperty().getLandlord() != null) {
            notificationService.createNotification(
                    savedLease.getProperty().getLandlord().getId(),
                    "Sözleşme Onaylandı",
                    savedLease.getTenantName() + " adlı kiracı " + savedLease.getProperty().getTitle() + " mülkü için sözleşmeyi onayladı.",
                    "LEASE",
                    savedLease.getId()
            );
        }

        return savedLease;
    }

    public LeaseAgreement findByInviteCode(String inviteCode) {
        return leaseRepository.findByInviteCode(inviteCode)
                .orElseThrow(() -> new RuntimeException("Geçersiz davet kodu"));
    }

    public com.ars.kirazbackend.dto.InviteValidationResponse validateInvite(String inviteCode) {
        LeaseAgreement lease = findByInviteCode(inviteCode);
        String email = lease.getTenant() != null ? lease.getTenant().getEmail() : null;
        String name = lease.getTenant() != null ? lease.getTenant().getFullName() : null;
        String status = lease.getStatus() != null ? lease.getStatus().name() : null;

        return com.ars.kirazbackend.dto.InviteValidationResponse.builder()
                .tenantEmail(email)
                .tenantName(name)
                .leaseId(lease.getId())
                .status(status)
                .message("Davet kodu geçerli")
                .build();
    }

    public LeaseAgreement getLeaseById(Long id) {
        return leaseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Sözleşme bulunamadı: " + id));
    }

    @Transactional
    public LeaseAgreement uploadContract(Long leaseId, MultipartFile file) {
        return uploadContract(leaseId, file, null);
    }

    @Transactional
    public LeaseAgreement uploadContract(Long leaseId, MultipartFile file, Long userId) {
        LeaseAgreement lease = leaseRepository.findById(leaseId)
                .orElseThrow(() -> new RuntimeException("Sözleşme bulunamadı: " + leaseId));

        if (userId != null) {
            User user = userRepository.findById(userId).orElse(null);
            if (user != null && user.getRole() == RoleType.AGENT) {
                if (!propertyDelegationService.hasActiveDelegation(lease.getProperty().getId(), user.getId())) {
                    throw new RuntimeException("Yetkisiz işlem: Bu mülk için aktif vekaletiniz bulunmamaktadır!");
                }
            }
        }

        String fileUrl = fileStorageService.storeFile(file);
        lease.setContractFileUrl(fileUrl);
        return leaseRepository.save(lease);
    }

    @Transactional
    public LeaseAgreement approveLease(Long leaseId, Long landlordId) {
        LeaseAgreement lease = leaseRepository.findById(leaseId)
                .orElseThrow(() -> new RuntimeException("Sözleşme bulunamadı: " + leaseId));

        if (landlordId != null && !lease.getProperty().getLandlord().getId().equals(landlordId)) {
            throw new RuntimeException("Yalnızca mülk sahibi sözleşmeyi onaylayabilir!");
        }

        lease.setApprovalStatus(LeaseApprovalStatus.ACTIVE);
        lease.setStatus(LeaseStatus.ACTIVE);
        LeaseAgreement savedLease = leaseRepository.save(lease);

        User landlord = lease.getProperty().getLandlord();
        auditLogService.record(
                "LEASE_AGREEMENT",
                savedLease.getId(),
                "LEASE_APPROVED",
                landlord,
                String.format("Ev sahibi '%s' sözleşmeyi onayladı ve ACTIVE statüsüne çekti.", landlord.getFullName())
        );

        // Bildirim: Emlakçıya bildir
        if (lease.getCreatedBy() != null && lease.getCreatedBy().getRole() == RoleType.AGENT) {
            notificationService.createNotification(
                    lease.getCreatedBy().getId(),
                    "Sözleşme Onaylandı",
                    String.format("'%s' mülkü için hazırladığınız sözleşme ev sahibi tarafından onaylandı.",
                            lease.getProperty().getTitle()),
                    "LEASE_APPROVED",
                    savedLease.getId()
            );
        }

        // Bildirim: Kiracıya bildir
        if (lease.getTenant() != null) {
            notificationService.createNotification(
                    lease.getTenant().getId(),
                    "Kira Sözleşmeniz Onaylandı",
                    String.format("'%s' mülkü için kira sözleşmeniz ev sahibi tarafından onaylanmıştır.",
                            lease.getProperty().getTitle()),
                    "LEASE_APPROVED",
                    savedLease.getId()
            );
        }

        return savedLease;
    }

    @Transactional
    public LeaseAgreement rejectLease(Long leaseId, Long landlordId, String reason) {
        LeaseAgreement lease = leaseRepository.findById(leaseId)
                .orElseThrow(() -> new RuntimeException("Sözleşme bulunamadı: " + leaseId));

        if (landlordId != null && !lease.getProperty().getLandlord().getId().equals(landlordId)) {
            throw new RuntimeException("Yalnızca mülk sahibi sözleşmeyi reddedebilir!");
        }

        lease.setApprovalStatus(LeaseApprovalStatus.REJECTED);
        lease.setStatus(LeaseStatus.CANCELLED);
        lease.setRejectionReason(reason != null && !reason.trim().isEmpty() ? reason.trim() : "Ev sahibi tarafından reddedildi");
        LeaseAgreement savedLease = leaseRepository.save(lease);

        User landlord = lease.getProperty().getLandlord();
        auditLogService.record(
                "LEASE_AGREEMENT",
                savedLease.getId(),
                "LEASE_REJECTED",
                landlord,
                String.format("Ev sahibi sözleşmeyi reddetti. Sebep: %s", lease.getRejectionReason())
        );

        // Bildirim: Emlakçıya bildir
        if (lease.getCreatedBy() != null && lease.getCreatedBy().getRole() == RoleType.AGENT) {
            notificationService.createNotification(
                    lease.getCreatedBy().getId(),
                    "Sözleşme Reddedildi",
                    String.format("'%s' mülkü için hazırladığınız sözleşme ev sahibi tarafından reddedildi: %s",
                            lease.getProperty().getTitle(), lease.getRejectionReason()),
                    "LEASE_REJECTED",
                    savedLease.getId()
            );
        }

        return savedLease;
    }

    public List<LeaseAgreement> getPendingApprovalLeasesForLandlord(Long landlordId) {
        return leaseRepository.findByPropertyLandlordIdAndApprovalStatus(
                landlordId, LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL
        );
    }
}
