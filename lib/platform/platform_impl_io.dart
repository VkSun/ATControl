// Реализации платформенного слоя для dart:io-платформ (Windows, Android,
// десктопы). Выбирается условным импортом в app_platform.dart.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app_autostart.dart';
import 'app_notifications.dart';
import 'window_service.dart';

bool get isWindowsImpl => Platform.isWindows;
bool get isAndroidImpl => Platform.isAndroid;

AppNotifications createNotifications() => Platform.isAndroid
    ? AndroidNotifications()
    : Platform.isWindows
        ? WindowsNotifications()
        : NoopNotifications();

WindowService createWindowService() =>
    Platform.isWindows ? WindowsWindowService() : NoopWindowService();

AutostartService createAutostart() =>
    Platform.isWindows ? WindowsAutostart() : NoopAutostart();

Future<bool> checkConnectivityImpl() async {
  final result = await InternetAddress.lookup('supabase.co')
      .timeout(const Duration(seconds: 5));
  return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
}

// ─── Уведомления ────────────────────────────────────────────────────────────

class AndroidNotifications implements AppNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> show({required String title, required String body}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'atcontrol_expiry',
        'Истечение сроков',
        channelDescription: 'Уведомления об истечении сроков документов',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(0, title, body, details);
  }
}

class WindowsNotifications implements AppNotifications {
  LocalNotification? _lastNotification;

  @override
  Future<void> init() async {
    await localNotifier.setup(appName: 'ATControl');
  }

  @override
  Future<void> show({required String title, required String body}) async {
    await _lastNotification?.close();
    _lastNotification = LocalNotification(title: title, body: body);
    await _lastNotification!.show();
  }
}

// ─── Окно и трей (Windows) ──────────────────────────────────────────────────

class WindowsWindowService
    with WindowListener, TrayListener
    implements WindowService {
  WindowHandlers? _handlers;

  @override
  Future<void> init() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await _limitMinimumSize();
  }

  // Не даём ужать окно меньше четверти экрана (половина ширины × половина
  // высоты) — на меньшем окне десктопная раскладка (сайдбар + контент)
  // банально не помещается.
  Future<void> _limitMinimumSize() async {
    final displays = PlatformDispatcher.instance.displays;
    if (displays.isEmpty) return;
    final display = displays.first;
    final logicalSize = display.size / display.devicePixelRatio;
    await windowManager.setMinimumSize(logicalSize / 2);
  }

  @override
  void addHandlers(WindowHandlers handlers) {
    _handlers = handlers;
    windowManager.addListener(this);
    trayManager.addListener(this);
  }

  @override
  void removeHandlers() {
    _handlers = null;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  @override
  Future<void> setupTray() async {
    await trayManager.setIcon('assets/icons/app_icon.ico');
    await trayManager.setToolTip('ATControl');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Развернуть ATControl'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Закрыть ATControl'),
    ]));
  }

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> destroy() async {
    // windowManager.destroy()/trayManager.destroy() лишь просят Win32
    // аккуратно закрыть окно и убрать иконку из трея — если ответ по
    // platform-каналу не придёт (например, цикл сообщений уже занят
    // диалогом закрытия), await здесь никогда не вернётся и приложение
    // зависнет как «не отвечает». Даём короткое окно на аккуратное
    // закрытие, но в любом случае завершаем процесс сами.
    await Future.wait([
      trayManager.destroy(),
      windowManager.destroy(),
    ]).timeout(const Duration(seconds: 1), onTimeout: () => []);
    exit(0);
  }

  // WindowListener
  @override
  void onWindowClose() {
    _handlers?.onCloseRequested();
  }

  // TrayListener
  @override
  void onTrayIconMouseDown() {
    showAndFocus();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      showAndFocus();
    } else if (menuItem.key == 'quit') {
      _handlers?.onQuitRequested();
    }
  }
}

// ─── Автозагрузка (Windows) ─────────────────────────────────────────────────

class WindowsAutostart implements AutostartService {
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    final info = await PackageInfo.fromPlatform();
    LaunchAtStartup.instance.setup(
      appName: info.appName,
      appPath: Platform.resolvedExecutable,
    );
    _initialized = true;
  }

  @override
  Future<bool> isEnabled() => LaunchAtStartup.instance.isEnabled();

  @override
  Future<void> setEnabled(bool value) async {
    if (value) {
      await LaunchAtStartup.instance.enable();
    } else {
      await LaunchAtStartup.instance.disable();
    }
  }
}
