-- Общее API для двух клиентов (Flutter-приложение и браузерное расширение).
-- Правило: логика, нужная обоим клиентам, живёт в БД (см. README).
-- Обе функции SECURITY INVOKER — RLS-политики таблиц (включая
-- restrictive active_user_only) применяются как при прямых запросах.

-- Профиль текущего пользователя: строка user_roles, display-поля
-- переопределяются из profiles, если профиль создан. Заменяет
-- дублировавшуюся логику: user_roles-запрос в расширении (App.jsx),
-- currentUserRoleProvider и fallback в ProfileService (Flutter).
-- NULL — если пользователь не найден в user_roles.
CREATE OR REPLACE FUNCTION get_my_profile()
RETURNS json
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT row_to_json(t) FROM (
    SELECT r.id,
           r.user_id,
           coalesce(nullif(p.full_name, ''), r.full_name)       AS full_name,
           coalesce(nullif(p.position, ''), r.position)         AS position,
           coalesce(nullif(p.initials, ''), r.initials)         AS initials,
           coalesce(nullif(p.avatar_color, ''), r.avatar_color) AS avatar_color,
           r.is_admin,
           r.perm_full_access,
           r.perm_edit,
           r.perm_execute,
           r.perm_read,
           r.perm_write,
           r.perm_own_only,
           r.is_active,
           r.department_id,
           r.section_id
    FROM user_roles r
    LEFT JOIN profiles p ON p.id = r.user_id
    WHERE r.user_id = auth.uid()
  ) t;
$$;

-- Задачи, видимые текущему пользователю: expiry-задачи + собственные,
-- с опциональным диапазоном дат. Заменяет одинаковый or-фильтр в
-- TodoCard.jsx и четырёх методах TaskService (Flutter).
--   get_my_tasks()                         — все
--   get_my_tasks(p_from := d, p_to := d)   — на день d
--   get_my_tasks(p_to := d)                — всё до d включительно
CREATE OR REPLACE FUNCTION get_my_tasks(p_from date DEFAULT NULL, p_to date DEFAULT NULL)
RETURNS SETOF tasks
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT * FROM tasks
  WHERE (type = 'expiry' OR user_id = auth.uid())
    AND (p_from IS NULL OR due_date >= p_from)
    AND (p_to IS NULL OR due_date <= p_to)
  ORDER BY due_date ASC NULLS LAST, due_time ASC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION get_my_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_tasks(date, date) TO authenticated;
