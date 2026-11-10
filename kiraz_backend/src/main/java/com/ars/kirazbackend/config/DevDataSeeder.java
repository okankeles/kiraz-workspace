package com.ars.kirazbackend.config;

import com.ars.kirazbackend.entity.*;
import com.ars.kirazbackend.enums.*;
import com.ars.kirazbackend.repository.*;
import com.ars.kirazbackend.service.LeaseService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Geliştirme (dev) profilinde çalışan idempotent test verisi tohumlama bileşeni.
 * Dört rol (LANDLORD, TENANT, AGENT, PROPERTY_MANAGER) için kullanıcılar,
 * örnek mülkler, delegasyonlar, sözleşmeler ve kira dönemleri oluşturur.
 * Tüm test e-postaları RFC 2606 uyumlu '@example.com' alan adındadır.
 * Parolalar kodda sabit tutulmaz, doğrudan ortam değişkenlerinden okunur.
 */
@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
public class DevDataSeeder implements CommandLineRunner {

    public static final String LANDLORD_EMAIL = "dev.landlord@example.com";
    public static final String TENANT_EMAIL = "dev.tenant@example.com";
    public static final String AGENT_EMAIL = "dev.agent@example.com";
    public static final String MANAGER_EMAIL = "dev.manager@example.com";

    private final UserRepository userRepository;
    private final PropertyRepository propertyRepository;
    private final LeaseAgreementRepository leaseRepository;
    private final PropertyDelegationRepository delegationRepository;
    private final RentPeriodRepository periodRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${DEV_SEED_LANDLORD_PASSWORD}")
    private String landlordPassword;

    @Value("${DEV_SEED_TENANT_PASSWORD}")
    private String tenantPassword;

    @Value("${DEV_SEED_AGENT_PASSWORD}")
    private String agentPassword;

    @Value("${DEV_SEED_MANAGER_PASSWORD}")
    private String managerPassword;

    @Override
    @Transactional
    public void run(String... args) {
        log.info("--- [DEV PROFILE] Test Verisi Tohumlama (Data Seeding) Başlatılıyor ---");

        validateSeedPasswords();

        // 1. Kullanıcılar (@example.com)
        User landlord = getOrCreateOrUpdateUser(
                LANDLORD_EMAIL,
                "Dev Ev Sahibi",
                landlordPassword,
                "05551112233",
                RoleType.LANDLORD,
                null
        );

        User tenant = getOrCreateOrUpdateUser(
                TENANT_EMAIL,
                "Dev Kiracı",
                tenantPassword,
                "05552223344",
                RoleType.TENANT,
                null
        );

        User agent = getOrCreateOrUpdateUser(
                AGENT_EMAIL,
                "Dev Emlakçı",
                agentPassword,
                "05553334455",
                RoleType.AGENT,
                "AGT-DEV12345"
        );

        User manager = getOrCreateOrUpdateUser(
                MANAGER_EMAIL,
                "Dev Mülk Yöneticisi",
                managerPassword,
                "05554445566",
                RoleType.PROPERTY_MANAGER,
                "MGR-DEV12345"
        );

        // 2. Mülkler
        List<Property> existingProperties = propertyRepository.findByLandlordId(landlord.getId());
        Property propertyA;
        Property propertyB;

        if (existingProperties.isEmpty()) {
            propertyA = propertyRepository.save(Property.builder()
                    .title("KiraZ Kadıköy Plaza No:101")
                    .address("Moda Caddesi No:101 Kadıköy")
                    .city("İstanbul")
                    .daskEndDate(LocalDate.now().plusMonths(9))
                    .status("ACTIVE")
                    .landlord(landlord)
                    .build());
            log.info("Örnek Mülk A oluşturuldu: ID={}", propertyA.getId());

            propertyB = propertyRepository.save(Property.builder()
                    .title("KiraZ Beşiktaş Rezidans D:4")
                    .address("Sinanpaşa Mah. Şair Nedim Cad. No:24 Beşiktaş")
                    .city("İstanbul")
                    .daskEndDate(LocalDate.now().plusMonths(11))
                    .status("ACTIVE")
                    .landlord(landlord)
                    .build());
            log.info("Örnek Mülk B oluşturuldu: ID={}", propertyB.getId());
        } else {
            propertyA = existingProperties.get(0);
            propertyB = existingProperties.size() > 1 ? existingProperties.get(1) : propertyA;
        }

        // 3. Delegasyonlar (Vekaletler)
        if (!delegationRepository.existsByPropertyIdAndAgentIdAndStatus(propertyA.getId(), agent.getId(), DelegationStatus.ACTIVE)) {
            PropertyDelegation delA = delegationRepository.save(PropertyDelegation.builder()
                    .property(propertyA)
                    .agent(agent)
                    .grantedBy(landlord)
                    .status(DelegationStatus.ACTIVE)
                    .startDate(LocalDate.now().minusMonths(1))
                    .endDate(LocalDate.now().plusMonths(5))
                    .build());
            log.info("Emlakçı vekaleti oluşturuldu: ID={}, Property={}, Agent={}", delA.getId(), propertyA.getTitle(), agent.getEmail());
        }

        if (!delegationRepository.existsByPropertyIdAndAgentIdAndStatus(propertyB.getId(), manager.getId(), DelegationStatus.ACTIVE)) {
            PropertyDelegation delB = delegationRepository.save(PropertyDelegation.builder()
                    .property(propertyB)
                    .agent(manager)
                    .grantedBy(landlord)
                    .status(DelegationStatus.ACTIVE)
                    .startDate(LocalDate.now().minusMonths(1))
                    .endDate(LocalDate.now().plusMonths(5))
                    .build());
            log.info("Mülk yöneticisi vekaleti oluşturuldu: ID={}, Property={}, Manager={}", delB.getId(), propertyB.getTitle(), manager.getEmail());
        }

        // 4. Sözleşmeler ve Kira Dönemleri
        List<LeaseAgreement> leases = leaseRepository.findByPropertyId(propertyA.getId());
        if (leases.isEmpty()) {
            LeaseAgreement activeLease = leaseRepository.save(LeaseAgreement.builder()
                    .property(propertyA)
                    .tenant(tenant)
                    .createdBy(landlord)
                    .monthlyRentAmount(BigDecimal.valueOf(25000))
                    .depositAmount(BigDecimal.valueOf(50000))
                    .paymentDay(5)
                    .startDate(LocalDate.now().minusMonths(2))
                    .endDate(LocalDate.now().plusMonths(10))
                    .status(LeaseStatus.ACTIVE)
                    .approvalStatus(LeaseApprovalStatus.ACTIVE)
                    .inviteCode(LeaseService.generateInviteCode())
                    .inviteCodeExpiresAt(LocalDateTime.now().plusDays(7))
                    .inviteCodeUsed(true)
                    .inviteCodeUsedAt(LocalDateTime.now().minusMonths(2))
                    .build());
            log.info("Aktif Sözleşme oluşturuldu: ID={}, Kiracı={}", activeLease.getId(), tenant.getEmail());

            // Önceki ay (PAID)
            periodRepository.save(RentPeriod.builder()
                    .leaseAgreement(activeLease)
                    .month(LocalDate.now().minusMonths(1).getMonthValue())
                    .year(LocalDate.now().minusMonths(1).getYear())
                    .periodStart(LocalDate.now().minusMonths(1).withDayOfMonth(1))
                    .paymentDate(LocalDate.now().minusMonths(1).withDayOfMonth(5))
                    .status(PaymentStatus.PAID)
                    .build());

            // Bu ay (PENDING)
            periodRepository.save(RentPeriod.builder()
                    .leaseAgreement(activeLease)
                    .month(LocalDate.now().getMonthValue())
                    .year(LocalDate.now().getYear())
                    .periodStart(LocalDate.now().withDayOfMonth(1))
                    .status(PaymentStatus.PENDING)
                    .build());
            log.info("Kira dönemleri eklendi (Geçmiş ay PAID, Mevcut ay PENDING)");
        }

        List<LeaseAgreement> leasesB = leaseRepository.findByPropertyId(propertyB.getId());
        if (leasesB.isEmpty()) {
            LeaseAgreement pendingLease = leaseRepository.save(LeaseAgreement.builder()
                    .property(propertyB)
                    .tenant(tenant)
                    .createdBy(agent)
                    .monthlyRentAmount(BigDecimal.valueOf(32000))
                    .depositAmount(BigDecimal.valueOf(64000))
                    .paymentDay(15)
                    .startDate(LocalDate.now())
                    .endDate(LocalDate.now().plusYears(1))
                    .status(LeaseStatus.PENDING)
                    .approvalStatus(LeaseApprovalStatus.PENDING_LANDLORD_APPROVAL)
                    .inviteCode(LeaseService.generateInviteCode())
                    .inviteCodeExpiresAt(LocalDateTime.now().plusDays(7))
                    .inviteCodeUsed(false)
                    .build());
            log.info("Maker-Checker Onay Bekleyen Taslak Sözleşme oluşturuldu: ID={}", pendingLease.getId());
        }

        log.info("--- [DEV PROFILE] Test Verisi Tohumlama Tamamlandı ---");
    }

    private void validateSeedPasswords() {
        if (landlordPassword == null || landlordPassword.isBlank()) {
            throw new IllegalStateException("DEV_SEED_LANDLORD_PASSWORD ortam değişkeni boş olamaz.");
        }
        if (tenantPassword == null || tenantPassword.isBlank()) {
            throw new IllegalStateException("DEV_SEED_TENANT_PASSWORD ortam değişkeni boş olamaz.");
        }
        if (agentPassword == null || agentPassword.isBlank()) {
            throw new IllegalStateException("DEV_SEED_AGENT_PASSWORD ortam değişkeni boş olamaz.");
        }
        if (managerPassword == null || managerPassword.isBlank()) {
            throw new IllegalStateException("DEV_SEED_MANAGER_PASSWORD ortam değişkeni boş olamaz.");
        }
    }

    private User getOrCreateOrUpdateUser(String email, String fullName, String rawPassword, String phone, RoleType role, String referenceCode) {
        return userRepository.findByEmail(email).map(existing -> {
            existing.setPasswordHash(passwordEncoder.encode(rawPassword));
            existing.setFullName(fullName);
            existing.setPhone(phone);
            existing.setRole(role);
            existing.setReferenceCode(referenceCode);
            User updated = userRepository.save(existing);
            log.info("Dev test kullanıcısı güncellendi: {} ({}) - ID={}", email, role, updated.getId());
            return updated;
        }).orElseGet(() -> {
            User newUser = User.builder()
                    .email(email)
                    .fullName(fullName)
                    .passwordHash(passwordEncoder.encode(rawPassword))
                    .phone(phone)
                    .role(role)
                    .referenceCode(referenceCode)
                    .build();
            User saved = userRepository.save(newUser);
            log.info("Dev test kullanıcısı oluşturuldu: {} ({}) - ID={}", email, role, saved.getId());
            return saved;
        });
    }
}
