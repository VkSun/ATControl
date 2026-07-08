/// Автозагрузка при старте системы. Реализация есть только на Windows;
/// на Android и вебе — no-op.
abstract class AutostartService {
  Future<void> init();

  Future<bool> isEnabled();

  Future<void> setEnabled(bool value);
}

class NoopAutostart implements AutostartService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool value) async {}
}
