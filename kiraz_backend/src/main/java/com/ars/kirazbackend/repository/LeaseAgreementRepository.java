package com.ars.kirazbackend.repository;

import com.ars.kirazbackend.entity.LeaseAgreement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LeaseAgreementRepository extends JpaRepository<LeaseAgreement, Long> {

    List<LeaseAgreement> findByTenantId(Long tenantId);

    List<LeaseAgreement> findByPropertyLandlordId(Long landlordId);

    List<LeaseAgreement> findByPropertyId(Long propertyId);

    Optional<LeaseAgreement> findByInviteCode(String inviteCode);
}
