package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.LandlordDashboardResponse;
import com.ars.kirazbackend.dto.LeaseSummaryDto;
import com.ars.kirazbackend.dto.MonthlyIncomeDto;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.enums.LeaseApprovalStatus;
import com.ars.kirazbackend.enums.LeaseStatus;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class LandlordDashboardService {

    private final PropertyRepository propertyRepository;
    private final LeaseAgreementRepository leaseAgreementRepository;
    private final RentPeriodRepository rentPeriodRepository;

    @Transactional(readOnly = true)
    public LandlordDashboardResponse getDashboardSummary(Long landlordId) {
        log.info("Generating Landlord dashboard summary for landlordId={}", landlordId);

        LocalDate today = LocalDate.now();
        int currentYear = today.getYear();
        int currentMonth = today.getMonthValue();

        List<Property> properties = propertyRepository.findByLandlordId(landlordId);
        List<LeaseAgreement> leases = leaseAgreementRepository.findByPropertyLandlordId(landlordId);
        List<RentPeriod> periods = rentPeriodRepository.findByLandlordId(landlordId);

        // 1. Bu ayki ödenmiş kiralardan elde edilen toplam gelir
        BigDecimal totalMonthlyIncome = periods.stream()
                .filter(p -> p.getStatus() == PaymentStatus.PAID
                        && p.getYear() != null && p.getYear() == currentYear
                        && p.getMonth() != null && p.getMonth() == currentMonth)
                .map(p -> p.getLeaseAgreement() != null && p.getLeaseAgreement().getMonthlyRentAmount() != null
                        ? p.getLeaseAgreement().getMonthlyRentAmount()
                        : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // 2. Gecikmiş ve bu ay vadesi gelip ödenmemiş toplam alacak
        BigDecimal totalPendingReceivables = periods.stream()
                .filter(p -> p.getStatus() != PaymentStatus.PAID
                        && p.getYear() != null && p.getMonth() != null
                        && (p.getYear() < currentYear || (p.getYear() == currentYear && p.getMonth() <= currentMonth)))
                .map(p -> p.getLeaseAgreement() != null && p.getLeaseAgreement().getMonthlyRentAmount() != null
                        ? p.getLeaseAgreement().getMonthlyRentAmount()
                        : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        // 3. Dolu mülk sayısı / Toplam mülk sayısı oranı (0.0 - 1.0)
        int totalProperties = properties.size();
        Set<Long> occupiedPropertyIds = leases.stream()
                .filter(l -> l.getProperty() != null)
                .filter(l -> (l.getStatus() == LeaseStatus.ACTIVE || l.getApprovalStatus() == LeaseApprovalStatus.ACTIVE))
                .filter(l -> l.getEndDate() == null || !l.getEndDate().isBefore(today))
                .map(l -> l.getProperty().getId())
                .collect(Collectors.toSet());

        long occupiedCount = properties.stream()
                .filter(p -> occupiedPropertyIds.contains(p.getId()))
                .count();

        double occupancyRate = totalProperties > 0
                ? BigDecimal.valueOf((double) occupiedCount / totalProperties)
                        .setScale(4, RoundingMode.HALF_UP)
                        .doubleValue()
                : 0.0;

        // 4. Önümüzdeki 60 gün içinde biten sözleşmelerin listesi
        LocalDate maxEndDate = today.plusDays(60);
        List<LeaseSummaryDto> upcomingExpirations = leases.stream()
                .filter(l -> l.getEndDate() != null)
                .filter(l -> !l.getEndDate().isBefore(today) && !l.getEndDate().isAfter(maxEndDate))
                .filter(l -> l.getStatus() != LeaseStatus.CANCELLED)
                .filter(l -> l.getApprovalStatus() != LeaseApprovalStatus.REJECTED && l.getApprovalStatus() != LeaseApprovalStatus.TERMINATED)
                .sorted(Comparator.comparing(LeaseAgreement::getEndDate))
                .map(l -> new LeaseSummaryDto(
                        l.getId(),
                        l.getProperty() != null ? l.getProperty().getId() : null,
                        l.getProperty() != null ? l.getProperty().getTitle() : "Taşınmaz",
                        l.getTenant() != null ? l.getTenant().getFullName() : "Kiracı",
                        l.getTenant() != null ? l.getTenant().getPhone() : null,
                        l.getStartDate(),
                        l.getEndDate(),
                        l.getMonthlyRentAmount() != null ? l.getMonthlyRentAmount() : BigDecimal.ZERO,
                        ChronoUnit.DAYS.between(today, l.getEndDate())
                ))
                .toList();

        // 5. Son 6 ayın 'Ay-Yıl' ve 'Toplam Gelir' bazında grafik verisi
        List<MonthlyIncomeDto> incomeChartData = new ArrayList<>(6);
        YearMonth currentYm = YearMonth.of(currentYear, currentMonth);
        for (int i = 5; i >= 0; i--) {
            YearMonth targetYm = currentYm.minusMonths(i);
            int y = targetYm.getYear();
            int m = targetYm.getMonthValue();
            String monthYear = String.format("%02d/%d", m, y);

            BigDecimal monthIncome = periods.stream()
                    .filter(p -> p.getStatus() == PaymentStatus.PAID
                            && p.getYear() != null && p.getYear() == y
                            && p.getMonth() != null && p.getMonth() == m)
                    .map(p -> p.getLeaseAgreement() != null && p.getLeaseAgreement().getMonthlyRentAmount() != null
                            ? p.getLeaseAgreement().getMonthlyRentAmount()
                            : BigDecimal.ZERO)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            incomeChartData.add(new MonthlyIncomeDto(monthYear, y, m, monthIncome));
        }

        log.info("Landlord dashboard summary generated: landlordId={}, monthlyIncome={}, pendingReceivables={}, occupancyRate={}, upcomingCount={}, chartMonths={}",
                landlordId, totalMonthlyIncome, totalPendingReceivables, occupancyRate, upcomingExpirations.size(), incomeChartData.size());

        return new LandlordDashboardResponse(
                totalMonthlyIncome,
                totalPendingReceivables,
                occupancyRate,
                upcomingExpirations,
                incomeChartData
        );
    }
}
