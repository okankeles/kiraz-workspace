# KiraZ PropTech B2B Platformu

KiraZ, mülk sahipleri (**LANDLORD**), kiracılar (**TENANT**), gayrimenkul danışmanları (**AGENT**) ve kurumsal portföy yöneticileri (**PROPERTY_MANAGER**) arasındaki tüm kiralama, sözleşme (Maker-Checker döngüsü), ödeme takibi (PayTR Sanal POS & Havale/EFT dijital kasa) ve portföy operasyonlarını uçtan uca dijitalleştiren kurumsal bir **B2B SaaS PropTech Platformu**dur.

---

## Mimari ve Teknoloji Yığını

- **Backend:** Spring Boot 3.x / Java 17+ (Stateless JWT Kimlik Doğrulama, Kaynak Bazlı Yetkilendirme, Flyway Migration)
- **Frontend:** Flutter SDK ^3.13.5 (iOS, Android, Web çok platformlu istemci)
- **Veritabanı:** PostgreSQL 15+ (Alpine)
- **Olay Akışı (Event Streaming):** Apache Kafka & Zookeeper
- **Loglama & Analitik (ELK):** Elasticsearch 8.x, Logstash, Kibana
- **Ödeme Altyapısı:** PayTR iFrame Sanal POS & Havale/EFT Dekont İnceleme

---

## Yerel Kurulum (Sıfırdan Kurulum Kılavuzu)

Boş bir veritabanı ve temiz bir makinede tüm KiraZ ekosistemini ayağa kaldırmak için aşağıdaki adımları sırasıyla uygulayın:

### 1. Ön Koşullar
Sisteminizde aşağıdaki araçların kurulu olduğunu doğrulayın:
- **Docker & Docker Compose** (v20+)
- **JDK 17+** (Java Development Kit)
- **Flutter SDK** (3.13.5+) & Dart SDK
- **Git**

---

### 2. Ortam Değişkenlerini (.env) Hazırlama
Proje kök dizininde yer alan `.env.example` şablonunu kopyalayarak `.env` dosyasını oluşturun:

```bash
cd /Users/okankeles/kiraz-workspace
cp .env.example .env
```

`.env` dosyasındaki temel parametreler:
- `DB_URL`: `jdbc:postgresql://localhost:5433/kiraz_db`
- `DB_USERNAME`: `ars_admin`
- `DB_PASSWORD`: `<.env dosyasından DB_PASSWORD>`
- `DB_PORT`: `5433`
- `JWT_SECRET`: En az 256-bit güvenli base64 anahtarı
- `API_BASE_URL`: `http://localhost:8080/api`
- `KAFKA_BOOTSTRAP_SERVERS`: `localhost:9092`
- `DEV_SEED_*_PASSWORD`: Dev profili tohumlama parolaları

---

### 3. Altyapı Servislerini Ayağa Kaldırma (Docker Compose)
Tüm altyapı servisleri projenin kök dizinindeki **tek `docker-compose.yml`** dosyasında birleştirilmiştir (`kiraz_backend/` altında mükerrer dosya tutulmaz). PostgreSQL veritabanı kalıcılığı `kiraz_backend_pgdata` isimli Docker volume ile sağlanır.

Kök dizindeki `docker-compose.yml` dosyası PostgreSQL, Kafka, Zookeeper, Elasticsearch, Logstash, Kibana ve Mailpit servislerini tek komutla başlatır. Tüm servis portları güvenlik gereği yalnızca yerel makineye (`127.0.0.1`) bağlanmıştır:

```bash
# Tüm konteynerleri arka planda başlat
docker compose up -d

# Servislerin durumunu kontrol et
docker compose ps
```

Beklenen durum:
- `kiraz_db` (PostgreSQL 15): `127.0.0.1:5433->5432` (Volume: `kiraz_backend_pgdata`)
- `kiraz_mailpit` (Mailpit SMTP / Web UI): `127.0.0.1:1025` (SMTP) / `127.0.0.1:8025` (Web UI - [http://localhost:8025](http://localhost:8025))
- `kiraz_kafka` (Kafka): `127.0.0.1:9092`
- `kiraz_zookeeper`: `127.0.0.1:2181`
- `kiraz_elasticsearch`: `127.0.0.1:9200`
- `kiraz_kibana`: `127.0.0.1:5601`
- `kiraz_logstash`: `127.0.0.1:5000`

---

### 4. Veritabanı Migration ve Test Verisi Tohumlama (Data Seeding)
Backend ilk kez ayağa kalktığında **Flyway** migration motoru şemayı otomatik olarak oluşturur (`V1`, `V2`, `V3`, `V4`).

Geliştirme (`dev`) profili aktifken **dört ana rol** için test kullanıcıları, örnek mülkler, delegasyonlar, sözleşmeler ve kira dönemleri otomatik olarak tohumlanır (veya `./scripts/seed-dev.sh` ile çalıştırılabilir):

```bash
# Tohumlama betiğini çalıştır
./scripts/seed-dev.sh
```

Oluşturulan Dev Test Kullanıcıları (E-postalar RFC 2606 uyumlu `@example.com`, parolalar `.env` dosyasından okunur):
| Rol | E-Posta | Parola Kaynağı | Açıklama |
|:---|:---|:---|:---|
| **LANDLORD** | `dev.landlord@example.com` | `.env` (`DEV_SEED_LANDLORD_PASSWORD`) | Ev Sahibi (Mülk A ve Mülk B sahibi) |
| **TENANT** | `dev.tenant@example.com` | `.env` (`DEV_SEED_TENANT_PASSWORD`) | Kiracı (Mülk A aktif sözleşme kiracısı) |
| **AGENT** | `dev.agent@example.com` | `.env` (`DEV_SEED_AGENT_PASSWORD`) | Emlakçı (Mülk A yetkili emlakçısı - `AGT-DEV12345`) |
| **PROPERTY_MANAGER** | `dev.manager@example.com` | `.env` (`DEV_SEED_MANAGER_PASSWORD`) | Mülk Yöneticisi (Mülk B yetkilisi - `MGR-DEV12345`) |

---

### 5. Backend Uygulamasını Başlatma

```bash
cd kiraz_backend

# Testleri atlayarak hızlı başlatma (Dev profili)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

Backend başarıyla başladığında:
- **API Base:** `http://localhost:8080/api`
- **Swagger UI (Yalnızca Dev Profili):** `http://localhost:8080/swagger-ui/index.html`
- **OpenAPI JSON Spesifikasyonu:** `http://localhost:8080/v3/api-docs`

---

### 6. Frontend Mobil / Web Uygulamasını Başlatma

```bash
cd /Users/okankeles/kiraz-workspace/kiraz_frontend

# Bağımlılıkları yükle
flutter pub get

# Statik kod analizini doğrula (0 hata / 0 uyarı beklenir)
flutter analyze

# Birim ve widget testlerini çalıştır
flutter test

# Uygulamayı başlat (Chrome, macOS masaüstü veya mobil simülatör)
flutter run -d chrome
```

---

### 7. Uçtan Uca Güvenlik Doğrulaması

Sistemin güvenlik kurallarını (IDOR koruması, JWT doğrulaması, hız sınırı, dosya türü filtreleme) test etmek için hazırlanmış betiği çalıştırın:

```bash
# 16 güvenlik senaryosunu canlı API üzerinde doğrula
python3 scripts/run-security-checks.py

# Alternatif olarak JUnit üzerinden MockMvc test suitini çalıştır
cd kiraz_backend
./mvnw test -Dtest=SecurityValidationEndToEndTest
```

---

## Proje Dizin Yapısı

```
kiraz-workspace/
├── .env                                  # Yerel ortam değişkenleri (Hassas sırlar içerir, git'e eklenmez)
├── .env.example                          # Ortam değişkenleri şablonu
├── docker-compose.yml                    # PostgreSQL, Kafka, ELK birleşik orkestrasyon
├── security-checks.http                  # 16 güvenlik senaryosunun HTTP istek koleksiyonu
├── scripts/
│   ├── seed-dev.sh                       # Dev ortamı veri tohumlama betiği
│   └── run-security-checks.py            # Uçtan uca güvenlik test otomasyon betiği
├── docs/
│   └── project_handover_and_architecture_guide.md # Kapsamlı Mimari ve Geliştirici El Kitabı
├── kiraz_backend/                        # Spring Boot REST API Servisi
│   ├── src/main/resources/db/migration/  # Flyway SQL migration dosyaları (V1..V4)
│   └── src/test/java/                    # Entegrasyon ve güvenlik testleri
├── kiraz_frontend/                       # Flutter İstemci Uygulaması
│   ├── lib/services/api_client.dart      # Merkezi JWT & Token Refresh HTTP İstemcisi
│   └── lib/screens/                      # Rol bazlı UI ekranları
└── logstash/                             # Logstash pipeline yapılandırması
```
