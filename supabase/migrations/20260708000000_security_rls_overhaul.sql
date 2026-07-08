-- Migration: security_rls_overhaul
-- Close direct client writes on user_roles / profiles / invitation_codes.
-- Move admin bootstrap and invitation registration to atomic server-side functions.

-- =========================================================
-- HELPER FUNCTIONS (SECURITY DEFINER — bypass RLS internally)
-- =========================================================

-- Returns true if the current session belongs to an active admin
CREATE OR REPLACE FUNCTION _is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id  = auth.uid()
      AND is_admin  = true
      AND is_active = true
  );
$$;

-- Mirrors Dart _getInitials: first letters of first two words, uppercased
CREATE OR REPLACE FUNCTION _compute_initials(p_full_name text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_parts text[];
BEGIN
  v_parts := array_remove(string_to_array(trim(p_full_name), ' '), '');
  IF v_parts IS NULL OR array_length(v_parts, 1) IS NULL THEN
    RETURN '';
  ELSIF array_length(v_parts, 1) = 1 THEN
    RETURN upper(left(v_parts[1], 1));
  ELSE
    RETURN upper(left(v_parts[1], 1) || left(v_parts[2], 1));
  END IF;
END;
$$;

-- =========================================================
-- PUBLIC RPC: has_admin — callable by anon (bootstrap check)
-- =========================================================
CREATE OR REPLACE FUNCTION has_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM user_roles WHERE is_admin = true);
$$;

GRANT EXECUTE ON FUNCTION has_admin() TO anon, authenticated;

-- =========================================================
-- PUBLIC RPC: register_first_admin
-- Atomic: advisory lock prevents two concurrent first-admins
-- =========================================================
CREATE OR REPLACE FUNCTION register_first_admin(
  p_full_name text,
  p_position  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_initials text;
  v_role_id  uuid;
  v_result   jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Prevent concurrent races on the first-admin slot
  PERFORM pg_advisory_xact_lock(hashtext('register_first_admin'));

  IF EXISTS (SELECT 1 FROM user_roles WHERE is_admin = true) THEN
    RAISE EXCEPTION 'Администратор уже существует';
  END IF;

  v_initials := _compute_initials(p_full_name);

  INSERT INTO user_roles (
    user_id, full_name, position, initials, avatar_color,
    is_admin, perm_full_access, perm_edit, perm_execute,
    perm_read, perm_write, perm_own_only, is_active
  ) VALUES (
    v_uid, p_full_name, p_position, v_initials, '#4361EE',
    true, true, true, true, true, true, false, true
  )
  RETURNING id INTO v_role_id;

  INSERT INTO profiles (id, full_name, position, initials, avatar_color)
  VALUES (v_uid, p_full_name, p_position, v_initials, '#4361EE')
  ON CONFLICT (id) DO UPDATE SET
    full_name    = EXCLUDED.full_name,
    position     = EXCLUDED.position,
    initials     = EXCLUDED.initials,
    avatar_color = EXCLUDED.avatar_color;

  SELECT to_jsonb(ur.*) INTO v_result
  FROM user_roles ur WHERE ur.id = v_role_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION register_first_admin(text, text) TO authenticated;

-- =========================================================
-- PUBLIC RPC: register_with_invitation
-- Validates + consumes code atomically (FOR UPDATE lock).
-- Uses server-side permissions from the code — client cannot escalate.
-- =========================================================
CREATE OR REPLACE FUNCTION register_with_invitation(p_code text)
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

  -- Lock the row to prevent two simultaneous uses of the same code
  SELECT * INTO v_inv
  FROM invitation_codes
  WHERE code = upper(trim(p_code))
    AND is_used = false
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Код приглашения недействителен или уже использован';
  END IF;

  IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < now() THEN
    RAISE EXCEPTION 'Код приглашения истёк';
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

  UPDATE invitation_codes
  SET is_used = true, used_by = v_uid
  WHERE id = v_inv.id;
END;
$$;

GRANT EXECUTE ON FUNCTION register_with_invitation(text) TO authenticated;

-- =========================================================
-- PUBLIC RPC: sync_profile_display
-- Lets a user sync only display fields back to user_roles
-- without being able to touch is_admin or perm_* columns.
-- =========================================================
CREATE OR REPLACE FUNCTION sync_profile_display(
  p_full_name    text,
  p_position     text,
  p_initials     text,
  p_avatar_color text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE user_roles
  SET full_name    = p_full_name,
      position     = p_position,
      initials     = p_initials,
      avatar_color = p_avatar_color
  WHERE user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION sync_profile_display(text, text, text, text) TO authenticated;

-- =========================================================
-- Backfill profiles for existing users who don't have a row
-- (ensures profile_service upsert always hits UPDATE not INSERT)
-- =========================================================
INSERT INTO profiles (id, full_name, position, initials, avatar_color)
SELECT ur.user_id, ur.full_name, ur.position, ur.initials, ur.avatar_color
FROM user_roles ur
WHERE ur.user_id NOT IN (SELECT id FROM profiles)
ON CONFLICT (id) DO NOTHING;

-- =========================================================
-- RLS: user_roles
-- =========================================================
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read all"                    ON user_roles;
DROP POLICY IF EXISTS "Self insert on registration" ON user_roles;
DROP POLICY IF EXISTS "Admin or self update"        ON user_roles;
DROP POLICY IF EXISTS "Admin delete"                ON user_roles;
DROP POLICY IF EXISTS "select_own_or_admin"         ON user_roles;
DROP POLICY IF EXISTS "admin_update"                ON user_roles;
DROP POLICY IF EXISTS "admin_delete"                ON user_roles;

-- Only own row or admin can read
CREATE POLICY "select_own_or_admin" ON user_roles
  FOR SELECT
  USING (user_id = auth.uid() OR _is_admin());

-- Only admins can UPDATE (covers _toggleActive + _EditUserDialog in users_screen)
CREATE POLICY "admin_update" ON user_roles
  FOR UPDATE
  USING (_is_admin())
  WITH CHECK (_is_admin());

-- Only admins can DELETE
CREATE POLICY "admin_delete" ON user_roles
  FOR DELETE
  USING (_is_admin());

-- No INSERT policy → all direct client INSERTs are blocked.
-- Registrations must go through register_first_admin or register_with_invitation RPCs.

-- =========================================================
-- RLS: profiles
-- =========================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Own profile access"  ON profiles;
DROP POLICY IF EXISTS "select_own_or_admin" ON profiles;
DROP POLICY IF EXISTS "insert_own"          ON profiles;
DROP POLICY IF EXISTS "update_own"          ON profiles;

-- Own row or admin reads
CREATE POLICY "select_own_or_admin" ON profiles
  FOR SELECT
  USING (id = auth.uid() OR _is_admin());

-- A user may INSERT only their own profile row
CREATE POLICY "insert_own" ON profiles
  FOR INSERT
  WITH CHECK (id = auth.uid());

-- A user may UPDATE only their own profile row
CREATE POLICY "update_own" ON profiles
  FOR UPDATE
  USING    (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- No DELETE policy → blocked from client

-- =========================================================
-- RLS: invitation_codes
-- =========================================================
ALTER TABLE invitation_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin manage invitations" ON invitation_codes;
DROP POLICY IF EXISTS "Check invitation code"    ON invitation_codes;
DROP POLICY IF EXISTS "select_codes"             ON invitation_codes;
DROP POLICY IF EXISTS "insert_admin"             ON invitation_codes;
DROP POLICY IF EXISTS "delete_admin"             ON invitation_codes;

-- Authenticated users see all codes (admin UI lists used/expired codes too).
-- Anon sees only unused non-expired codes (needed for validateInvitationCode
-- which runs before sign-up, so auth.uid() is NULL at that point).
-- Also fixes bug: old policy excluded codes with NULL expires_at.
CREATE POLICY "select_codes" ON invitation_codes
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    OR (is_used = false AND (expires_at IS NULL OR expires_at > now()))
  );

-- Only admins may create invitation codes
CREATE POLICY "insert_admin" ON invitation_codes
  FOR INSERT
  WITH CHECK (_is_admin());

-- Only admins may delete invitation codes
CREATE POLICY "delete_admin" ON invitation_codes
  FOR DELETE
  USING (_is_admin());

-- No UPDATE policy → direct client UPDATEs blocked.
-- Marking a code as used is handled inside register_with_invitation (SECURITY DEFINER).
