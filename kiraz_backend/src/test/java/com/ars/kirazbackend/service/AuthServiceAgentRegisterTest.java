package com.ars.kirazbackend.service;

import com.ars.kirazbackend.dto.AuthResponse;
import com.ars.kirazbackend.dto.RegisterRequest;
import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import com.ars.kirazbackend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceAgentRegisterTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private AuthService authService;

    private User placeholderAgent;

    @BeforeEach
    void setUp() {
        placeholderAgent = User.builder()
                .id(10L)
                .email("placeholder@emlak.com")
                .fullName("Emlakçı")
                .role(RoleType.AGENT)
                .referenceCode("AGT-ABC12345")
                .passwordHash("temp_hash")
                .build();
    }

    @Test
    void testRegisterAgent_WithValidReferenceCode_ActivatesPlaceholder() {
        RegisterRequest request = RegisterRequest.builder()
                .fullName("Sertan Gerçek Emlakçı")
                .email("placeholder@emlak.com")
                .password("YeniSifre123!")
                .phone("05321112233")
                .role(RoleType.AGENT)
                .referenceCode("AGT-ABC12345")
                .build();

        when(userRepository.findByReferenceCode("AGT-ABC12345")).thenReturn(Optional.of(placeholderAgent));
        when(userRepository.findByEmail("placeholder@emlak.com")).thenReturn(Optional.of(placeholderAgent));
        when(passwordEncoder.encode("YeniSifre123!")).thenReturn("encoded_new_password");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AuthResponse response = authService.register(request);

        assertNotNull(response);
        assertEquals(10L, response.getId());
        assertEquals("Sertan Gerçek Emlakçı", response.getFullName());
        assertEquals("placeholder@emlak.com", response.getEmail());
        assertEquals("AGT-ABC12345", response.getReferenceCode());
        assertEquals(RoleType.AGENT, response.getRole());

        assertEquals("encoded_new_password", placeholderAgent.getPasswordHash());
        assertEquals("05321112233", placeholderAgent.getPhone());
        verify(userRepository, times(1)).save(placeholderAgent);
    }

    @Test
    void testRegisterAgent_WithInvalidReferenceCode_ThrowsException() {
        RegisterRequest request = RegisterRequest.builder()
                .fullName("Emlakçı")
                .email("test@emlak.com")
                .password("pass")
                .role(RoleType.AGENT)
                .referenceCode("AGT-INVALID")
                .build();

        when(userRepository.findByReferenceCode("AGT-INVALID")).thenReturn(Optional.empty());

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));
        assertTrue(ex.getMessage().contains("Geçersiz referans kodu"));
    }

    @Test
    void testRegisterAgent_WithExistingEmailOfAnotherUser_ThrowsException() {
        User anotherUser = User.builder().id(99L).email("another@test.com").build();

        RegisterRequest request = RegisterRequest.builder()
                .fullName("Emlakçı")
                .email("another@test.com")
                .password("pass")
                .role(RoleType.AGENT)
                .referenceCode("AGT-ABC12345")
                .build();

        when(userRepository.findByReferenceCode("AGT-ABC12345")).thenReturn(Optional.of(placeholderAgent));
        when(userRepository.findByEmail("another@test.com")).thenReturn(Optional.of(anotherUser));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));
        assertTrue(ex.getMessage().contains("başka bir kullanıcı"));
    }

    @Test
    void testRegisterAgent_WithoutReferenceCode_WhenPlaceholderExists_ThrowsNotice() {
        RegisterRequest request = RegisterRequest.builder()
                .fullName("Emlakçı")
                .email("placeholder@emlak.com")
                .password("pass")
                .role(RoleType.AGENT)
                .referenceCode(null)
                .build();

        when(userRepository.findByEmail("placeholder@emlak.com")).thenReturn(Optional.of(placeholderAgent));

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));
        System.out.println("Actual message: [" + ex.getMessage() + "]");
        assertTrue(ex.getMessage().contains("davet") || ex.getMessage().contains("referans"));
    }

    @Test
    void testRegisterLandlord_Success() {
        RegisterRequest request = RegisterRequest.builder()
                .fullName("Ahmet Ev Sahibi")
                .email("ahmet@evsahibi.com")
                .password("Pass123!")
                .role(RoleType.LANDLORD)
                .build();

        when(userRepository.findByEmail("ahmet@evsahibi.com")).thenReturn(Optional.empty());
        when(passwordEncoder.encode("Pass123!")).thenReturn("hash");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User u = invocation.getArgument(0);
            u.setId(1L);
            return u;
        });

        AuthResponse response = authService.register(request);

        assertNotNull(response);
        assertEquals(RoleType.LANDLORD, response.getRole());
        assertNotNull(response.getReferenceCode());
    }
}
