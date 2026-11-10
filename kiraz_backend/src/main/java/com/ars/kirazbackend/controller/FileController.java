package com.ars.kirazbackend.controller;

import com.ars.kirazbackend.entity.LeaseAgreement;
import com.ars.kirazbackend.entity.RentPeriod;
import com.ars.kirazbackend.exception.ResourceNotFoundException;
import com.ars.kirazbackend.repository.LeaseAgreementRepository;
import com.ars.kirazbackend.repository.RentPeriodRepository;
import com.ars.kirazbackend.service.AccessControlService;
import com.ars.kirazbackend.service.FileStorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.nio.file.Files;
import java.nio.file.Path;

@Slf4j
@RestController
@RequestMapping("/api/files")
@RequiredArgsConstructor
@Tag(name = "Files", description = "Güvenli ve yetkilendirilmiş dosya akış uçları")
public class FileController {

    private final RentPeriodRepository rentPeriodRepository;
    private final LeaseAgreementRepository leaseRepository;
    private final FileStorageService fileStorageService;
    private final AccessControlService authz;

    /**
     * Kira dönemi dekontunu kaynak bazlı yetki kontrolü ile stream eder.
     * Ev sahibi (kendi mülkü), kiracı (kendi dönemi) veya aktif vekaleti olan emlakçı erişebilir.
     */
    @GetMapping("/receipts/{periodId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Kira dönemi dekont dosyasını güvenli şekilde stream et")
    public ResponseEntity<Resource> getReceiptFile(@PathVariable Long periodId) {
        authz.checkCanViewPeriod(periodId);

        RentPeriod period = rentPeriodRepository.findById(periodId)
                .orElseThrow(() -> new ResourceNotFoundException("Kira dönemi bulunamadı: " + periodId));

        String filePath = period.getReceiptFilePath();
        if (filePath == null || filePath.isBlank()) {
            filePath = period.getReceiptImageUrl();
        }

        if (filePath == null || filePath.isBlank()) {
            throw new ResourceNotFoundException("Bu kira dönemi için yüklenmiş dekont bulunamadı.");
        }

        Path path = fileStorageService.resolvePath(filePath);
        if (path == null || !Files.exists(path)) {
            throw new ResourceNotFoundException("Dekont dosyası sunucuda bulunamadı.");
        }

        try {
            Resource resource = new UrlResource(path.toUri());
            String mimeType = fileStorageService.detectMimeType(path);
            if (mimeType == null) {
                mimeType = Files.probeContentType(path);
            }
            if (mimeType == null) {
                mimeType = MediaType.APPLICATION_OCTET_STREAM_VALUE;
            }

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(mimeType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + path.getFileName().toString() + "\"")
                    .body(resource);
        } catch (Exception e) {
            log.error("Dekont dosyası okunamadı: periodId={}, error={}", periodId, e.getMessage());
            throw new ResourceNotFoundException("Dosya okunamadı: " + e.getMessage());
        }
    }

    /**
     * Kira sözleşmesi belgesini kaynak bazlı yetki kontrolü ile stream eder.
     * Ev sahibi (kendi mülkü), kiracı (kendi sözleşmesi) veya aktif vekaleti olan emlakçı erişebilir.
     */
    @GetMapping("/contracts/{leaseId}")
    @PreAuthorize("hasAnyRole('LANDLORD', 'AGENT', 'PROPERTY_MANAGER', 'TENANT')")
    @Operation(summary = "Kira sözleşmesi belgesini güvenli şekilde stream et")
    public ResponseEntity<Resource> getContractFile(@PathVariable Long leaseId) {
        authz.checkCanViewLease(leaseId);

        LeaseAgreement lease = leaseRepository.findById(leaseId)
                .orElseThrow(() -> new ResourceNotFoundException("Sözleşme bulunamadı: " + leaseId));

        String filePath = lease.getContractFilePath();
        if (filePath == null || filePath.isBlank()) {
            filePath = lease.getContractFileUrl();
        }

        if (filePath == null || filePath.isBlank()) {
            throw new ResourceNotFoundException("Bu sözleşme için yüklenmiş belge bulunamadı.");
        }

        Path path = fileStorageService.resolvePath(filePath);
        if (path == null || !Files.exists(path)) {
            throw new ResourceNotFoundException("Sözleşme belgesi sunucuda bulunamadı.");
        }

        try {
            Resource resource = new UrlResource(path.toUri());
            String mimeType = fileStorageService.detectMimeType(path);
            if (mimeType == null) {
                mimeType = Files.probeContentType(path);
            }
            if (mimeType == null) {
                mimeType = MediaType.APPLICATION_OCTET_STREAM_VALUE;
            }

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(mimeType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + path.getFileName().toString() + "\"")
                    .body(resource);
        } catch (Exception e) {
            log.error("Sözleşme belgesi okunamadı: leaseId={}, error={}", leaseId, e.getMessage());
            throw new ResourceNotFoundException("Dosya okunamadı: " + e.getMessage());
        }
    }
}
