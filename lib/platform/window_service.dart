import 'package:flutter/foundation.dart';

/// Обработчики событий окна/трея, которые требуют контекста приложения
/// (диалог подтверждения, настройка «сворачивать в трей»).
class WindowHandlers {
  /// Пользователь закрывает окно (крестик).
  final Future<void> Function() onCloseRequested;

  /// Пункт «Закрыть» в меню трея.
  final VoidCallback onQuitRequested;

  const WindowHandlers({
    required this.onCloseRequested,
    required this.onQuitRequested,
  });
}

/// Управление окном и треем. Реализация есть только на Windows;
/// на Android и вебе — no-op.
abstract class WindowService {
  /// Вызывается из main() до runApp: prevent-close и т.п.
  Future<void> init();

  /// Регистрирует обработчики окна/трея.
  void addHandlers(WindowHandlers handlers);

  void removeHandlers();

  /// Создаёт иконку и меню трея.
  Future<void> setupTray();

  Future<void> hide();

  Future<void> showAndFocus();

  /// Завершает приложение (обходит prevent-close).
  Future<void> destroy();
}

class NoopWindowService implements WindowService {
  @override
  Future<void> init() async {}

  @override
  void addHandlers(WindowHandlers handlers) {}

  @override
  void removeHandlers() {}

  @override
  Future<void> setupTray() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> showAndFocus() async {}

  @override
  Future<void> destroy() async {}
}
