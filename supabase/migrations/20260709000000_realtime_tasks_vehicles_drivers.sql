-- Realtime для tasks/vehicles/drivers: клиенты (приложение и браузерное
-- расширение) подписываются на postgres_changes вместо ручного
-- ref.invalidate — второй пользователь видит изменения без перезахода.
--
-- RLS уже включён и достаточен для realtime-подписок без дополнительных
-- грантов: Realtime применяет к каждому подписчику те же политики, что
-- и обычные запросы (permissive ALL-политики + RESTRICTIVE
-- active_user_only из 20260708000003_block_inactive_users.sql). Сама по
-- себе публикация доступ не расширяет — подписчик получит событие, только
-- если строка проходит его RLS.
--
-- REPLICA IDENTITY не меняем: клиент использует событие только как триггер
-- перезагрузки (get_my_tasks()/select с текущими правами), содержимое
-- payload не читается — значений старой/новой строки достаточно по
-- умолчанию (identity по primary key).

alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.vehicles;
alter publication supabase_realtime add table public.drivers;
