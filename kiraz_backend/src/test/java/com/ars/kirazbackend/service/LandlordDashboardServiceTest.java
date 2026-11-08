package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.LandlordDashboardResponse;
import com.ars.kirazbackend.dto.LeaseSummaryDto;
import com.ars.kirazbackend.dto.MonthlyIncomeDto;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.Property;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.LeaseApprovalStatus;
import com.ars.kirazbackend.enums.LeaseStatus;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import com.ars.kirazbackend.repository.PropertyRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LandlordDashboardServiceTest {

    @Mock
    private PropertyRepository propertyRepository;

    @Mock
    private LeaseAgreementRepository leaseAgreementRepository;

    @Mock
    private RentPeriodRepository rentPeriodRepository;

    @InjectMocks
    private LandlordDashboardService landlordDashboardService;

    private User landlord;
    private User tenant1;
    private User tenant2;
    private Property propertyA;
    private Property propertyB;
    private LeaseAgreement leaseA;
    private LeaseAgreement leaseB;

    @BeforeEach
    void setUp() {
        landlord = User.builder().id(1L).fullName("Ev Sahibi Ali").role(RoleType.LANDLORD).build();
        tenant1 = User.builder().id(2L).fullName("Kiracı Veli").phone("05321112233").role(RoleType.TENANT).build();
        tenant2 = User.builder().id(3L).fullName("Kiracı Ayşe").phone("05324445566").role(RoleType.TENANT).build();

        propertyA = Property.builder().id(10L).title("Daire 1").landlord(landlord).build();
        propertyB = Property.builder().id(20L).title("Daire 2").landlord(landlord).build();

        LocalDate today = LocalDate.now();

        leaseA = LeaseAgreement.builder()
                .id(100L)
                .property(propertyA)
                .tenant(tenant1)
                .monthlyRentAmount(BigDecimal.valueOf(15000.00))
                .status(LeaseStatus.ACTIVE)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .startDate(today.minusMonths(6))
                .endDate(today.plusDays(30)) // Expiring in 30 days
                .build();

        leaseB = LeaseAgreement.builder()
                .id(200L)
                .property(propertyB)
                .tenant(tenant2)
                .monthlyRentAmount(BigDecimal.valueOf(20000.00))
                .status(LeaseStatus.ACTIVE)
                .approvalStatus(LeaseApprovalStatus.ACTIVE)
                .startDate(today.minusMonths(3))
                .endDate(today.plusMonths(9)) // Not expiring soon (>60 days)
                .build();
    }

    @Test
    void testGetDashboardSummary_CalculatesAllMetricsCorrectly() {
        LocalDate today = LocalDate.now();
        int currentYear = today.getYear();
        int currentMonth = today.getMonthValue();

        // Rent periods for leaseA and leaseB
        // 1. Current month PAID for leaseA -> 15000
        RentPeriod paidCurrentMonth = RentPeriod.builder()
                .id(1L)
                .leaseAgreement(leaseA)
                .month(currentMonth)
                .year(currentYear)
                .status(PaymentStatus.PAID)
                .build();

        // 2. Current month PENDING for leaseB -> 20000 (pending receivable)
        RentPeriod pendingCurrentMonth = RentPeriod.builder()
                .id(2L)
                .leaseAgreement(leaseB)
                .month(currentMonth)
                .year(currentYear)
                .status(PaymentStatus.PENDING)
                .build();

        // 3. Past month OVERDUE for leaseA -> 15000 (pending receivable)
        LocalDate prevMonthDate = today.minusMonths(1);
        RentPeriod overduePastMonth = RentPeriod.builder()
                .id(3L)
                .leaseAgreement(leaseA)
                .month(prevMonthDate.getMonthValue())
                .year(prevMonthDate.getYear())
                .status(PaymentStatus.OVERDUE)
                .build();

        // 4. Past month PAID for leaseB -> 20000 (included in chart data)
        RentPeriod paidPastMonth = RentPeriod.builder()
                .id(4L)
                .leaseAgreement(leaseB)
                .month(prevMonthDate.getMonthValue())
                .year(prevMonthDate.getYear())
                .status(PaymentStatus.PAID)
                .build();

        when(propertyRepository.findByLandlordId(1L)).thenReturn(List.of(propertyA, propertyB));
        when(leaseAgreementRepository.findByPropertyLandlordId(1L)).thenReturn(List.of(leaseA, leaseB));
        when(rentPeriodRepository.findByLandlordId(1L)).thenReturn(List.of(
                paidCurrentMonth, pendingCurrentMonth, overduePastMonth, paidPastMonth
        ));

        LandlordDashboardResponse response = landlordDashboardService.getDashboardSummary(1L);

        assertNotNull(response);

        // 1. totalMonthlyIncome: paidCurrentMonth = 15000
        assertEquals(0, BigDecimal.valueOf(15000.00).compareTo(response.totalMonthlyIncome()));

        // 2. totalPendingReceivables: pendingCurrentMonth (20000) + overduePastMonth (15000) = 35000
        assertEquals(0, BigDecimal.valueOf(35000.00).compareTo(response.totalPendingReceivables()));

        // 3. occupancyRate: 2 properties, both occupied -> 1.0 (100%)
        assertEquals(1.0, response.occupancyRate(), 0.001);

        // 4. upcomingExpirations: only leaseA expires in 30 days (<= 60 days)
        assertEquals(1, response.upcomingExpirations().size());
        LeaseSummaryDto expiration = response.upcomingExpirations().get(0);
        assertEquals(100L, expiration.leaseId());
        assertEquals(10L, expiration.propertyId());
        assertEquals("Daire 1", expiration.propertyTitle());
        assertEquals("Kiracı Veli", expiration.tenantName());
        assertEquals(30, expiration.daysRemaining());

        // 5. incomeChartData: exactly 6 months
        assertEquals(6, response.incomeChartData().size());

        // Last element in chart data is current month
        MonthlyIncomeDto currentMonthChart = response.incomeChartData().get(5);
        assertEquals(currentMonth, currentMonthChart.month());
        assertEquals(currentYear, currentMonthChart.year());
        assertEquals(0, BigDecimal.valueOf(15000.00).compareTo(currentMonthChart.totalIncome()));

        // Second to last element is previous month
        MonthlyIncomeDto prevMonthChart = response.incomeChartData().get(4);
        assertEquals(prevMonthDate.getMonthValue(), prevMonthChart.month());
        assertEquals(prevMonthDate.getYear(), prevMonthChart.year());
        assertEquals(0, BigDecimal.valueOf(20000.00).compareTo(prevMonthChart.totalIncome()));
    }

    @Test
    void testGetDashboardSummary_EmptyLandlord_ReturnsZerosAndEmptyLists() {
        when(propertyRepository.findByLandlordId(999L)).thenReturn(List.of());
        when(leaseAgreementRepository.findByPropertyLandlordId(999L)).thenReturn(List.of());
        when(rentPeriodRepository.findByLandlordId(999L)).thenReturn(List.of());

        LandlordDashboardResponse response = landlordDashboardService.getDashboardSummary(999L);

        assertNotNull(response);
        assertEquals(0, BigDecimal.ZERO.compareTo(response.totalMonthlyIncome()));
        assertEquals(0, BigDecimal.ZERO.compareTo(response.totalPendingReceivables()));
        assertEquals(0.0, response.occupancyRate(), 0.001);
        assertTrue(response.upcomingExpirations().isEmpty());
        assertEquals(6, response.incomeChartData().size());
        for (MonthlyIncomeDto item : response.incomeChartData()) {
            assertEquals(0, BigDecimal.ZERO.compareTo(item.totalIncome()));
        }
    }

    @Test
    void testGetDashboardSummary_PartialOccupancy() {
        // Property A has active lease, Property B has no active lease
        when(propertyRepository.findByLandlordId(1L)).thenReturn(List.of(propertyA, propertyB));
        when(leaseAgreementRepository.findByPropertyLandlordId(1L)).thenReturn(List.of(leaseA));
        when(rentPeriodRepository.findByLandlordId(1L)).thenReturn(List.of());

        LandlordDashboardResponse response = landlordDashboardService.getDashboardSummary(1L);

        assertNotNull(response);
        // 1 occupied out of 2 = 0.5
        assertEquals(0.5, response.occupancyRate(), 0.001);
    }
}
