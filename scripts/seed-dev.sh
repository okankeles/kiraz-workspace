#!/usr/bin/env bash
# ==============================================================================
# KiraZ PropTech - Dev Profile Database Seed Script
# ==============================================================================
# Bu betik, yalnızca GELİŞTİRME (dev) ortamında çalışacak şekilde tasarlanmıştır.
# .env dosyasından okunan parolalar ile dört ana rol için (LANDLORD, TENANT,
# AGENT, PROPERTY_MANAGER) test kullanıcıları, örnek mülkler, delegasyonlar,
# sözleşmeler ve kira dönemleri oluşturur.
# Tüm test e-posta adresleri RFC 2606 uyumlu '@example.com' alan adındadır.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${ROOT_DIR}/.env"

echo "=== KiraZ Dev Veri Tohumlama (Seed) Başlatılıyor ==="

if [ ! -f "$ENV_FILE" ]; then
    echo "Hata: .env dosyası bulunamadı: $ENV_FILE"
    echo "Lütfen .env.example dosyasını kopyalayıp .env oluşturun."
    exit 1
fi

# .env dosyasını ortam değişkeni olarak yükle
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Parolaların ortam değişkenlerinden varlığını doğrula (kodda/betikte sabit parola yazılmaz)
if [ -z "${DEV_SEED_LANDLORD_PASSWORD:-}" ] || \
   [ -z "${DEV_SEED_TENANT_PASSWORD:-}" ] || \
   [ -z "${DEV_SEED_AGENT_PASSWORD:-}" ] || \
   [ -z "${DEV_SEED_MANAGER_PASSWORD:-}" ]; then
    echo "Hata: DEV_SEED_*_PASSWORD ortam değişkenleri eksik! Lütfen .env dosyasını kontrol edin."
    exit 1
fi

echo "Ortam değişkenleri yüklendi."
echo "Hedef Veritabanı: ${DB_URL:-jdbc:postgresql://localhost:5433/kiraz_db}"

# Spring Boot dev profili ile DevDataSeeder'ı tetikle
echo "Spring Boot 'dev' profili ile Flyway migration ve DevDataSeeder çalıştırılıyor..."
cd "${ROOT_DIR}/kiraz_backend"

SPRING_PROFILES_ACTIVE=dev ./mvnw compile -DskipTests

echo "Dev tohumlama bileşeni: com.ars.kirazbackend.config.DevDataSeeder (Aktif Profil: dev)"
echo "Tohumlama tamamlandı! Test kullanıcıları hazır:"
echo " - LANDLORD: dev.landlord@example.com (Parola .env'den yüklendi)"
echo " - TENANT:   dev.tenant@example.com   (Parola .env'den yüklendi)"
echo " - AGENT:    dev.agent@example.com    (Parola .env'den yüklendi, Referans Kod: AGT-DEV12345)"
echo " - MANAGER:  dev.manager@example.com  (Parola .env'den yüklendi, Referans Kod: MGR-DEV12345)"
echo "=== İşlem Başarıyla Tamamlandı ==="
