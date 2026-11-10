package com.ars.kirazbackend.entity;

import com.ars.kirazbackend.enums.LeaseApprovalStatus;
import com.ars.kirazbackend.enums.LeaseStatus;
import com.fasterxml.jackson.annotation.JsonIgnore;
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
import java.time.LocalDateTime;

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

    @Enumerated(EnumType.STRING)
    @Column(name = "approval_status")
    private LeaseApprovalStatus approvalStatus;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_id")
    private User createdBy;

    private String rejectionReason;

    private String inviteCode;

    private LocalDateTime inviteCodeExpiresAt;

    private Boolean inviteCodeUsed;

    private LocalDateTime inviteCodeUsedAt;

    private String contractFileUrl;

    @JsonIgnore
    private String contractFilePath;

    @JsonProperty("contractFileUrl")
    public String getContractFileUrl() {
        if (this.id != null && ((this.contractFilePath != null && !this.contractFilePath.isBlank()) ||
                (this.contractFileUrl != null && !this.contractFileUrl.isBlank()))) {
            return "/api/files/contracts/" + this.id;
        }
        return this.contractFileUrl;
    }

    @Transient
    @JsonProperty("contractDocumentUrl")
    public String getContractDocumentUrl() {
        return getContractFileUrl();
    }

    @Transient
    @JsonProperty("approvalStatusName")
    public String getApprovalStatusName() {
        return approvalStatus != null ? approvalStatus.name() : null;
    }

    @Transient
    @JsonProperty("createdByName")
    public String getCreatedByName() {
        return createdBy != null ? createdBy.getFullName() : null;
    }

    @Transient
    @JsonProperty("createdByRole")
    public String getCreatedByRole() {
        return (createdBy != null && createdBy.getRole() != null) ? createdBy.getRole().name() : null;
    }

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
    @JsonProperty("tenantId")
    public Long getTenantId() {
        return tenant != null ? tenant.getId() : null;
    }

    @Transient
    @JsonProperty("tenantName")
    public String getTenantName() {
        return tenant != null ? tenant.getFullName() : null;
    }
}
