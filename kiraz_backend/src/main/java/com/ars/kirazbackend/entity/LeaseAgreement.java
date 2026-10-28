package com.ars.kirazbackend.entity;

import com.ars.kirazbackend.enums.LeaseStatus;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "lease_agreements")
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class LeaseAgreement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "property_id", nullable = false)
    private Property property;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "tenant_id", nullable = false)
    private User tenant;

    private LocalDate startDate;

    private LocalDate endDate;

    @Column(nullable = false)
    private BigDecimal monthlyRentAmount;

    private BigDecimal depositAmount;

    private Integer paymentDay;

    @Enumerated(EnumType.STRING)
    private LeaseStatus status;

    private String inviteCode;

    private String contractFileUrl;

    @Transient
    @JsonProperty("landlordName")
    public String getLandlordName() {
        return (property != null && property.getLandlord() != null)
                ? property.getLandlord().getFullName()
                : null;
    }

    @Transient
    @JsonProperty("landlordEmail")
    public String getLandlordEmail() {
        return (property != null && property.getLandlord() != null)
                ? property.getLandlord().getEmail()
                : null;
    }

    @Transient
    @JsonProperty("tenantEmail")
    public String getTenantEmail() {
        return tenant != null ? tenant.getEmail() : null;
    }

    @Transient
    @JsonProperty("tenantName")
    public String getTenantName() {
        return tenant != null ? tenant.getFullName() : null;
    }
}
