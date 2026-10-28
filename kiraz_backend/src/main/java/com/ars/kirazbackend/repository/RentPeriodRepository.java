package com.ars.kirazbackend.repository;

import com.ars.kirazbackend.entity.RentPeriod;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface RentPeriodRepository extends JpaRepository<RentPeriod, Long> {

    List<RentPeriod> findByLeaseAgreementId(Long leaseId);

    List<RentPeriod> findByLeaseAgreementIdOrderByPeriodStartAsc(Long leaseId);
}
