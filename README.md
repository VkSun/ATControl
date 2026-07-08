# ATControl

Система управления автопарком для Windows и Android.

## Возможности

- **Транспорт** — учёт автомобилей, сроки техосмотра, страховки, спец.разрешений, ТО автомобиля и оборудования
- **Водители** — база водителей, сроки водительских удостоверений и медицинских справок, привязка к автомобилю
- **Планировщик** — задачи, автоматические уведомления об истекающих сроках, быстрые заметки, календарь
- **Главная** — сводка истекающих сроков и задач на сегодня/завтра
- **Настройки** — тема оформления, уведомления, пути для импорта/экспорта XLS

## Технологии

- [Flutter](https://flutter.dev) — кроссплатформенный UI фреймворк
- [Supabase](https://supabase.com) — облачная база данных PostgreSQL
- [Riverpod](https://riverpod.dev) — управление состоянием
- [GoRouter](https://pub.dev/packages/go_router) — навигация

## Архитектура: два клиента, одна логика

К Supabase ходят два клиента: Flutter-приложение (`lib/`) и браузерное
расширение на React (`browser-extension/`).

**Правило: логика, нужная обоим клиентам, живёт в БД** — в виде RPC-функций
или view с RLS (`supabase/migrations/`), а не дублируется на Dart и JS.

Существующие общие вызовы:

- `get_my_profile()` — профиль текущего пользователя: строка `user_roles`
  с display-полями из `profiles` (если профиль создан). Используется в
  `currentUserRoleProvider` и `ProfileService` (Flutter) и в `App.jsx`
  (расширение).
- `get_my_tasks(p_from date, p_to date)` — задачи, видимые пользователю
  (expiry + собственные), с опциональным диапазоном дат. Используется в
  `TaskService` (Flutter) и `TodoCard.jsx` (расширение).

Обе функции `SECURITY INVOKER`: RLS-политики таблиц (включая
`active_user_only` для заблокированных пользователей) применяются так же,
как при прямых запросах. Простые CRUD-записи без общей логики клиенты
делают напрямую — их защищает RLS.

## Запуск

### Требования
- Flutter SDK 3.x
- Android Studio (для Android)
- Аккаунт Supabase

### Установка

1. Клонировать репозиторий:
git clone https://github.com/VkSun/ATControl.git

2. Установить зависимости:
flutter pub get

3. Запустить:
flutter run -d windows

### Свой инстанс Supabase (без правки кода)

Конфигурация отделена от исходников (`lib/config.dart`,
`browser-extension/src/lib/supabase.js`); без параметров используются
значения основного инстанса.

**Flutter** — через `--dart-define`:
```bash
flutter run -d windows \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
# то же для flutter build windows / apk
```

**Расширение** — через `.env` (см. `browser-extension/.env.example`):
```bash
cd browser-extension
cp .env.example .env   # заполнить VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY
npm run build
```

**CI/релизы** — GitHub Secrets `SUPABASE_URL` и `SUPABASE_ANON_KEY`
(передаются в сборки через `--dart-define` и `VITE_*`; если секреты не
заданы, используются значения по умолчанию).

## Версия

1.0.0 — первый релиз
