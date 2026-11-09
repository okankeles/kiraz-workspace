package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.DelegationRequestDto;
import com.ars.kirazbackend.dto.DelegationResponseDto;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.PropertyDelegationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/landlord/delegations")
@RequiredArgsConstructor
public class LandlordDelegationController {

    private final PropertyDelegationService delegationService;
    private final UserRepository userRepository;

    @PostMapping
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<DelegationResponseDto> assignManager(
            @RequestBody DelegationRequestDto request,
            Authentication authentication
    ) {
        log.info("Request to assign manager for propertyId={}, managerEmail={}",
                request != null ? request.propertyId() : null,
                request != null ? request.managerEmail() : null);

        User landlord = resolveLandlord(authentication);
        DelegationResponseDto response = delegationService.assignManager(request, landlord);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<DelegationResponseDto>> getLandlordDelegations(
            Authentication authentication
    ) {
        User landlord = resolveLandlord(authentication);
        if (landlord == null || landlord.getId() == null) {
            log.warn("Could not resolve landlord for delegations list");
            throw new RuntimeException("Ev sahibi kimliği belirlenemedi.");
        }

        log.info("Fetching delegations for landlordId={}", landlord.getId());
        List<DelegationResponseDto> delegations = delegationService.getLandlordDelegations(landlord.getId());
        return ResponseEntity.ok(delegations);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<DelegationResponseDto> revokeDelegation(
            @PathVariable Long id,
            Authentication authentication
    ) {
        log.info("Request to revoke delegation id={}", id);
        User landlord = resolveLandlord(authentication);
        Long landlordId = landlord != null ? landlord.getId() : null;
        DelegationResponseDto response = delegationService.revokeDelegationDto(id, landlordId);
        return ResponseEntity.ok(response);
    }

    private User resolveLandlord(Authentication auth) {
        if (auth == null) {
            auth = SecurityContextHolder.getContext().getAuthentication();
        }

        if (auth != null) {
            if (auth.getPrincipal() instanceof User user) {
                return user;
            } else if (auth.getName() != null && !auth.getName().trim().isEmpty()) {
                Optional<User> userOpt = userRepository.findByEmail(auth.getName().trim());
                if (userOpt.isPresent()) {
                    return userOpt.get();
                }
            }
        }

        return null;
    }
}
