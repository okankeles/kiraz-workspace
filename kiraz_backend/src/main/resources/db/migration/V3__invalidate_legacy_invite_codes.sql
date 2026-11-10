--
-- Migration V3: Invalidate legacy development invite codes on PENDING leases and clean up database constraints
--

-- 1. Ensure users_role_check constraint contains LANDLORD, TENANT, and AGENT
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('LANDLORD', 'TENANT', 'AGENT'));

-- 2. Ensure any legacy rent_periods_status_check constraint is removed
ALTER TABLE public.rent_periods DROP CONSTRAINT IF EXISTS rent_periods_status_check;

-- 3. Invalidate legacy development invite codes on PENDING lease agreements (marking as used and expired)
UPDATE public.lease_agreements
SET invite_code_used = TRUE,
    invite_code_used_at = NOW(),
    invite_code_expires_at = NOW()
WHERE status = 'PENDING'
  AND invite_code IS NOT NULL
  AND length(invite_code) < 20;
