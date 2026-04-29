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

3. Указать ключи Supabase в `lib/main.dart`:
```dart
await Supabase.initialize(
  url: 'ВАША_SUPABASE_URL',
  anonKey: 'ВАШ_SUPABASE_ANON_KEY',
);
```

4. Запустить:
flutter run -d windows

## Версия

1.0.0 — первый релиз
