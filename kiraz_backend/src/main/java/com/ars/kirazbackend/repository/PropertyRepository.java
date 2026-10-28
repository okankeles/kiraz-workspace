package com.ars.kirazbackend.repository;

import com.ars.kirazbackend.entity.Property;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PropertyRepository extends JpaRepository<Property, Long> {

    List<Property> findByLandlordId(Long landlordId);
}
