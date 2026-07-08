-- Блокировка на уровне API: JWT заблокированного пользователя остаётся
-- валидным, поэтому одной клиентской проверки is_active недостаточно.
-- RESTRICTIVE-политики объединяются с существующими permissive-политиками
-- через AND: неактивный пользователь теряет доступ к основным таблицам,
-- какими бы ни были остальные политики.

-- SECURITY DEFINER: читает user_roles в обход RLS; STABLE — один вызов
-- на statement.
CREATE OR REPLACE FUNCTION _is_active_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
      AND is_active = true
  );
$$;

DROP POLICY IF EXISTS "active_user_only" ON vehicles;
CREATE POLICY "active_user_only" ON vehicles
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (_is_active_user())
  WITH CHECK (_is_active_user());

DROP POLICY IF EXISTS "active_user_only" ON drivers;
CREATE POLICY "active_user_only" ON drivers
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (_is_active_user())
  WITH CHECK (_is_active_user());

DROP POLICY IF EXISTS "active_user_only" ON tasks;
CREATE POLICY "active_user_only" ON tasks
  AS RESTRICTIVE
  FOR ALL
  TO authenticated
  USING (_is_active_user())
  WITH CHECK (_is_active_user());
