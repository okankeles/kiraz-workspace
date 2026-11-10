package com.ars.kirazbackend.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "Yenilenen davet kodu yanıt modeli")
public class RegenerateInviteResponse {

    @Schema(description = "Sözleşme ID", example = "12")
    private Long leaseId;

    @Schema(description = "Yeni 128-bit davet kodu", example = "ARS-E2A4B6C8D0F1E2A3B4C5D6E7F8091A2B")
    private String inviteCode;

    @Schema(description = "Yeni davet kodunun son kullanma tarihi (7 gün)", example = "2026-11-17T05:00:00")
    private LocalDateTime inviteCodeExpiresAt;

    @Schema(description = "İşlem sonucu mesajı", example = "Yeni davet kodu başarıyla oluşturuldu.")
    private String message;
}
