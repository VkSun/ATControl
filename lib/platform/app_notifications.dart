/// Показ системных уведомлений. Общая логика (запрос данных, подсчёт
/// 7/14/30 дней) живёт в NotificationService — сюда уходит только показ.
abstract class AppNotifications {
  /// Инициализация плагина и запрос разрешения (Android).
  Future<void> init();

  /// Показывает (или заменяет предыдущее) уведомление.
  Future<void> show({required String title, required String body});
}

/// Веб и прочие платформы без системных уведомлений.
class NoopNotifications implements AppNotifications {
  @override
  Future<void> init() async {}

  @override
  Future<void> show({required String title, required String body}) async {}
}
