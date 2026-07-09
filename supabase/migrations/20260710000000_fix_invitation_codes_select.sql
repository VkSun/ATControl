-- Migration: fix_invitation_codes_select
-- The "select_codes" policy from 20260708000000_security_rls_overhaul.sql
-- accidentally granted SELECT on invitation_codes to ANY authenticated user
-- (`auth.uid() IS NOT NULL OR ...`), not just admins. Any logged-in user —
-- including a freshly-invited low-privilege one — could read every
-- not-yet-used invitation code system-wide, including the permission grant
-- attached to it (perm_full_access, department_id, etc.) and the code
-- string itself, which is the single-use credential gating registration.
-- That undermines the whole "code = secret one-time credential" model:
-- anyone with the code, from anyone, can redeem it for themselves.
--
-- Fix: only admins get the full read (needed for the "Коды приглашений"
-- admin UI, which lists used/expired codes too). Anonymous / any other
-- authenticated caller keeps the narrow existing-behavior check needed by
-- validateInvitationCode() before sign-up (auth.uid() is NULL at that point).

DROP POLICY IF EXISTS "select_codes" ON invitation_codes;

CREATE POLICY "select_codes" ON invitation_codes
  FOR SELECT
  USING (
    _is_admin()
    OR (is_used = false AND (expires_at IS NULL OR expires_at > now()))
  );
