--
-- Migration V2: Populate receipt_file_path and contract_file_path from existing legacy URLs
-- Also mark invite codes for already active leases as used, and grant 7-day grace period for pending leases
--

UPDATE public.rent_periods
SET receipt_file_path = TRIM(LEADING '/' FROM receipt_image_url)
WHERE receipt_image_url IS NOT NULL 
  AND receipt_image_url <> '' 
  AND (receipt_file_path IS NULL OR receipt_file_path = '');

UPDATE public.lease_agreements
SET contract_file_path = TRIM(LEADING '/' FROM contract_file_url)
WHERE contract_file_url IS NOT NULL 
  AND contract_file_url <> '' 
  AND (contract_file_path IS NULL OR contract_file_path = '');

-- Mark invite codes as used for already ACTIVE leases
UPDATE public.lease_agreements
SET invite_code_used = TRUE,
    invite_code_used_at = NOW()
WHERE status = 'ACTIVE'
  AND invite_code IS NOT NULL
  AND invite_code_used IS NULL;

-- Set 7-day grace period expiration for PENDING leases with legacy invite codes
UPDATE public.lease_agreements
SET invite_code_expires_at = NOW() + INTERVAL '7' DAY,
    invite_code_used = FALSE
WHERE status = 'PENDING'
  AND invite_code IS NOT NULL
  AND invite_code_expires_at IS NULL;
