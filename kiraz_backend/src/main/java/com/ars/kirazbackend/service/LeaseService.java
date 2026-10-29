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

        LeaseAgreement lease = LeaseAgreement.builder()
                .property(property)
                .tenant(tenant)
                .startDate(start)
                .endDate(end)
                .monthlyRentAmount(rentAmount)
                .depositAmount(request.getDepositAmount())
                .paymentDay(paymentDay)
                .status(LeaseStatus.PENDING)
                .inviteCode(inviteCode)
                .contractFileUrl(request.getContractFileUrl())
                .build();
        LeaseAgreement savedLease = leaseRepository.save(lease);

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
        LeaseAgreement lease = leaseRepository.findById(leaseId)
                .orElseThrow(() -> new RuntimeException("Sözleşme bulunamadı: " + leaseId));

        String fileUrl = fileStorageService.storeFile(file);
        lease.setContractFileUrl(fileUrl);
        return leaseRepository.save(lease);
    }
}
