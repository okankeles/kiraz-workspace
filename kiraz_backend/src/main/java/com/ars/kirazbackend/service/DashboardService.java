package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.DashboardStatsDTO;
import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.enums.PaymentStatus;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final LeaseAgreementRepository leaseAgreementRepository;
    private final RentPeriodService rentPeriodService;
    private final PropertyDelegationService propertyDelegationService;

    public DashboardStatsDTO getLandlordStats(Long landlordId) {
        List<LeaseAgreement> leases = leaseAgreementRepository.findByPropertyLandlordId(landlordId);
        return calculateStats(leases);
    }

    public DashboardStatsDTO getTenantStats(Long tenantId) {
        List<LeaseAgreement> leases = leaseAgreementRepository.findByTenantId(tenantId);
        return calculateStats(leases);
    }

    public DashboardStatsDTO getAgentStats(Long agentId) {
        List<PropertyDelegation> delegations = propertyDelegationService.getActiveDelegationsForAgent(agentId);
        List<LeaseAgreement> leases = new ArrayList<>();
        for (PropertyDelegation del : delegations) {
            leases.addAll(leaseAgreementRepository.findByPropertyId(del.getProperty().getId()));
        }
        return calculateStats(leases);
    }

    private DashboardStatsDTO calculateStats(List<LeaseAgreement> leases) {
        BigDecimal totalPaid = BigDecimal.ZERO;
        BigDecimal upcoming = BigDecimal.ZERO;
        BigDecimal pendingApproval = BigDecimal.ZERO;
        BigDecimal overdue = BigDecimal.ZERO;

        for (LeaseAgreement lease : leases) {
            BigDecimal rentAmount = lease.getMonthlyRentAmount() != null
                    ? lease.getMonthlyRentAmount()
                    : BigDecimal.ZERO;

            List<RentPeriod> periods = rentPeriodService.getPeriodsByLeaseId(lease.getId());

            for (RentPeriod period : periods) {
                PaymentStatus status = period.getStatus();
                String receipt = period.getReceiptImageUrl();
                boolean hasReceipt = receipt != null && !receipt.trim().isEmpty();

                if (status == PaymentStatus.PAID) {
                    totalPaid = totalPaid.add(rentAmount);
                } else if (status == PaymentStatus.OVERDUE || status == PaymentStatus.IN_LEGAL_PROCESS) {
                    overdue = overdue.add(rentAmount);
                } else if (status == PaymentStatus.PENDING) {
                    if (hasReceipt) {
                        pendingApproval = pendingApproval.add(rentAmount);
                    } else {
                        upcoming = upcoming.add(rentAmount);
                    }
                } else if (status == PaymentStatus.REJECTED) {
                    overdue = overdue.add(rentAmount);
                }
            }
        }

        return new DashboardStatsDTO(totalPaid, upcoming, pendingApproval, overdue);
    }
}
