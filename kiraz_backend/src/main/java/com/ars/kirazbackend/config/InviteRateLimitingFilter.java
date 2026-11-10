package com.ars.kirazbackend.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * IP başına hız sınırlayıcı (Rate Limiting) filtresi.
 * Kimlik doğrulamasız çalışan /api/leases/accept ve /api/leases/validate-invite
 * uç noktalarına kaba kuvvet (brute-force) ve spam saldırılarını önlemek için
 * IP başına dakikada maksimum 10 isteğe izin verir.
 */
@Slf4j
@Component
public class InviteRateLimitingFilter extends OncePerRequestFilter {

    public static final int MAX_REQUESTS_PER_MINUTE = 10;
    public static final long WINDOW_MILLIS = 60_000L; // 1 dakika

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final ConcurrentHashMap<String, RequestCounter> ipCounters = new ConcurrentHashMap<>();

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return !path.equals("/api/leases/accept") && !path.equals("/api/leases/validate-invite");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String clientIp = resolveClientIp(request);
        RequestCounter counter = ipCounters.computeIfAbsent(clientIp, k -> new RequestCounter());

        if (!counter.allowRequest(MAX_REQUESTS_PER_MINUTE, WINDOW_MILLIS)) {
            log.warn("Rate limit aşıldı: clientIp={}, path={}", clientIp, request.getRequestURI());
            writeTooManyRequestsResponse(response);
            return;
        }

        // Periyodik hafıza temizliği
        if (ipCounters.size() > 1000) {
            long now = System.currentTimeMillis();
            ipCounters.entrySet().removeIf(entry -> now - entry.getValue().windowStart > WINDOW_MILLIS * 2);
        }

        filterChain.doFilter(request, response);
    }

    private void writeTooManyRequestsResponse(HttpServletResponse response) throws IOException {
        response.setStatus(429);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");

        Map<String, Object> body = Map.of(
                "status", 429,
                "error", "Too Many Requests",
                "message", "Çok fazla istek yapıldı. Lütfen 1 dakika sonra tekrar deneyin."
        );

        response.getWriter().write(objectMapper.writeValueAsString(body));
    }

    @org.springframework.beans.factory.annotation.Value("${kiraz.security.trusted-proxies:}")
    private String trustedProxiesConfig;

    public String resolveClientIp(HttpServletRequest request) {
        String remoteAddr = request.getRemoteAddr();
        if (isTrustedProxy(remoteAddr)) {
            String clientIp = request.getHeader("X-Forwarded-For");
            if (clientIp != null && !clientIp.trim().isEmpty() && !"unknown".equalsIgnoreCase(clientIp)) {
                if (clientIp.contains(",")) {
                    return clientIp.split(",")[0].trim();
                }
                return clientIp.trim();
            }
            clientIp = request.getHeader("X-Real-IP");
            if (clientIp != null && !clientIp.trim().isEmpty() && !"unknown".equalsIgnoreCase(clientIp)) {
                return clientIp.trim();
            }
        }
        return remoteAddr;
    }

    private boolean isTrustedProxy(String remoteAddr) {
        if (remoteAddr == null || trustedProxiesConfig == null || trustedProxiesConfig.trim().isEmpty()) {
            return false;
        }
        for (String trusted : trustedProxiesConfig.split(",")) {
            if (trusted.trim().equalsIgnoreCase(remoteAddr.trim())) {
                return true;
            }
        }
        return false;
    }

    public void resetForTesting() {
        ipCounters.clear();
    }

    private static class RequestCounter {
        private final AtomicInteger count = new AtomicInteger(0);
        private volatile long windowStart = System.currentTimeMillis();

        synchronized boolean allowRequest(int maxRequests, long windowMillis) {
            long now = System.currentTimeMillis();
            if (now - windowStart >= windowMillis) {
                windowStart = now;
                count.set(0);
            }
            return count.incrementAndGet() <= maxRequests;
        }
    }
}
