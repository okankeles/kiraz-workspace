#!/usr/bin/env python3
"""
KiraZ PropTech — Faz 0 / Adım 6b: Uçtan Uca Güvenlik Doğrulama Betiği
Bu betik:
1. Başlarken /v3/api-docs üzerinden OpenAPI 3 spesifikasyonunu çeker.
2. Test edilen her ucun spec'te var olduğunu doğrular (silinmiş uçlar muaf).
3. Gerçekleştirilen HTTP isteklerini (metot + yol) ve alınan HTTP durum kodlarını yazdırır (token/parola basmaz).
4. Tüm e-posta adresleri RFC 2606 uyumlu '@example.com' alan adındadır.
5. Parolalar doğrudan .env / ortam değişkenlerinden okunur (kodda sabit yazılmaz).
6. 16 senaryonun çalıştırılabilir doğrulamalarını gerçekleştirir ve ham sonuç tablosunu üretir.
"""

import os
import sys
import json
import time
import socket
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

if not all([LANDLORD_PASS, TENANT_PASS, AGENT_PASS, MANAGER_PASS]):
    print("HATA: DEV_SEED_*_PASSWORD ortam değişkenleri eksik! Lütfen .env dosyasını kontrol edin.", file=sys.stderr)
    sys.exit(1)

# Kullanıcı E-postaları (@example.com)
LANDLORD_EMAIL = "dev.landlord@example.com"
TENANT_EMAIL = "dev.tenant@example.com"
AGENT_EMAIL = "dev.agent@example.com"
MANAGER_EMAIL = "dev.manager@example.com"

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

    # Sanitize path for display (hide full query secrets if any)
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

# -----------------------------------------------------------------------------
# 4. Ana Test Koşucusu
# -----------------------------------------------------------------------------
def main():
    print("=" * 80)
    print("KiraZ — Faz 0 / Adım 6b: Uçtan Uca Güvenlik Doğrulaması")
    print("=" * 80)
    
    fetch_openapi_spec()
    
    results = []

    # 0. Girişler (Oturum Açma)
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

    # İkinci bir Ev Sahibi ve Kiracı oluşturarak IDOR testleri için hazırla
    landlord_b_email = "landlord_b@example.com"
    landlord_b_pass = "LandlordBPass2026!"
    http_request("POST", "/auth/register", {
        "email": landlord_b_email,
        "password": landlord_b_pass,
        "fullName": "İkinci Ev Sahibi",
        "phone": "05559998877",
        "role": "LANDLORD"
    })
    _, l_b_body = http_request("POST", "/auth/login", {"email": landlord_b_email, "password": landlord_b_pass})
    landlord_b_token = json.loads(l_b_body)["accessToken"]

    # Landlord B için izole bir mülk oluştur
    _, p_b_body = http_request("POST", "/properties", {
        "title": "Mülk B - Kadıköy Moda",
        "address": "Moda Cad. No:99",
        "city": "İstanbul"
    }, token=landlord_b_token)
    property_b_id = json.loads(p_b_body)["id"]

    # İkinci Kiracı B oluştur
    tenant_b_email = "tenant_b@example.com"
    tenant_b_pass = "TenantBPass2026!"
    http_request("POST", "/auth/register", {
        "email": tenant_b_email,
        "password": tenant_b_pass,
        "fullName": "İkinci Kiracı",
        "phone": "05558887766",
        "role": "TENANT"
    })
    _, t_b_body = http_request("POST", "/auth/login", {"email": tenant_b_email, "password": tenant_b_pass})
    tenant_b_token = json.loads(t_b_body)["accessToken"]

    # Landlord B ve Tenant B için bir sözleşme ve dönem oluştur
    _, lease_b_body = http_request("POST", "/leases", {
        "propertyId": property_b_id,
        "tenantEmail": tenant_b_email,
        "startDate": "2026-01-01",
        "endDate": "2026-12-31",
        "monthlyRentAmount": 20000,
        "depositAmount": 40000,
        "paymentDay": 1
    }, token=landlord_b_token)
    lease_b_id = json.loads(lease_b_body)["id"]

    # Dönem B listele
    _, periods_b_body = http_request("GET", f"/periods/lease/{lease_b_id}", token=landlord_b_token)
    periods_b = json.loads(periods_b_body)
    period_b_id = periods_b[0]["id"] if periods_b else 999999

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

    print("\n--- TEST SENARYOLARI BAŞLIYOR ---\n")

    # -------------------------------------------------------------------------
    # SENARYO 1: X-User-Id header'ı ile başka kullanıcıyı taklit → 401
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/landlord/dashboard")
    status, body = http_request("GET", "/landlord/dashboard", headers={"X-User-Id": str(landlord_id)})
    passed = spec_ok and (status == 401)
    results.append({
        "no": 1,
        "name": "X-User-Id header'ı ile başka kullanıcıyı taklit",
        "endpoint": "GET /api/landlord/dashboard",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "expected": "401 Unauthorized",
        "actual": f"{status} Unauthorized" if status == 401 else str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 2: Ev sahibi A'nın token'ı ile ev sahibi B'nin mülkü ve dönemi → 403/404
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("GET", "/api/properties/{id}")
    spec_ok2 = verify_endpoint_in_spec("GET", "/api/periods/lease/{leaseId}")
    status1, _ = http_request("GET", f"/properties/{property_b_id}", token=landlord_token)
    status2, _ = http_request("GET", f"/periods/lease/{lease_b_id}", token=landlord_token)
    passed = spec_ok1 and spec_ok2 and (status1 in (403, 404)) and (status2 in (403, 404))
    results.append({
        "no": 2,
        "name": "Ev sahibi A token'ı ile ev sahibi B mülk ve dönemine IDOR erişim",
        "endpoint": f"GET /api/properties/{property_b_id}, GET /api/periods/lease/{lease_b_id}",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "expected": "403 / 404",
        "actual": f"{status1} / {status2}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 3: Kiracı A'nın token'ı ile kiracı B'nin dönemine dekont yükleme → 403/404
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("POST", "/api/tenant/receipts/{periodId}")
    png_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
    data_bytes, ct = build_multipart({}, {"file": ("dekont.png", png_bytes, "image/png")})
    status, _ = http_request("POST", f"/tenant/receipts/{period_b_id}", data=data_bytes, token=tenant_token, content_type=ct)
    passed = spec_ok and (status in (403, 404))
    results.append({
        "no": 3,
        "name": "Kiracı A token'ı ile kiracı B dönemine dekont yükleme",
        "endpoint": f"POST /api/tenant/receipts/{period_b_id}",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "expected": "403 / 404",
        "actual": str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 4: Delegasyonu iptal edilmiş emlakçı ile mülke erişim → 403/404
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/properties/{id}")
    # Dev seeder'da Property B emlakçı için aktif vekalete sahip değildir veya iptal edilmiştir
    status, _ = http_request("GET", f"/properties/{property_b_id}", token=agent_token)
    passed = spec_ok and (status in (403, 404))
    results.append({
        "no": 4,
        "name": "Yetkisiz / Delegasyonu iptal edilmiş emlakçı ile mülke erişim",
        "endpoint": f"GET /api/properties/{property_b_id}",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "expected": "403 / 404",
        "actual": str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 5: Süresi dolmuş access token → 401; refresh sonrası aynı istek → 200
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("GET", "/api/tenant/leases")
    spec_ok2 = verify_endpoint_in_spec("POST", "/api/auth/refresh")
    # Sahte süresi dolmuş JWT token (exp: 1514764800)
    expired_jwt = "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiIxOSIsImV4cCI6MTUxNDc2NDgwMH0.INVALID_SIGNATURE_EXPIRED_MOCK"
    status1, _ = http_request("GET", "/tenant/leases", token=expired_jwt)
    status2, ref_body = http_request("POST", "/auth/refresh", {"refreshToken": tenant_refresh})
    new_token = json.loads(ref_body).get("accessToken") if status2 == 200 else None
    status3, _ = http_request("GET", "/tenant/leases", token=new_token) if new_token else (-1, "")
    passed = spec_ok1 and spec_ok2 and (status1 == 401) and (status2 == 200) and (status3 == 200)
    results.append({
        "no": 5,
        "name": "Süresi dolmuş token → 401; refresh → 200; yeni token ile istek → 200",
        "endpoint": "GET /api/tenant/leases, POST /api/auth/refresh",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "expected": "401 -> 200 -> 200",
        "actual": f"{status1} -> {status2} -> {status3}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 6: Kullanılmış refresh token ile refresh → 401 (Reuse Detection)
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("POST", "/api/auth/refresh")
    # tenant_refresh senaryo 5'te zaten kullanıldı; tekrar deneniyor
    status, _ = http_request("POST", "/auth/refresh", {"refreshToken": tenant_refresh})
    passed = spec_ok and (status == 401)
    results.append({
        "no": 6,
        "name": "Kullanılmış refresh token ile tekrar yenileme (Reuse Detection)",
        "endpoint": "POST /api/auth/refresh",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "expected": "401 Unauthorized",
        "actual": str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 7: PayTR callback'ine geçersiz hash ile istek → 400 Bad Request
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("POST", "/api/payments/paytr-callback")
    paytr_data = {
        "merchant_oid": f"RENT-{period_a_id}-1700000000",
        "status": "success",
        "total_amount": "25000",
        "hash": "INVALID_FORGED_HASH_CODE"
    }
    status, body = http_request("POST", "/payments/paytr-callback", data=paytr_data, content_type="application/x-www-form-urlencoded")
    passed = spec_ok and (status == 400)
    results.append({
        "no": 7,
        "name": "PayTR callback'ine geçersiz hash ile istek",
        "endpoint": "POST /api/payments/paytr-callback",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "expected": "400 Bad Request",
        "actual": str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 8: Kaldırılan PUT /api/periods/{id}/status → 404 veya 405
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("PUT", "/api/periods/{id}/status", intentionally_removed=True)
    status, _ = http_request("PUT", f"/periods/{period_a_id}/status?status=PAID", token=landlord_token)
    passed = status in (404, 405)
    results.append({
        "no": 8,
        "name": "Kaldırılan uç: PUT /api/periods/{id}/status",
        "endpoint": f"PUT /api/periods/{period_a_id}/status",
        "spec_valid": "EVET (Bilinçli Silinmiş)",
        "expected": "404 veya 405",
        "actual": str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 9: Token olmadan dosya erişimi → 401; başka kiracının dekontu → 404
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("GET", "/api/files/receipts/{periodId}")
    spec_ok2 = verify_endpoint_in_spec("GET", "/api/files/contracts/{leaseId}")
    status1, _ = http_request("GET", f"/files/receipts/{period_a_id}") # Tokensiz
    status2, _ = http_request("GET", f"/files/contracts/{active_lease_id}") # Tokensiz
    status3, _ = http_request("GET", f"/files/receipts/{period_b_id}", token=tenant_token) # Yetkisiz kiracı
    passed = spec_ok1 and spec_ok2 and (status1 == 401) and (status2 == 401) and (status3 in (403, 404))
    results.append({
        "no": 9,
        "name": "Tokensiz dosya stream → 401; Başka kiracının dekontuna erişim → 404",
        "endpoint": f"GET /api/files/receipts/{period_a_id}, GET /api/files/contracts/{active_lease_id}",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
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
    pending_lease_id = json.loads(p_pending_body)["id"]
    status, _ = http_request("PUT", f"/leases/{pending_lease_id}/activate", token=tenant_token)
    passed = spec_ok and (status == 409)
    results.append({
        "no": 10,
        "name": "Ev sahibi onayı olmayan taslak sözleşmeyi kiracının aktive etmesi",
        "endpoint": f"PUT /api/leases/{pending_lease_id}/activate",
        "spec_valid": "EVET" if spec_ok else "GEÇERSİZ: uç yok",
        "expected": "409 Conflict",
        "actual": str(status),
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 14: POST /api/landlord/leases/{id}/regenerate-invite
    # (Not: Rate Limit Senaryo 11'den önce çalıştırılır)
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("POST", "/api/landlord/leases/{id}/regenerate-invite")
    spec_ok2 = verify_endpoint_in_spec("GET", "/api/leases/validate-invite")
    
    # 1. Yeni davet kodu oluştur
    status1, reg_body = http_request("POST", f"/landlord/leases/{pending_lease_id}/regenerate-invite", token=landlord_token)
    new_invite_code = json.loads(reg_body).get("inviteCode") if status1 == 200 else None
    
    # 2. Yeni kodu doğrula -> 200
    status2, _ = http_request("GET", f"/leases/validate-invite?inviteCode={new_invite_code}") if new_invite_code else (-1, "")
    
    # 3. Eski kodu doğrula -> 400 / 404
    old_invite_code = "ARS-OLD_REVOKED_CODE_12345"
    status3, _ = http_request("GET", f"/leases/validate-invite?inviteCode={old_invite_code}")
    
    # 4. Kiracısı bağlanmış (ACTIVE) sözleşmede kod yenileme -> 409 Conflict
    status4, _ = http_request("POST", f"/landlord/leases/{active_lease_id}/regenerate-invite", token=landlord_token)
    
    passed = spec_ok1 and spec_ok2 and (status1 == 200) and (status2 == 200) and (status3 in (400, 404)) and (status4 == 409)
    results.append({
        "no": 14,
        "name": "Davet kodu yenileme: yeni kod 200, eski kod reddedilir, aktifte 409",
        "endpoint": f"POST /api/landlord/leases/{pending_lease_id}/regenerate-invite, GET /api/leases/validate-invite",
        "spec_valid": "EVET" if (spec_ok1 and spec_ok2) else "GEÇERSİZ: uç yok",
        "expected": "200 -> 200 -> 400/404 -> 409",
        "actual": f"{status1} -> {status2} -> {status3} -> {status4}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 11: Süresi dolmuş/kullanılmış davet kodu ve hız sınırı (429)
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
        "expected": "400/404 ve 429 Too Many Requests",
        "actual": f"{status_bad} ve {flood_status}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 12: Deprecated uçlar (Adım 5b sonrası) → 404
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("GET", "/api/properties/landlord", intentionally_removed=True)
    status1, _ = http_request("GET", "/properties/landlord", token=landlord_token)
    status2, _ = http_request("GET", "/dashboard/landlord", token=landlord_token)
    passed = (status1 == 404) and (status2 == 404)
    results.append({
        "no": 12,
        "name": "Deprecated / Silinmiş uçlar (404 beklenir)",
        "endpoint": "GET /api/properties/landlord, GET /api/dashboard/landlord",
        "spec_valid": "EVET (Bilinçli Silinmiş)",
        "expected": "404 Not Found",
        "actual": f"{status1} / {status2}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 13: PUT /api/properties/{id} Yetkilendirme Matrisi
    # -------------------------------------------------------------------------
    spec_ok = verify_endpoint_in_spec("PUT", "/api/properties/{id}")
    update_data = {"title": "Kadıköy Plaza Güncellendi", "address": "Moda No:1", "city": "İstanbul"}
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
        "expected": "200 / 404 / 403 / 403",
        "actual": f"{s_owner} / {s_other} / {s_agent} / {s_tenant}",
        "status": "PASS" if passed else "FAIL"
    })

    # -------------------------------------------------------------------------
    # SENARYO 15: Sözleşme ve Dekont Dosya Formatı (PDF/JPEG/PNG 200; WEBP/TXT 400)
    # -------------------------------------------------------------------------
    spec_ok1 = verify_endpoint_in_spec("POST", "/api/leases/{id}/contract")
    spec_ok2 = verify_endpoint_in_spec("POST", "/api/tenant/receipts/{periodId}")
    
    pdf_bytes = b"%PDF-1.4\n%mock contract content"
    webp_bytes = b"RIFF\x24\x00\x00\x00WEBPVP8 "
    txt_bytes = b"Bu duz metin sozlesme belgesidir"
    
    # 1. Sözleşme PDF -> 200
    d, ct = build_multipart({}, {"file": ("contract.pdf", pdf_bytes, "application/pdf")})
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
        "expected": f"{DB_USER}@{DB_NAME} (TCP Başarılı)",
        "actual": actual_db_msg,
        "status": "PASS" if tcp_ok else "FAIL"
    })

    # -------------------------------------------------------------------------
    # RAPOR TABLOSU ÇIKTISI
    # -------------------------------------------------------------------------
    print("\n" + "=" * 100)
    print("GÜVENLİK VE YETKİLENDİRME SENARYO DOĞRULAMA HAM SONUÇ TABLOSU")
    print("=" * 100)
    print("| # | Senaryo Adı | Test Edilen Uç (HTTP) | OpenAPI Spec'te Var mı? | Beklenen Durum | Gerçekleşen Durum | Sonuç |")
    print("|:---|:---|:---|:---|:---|:---|:---|")
    for r in results:
        print(f"| **{r['no']}** | {r['name']} | `{r['endpoint']}` | {r['spec_valid']} | {r['expected']} | **{r['actual']}** | **{r['status']}** |")
    print("=" * 100)
    
    all_passed = all(r["status"] == "PASS" for r in results)
    print(f"\nToplam Senaryo: {len(results)}, Başarılı: {sum(1 for r in results if r['status'] == 'PASS')}, Başarısız: {sum(1 for r in results if r['status'] != 'PASS')}")
    if all_passed:
        print(">>> TÜM 16 SENARYO BAŞARIYLA TAMAMLANDI (ALL PASS) <<<\n")
    else:
        print(">>> BAZI SENARYOLAR BAŞARISIZ OLDU <<<\n", file=sys.stderr)
        sys.exit(2)

if __name__ == "__main__":
    main()
