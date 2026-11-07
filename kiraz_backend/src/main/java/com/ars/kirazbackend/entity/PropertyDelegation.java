package com.ars.kirazbackend.entity;

import com.ars.kirazbackend.enums.DelegationStatus;
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
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@Entity
@Table(name = "property_delegations")
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class PropertyDelegation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "property_id", nullable = false)
    private Property property;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "agent_id", nullable = false)
    private User agent;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "granted_by_id", nullable = false)
    private User grantedBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DelegationStatus status;

    private LocalDate startDate;

    private LocalDate endDate;

    private LocalDateTime revokedAt;

    private String revocationReason;

    @CreationTimestamp
    private LocalDateTime createdAt;

    @Transient
    @JsonProperty("propertyName")
    public String getPropertyName() {
        return property != null ? property.getTitle() : null;
    }

    @Transient
    @JsonProperty("propertyAddress")
    public String getPropertyAddress() {
        return property != null ? property.getAddress() : null;
    }

    @Transient
    @JsonProperty("propertyCity")
    public String getPropertyCity() {
        return property != null ? property.getCity() : null;
    }

    @Transient
    @JsonProperty("agentName")
    public String getAgentName() {
        return agent != null ? agent.getFullName() : null;
    }

    @Transient
    @JsonProperty("agentEmail")
    public String getAgentEmail() {
        return agent != null ? agent.getEmail() : null;
    }

    @Transient
    @JsonProperty("agentPhone")
    public String getAgentPhone() {
        return agent != null ? agent.getPhone() : null;
    }

    @Transient
    @JsonProperty("grantedByName")
    public String getGrantedByName() {
        return grantedBy != null ? grantedBy.getFullName() : null;
    }

    @Transient
    @JsonProperty("grantedByEmail")
    public String getGrantedByEmail() {
        return grantedBy != null ? grantedBy.getEmail() : null;
    }

    @Transient
    @JsonProperty("referenceCode")
    public String getReferenceCode() {
        return agent != null ? agent.getReferenceCode() : null;
    }

    @Transient
    @JsonProperty("agentReferenceCode")
    public String getAgentReferenceCode() {
        return agent != null ? agent.getReferenceCode() : null;
    }
}
