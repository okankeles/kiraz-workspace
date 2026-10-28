package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.service.RentPeriodService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/periods")
@RequiredArgsConstructor
public class RentPeriodController {
    private final RentPeriodService rentPeriodService;

    @GetMapping("/lease/{leaseId}")
    public ResponseEntity<List<RentPeriod>> getPeriodsByLeaseId(@PathVariable Long leaseId) {
        return ResponseEntity.ok(rentPeriodService.getPeriodsByLeaseId(leaseId));
    }

    @PostMapping("/{id}/receipt")
    public ResponseEntity<RentPeriod> uploadReceipt(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(rentPeriodService.uploadReceipt(id, file));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<RentPeriod> updateStatus(
            @PathVariable Long id,
            @RequestParam("status") String status) {
        return ResponseEntity.ok(rentPeriodService.updateStatus(id, status));
    }
}
