// Единственное место выбора платформенной реализации: условный импорт
// подставляет io- или веб-вариант; остальной код работает с интерфейсами.
import 'platform_impl_web.dart' if (dart.library.io) 'platform_impl_io.dart'
    as impl;

import 'app_autostart.dart';
import 'app_notifications.dart';
import 'window_service.dart';

export 'app_autostart.dart' show AutostartService;
export 'app_notifications.dart' show AppNotifications;
export 'window_service.dart' show WindowHandlers, WindowService;

class AppPlatform {
  AppPlatform._();

  static final AppNotifications notifications = impl.createNotifications();
  static final WindowService window = impl.createWindowService();
  static final AutostartService autostart = impl.createAutostart();

  /// Замена Platform.isWindows/isAndroid без dart:io (на вебе — false).
  static bool get isWindows => impl.isWindowsImpl;
  static bool get isAndroid => impl.isAndroidImpl;

  /// Быстрая проверка доступности сети (индикатор в сайдбаре).
  static Future<bool> checkConnectivity() => impl.checkConnectivityImpl();
}
