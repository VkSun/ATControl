-- Оптимизация запросов: явные колонки и лимит в get_my_tasks,
-- count-RPC для бейджа просроченных задач, индексы под реальные фильтры.

-- get_my_tasks: явный список колонок (ровно поля Task.fromJson /
-- taskToDisplay расширения) + серверный LIMIT (по умолчанию 500).
-- Смена возвращаемого типа требует DROP (внутри транзакции миграции).
DROP FUNCTION IF EXISTS get_my_tasks(date, date);
CREATE FUNCTION get_my_tasks(
  p_from date DEFAULT NULL,
  p_to date DEFAULT NULL,
  p_limit int DEFAULT 500
)
RETURNS TABLE (
  id uuid,
  title character varying,
  description text,
  due_date date,
  due_time time,
  is_completed boolean,
  priority character varying,
  type character varying,
  vehicle_id uuid,
  driver_id uuid
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT t.id, t.title, t.description, t.due_date, t.due_time,
         t.is_completed, t.priority, t.type, t.vehicle_id, t.driver_id
  FROM tasks t
  WHERE (t.type = 'expiry' OR t.user_id = auth.uid())
    AND (p_from IS NULL OR t.due_date >= p_from)
    AND (p_to IS NULL OR t.due_date <= p_to)
  ORDER BY t.due_date ASC NULLS LAST, t.due_time ASC NULLS LAST
  LIMIT p_limit;
$$;

-- Счётчик просроченных: раньше клиент скачивал все строки ради length.
CREATE OR REPLACE FUNCTION count_my_pending_tasks(p_to date)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT count(*)::int FROM tasks
  WHERE (type = 'expiry' OR user_id = auth.uid())
    AND is_completed = false
    AND due_date <= p_to;
$$;

GRANT EXECUTE ON FUNCTION get_my_tasks(date, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION count_my_pending_tasks(date) TO authenticated;

-- Индексы под реальные фильтры. tasks(due_date/type/user_id),
-- invitation_codes(code), user_roles(user_id), notes(user_id) уже
-- созданы миграцией add_missing_indexes — добавляем недостающие.
CREATE INDEX IF NOT EXISTS idx_vehicles_department_id ON vehicles (department_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_section_id ON vehicles (section_id);
CREATE INDEX IF NOT EXISTS idx_drivers_department_id ON drivers (department_id);
CREATE INDEX IF NOT EXISTS idx_drivers_section_id ON drivers (section_id);
CREATE INDEX IF NOT EXISTS idx_sections_department_id ON sections (department_id);
-- Частичный индекс под count_my_pending_tasks (is_completed=false + due_date<=)
CREATE INDEX IF NOT EXISTS idx_tasks_pending_due
  ON tasks (due_date) WHERE is_completed = false;
