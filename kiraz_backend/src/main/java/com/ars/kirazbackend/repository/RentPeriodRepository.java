package com.ars.kirazbackend.repository;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.enums.PaymentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface RentPeriodRepository extends JpaRepository<RentPeriod, Long> {

    List<RentPeriod> findByLeaseAgreementId(Long leaseId);

    List<RentPeriod> findByLeaseAgreementIdOrderByPeriodStartAsc(Long leaseId);

    List<RentPeriod> findByStatus(PaymentStatus status);

    @Query("SELECT r FROM RentPeriod r WHERE r.status = :status AND ((r.paymentDate IS NOT NULL AND r.paymentDate < :today) OR (r.paymentDate IS NULL AND r.periodStart < :today))")
    List<RentPeriod> findPendingOverduePeriods(
            @Param("status") PaymentStatus status,
            @Param("today") LocalDate today
    );

    @Query("SELECT r FROM RentPeriod r WHERE r.leaseAgreement.tenant.id = :tenantId ORDER BY r.periodStart ASC")
    List<RentPeriod> findByTenantId(@Param("tenantId") Long tenantId);

    @Query("SELECT r FROM RentPeriod r " +
           "JOIN FETCH r.leaseAgreement l " +
           "JOIN FETCH l.property p " +
           "LEFT JOIN FETCH l.tenant t " +
           "WHERE p.landlord.id = :landlordId")
    List<RentPeriod> findByLandlordId(@Param("landlordId") Long landlordId);

    @Query("SELECT r FROM RentPeriod r " +
           "JOIN FETCH r.leaseAgreement l " +
           "JOIN FETCH l.property p " +
           "LEFT JOIN FETCH l.tenant t " +
           "WHERE p.landlord.id = :landlordId AND r.status = :status " +
           "ORDER BY r.year DESC, r.month DESC")
    List<RentPeriod> findByLandlordIdAndStatus(
            @Param("landlordId") Long landlordId,
            @Param("status") PaymentStatus status
    );
}
