import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AutostartService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (!Platform.isWindows) return;
    if (_initialized) return;
    final info = await PackageInfo.fromPlatform();
    LaunchAtStartup.instance.setup(
      appName: info.appName,
      appPath: Platform.resolvedExecutable,
    );
    _initialized = true;
  }

  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    return LaunchAtStartup.instance.isEnabled();
  }

  static Future<void> setEnabled(bool value) async {
    if (!Platform.isWindows) return;
    if (value) {
      await LaunchAtStartup.instance.enable();
    } else {
      await LaunchAtStartup.instance.disable();
    }
  }
}
