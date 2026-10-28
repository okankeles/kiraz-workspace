package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.AuthResponse;
import com.ars.kirazbackend.dto.LoginRequest;
import com.ars.kirazbackend.dto.RegisterRequest;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new RuntimeException("Email already in use");
        }

        String referenceCode = request.getReferenceCode();
        if (request.getRole() == RoleType.LANDLORD) {
            referenceCode = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        }

        User user = User.builder()
            .fullName(request.getFullName())
            .email(request.getEmail())
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
