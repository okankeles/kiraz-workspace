package com.ars.kirazbackend.service;

import com.ars.kirazbackend.entity.RefreshToken;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.exception.InvalidRefreshTokenException;
import com.ars.kirazbackend.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final PlatformTransactionManager transactionManager;

    @Value("${jwt.refresh-token-expiration-days:14}")
    private long refreshTokenExpirationDays;

    public static String hashToken(String rawToken) {
        if (rawToken == null || rawToken.trim().isEmpty()) {
            throw new InvalidRefreshTokenException("Refresh token boş olamaz.");
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.trim().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algoritması bulunamadı.", e);
        }
    }

    @Transactional
    public String createRefreshToken(User user) {
        String rawToken = UUID.randomUUID().toString().replace("-", "") +
                          UUID.randomUUID().toString().replace("-", "");
        String tokenHash = hashToken(rawToken);

        RefreshToken refreshToken = RefreshToken.builder()
                .tokenHash(tokenHash)
                .user(user)
                .expiryDate(Instant.now().plus(refreshTokenExpirationDays, ChronoUnit.DAYS))
                .revoked(false)
                .createdAt(Instant.now())
                .build();

        refreshTokenRepository.save(refreshToken);
        log.debug("Created hashed refresh token for user id={}", user.getId());
        return rawToken;
    }

    public RefreshTokenValidationResult rotateRefreshToken(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.trim().isEmpty()) {
            throw new InvalidRefreshTokenException("Refresh token boş olamaz.");
        }

        String tokenHash = hashToken(rawRefreshToken.trim());
        Optional<RefreshToken> tokenOpt = refreshTokenRepository.findByTokenHash(tokenHash);

        if (tokenOpt.isEmpty()) {
            log.warn("Refresh token bulunamadı: hash={}", tokenHash);
            throw new InvalidRefreshTokenException("Geçersiz veya bulunamayan refresh token.");
        }

        RefreshToken token = tokenOpt.get();

        // Check if token was previously revoked (reuse detection!)
        if (token.isRevoked()) {
            log.warn("GÜVENLİK ALARMI: Daha önce kullanılmış/iptal edilmiş refresh token tekrar kullanıldı! User ID: {}. Tüm oturumlar sonlandırılıyor.",
                    token.getUser().getId());

            // Commit revocation of ALL refresh tokens in an isolated, immediately committed transaction
            TransactionTemplate tx = new TransactionTemplate(transactionManager);
            tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
            tx.executeWithoutResult(status -> {
                refreshTokenRepository.revokeAllByUser(token.getUser());
            });

            throw new InvalidRefreshTokenException("Kullanılmış bir refresh token tespit edildi. Kullanıcının tüm oturumları güvenlik nedeniyle iptal edildi.");
        }

        // Check expiration
        if (token.isExpired()) {
            log.warn("Refresh token süresi dolmuş. User ID: {}", token.getUser().getId());
            token.setRevoked(true);
            refreshTokenRepository.save(token);
            throw new InvalidRefreshTokenException("Refresh token süresi dolmuş. Lütfen tekrar giriş yapın.");
        }

        // Token is valid: Revoke old token and create new one in a dedicated transaction
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        return tx.execute(status -> {
            token.setRevoked(true);
            refreshTokenRepository.save(token);
            User user = token.getUser();
            String newRefreshToken = createRefreshToken(user);
            return new RefreshTokenValidationResult(user, newRefreshToken);
        });
    }

    @Transactional
    public void revokeRefreshToken(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.trim().isEmpty()) {
            return;
        }
        String tokenHash = hashToken(rawRefreshToken.trim());
        refreshTokenRepository.findByTokenHash(tokenHash).ifPresent(token -> {
            token.setRevoked(true);
            refreshTokenRepository.save(token);
            log.info("Refresh token iptal edildi: userId={}", token.getUser().getId());
        });
    }

    @Transactional
    public void revokeAllUserTokens(User user) {
        refreshTokenRepository.revokeAllByUser(user);
        log.info("Kullanıcının tüm refresh token'ları iptal edildi: userId={}", user.getId());
    }

    public record RefreshTokenValidationResult(User user, String newRefreshToken) {}
}
