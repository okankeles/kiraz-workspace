package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.AuthResponse;
import com.ars.kirazbackend.dto.LoginRequest;
import com.ars.kirazbackend.dto.RegisterRequest;
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

        return AuthResponse.builder()
            .id(savedUser.getId())
            .fullName(savedUser.getFullName())
            .email(savedUser.getEmail())
            .role(savedUser.getRole())
            .referenceCode(savedUser.getReferenceCode())
            .message("User registered successfully")
            .build();
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

            return AuthResponse.builder()
                    .id(savedUser.getId())
                    .fullName(savedUser.getFullName())
                    .email(savedUser.getEmail())
                    .role(savedUser.getRole())
                    .referenceCode(savedUser.getReferenceCode())
                    .message("Emlakçı kaydı başarıyla tamamlandı ve hesap aktifleştirildi")
                    .build();
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

            return AuthResponse.builder()
                    .id(savedUser.getId())
                    .fullName(savedUser.getFullName())
                    .email(savedUser.getEmail())
                    .role(savedUser.getRole())
                    .referenceCode(savedUser.getReferenceCode())
                    .message("Emlakçı kaydı başarıyla tamamlandı")
                    .build();
        }
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Invalid credentials");
        }

        return AuthResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole())
                .referenceCode(user.getReferenceCode())
                .message("Login successful")
                .build();
    }
}
