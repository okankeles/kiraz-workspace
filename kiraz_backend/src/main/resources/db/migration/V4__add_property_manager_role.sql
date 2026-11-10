--
-- Migration V4: Update role check constraints to include PROPERTY_MANAGER
--

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('LANDLORD', 'TENANT', 'AGENT', 'PROPERTY_MANAGER'));

ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_performed_by_role_check;
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_performed_by_role_check CHECK (performed_by_role IN ('LANDLORD', 'TENANT', 'AGENT', 'PROPERTY_MANAGER'));
