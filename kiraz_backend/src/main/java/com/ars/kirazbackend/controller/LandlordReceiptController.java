package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.dto.PendingReceiptDto;
import com.ars.kirazbackend.dto.RejectReceiptRequest;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.repository.UserRepository;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.LandlordReceiptService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.AuthenticationCredentialsNotFoundException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/landlord/receipts")
@RequiredArgsConstructor
public class LandlordReceiptController {

    private final LandlordReceiptService landlordReceiptService;
    private final UserRepository userRepository;
    private final AccessControlService authz;

    @GetMapping("/pending")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<List<PendingReceiptDto>> getPendingReceipts(
            Authentication authentication
    ) {
        User landlord = resolveLandlord(authentication);
        if (landlord == null || landlord.getId() == null) {
            log.warn("Could not resolve landlord from SecurityContext");
            throw new AuthenticationCredentialsNotFoundException("Ev sahibi kimliği belirlenemedi.");
        }

        log.info("Fetching pending receipts for landlordId={}", landlord.getId());
        List<PendingReceiptDto> pendingReceipts = landlordReceiptService.getPendingReceipts(landlord.getId());
        return ResponseEntity.ok(pendingReceipts);
    }

    @PostMapping("/{periodId}/approve")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<RentPeriod> approveReceipt(
            @PathVariable Long periodId
    ) {
        authz.checkCanReviewReceipt(periodId);
        log.info("Request to approve receipt for periodId={}", periodId);
        RentPeriod approved = landlordReceiptService.approveReceipt(periodId);
        return ResponseEntity.ok(approved);
    }

    @PostMapping("/{periodId}/reject")
    @PreAuthorize("hasRole('LANDLORD')")
    public ResponseEntity<RentPeriod> rejectReceipt(
            @PathVariable Long periodId,
            @RequestBody(required = false) RejectReceiptRequest rejectRequest,
            Authentication authentication
    ) {
        authz.checkCanReviewReceipt(periodId);
        User landlord = resolveLandlord(authentication);
        String reason = (rejectRequest != null && rejectRequest.reason() != null && !rejectRequest.reason().trim().isEmpty())
                ? rejectRequest.reason().trim()
                : "Ev sahibi tarafından reddedildi.";

        log.info("Request to reject receipt for periodId={}, reason={}", periodId, reason);
        RentPeriod rejected = landlordReceiptService.rejectReceipt(periodId, reason, landlord);
        return ResponseEntity.ok(rejected);
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
