package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.*;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (request.getRole() == RoleType.AGENT) {
            return registerAgent(request);
        }

        if (userRepository.findByEmail(request.getEmail().trim()).isPresent()) {
            throw new RuntimeException("Email already in use");
        }

        String referenceCode = request.getReferenceCode();
        if (request.getRole() == RoleType.LANDLORD) {
            referenceCode = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        }

        User user = User.builder()
            .fullName(request.getFullName())
            .email(request.getEmail().trim())
            .passwordHash(passwordEncoder.encode(request.getPassword()))
            .phone(request.getPhone())
            .role(request.getRole())
            .referenceCode(referenceCode)
            .build();

        User savedUser = userRepository.save(user);

        return buildAuthResponse(savedUser, "User registered successfully");
    }

    private AuthResponse registerAgent(RegisterRequest request) {
        String referenceCode = request.getReferenceCode();
        if (referenceCode != null && !referenceCode.trim().isEmpty()) {
            String trimmedRefCode = referenceCode.trim().toUpperCase();
            User placeholderUser = userRepository.findByReferenceCode(trimmedRefCode)
                    .orElseThrow(() -> new RuntimeException("Geçersiz referans kodu: " + trimmedRefCode));

            if (placeholderUser.getRole() != RoleType.AGENT) {
                throw new RuntimeException("Bu referans kodu bir emlakçıya ait değil!");
            }

            // Formdan gelen e-posta adresini kontrol et
            String requestEmail = request.getEmail() != null ? request.getEmail().trim().toLowerCase() : null;
            if (requestEmail != null && !requestEmail.isEmpty()) {
                Optional<User> existingEmailUser = userRepository.findByEmail(requestEmail);
                if (existingEmailUser.isPresent() && !existingEmailUser.get().getId().equals(placeholderUser.getId())) {
                    throw new RuntimeException("Bu e-posta adresi başka bir kullanıcı tarafından kullanılıyor: " + requestEmail);
                }
                placeholderUser.setEmail(requestEmail);
            }

            // Gerçek bilgilerle placeholder kaydını güncelle ve aktifleştir
            if (request.getFullName() != null && !request.getFullName().trim().isEmpty()) {
                placeholderUser.setFullName(request.getFullName().trim());
            }
            if (request.getPassword() != null && !request.getPassword().trim().isEmpty()) {
                placeholderUser.setPasswordHash(passwordEncoder.encode(request.getPassword().trim()));
            }
            if (request.getPhone() != null && !request.getPhone().trim().isEmpty()) {
                placeholderUser.setPhone(request.getPhone().trim());
            }
            placeholderUser.setRole(RoleType.AGENT);

            User savedUser = userRepository.save(placeholderUser);

            log.info("Emlakçı davet koduyla başarıyla kaydedildi ve aktifleştirildi: id={}, email={}, refCode={}",
                    savedUser.getId(), savedUser.getEmail(), savedUser.getReferenceCode());

            return buildAuthResponse(savedUser, "Emlakçı kaydı başarıyla tamamlandı ve hesap aktifleştirildi");
        } else {
            // Referans kodu verilmemişse:
            String requestEmail = request.getEmail() != null ? request.getEmail().trim().toLowerCase() : null;
            if (requestEmail != null && !requestEmail.isEmpty()) {
                Optional<User> existingOpt = userRepository.findByEmail(requestEmail);
                if (existingOpt.isPresent()) {
                    User existing = existingOpt.get();
                    if (existing.getRole() == RoleType.AGENT && existing.getReferenceCode() != null) {
                        throw new RuntimeException("Bu e-posta için bir emlakçı daveti bulunmaktadır. Lütfen davet (referans) kodunuzu girerek kaydolun.");
                    }
                    throw new RuntimeException("Email already in use");
                }
            }

            String newRefCode = "AGT-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
            User user = User.builder()
                    .fullName(request.getFullName())
                    .email(requestEmail)
                    .passwordHash(passwordEncoder.encode(request.getPassword()))
                    .phone(request.getPhone())
                    .role(RoleType.AGENT)
                    .referenceCode(newRefCode)
                    .build();

            User savedUser = userRepository.save(user);

            return buildAuthResponse(savedUser, "Emlakçı kaydı başarıyla tamamlandı");
        }
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail().trim())
                .orElseThrow(() -> new RuntimeException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Invalid credentials");
        }

        return buildAuthResponse(user, "Login successful");
    }

    public AuthResponse refresh(RefreshTokenRequest request) {
        RefreshTokenService.RefreshTokenValidationResult result =
                refreshTokenService.rotateRefreshToken(request.getRefreshToken());

        User user = result.user();
        String newAccessToken = jwtService.generateAccessToken(user);
        String newRefreshToken = result.newRefreshToken();
        long expiresIn = jwtService.getAccessTokenExpirationSeconds();

        UserSummaryDto userSummary = UserSummaryDto.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .build();

        return AuthResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(newRefreshToken)
                .expiresIn(expiresIn)
                .user(userSummary)
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .referenceCode(user.getReferenceCode())
                .message("Token refreshed successfully")
                .build();
    }

    @Transactional
    public void logout(LogoutRequest request) {
        if (request != null && request.getRefreshToken() != null) {
            refreshTokenService.revokeRefreshToken(request.getRefreshToken());
        }
    }

    private AuthResponse buildAuthResponse(User user, String message) {
        String accessToken = jwtService.generateAccessToken(user);
        String refreshToken = refreshTokenService.createRefreshToken(user);
        long expiresIn = jwtService.getAccessTokenExpirationSeconds();

        UserSummaryDto userSummary = UserSummaryDto.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .build();

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .expiresIn(expiresIn)
                .user(userSummary)
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .referenceCode(user.getReferenceCode())
                .message(message)
                .build();
    }
}
