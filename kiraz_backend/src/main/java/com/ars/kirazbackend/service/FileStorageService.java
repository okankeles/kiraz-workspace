package com.ars.kirazbackend.service;

import com.ars.kirazbackend.exception.FileValidationException;
import com.ars.kirazbackend.util.FileValidationUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

@Slf4j
@Service
public class FileStorageService {

    private final Path fileStorageLocation = Paths.get("uploads/receipts").toAbsolutePath().normalize();
    private final Path baseUploadLocation = Paths.get("uploads").toAbsolutePath().normalize();

    public FileStorageService() {
        try {
            Files.createDirectories(this.fileStorageLocation);
        } catch (Exception ex) {
            throw new RuntimeException("Upload klasörü oluşturulamadı.", ex);
        }
    }

    /**
     * Yüklenen dosyayı magic bytes ve boyut sınırına (10 MB) göre doğrular,
     * tahmin edilemez bir UUID dosya adı üretir ve güvenli konuma kaydeder.
     *
     * @param file Yüklenen dosya
     * @return Kaydedilen göreceli dosya yolu (ör. "uploads/receipts/UUID.jpg")
     */
    public String storeFile(MultipartFile file) {
        String mimeType = FileValidationUtil.validateAndDetectMimeType(file);
        String extension = FileValidationUtil.getExtensionForMimeType(mimeType);

        String fileName = UUID.randomUUID().toString() + extension;
        Path targetLocation = this.fileStorageLocation.resolve(fileName).normalize();

        // Path traversal koruması
        if (!targetLocation.startsWith(this.fileStorageLocation)) {
            throw new FileValidationException("Geçersiz dosya kaydetme konumu.");
        }

        try (InputStream inputStream = file.getInputStream()) {
            Files.copy(inputStream, targetLocation, StandardCopyOption.REPLACE_EXISTING);
            log.info("Dosya başarıyla kaydedildi: fileName={}, mimeType={}, size={}",
                    fileName, mimeType, file.getSize());
            return "uploads/receipts/" + fileName;
        } catch (Exception ex) {
            log.error("Dosya kaydedilemedi: {}", ex.getMessage());
            throw new RuntimeException("Dosya kaydedilemedi: " + ex.getMessage(), ex);
        }
    }

    /**
     * Veritabanında kayıtlı dosya yolunu sistemdeki güvenli dosya yoluna çözümler.
     */
    public Path resolvePath(String storedPath) {
        if (storedPath == null || storedPath.trim().isEmpty()) {
            return null;
        }

        String cleaned = storedPath.trim();
        if (cleaned.startsWith("/uploads/")) {
            cleaned = cleaned.substring("/uploads/".length());
        } else if (cleaned.startsWith("uploads/")) {
            cleaned = cleaned.substring("uploads/".length());
        }

        Path resolved = this.baseUploadLocation.resolve(cleaned).normalize();
        if (!resolved.startsWith(this.baseUploadLocation)) {
            log.warn("Path traversal denemesi tespit edildi: {}", storedPath);
            throw new FileValidationException("Geçersiz dosya yolu.");
        }

        return resolved;
    }

    public String detectMimeType(Path path) {
        return FileValidationUtil.detectMimeTypeFromPath(path);
    }
}
