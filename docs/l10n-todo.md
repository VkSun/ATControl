# Локализация: чек-лист миграции на AppLocalizations

Инфраструктура (`flutter gen-l10n`, `lib/l10n/app_ru.arb` + `app_en.arb`,
`AppLocalizations.delegate` в `main.dart`) настроена. Готовы модули:

- ✅ **auth** (`lib/screens/auth/`) — login/register/invite, типизированные
  ошибки `AuthService` (`lib/models/auth_exceptions.dart`).
- ✅ **main_layout** (`lib/widgets/main_layout.dart`, `sidebar.dart`,
  `sync_sheet.dart`, `window_close.dart`, `update_dialog.dart`).

`locale` в `main.dart` пока зафиксирован `const Locale('ru')` — переключить
на системную (убрать хардкод, оставить только `supportedLocales`) только
когда миграция ниже будет завершена, иначе часть экранов останется
русской независимо от локали устройства.

## Как переносить очередной модуль

1. Добавь строки в `lib/l10n/app_ru.arb` (с `@key` описанием) и
   `lib/l10n/app_en.arb` (без описаний, только перевод) — ключи должны
   совпадать 1:1, `flutter gen-l10n` падает при расхождении.
2. Параметризованные строки — ARB-плейсхолдеры
   (`"{name}"` + `"placeholders"` в `@key`). Если параметр — счётное
   существительное, которое грамматически меняет форму (не просто число
   в скобках вроде `(N)`), используй ICU `plural` с категориями
   `one/few/many/other` для ru (пример: `passwordTooShortError` в auth).
3. Тексты, которые **бросает сервис** (Exception/кастомное исключение),
   не локализуй вызовом `AppLocalizations.of(context)` из сервиса — сервис
   не знает про BuildContext. Вместо этого:
   - заведи типизированное исключение в `lib/models/` (см.
     `auth_exceptions.dart` как образец: `implements Exception`,
     `toString()` — русский текст для логов, не для UI);
   - сервис бросает его вместо `Exception('...')`;
   - экран (или общий helper рядом с экранами, см.
     `lib/screens/auth/auth_error_text.dart`) в `catch` определяет тип
     исключения и выбирает локализованную строку, с фолбэком для
     нераспознанных ошибок.
4. `import '../../l10n/gen/app_localizations.dart';` и
   `final l10n = AppLocalizations.of(context);` в начале `build()`
   (или в месте использования, если `context` доступен только там —
   например, в `validator:` замыканиях `TextFormField`).
5. `flutter gen-l10n` (или просто `flutter pub get`/`flutter test` —
   генерация запускается автоматически) → `flutter analyze` (baseline
   сейчас 45 issues, новых быть не должно) → `flutter test`.
6. Если тест строит `MaterialApp` НЕ через общий `test/helpers.dart`
   (сейчас так делают `desktop_layout_test.dart`, `dialog_layout_test.dart`,
   `edit_dialog_test.dart` — у каждого свой локальный `pumpApp`), и
   переносимый экран/виджет теперь вызывает `AppLocalizations.of(context)`,
   добавь в его `MaterialApp`:
   ```dart
   locale: const Locale('ru'),
   localizationsDelegates: AppLocalizations.localizationsDelegates,
   supportedLocales: AppLocalizations.supportedLocales,
   ```
   Без явного `locale:` тест резолвит системную (в `flutter test` — `en`),
   что скрыто проваливает сравнения с русским текстом.
7. Один модуль — один коммит.

## Оставшиеся модули (хардкод по-русски)

Порядок — предложение, не жёсткое требование; ориентируйся на связность
экранов.

- [ ] **profile** — `lib/screens/profile/profile_dialog.dart`.
- [ ] **transport** — `lib/screens/transport/transport_screen.dart`,
      `vehicle_edit_dialog.dart`.
- [ ] **drivers** — `lib/screens/drivers/drivers_screen.dart`,
      `driver_edit_dialog.dart`.
- [ ] **planner** — `lib/screens/planner/planner_screen.dart`,
      `task_list.dart`, `add_task_dialog.dart`, `expiry_edit_dialog.dart`,
      `notes_card.dart` (и `mini_calendar.dart`, если там остались строки —
      сейчас там только `DateFormat(..., 'ru')`, который трогать не нужно,
      формат дат — не про этот чек-лист).
- [ ] **home** — `lib/screens/home/home_screen.dart`.
- [ ] **users** — `lib/screens/users/*.dart` (users_screen, users_tab,
      invitations_tab, edit_user_dialog, create_invitation_dialog,
      show_code_dialog, departments_tab).
- [ ] **settings** — `lib/screens/settings/settings_screen.dart`,
      `department_editor.dart`, `import_dialog.dart`.
- [ ] **shared widgets** — `lib/widgets/async_value_view.dart` (общий
      loading/error, дальше — `lib/utils/date_picker.dart` (общий пикер дат,
      использует `DateFormat(..., 'ru')` для подписи месяцев — если решишь
      переводить, месяцы тоже нужно брать из `intl` под текущую локаль,
      а не оставлять хардкод `'ru'`).

### Известные сервисные исключения без типа (найдены при подготовке чек-листа)

Эти два throw ещё используют «сырой» `Exception('русский текст')» —
при миграции соответствующего экрана заведи типизированные исключения
по образцу `auth_exceptions.dart`:

- `lib/services/profile_service.dart:33` — `Пользователь не авторизован`.
- `lib/services/weather_service.dart:23` — `Ошибка погоды` (используется
  из sidebar — уже частично мигрированного модуля; текст самой ошибки не
  показывается пользователю напрямую сейчас, так что можно отложить до
  ревизии `weather_service.dart` целиком).
