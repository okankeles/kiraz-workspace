package com.ars.kirazbackend.support;

import com.ars.kirazbackend.entity.User;
import com.ars.kirazbackend.enums.RoleType;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class AuthTestHelper {

    public static final String TEST_SECRET = "dummyTestSecretKeyForJwtAuthenticationMustBeAtLeast256BitsLongForHmacSha256!";
    private static final SecretKey SECRET_KEY = Keys.hmacShaKeyFor(TEST_SECRET.getBytes(StandardCharsets.UTF_8));

    public static String generateValidToken(Long userId, String email, RoleType role) {
        return generateToken(userId, email, role, 15 * 60 * 1000);
    }

    public static String generateValidToken(User user) {
        return generateValidToken(user.getId(), user.getEmail(), user.getRole());
    }

    public static String generateExpiredToken(Long userId, String email, RoleType role) {
        return generateToken(userId, email, role, -1000); // expired 1s ago
    }

    public static String generateTokenWithInvalidSignature(Long userId, String email, RoleType role) {
        SecretKey wrongKey = Keys.hmacShaKeyFor("anotherSecretKeyThatDoesNotMatchTheExpectedKeyAtLeast256Bits!".getBytes(StandardCharsets.UTF_8));
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("role", role != null ? role.name() : "")
                .claim("email", email)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 60000))
                .signWith(wrongKey)
                .compact();
    }

    private static String generateToken(Long userId, String email, RoleType role, long validityMs) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("role", role != null ? role.name() : "")
                .claim("email", email)
                .issuedAt(new Date(now))
                .expiration(new Date(now + validityMs))
                .signWith(SECRET_KEY)
                .compact();
    }

    public static UsernamePasswordAuthenticationToken createAuthentication(User user) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        if (user.getRole() != null) {
            authorities.add(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()));
            authorities.add(new SimpleGrantedAuthority(user.getRole().name()));
            if (user.getRole() == RoleType.AGENT || user.getRole() == RoleType.PROPERTY_MANAGER) {
                authorities.add(new SimpleGrantedAuthority("ROLE_PROPERTY_MANAGER"));
                authorities.add(new SimpleGrantedAuthority("PROPERTY_MANAGER"));
                authorities.add(new SimpleGrantedAuthority("ROLE_AGENT"));
                authorities.add(new SimpleGrantedAuthority("AGENT"));
            }
        }
        return new UsernamePasswordAuthenticationToken(user, null, authorities);
    }
}
