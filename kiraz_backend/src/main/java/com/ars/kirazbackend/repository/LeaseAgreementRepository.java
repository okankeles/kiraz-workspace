package com.ars.kirazbackend.repository;

import com.ars.kirazbackend.entity.LeaseAgreement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LeaseAgreementRepository extends JpaRepository<LeaseAgreement, Long> {

    @Query("SELECT l FROM LeaseAgreement l WHERE l.tenant.id = :tenantId")
    List<LeaseAgreement> findByTenantId(@Param("tenantId") Long tenantId);

    @Query("SELECT l FROM LeaseAgreement l " +
           "JOIN FETCH l.property p " +
           "LEFT JOIN FETCH l.tenant t " +
           "WHERE p.landlord.id = :landlordId")
    List<LeaseAgreement> findByPropertyLandlordId(@Param("landlordId") Long landlordId);

    @Query("SELECT l FROM LeaseAgreement l WHERE l.property.id = :propertyId")
    List<LeaseAgreement> findByPropertyId(@Param("propertyId") Long propertyId);

    Optional<LeaseAgreement> findByInviteCode(String inviteCode);

    List<LeaseAgreement> findByPropertyLandlordIdAndApprovalStatus(Long landlordId, com.ars.kirazbackend.enums.LeaseApprovalStatus approvalStatus);

    List<LeaseAgreement> findByCreatedById(Long createdById);

    List<LeaseAgreement> findByApprovalStatus(com.ars.kirazbackend.enums.LeaseApprovalStatus approvalStatus);
}

