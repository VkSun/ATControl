-- Migration: redeem_invitation_function
-- Replace register_with_invitation (previous migration) with redeem_invitation.
-- New version distinguishes three failure modes with separate error codes so
-- the Dart layer can surface accurate Russian error messages.
--
-- Error codes raised (checked via PostgrestException.message):
--   'invitation_not_found' — code string doesn't exist in the table
--   'invitation_used'      — code exists but is already consumed
--   'invitation_expired'   — code exists, unused, but expires_at has passed
--
-- Atomicity guarantee:
--   FOR UPDATE on the invitation row + all three writes (user_roles, profiles,
--   invitation_codes update) are in one PL/pgSQL transaction. Either all
--   succeed or none do. The Dart layer calls signOut() on any exception so no
--   orphaned auth user is left signed-in without a role.

DROP FUNCTION IF EXISTS register_with_invitation(text);

CREATE OR REPLACE FUNCTION redeem_invitation(p_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_inv  invitation_codes%ROWTYPE;
  v_init text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Lock the row unconditionally to distinguish "never existed" from "already used".
  SELECT * INTO v_inv
  FROM invitation_codes
  WHERE code = upper(trim(p_code))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_found';
  END IF;

  IF v_inv.is_used THEN
    RAISE EXCEPTION 'invitation_used';
  END IF;

  IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < now() THEN
    RAISE EXCEPTION 'invitation_expired';
  END IF;

  v_init := _compute_initials(coalesce(v_inv.full_name, ''));

  INSERT INTO user_roles (
    user_id, full_name, position, initials, avatar_color,
    is_admin, perm_full_access, perm_edit, perm_execute,
    perm_read, perm_write, perm_own_only, is_active,
    department_id, section_id
  ) VALUES (
    v_uid,
    coalesce(v_inv.full_name, ''),
    v_inv.position,
    v_init,
    '#4361EE',
    false,
    v_inv.perm_full_access,
    v_inv.perm_edit,
    v_inv.perm_execute,
    v_inv.perm_read,
    v_inv.perm_write,
    v_inv.perm_own_only,
    true,
    v_inv.department_id,
    v_inv.section_id
  );

  INSERT INTO profiles (id, full_name, position, initials, avatar_color)
  VALUES (v_uid, coalesce(v_inv.full_name, ''), v_inv.position, v_init, '#4361EE')
  ON CONFLICT (id) DO UPDATE SET
    full_name    = EXCLUDED.full_name,
    position     = EXCLUDED.position,
    initials     = EXCLUDED.initials,
    avatar_color = EXCLUDED.avatar_color;

  -- Mark used atomically in the same transaction.
  UPDATE invitation_codes
  SET is_used = true, used_by = v_uid
  WHERE id = v_inv.id;
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_invitation(text) TO authenticated;
