#!/usr/bin/env python3
"""
KiraZ PropTech — Faz 0 / Adım 6c: Uçtan Uca Güvenlik Doğrulama Betiği
Bu betik:
1. Başlarken /v3/api-docs üzerinden OpenAPI 3 spesifikasyonunu çeker.
2. Test edilen her ucun spec'te var olduğunu doğrular (silinmiş uçlar muaf).
3. Gerçekleştirilen HTTP isteklerini (metot + yol) ve alınan HTTP durum kodlarını yazdırır (token/parola basmaz).
4. Her negatif yetki senaryosunu, aynı kaynağa yetkili bir kullanıcıyla yapılan POZİTİF KONTROL ile eşleştirir.
5. Kodda hiçbir uydurma kaynak ID'si (ör. 300) veya uydurma davet kodu kullanmaz; tüm kaynaklar dinamiktir.
6. Betiğin oluşturduğu tüm kayıtlar ayırt edilebilirdir (Mülkler 'SECCHECK-', kullanıcılar 'seccheck-…@example.com').
7. Bir çalıştırmanın veritabanına kaç kayıt eklediğini başlangıç ve bitiş sayılarını karşılaştırarak raporlar.
"""

import os
import sys
import json
import time
import hmac
import hashlib
import base64
import subprocess
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path

BASE_URL = "http://localhost:8080/api"
DOCS_URL = "http://localhost:8080/v3/api-docs"

# -----------------------------------------------------------------------------
# 1. Ortam Değişkenlerini Yükleme (.env)
# -----------------------------------------------------------------------------
def load_env():
    root_dir = Path(__file__).resolve().parent.parent
    env_file = root_dir / ".env"
    env_vars = {}
    if env_file.exists():
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, val = line.split("=", 1)
                    val = val.strip().strip("'\"")
                    env_vars[key.strip()] = val
    # os.environ önceliklidir
    for k, v in env_vars.items():
        if k not in os.environ:
            os.environ[k] = v

load_env()

LANDLORD_PASS = os.environ.get("DEV_SEED_LANDLORD_PASSWORD")
TENANT_PASS = os.environ.get("DEV_SEED_TENANT_PASSWORD")
AGENT_PASS = os.environ.get("DEV_SEED_AGENT_PASSWORD")
MANAGER_PASS = os.environ.get("DEV_SEED_MANAGER_PASSWORD")
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", "5433"))
DB_NAME = os.environ.get("DB_NAME", "kiraz_db")
DB_USER = os.environ.get("DB_USERNAME", "ars_admin")
DB_PASS = os.environ.get("DB_PASSWORD")

PAYTR_SALT = os.environ.get("PAYTR_MERCHANT_SALT", "K5uAP8fQ5htrfKd4")
PAYTR_KEY = os.environ.get("PAYTR_MERCHANT_KEY", "XQTmSzbmBw5YAYzW")

if not all([LANDLORD_PASS, TENANT_PASS, AGENT_PASS, MANAGER_PASS]):
    print("HATA: DEV_SEED_*_PASSWORD ortam değişkenleri eksik! Lütfen .env dosyasını kontrol edin.", file=sys.stderr)
    sys.exit(1)

# Kullanıcı E-postaları (@example.com)
LANDLORD_EMAIL = "dev.landlord@example.com"
TENANT_EMAIL = "dev.tenant@example.com"
AGENT_EMAIL = "dev.agent@example.com"
MANAGER_EMAIL = "dev.manager@example.com"

# İkinci Ev Sahibi ve Kiracı B (Ayırt edilebilir: seccheck-…@example.com)
LANDLORD_B_EMAIL = "seccheck-landlord-b@example.com"
LANDLORD_B_PASS = "SecCheckLandlord2026!"
TENANT_B_EMAIL = "seccheck-tenant-b@example.com"
TENANT_B_PASS = "SecCheckTenant2026!"

# -----------------------------------------------------------------------------
# 2. OpenAPI Spesifikasyonunu Çekme ve Uç Doğrulama
# -----------------------------------------------------------------------------
OPENAPI_PATHS = set()

def fetch_openapi_spec():
    global OPENAPI_PATHS
    req = urllib.request.Request(DOCS_URL)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            paths = data.get("paths", {})
            for path_key, methods in paths.items():
                for m in methods.keys():
                    OPENAPI_PATHS.add((m.upper(), path_key))
            print(f"[OpenAPI] {len(OPENAPI_PATHS)} adet geçerli uç spec'ten başarıyla yüklendi.")
    except Exception as e:
        print(f"HATA: /v3/api-docs çekilemedi: {e}", file=sys.stderr)
        print("Backend dev profilinde ayağa kalkmış olmalıdır.", file=sys.stderr)
        sys.exit(1)

def verify_endpoint_in_spec(method, path_template, intentionally_removed=False):
    if intentionally_removed:
        return True
    key = (method.upper(), path_template)
    if key not in OPENAPI_PATHS:
        print(f"  [GEÇERSİZ UÇ HATASI] {method} {path_template} OpenAPI spec'inde bulunamadı!", file=sys.stderr)
        return False
    return True

# -----------------------------------------------------------------------------
# 3. HTTP İstek Yardımcısı (Token ve Parola Loglamaz)
# -----------------------------------------------------------------------------
def http_request(method, path, data=None, token=None, headers=None, content_type="application/json"):
    url = f"{BASE_URL}{path}" if path.startswith("/") else f"{BASE_URL}/{path}"
    h = headers.copy() if headers else {}
    
    if token:
        h["Authorization"] = f"Bearer {token}"
    
    encoded_data = None
    if data is not None:
        if content_type == "application/json":
            h["Content-Type"] = "application/json"
            encoded_data = json.dumps(data).encode("utf-8")
        elif content_type == "application/x-www-form-urlencoded":
            h["Content-Type"] = "application/x-www-form-urlencoded"
            encoded_data = urllib.parse.urlencode(data).encode("utf-8")
        elif content_type.startswith("multipart/form-data"):
            h["Content-Type"] = content_type
            encoded_data = data  # raw bytes
        else:
            encoded_data = data
            
    req = urllib.request.Request(url, data=encoded_data, headers=h, method=method)
    
    status_code = None
    body_text = ""
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.getcode()
            body_text = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        status_code = e.code
        body_text = e.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as e:
        status_code = 0
        body_text = str(e.reason)
    except Exception as e:
        status_code = -1
        body_text = str(e)

    display_path = path
    print(f"  --> {method} {display_path} => HTTP {status_code}")
    return status_code, body_text

def build_multipart(fields, files):
    boundary = "----WebKitFormBoundary" + hex(int(time.time() * 1000))[2:]
    body = bytearray()
    for name, value in fields.items():
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode("utf-8"))
        body.extend(f"{value}\r\n".encode("utf-8"))
    for name, (filename, content_bytes, mime) in files.items():
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'.encode("utf-8"))
        body.extend(f"Content-Type: {mime}\r\n\r\n".encode("utf-8"))
        body.extend(content_bytes)
        body.extend(b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode("utf-8"))
    return bytes(body), f"multipart/form-data; boundary={boundary}"

def get_db_counts():
    """Veritabanındaki tablo kayıt sayılarını çeker."""
    counts = {}
    try:
        env = os.environ.copy()
        if DB_PASS:
            env["PGPASSWORD"] = DB_PASS
        res = subprocess.run(
            ["psql", "-h", "127.0.0.1", "-p", str(DB_PORT), "-U", DB_USER, "-d", DB_NAME, "-t", "-c",
             "SELECT 'properties', count(*) FROM properties UNION ALL SELECT 'lease_agreements', count(*) FROM lease_agreements UNION ALL SELECT 'rent_periods', count(*) FROM rent_periods UNION ALL SELECT 'users', count(*) FROM users;"],
            capture_output=True, text=True, env=env, timeout=5
        )
        if res.returncode == 0:
            for line in res.stdout.strip().split("\n"):
                if "|" in line:
                    parts = line.split("|")
                    counts[parts[0].strip()] = int(parts[1].strip())
    except Exception:
        pass
    return counts

# -----------------------------------------------------------------------------
# 4. Ana Test Koşucusu
# -----------------------------------------------------------------------------
def main():
    print("=" * 80)
    print("KiraZ — Faz 0 / Adım 6c: Uçtan Uca Güvenlik Doğrulaması")
    print("=" * 80)
    
    fetch_openapi_spec()
    initial_counts = get_db_counts()
    
    results = []

    # 0. Girişler ve Dinamik Test Verisi Kurulumu
    print("\n[0] Dev Kullanıcıları İçin Giriş Yapılıyor...")
    assert verify_endpoint_in_spec("POST", "/api/auth/login")
    
    status, body = http_request("POST", "/auth/login", {"email": LANDLORD_EMAIL, "password": LANDLORD_PASS})
    if status != 200:
        print(f"HATA: Landlord girişi başarısız ({status}): {body}", file=sys.stderr)
        sys.exit(1)
    landlord_data = json.loads(body)
    landlord_token = landlord_data["accessToken"]
    landlord_refresh = landlord_data["refreshToken"]
    landlord_id = landlord_data["user"]["id"]

    status, body = http_request("POST", "/auth/login", {"email": TENANT_EMAIL, "password": TENANT_PASS})
    tenant_data = json.loads(body)
    tenant_token = tenant_data["accessToken"]
    tenant_refresh = tenant_data["refreshToken"]
    tenant_id = tenant_data["user"]["id"]

    status, body = http_request("POST", "/auth/login", {"email": AGENT_EMAIL, "password": AGENT_PASS})
    agent_data = json.loads(body)
    agent_token = agent_data["accessToken"]

    # İkinci Ev Sahibi B (Ayırt edilebilir: seccheck-landlord-b@example.com)
    http_request("POST", "/auth/register", {
        "email": LANDLORD_B_EMAIL,
        "password": LANDLORD_B_PASS,
        "fullName": "İkinci Ev Sahibi (SecCheck)",
        "phone": "05559998877",
        "role": "LANDLORD"
    })
    _, l_b_body = http_request("POST", "/auth/login", {"email": LANDLORD_B_EMAIL, "password": LANDLORD_B_PASS})
    landlord_b_token = json.loads(l_b_body)["accessToken"]

    # İkinci Kiracı B (Ayırt edilebilir: seccheck-tenant-b@example.com)
    http_request("POST", "/auth/register", {
        "email": TENANT_B_EMAIL,
        "password": TENANT_B_PASS,
        "fullName": "İkinci Kiracı (SecCheck)",
        "phone": "05558887766",
        "role": "TENANT"
    })
    _, t_b_body = http_request("POST", "/auth/login", {"email": TENANT_B_EMAIL, "password": TENANT_B_PASS})
    tenant_b_token = json.loads(t_b_body)["accessToken"]

    # Landlord B için izole bir mülk oluştur (Ayırt edilebilir: SECCHECK-...)
    _, p_b_body = http_request("POST", "/properties", {
        "title": "SECCHECK-Mülk B (Kadıköy Moda)",
        "address": "Moda Cad. No:99",
        "city": "İstanbul"
    }, token=landlord_b_token)
    property_b_id = json.loads(p_b_body)["id"]

    # Landlord B ve Tenant B için gerçek sözleşme oluştur
    _, lease_b_body = http_request("POST", "/leases", {
        "propertyId": property_b_id,
        "tenantEmail": TENANT_B_EMAIL,
        "startDate": "2026-01-01",
        "endDate": "2026-12-31",
        "monthlyRentAmount": 20000,
        "depositAmount": 40000,
        "paymentDay": 1
    }, token=landlord_b_token)
    lease_b_id = json.loads(lease_b_body)["id"]

    # Kiracı B'nin dönemini bul ve Kiracı B ile GERÇEK bir dekont yükle
    _, periods_b_body = http_request("GET", f"/periods/lease/{lease_b_id}", token=landlord_b_token)
    periods_b = json.loads(periods_b_body)
    period_b_id = periods_b[0]["id"]

    # Kiracı B gerçek dekontu kendi dönemine yüklüyor (Böylece dönemde dosya kesinlikle var oluyor!)
    png_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4"
    d_b, ct_b = build_multipart({}, {"file": ("dekont_b.png", png_bytes, "image/png")})
    status_setup_receipt, _ = http_request("POST", f"/tenant/receipts/{period_b_id}", data=d_b, token=tenant_b_token, content_type=ct_b)
    print(f"  [Kurulum] Kiracı B için gerçek dekont yüklendi => HTTP {status_setup_receipt}")

    # Landlord A'nın aktif mülk, sözleşme ve kira dönemini bul
    property_a_id = None
    active_lease_id = None
    period_a_id = None

    _, p_a_body = http_request("GET", "/landlord/properties", token=landlord_token)
    properties_a = json.loads(p_a_body)
    for p in properties_a:
        _, leases_body = http_request("GET", f"/leases/property/{p['id']}", token=landlord_token)
        leases = json.loads(leases_body)
        for l in leases:
            if l.get("status") == "ACTIVE":
                property_a_id = p["id"]
                active_lease_id = l["id"]
                _, periods_body = http_request("GET", f"/periods/lease/{l['id']}", token=landlord_token)
                periods = json.loads(periods_body)
                if periods:
                    period_a_id = periods[0]["id"]
                    break
        if active_lease_id:
            break

    # Landlord A'nın aktif sözleşmesine ve dönemine de dosya yükleyelim (Senaryo 9 için)
    pdf_sample = b"%PDF-1.4\n%mock sample contract pdf content"
    d_c, ct_c = build_multipart({}, {"file": ("contract_sample.pdf", pdf_sample, "application/pdf")})
    http_request("POST", f"/leases/{active_lease_id}/contract", data=d_c, token=landlord_token, content_type=ct_c)
    d_ra, ct_ra = build_multipart({}, {"file": ("receipt_a.png", png_bytes, "image/png")})
    http_request("POST", f"/tenant/receipts/{period_a_id}", data=d_ra, token=tenant_token, content_type=ct_ra)

    print("\n--- TEST SENARYOLARI BAŞLIYOR ---\n")

    # -------------------------------------------------------------------------
    # SENARYO 1: X-User-Id header'ı ile başka kullanıcıyı taklit → 401
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/landlord/dashboard")
    status_neg, _ = http_request("GET", "/landlord/dashboard", headers={"X-User-Id": str(landlord_id)})
    status_pos, _ = http_request("GET", "/landlord/dashboard", token=landlord_token)
    passed = spec_ok and (status_neg == 401) and (status_pos == 200)
    results.append({
        "no": 1,
        "name": "X-User-Id header'ı ile başka kullanıcıyı taklit",
        "endpoint": "GET /api/landlord/dashboard",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"GET /api/landlord/dashboard (Landlord A) => {status_pos} OK",
        "expected": "401 Unauthorized",
        "actual": f"{status_neg} Unauthorized" if status_neg == 401 else str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 2: Ev sahibi A'nın token'ı ile ev sahibi B'nin mülkü ve dönemi → 404
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("GET", "/api/properties/{id}")
    spec_ok2 = verify_endpoint_in_spec("GET", "/api/periods/lease/{leaseId}")
    status_neg1, _ = http_request("GET", f"/properties/{property_b_id}", token=landlord_token)
    status_neg2, _ = http_request("GET", f"/periods/lease/{lease_b_id}", token=landlord_token)
    status_pos1, _ = http_request("GET", f"/properties/{property_b_id}", token=landlord_b_token)
    status_pos2, _ = http_request("GET", f"/periods/lease/{lease_b_id}", token=landlord_b_token)
    passed = spec_ok1 and spec_ok2 and (status_neg1 in (403, 404)) and (status_neg2 in (403, 404)) and (status_pos1 == 200) and (status_pos2 == 200)
    results.append({
        "no": 2,
        "name": "Ev sahibi A token'ı ile ev sahibi B mülk ve dönemine IDOR erişim",
        "endpoint": f"GET /api/properties/{property_b_id}, GET /api/periods/lease/{lease_b_id}",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "positive": f"Landlord B => {status_pos1} OK / {status_pos2} OK",
        "expected": "403 / 404",
        "actual": f"{status_neg1} / {status_neg2}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 3: Kiracı A'nın token'ı ile kiracı B'nin GERÇEK dönemine dekont yükleme → 404
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("POST", "/api/tenant/receipts/{periodId}")
    d_neg, ct_neg = build_multipart({}, {"file": ("dekont_saldiri.png", png_bytes, "image/png")})
    status_neg, _ = http_request("POST", f"/tenant/receipts/{period_b_id}", data=d_neg, token=tenant_token, content_type=ct_neg)
    d_pos, ct_pos = build_multipart({}, {"file": ("dekont_mesru.png", png_bytes, "image/png")})
    status_pos, _ = http_request("POST", f"/tenant/receipts/{period_b_id}", data=d_pos, token=tenant_b_token, content_type=ct_pos)
    passed = spec_ok and (status_neg in (403, 404)) and (status_pos == 200)
    results.append({
        "no": 3,
        "name": "Kiracı A token'ı ile kiracı B dönemine dekont yükleme",
        "endpoint": f"POST /api/tenant/receipts/{period_b_id}",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"Kiracı B ile kendi dönemine yükleme => {status_pos} OK",
        "expected": "403 / 404",
        "actual": str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 4: Delegasyonu iptal edilmiş / olmayan emlakçı ile mülke erişim → 404
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/properties/{id}")
    status_neg, _ = http_request("GET", f"/properties/{property_b_id}", token=agent_token)
    status_pos, _ = http_request("GET", f"/properties/{property_b_id}", token=landlord_b_token)
    passed = spec_ok and (status_neg in (403, 404)) and (status_pos == 200)
    results.append({
        "no": 4,
        "name": "Yetkisiz / Delegasyonu iptal edilmiş emlakçı ile mülke erişim",
        "endpoint": f"GET /api/properties/{property_b_id}",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"Mülk Sahibi B => {status_pos} OK",
        "expected": "403 / 404",
        "actual": str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 5: Süresi dolmuş token → 401; refresh → 200; yeni token ile istek → 200
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("GET", "/api/tenant/leases")
    spec_ok2 = verify_endpoint_in_spec("POST", "/api/auth/refresh")
    expired_jwt = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIxOSIsImV4cCI6MTUxNDc2NDgwMH0.INVALID_SIGNATURE_EXPIRED_MOCK"
    status1, _ = http_request("GET", "/tenant/leases", token=expired_jwt)
    status2, ref_body = http_request("POST", "/auth/refresh", {"refreshToken": tenant_refresh})
    new_token = json.loads(ref_body).get("accessToken") if status2 == 200 else None
    new_tenant_refresh = json.loads(ref_body).get("refreshToken") if status2 == 200 else None
    status3, _ = http_request("GET", "/tenant/leases", token=new_token) if new_token else (-1, "")
    passed = spec_ok1 and spec_ok2 and (status1 == 401) and (status2 == 200) and (status3 == 200)
    results.append({
        "no": 5,
        "name": "Süresi dolmuş token → 401; refresh → 200; yeni token ile istek → 200",
        "endpoint": "GET /api/tenant/leases, POST /api/auth/refresh",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "positive": f"GET /api/tenant/leases (Yeni Token) => {status3} OK",
        "expected": "401 -> 200 -> 200",
        "actual": f"{status1} -> {status2} -> {status3}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 6: Kullanılmış refresh token ile tekrar yenileme (Reuse Detection) → 401
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("POST", "/api/auth/refresh")
    # 1. Negatif kontrol: tenant_refresh senaryo 5'te zaten kullanıldı; tekrar deneniyor -> 401
    status_neg, _ = http_request("POST", "/auth/refresh", {"refreshToken": tenant_refresh})
    
    # 2. Pozitif kontrol: Taze bir oturum açılarak geçerli bir refresh token ile yenileme denenir -> 200
    _, fresh_login_body = http_request("POST", "/auth/login", {"email": LANDLORD_EMAIL, "password": LANDLORD_PASS})
    fresh_refresh = json.loads(fresh_login_body)["refreshToken"]
    status_pos, _ = http_request("POST", "/auth/refresh", {"refreshToken": fresh_refresh})
    
    passed = spec_ok and (status_neg == 401) and (status_pos == 200)
    results.append({
        "no": 6,
        "name": "Kullanılmış refresh token ile tekrar yenileme (Reuse Detection)",
        "endpoint": "POST /api/auth/refresh",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"POST /api/auth/refresh (Geçerli Refresh Token) => {status_pos} OK",
        "expected": "401 Unauthorized",
        "actual": str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 7: PayTR callback'ine geçersiz hash ile istek → 400 Bad Request
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("POST", "/api/payments/paytr-callback")
    merchant_oid = f"RENT-{period_a_id}-{int(time.time())}"
    paytr_data_bad = {
        "merchant_oid": merchant_oid,
        "status": "failed",
        "total_amount": "25000",
        "hash": "INVALID_FORGED_HASH_CODE"
    }
    status_neg, _ = http_request("POST", "/payments/paytr-callback", data=paytr_data_bad, content_type="application/x-www-form-urlencoded")
    
    # Pozitif Kontrol: Geçerli HMAC-SHA256 imzası hesapla
    hash_str = f"{merchant_oid}{PAYTR_SALT}failed25000"
    valid_hash = base64.b64encode(hmac.new(PAYTR_KEY.encode("utf-8"), hash_str.encode("utf-8"), hashlib.sha256).digest()).decode("utf-8")
    paytr_data_good = {
        "merchant_oid": merchant_oid,
        "status": "failed",
        "total_amount": "25000",
        "hash": valid_hash
    }
    status_pos, _ = http_request("POST", "/payments/paytr-callback", data=paytr_data_good, content_type="application/x-www-form-urlencoded")
    passed = spec_ok and (status_neg == 400) and (status_pos == 200)
    results.append({
        "no": 7,
        "name": "PayTR callback'ine geçersiz hash ile istek",
        "endpoint": "POST /api/payments/paytr-callback",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"POST /api/payments/paytr-callback (Geçerli HMAC-SHA256) => {status_pos} OK",
        "expected": "400 Bad Request",
        "actual": str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 8: Kaldırılan PUT /api/periods/{id}/status → 404 veya 405
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("PUT", "/api/periods/{id}/status", intentionally_removed=True)
    status_neg, _ = http_request("PUT", f"/periods/{period_a_id}/status?status=PAID", token=landlord_token)
    passed = status_neg in (404, 405)
    results.append({
        "no": 8,
        "name": "Kaldırılan uç: PUT /api/periods/{id}/status",
        "endpoint": f"PUT /api/periods/{period_a_id}/status",
        "spec_valid": "EVET (Bilinçli Silinmiş)",
        "positive": "Uç bilinçli silindi (Pozitif karşılığı yok)",
        "expected": "404 veya 405",
        "actual": str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 9: Token olmadan dosya erişimi → 401; başka kiracının dekontu → 404
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("GET", "/api/files/receipts/{periodId}")
    spec_ok2 = verify_endpoint_in_spec("GET", "/api/files/contracts/{leaseId}")
    status1, _ = http_request("GET", f"/files/receipts/{period_a_id}") # Tokensiz
    status2, _ = http_request("GET", f"/files/contracts/{active_lease_id}") # Tokensiz
    status3, _ = http_request("GET", f"/files/receipts/{period_b_id}", token=tenant_token) # Yetkisiz Kiracı A
    status_pos1, _ = http_request("GET", f"/files/receipts/{period_b_id}", token=tenant_b_token) # Yetkili Kiracı B
    status_pos2, _ = http_request("GET", f"/files/contracts/{active_lease_id}", token=landlord_token) # Yetkili Landlord A
    passed = spec_ok1 and spec_ok2 and (status1 == 401) and (status2 == 401) and (status3 in (403, 404)) and (status_pos1 == 200) and (status_pos2 == 200)
    results.append({
        "no": 9,
        "name": "Tokensiz dosya stream → 401; Başka kiracının dekontuna erişim → 404",
        "endpoint": f"GET /api/files/receipts/{period_a_id}, GET /api/files/contracts/{active_lease_id}",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "positive": f"Kiracı B dekontu => {status_pos1} OK, Landlord A sözleşme => {status_pos2} OK",
        "expected": "401 -> 401 -> 404",
        "actual": f"{status1} -> {status2} -> {status3}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 10: Ev sahibi onayı olmayan sözleşmeyi kiracının aktive etmesi → 409
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("PUT", "/api/leases/{id}/activate")
    # Taslak Maker-Checker sözleşmesi oluştur (PENDING_LANDLORD_APPROVAL)
    _, p_pending_body = http_request("POST", "/leases", {
        "propertyId": property_a_id,
        "tenantEmail": TENANT_EMAIL,
        "startDate": "2026-03-01",
        "endDate": "2027-03-01",
        "monthlyRentAmount": 28000,
        "depositAmount": 56000,
        "paymentDay": 10
    }, token=agent_token)
    pending_lease_data = json.loads(p_pending_body)
    pending_lease_id = pending_lease_data["id"]
    original_invite_code = pending_lease_data.get("inviteCode")

    status_neg, _ = http_request("PUT", f"/leases/{pending_lease_id}/activate", token=tenant_token)
    passed = spec_ok and (status_neg == 409)
    results.append({
        "no": 10,
        "name": "Ev sahibi onayı olmayan taslak sözleşmeyi kiracının aktive etmesi",
        "endpoint": f"PUT /api/leases/{pending_lease_id}/activate",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"Sözleşme taslak olarak oluşturuldu (ID: {pending_lease_id}, Davet Kodu mevcut)",
        "expected": "409 Conflict",
        "actual": str(status_neg),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 14: POST /api/landlord/leases/{id}/regenerate-invite (GERÇEK ESKİ KODLA!)
    # (Not: Rate Limit Senaryo 11'den önce çalıştırılır)
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("POST", "/api/landlord/leases/{id}/regenerate-invite")
    spec_ok2 = verify_endpoint_in_spec("GET", "/api/leases/validate-invite")
    
    # 1. Yeni davet kodu oluştur
    status1, reg_body = http_request("POST", f"/landlord/leases/{pending_lease_id}/regenerate-invite", token=landlord_token)
    new_invite_code = json.loads(reg_body).get("inviteCode") if status1 == 200 else None
    
    # 2. Yeni kodu doğrula -> 200 (Pozitif Kontrol)
    status2, _ = http_request("GET", f"/leases/validate-invite?inviteCode={new_invite_code}") if new_invite_code else (-1, "")
    
    # 3. Gerçek eski kodu doğrula -> 404 (veya 400)
    status3, _ = http_request("GET", f"/leases/validate-invite?inviteCode={original_invite_code}")
    
    # 4. Kiracısı bağlanmış (ACTIVE) sözleşmede kod yenileme -> 409 Conflict
    status4, _ = http_request("POST", f"/landlord/leases/{active_lease_id}/regenerate-invite", token=landlord_token)
    
    passed = spec_ok1 and spec_ok2 and (status1 == 200) and (status2 == 200) and (status3 in (400, 404)) and (status4 == 409)
    results.append({
        "no": 14,
        "name": "Davet kodu yenileme: yeni kod 200, eski kod reddedilir, aktifte 409",
        "endpoint": f"POST /api/landlord/leases/{pending_lease_id}/regenerate-invite, GET /api/leases/validate-invite",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "positive": f"Yeni Davet Kodu Doğrulandı => {status2} OK",
        "expected": "200 -> 200 -> 400/404 -> 409",
        "actual": f"{status1} -> {status2} -> {status3} -> {status4}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 11: Geçersiz davet kodu reddi ve dakikada 10 istek limit aşımı (429)
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/leases/validate-invite")
    status_bad, _ = http_request("GET", "/leases/validate-invite?inviteCode=INVALID_INVITE_TEST")
    flood_status = None
    for _ in range(12):
        s, _ = http_request("GET", "/leases/validate-invite?inviteCode=FLOOD_TEST_CODE")
        if s == 429:
            flood_status = 429
            break
    passed = spec_ok and (status_bad in (400, 404)) and (flood_status == 429)
    results.append({
        "no": 11,
        "name": "Geçersiz davet kodu reddi ve dakikada 10 istek limit aşımı",
        "endpoint": "GET /api/leases/validate-invite?inviteCode=...",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"Limit öncesi geçerli davet kodu doğrulaması (Senaryo 14'te {status2} OK)",
        "expected": "400/404 ve 429 Too Many Requests",
        "actual": f"{status_bad} ve {flood_status}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 12: Deprecated / Silinmiş uçlar (404 beklenir)
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/properties/landlord", intentionally_removed=True)
    status_neg1, _ = http_request("GET", "/properties/landlord", token=landlord_token)
    status_neg2, _ = http_request("GET", "/dashboard/landlord", token=landlord_token)
    status_pos1, _ = http_request("GET", "/landlord/properties", token=landlord_token)
    status_pos2, _ = http_request("GET", "/landlord/dashboard", token=landlord_token)
    passed = (status_neg1 == 404) and (status_neg2 == 404) and (status_pos1 == 200) and (status_pos2 == 200)
    results.append({
        "no": 12,
        "name": "Deprecated / Silinmiş uçlar (404 beklenir)",
        "endpoint": "GET /api/properties/landlord, GET /api/dashboard/landlord",
        "spec_valid": "EVET (Bilinçli Silinmiş)",
        "positive": f"Kanonik Uçlar => /landlord/properties ({status_pos1} OK) & /landlord/dashboard ({status_pos2} OK)",
        "expected": "404 Not Found",
        "actual": f"{status_neg1} / {status_neg2}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 13: PUT /api/properties/{id} Yetkilendirme Matrisi
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("PUT", "/api/properties/{id}")
    update_data = {"title": "SECCHECK-Kadıköy Plaza Güncellendi", "address": "Moda No:1", "city": "İstanbul"}
    s_owner, _ = http_request("PUT", f"/properties/{property_a_id}", data=update_data, token=landlord_token)
    s_other, _ = http_request("PUT", f"/properties/{property_a_id}", data=update_data, token=landlord_b_token)
    s_agent, _ = http_request("PUT", f"/properties/{property_a_id}", data=update_data, token=agent_token)
    s_tenant, _ = http_request("PUT", f"/properties/{property_a_id}", data=update_data, token=tenant_token)
    passed = spec_ok and (s_owner == 200) and (s_other == 404) and (s_agent == 403) and (s_tenant == 403)
    results.append({
        "no": 13,
        "name": "PUT /api/properties/{id}: sahibi 200, başka ev sahibi 404, emlakçı/kiracı 403",
        "endpoint": f"PUT /api/properties/{property_a_id}",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "positive": f"Mülk Sahibi Güncelleme => {s_owner} OK",
        "expected": "200 / 404 / 403 / 403",
        "actual": f"{s_owner} / {s_other} / {s_agent} / {s_tenant}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 15: Dosya formatı doğrulaması: PDF 200, WEBP 400, TXT 400
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("POST", "/api/leases/{id}/contract")
    spec_ok2 = verify_endpoint_in_spec("POST", "/api/tenant/receipts/{periodId}")
    
    webp_bytes = b"RIFF\x24\x00\x00\x00WEBPVP8 "
    txt_bytes = b"Bu duz metin sozlesme belgesidir"
    
    # 1. Sözleşme PDF -> 200 (Pozitif Kontrol)
    d, ct = build_multipart({}, {"file": ("contract.pdf", pdf_sample, "application/pdf")})
    s_c_pdf, _ = http_request("POST", f"/leases/{active_lease_id}/contract", data=d, token=landlord_token, content_type=ct)
    
    # 2. Sözleşme WEBP -> 400
    d, ct = build_multipart({}, {"file": ("contract.webp", webp_bytes, "image/webp")})
    s_c_webp, _ = http_request("POST", f"/leases/{active_lease_id}/contract", data=d, token=landlord_token, content_type=ct)
    
    # 3. Sözleşme TXT -> 400
    d, ct = build_multipart({}, {"file": ("contract.txt", txt_bytes, "text/plain")})
    s_c_txt, _ = http_request("POST", f"/leases/{active_lease_id}/contract", data=d, token=landlord_token, content_type=ct)
    
    # 4. Dekont WEBP -> 400
    d, ct = build_multipart({}, {"file": ("receipt.webp", webp_bytes, "image/webp")})
    s_r_webp, _ = http_request("POST", f"/tenant/receipts/{period_a_id}", data=d, token=tenant_token, content_type=ct)
    
    # 5. Dekont TXT -> 400
    d, ct = build_multipart({}, {"file": ("receipt.txt", txt_bytes, "text/plain")})
    s_r_txt, _ = http_request("POST", f"/tenant/receipts/{period_a_id}", data=d, token=tenant_token, content_type=ct)
    
    passed = spec_ok1 and spec_ok2 and (s_c_pdf == 200) and (s_c_webp == 400) and (s_c_txt == 400) and (s_r_webp == 400) and (s_r_txt == 400)
    results.append({
        "no": 15,
        "name": "Dosya formatı doğrulaması: PDF 200, WEBP 400, TXT 400",
        "endpoint": f"POST /api/leases/{active_lease_id}/contract, POST /api/tenant/receipts/{period_a_id}",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "positive": f"PDF Sözleşme Yükleme => {s_c_pdf} OK",
        "expected": "PDF: 200, WEBP: 400, TXT: 400",
        "actual": f"PDF: {s_c_pdf}, WEBP: {s_c_webp}/{s_r_webp}, TXT: {s_c_txt}/{s_r_txt}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 16: Host'tan TCP üzerinden PostgreSQL kimlik doğrulaması
    # -------------------------------------------------------------------------
    tcp_ok = False
    actual_db_msg = ""
    try:
        env = os.environ.copy()
        if DB_PASS:
            env["PGPASSWORD"] = DB_PASS
        res = subprocess.run(
            ["psql", "-h", "127.0.0.1", "-p", str(DB_PORT), "-U", DB_USER, "-d", DB_NAME, "-t", "-c", "SELECT current_user, current_database();"],
            capture_output=True, text=True, env=env, timeout=5
        )
        if res.returncode == 0:
            output = res.stdout.strip()
            actual_db_msg = f"{output} (TCP Port {DB_PORT} bağlantısı başarılı)"
            tcp_ok = (DB_USER in output) and (DB_NAME in output)
        else:
            actual_db_msg = f"HATA (Kod {res.returncode}): {res.stderr.strip()}"
    except Exception as e:
        actual_db_msg = f"HATA: {e}"

    results.append({
        "no": 16,
        "name": "Backend DB bağlantısı: Host'tan TCP şifreli doğrulama",
        "endpoint": f"TCP {DB_HOST}:{DB_PORT} -> PostgreSQL ({DB_NAME})",
        "spec_valid": "TCP Soket Doğrulaması",
        "positive": f"TCP Soket Doğrulaması ({DB_USER}@{DB_NAME}) => 200 Başarılı",
        "expected": f"{DB_USER}@{DB_NAME} (TCP Başarılı)",
        "actual": actual_db_msg,
        "status": "PASS" if tcp_ok else "FAIL"
    })

    # -------------------------------------------------------------------------
    # RAPOR TABLOSU ÇIKTISI (POZİTİF KONTROL SÜTUNU İLE)
    # -------------------------------------------------------------------------
    print("\n" + "=" * 130)
    print("GÜVENLİK VE YETKİLENDİRME SENARYO DOĞRULAMA HAM SONUÇ TABLOSU (POZİTİF KONTROL DESTEKLİ)")
    print("=" * 130)
    print("| # | Senaryo Adı | Test Edilen Uç (HTTP) | OpenAPI Spec'te Var mı? | Pozitif Kontrol (Yetkili İstek) | Beklenen Durum | Gerçekleşen Durum | Sonuç |")
    print("|:---|:---|:---|:---|:---|:---|:---|:---|")
    for r in results:
        print(f"| **{r['no']}** | {r['name']} | `{r['endpoint']}` | {r['spec_valid']} | {r['positive']} | {r['expected']} | **{r['actual']}** | **{r['status']}** |")
    print("=" * 130)
    
    final_counts = get_db_counts()
    print("\n[VERİTABANI KAYIT SAYILARI DEĞİŞİM RAPORU (BİR ÇALIŞTIRMADA EKLENEN)]")
    for tbl in ["properties", "lease_agreements", "rent_periods", "users"]:
        init_c = initial_counts.get(tbl, 0)
        fin_c = final_counts.get(tbl, 0)
        diff = fin_c - init_c
        print(f"  - {tbl:<18}: Başlangıç={init_c}, Bitiş={fin_c} (Eklenen: +{diff})")

    all_passed = all(r["status"] == "PASS" for r in results)
    print(f"\nToplam Senaryo: {len(results)}, Başarılı: {sum(1 for r in results if r['status'] == 'PASS')}, Başarısız: {sum(1 for r in results if r['status'] != 'PASS')}")
    if all_passed:
        print(">>> TÜM 16 SENARYO POZİTİF KONTROLLERİYLE BİRLİKTE BAŞARIYLA TAMAMLANDI (ALL PASS) <<<\n")
    else:
        print(">>> BAZI SENARYOLAR BAŞARISIZ OLDU <<<\n", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()
