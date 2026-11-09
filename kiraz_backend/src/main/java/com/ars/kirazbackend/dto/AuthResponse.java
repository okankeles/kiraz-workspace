package com.ars.kirazbackend.dto;

import com.ars.kirazbackend.enums.RoleType;
import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AuthResponse {
    private String accessToken;
    private String refreshToken;
    private Long expiresIn;
    private UserSummaryDto user;

    // Direct accessors & backwards-compatibility fields
    private Long id;
    private String fullName;
    private String email;
    private RoleType role;
    private String referenceCode;
    private String message;

    public Long getId() {
        if (id != null) return id;
        return user != null ? user.getId() : null;
    }

    public String getFullName() {
        if (fullName != null) return fullName;
        return user != null ? user.getFullName() : null;
    }

    public String getEmail() {
        if (email != null) return email;
        return user != null ? user.getEmail() : null;
    }

    public RoleType getRole() {
        if (role != null) return role;
        return user != null ? user.getRole() : null;
    }
}
