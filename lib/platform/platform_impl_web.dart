// Реализации платформенного слоя для веба (и как stub по умолчанию):
// системных уведомлений, окна, трея и автозагрузки нет — везде no-op.
import 'app_autostart.dart';
import 'app_notifications.dart';
import 'window_service.dart';

bool get isWindowsImpl => false;
bool get isAndroidImpl => false;

AppNotifications createNotifications() => NoopNotifications();

WindowService createWindowService() => NoopWindowService();

AutostartService createAutostart() => NoopAutostart();

// dart:io недоступен — считаем, что сеть есть; реальные сетевые ошибки
// обрабатываются на уровне запросов (isNetworkError / офлайн-баннер).
Future<bool> checkConnectivityImpl() async => true;
