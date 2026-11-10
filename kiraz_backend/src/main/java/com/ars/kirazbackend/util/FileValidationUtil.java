package com.ars.kirazbackend.util;

import com.ars.kirazbackend.exception.FileValidationException;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

public final class FileValidationUtil {

    private static final byte[] PDF_MAGIC = new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D}; // %PDF-
    private static final byte[] JPEG_MAGIC = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] PNG_MAGIC = new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
    public static final long MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

    private FileValidationUtil() {}

    /**
     * Yüklenen dosyanın boş olmadığını, 10MB sınırını aşmadığını ve magic byte'lara göre
     * yalnızca PDF, JPEG veya PNG olduğunu doğrular. Geçersizse FileValidationException fırlatır.
     * Geçerli ise tespit edilen MIME türünü döner.
     */
    public static String validateAndDetectMimeType(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new FileValidationException("Yüklenecek dosya boş olamaz.");
        }

        if (file.getSize() > MAX_FILE_SIZE_BYTES) {
            throw new FileValidationException("Dosya boyutu 10 MB sınırını aşamaz.");
        }

        byte[] header = new byte[16];
        try (InputStream is = file.getInputStream()) {
            int read = is.read(header);
            if (read < 3) {
                throw new FileValidationException("Dosya içeriği okunamadı veya çok kısa.");
            }
        } catch (FileValidationException e) {
            throw e;
        } catch (Exception e) {
            throw new FileValidationException("Dosya içeriği okunamadı: " + e.getMessage());
        }

        String mimeType = detectMimeTypeFromBytes(header);
        if (mimeType == null) {
            throw new FileValidationException("Desteklenmeyen dosya formatı. Yalnızca PDF, JPEG ve PNG formatları kabul edilmektedir.");
        }

        return mimeType;
    }

    public static String detectMimeTypeFromBytes(byte[] headerBytes) {
        if (headerBytes == null || headerBytes.length < 3) {
            return null;
        }

        if (headerBytes.length >= 5 && startsWith(headerBytes, PDF_MAGIC)) {
            return "application/pdf";
        }
        if (startsWith(headerBytes, JPEG_MAGIC)) {
            return "image/jpeg";
        }
        if (headerBytes.length >= 8 && startsWith(headerBytes, PNG_MAGIC)) {
            return "image/png";
        }

        return null;
    }

    public static String detectMimeTypeFromPath(Path path) {
        try {
            byte[] header = new byte[16];
            try (InputStream is = Files.newInputStream(path)) {
                int read = is.read(header);
                if (read >= 3) {
                    String detected = detectMimeTypeFromBytes(header);
                    if (detected != null) {
                        return detected;
                    }
                }
            }
            return Files.probeContentType(path);
        } catch (Exception e) {
            return null;
        }
    }

    public static String getExtensionForMimeType(String mimeType) {
        if ("application/pdf".equalsIgnoreCase(mimeType)) {
            return ".pdf";
        } else if ("image/jpeg".equalsIgnoreCase(mimeType)) {
            return ".jpg";
        } else if ("image/png".equalsIgnoreCase(mimeType)) {
            return ".png";
        }
        return ".bin";
    }

    private static boolean startsWith(byte[] data, byte[] prefix) {
        if (data.length < prefix.length) return false;
        for (int i = 0; i < prefix.length; i++) {
            if (data[i] != prefix[i]) return false;
        }
        return true;
    }
}
