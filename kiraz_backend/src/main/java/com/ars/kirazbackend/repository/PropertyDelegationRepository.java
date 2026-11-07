package com.ars.kirazbackend.repository;

import com.ars.kirazbackend.entity.PropertyDelegation;
import com.ars.kirazbackend.enums.DelegationStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface PropertyDelegationRepository extends JpaRepository<PropertyDelegation, Long> {

    List<PropertyDelegation> findByPropertyId(Long propertyId);

    List<PropertyDelegation> findByPropertyIdOrderByCreatedAtDesc(Long propertyId);

    List<PropertyDelegation> findByAgentIdOrderByCreatedAtDesc(Long agentId);

    List<PropertyDelegation> findByAgentIdAndStatus(Long agentId, DelegationStatus status);

    List<PropertyDelegation> findByPropertyIdAndStatus(Long propertyId, DelegationStatus status);

    Optional<PropertyDelegation> findFirstByPropertyIdAndAgentIdAndStatus(Long propertyId, Long agentId, DelegationStatus status);

    boolean existsByPropertyIdAndAgentIdAndStatus(Long propertyId, Long agentId, DelegationStatus status);

    List<PropertyDelegation> findByGrantedByIdOrderByCreatedAtDesc(Long grantedById);
}
