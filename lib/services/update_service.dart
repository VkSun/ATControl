import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateType { app, extension }

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseUrl;
  final UpdateType type;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.type,
  });
}

class UpdateService {
  static const _releasesUrl =
      'https://api.github.com/repos/VkSun/ATControl/releases?per_page=15';
  static const _prefKeyDismissedExt = 'dismissed_ext_version';

  static Future<List<UpdateInfo>> checkForUpdates() async {
    final updates = <UpdateInfo>[];
    try {
      final info = await PackageInfo.fromPlatform();
      final currentApp = info.version;

      final res = await http.get(Uri.parse(_releasesUrl), headers: {
        'Accept': 'application/vnd.github+json',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return updates;

      final releases =
          (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();

      // Найти последний релиз приложения и последний релиз расширения
      Map<String, dynamic>? latestAppRelease;
      Map<String, dynamic>? latestExtRelease;

      for (final release in releases) {
        if (release['draft'] == true || release['prerelease'] == true) continue;
        final tag = release['tag_name'] as String;
        if (tag.startsWith('ext-')) {
          latestExtRelease ??= release;
        } else if (tag.startsWith('v')) {
          latestAppRelease ??= release;
        }
      }

      // Проверка обновления приложения
      if (latestAppRelease != null) {
        final tag = latestAppRelease['tag_name'] as String;
        final latest = tag.replaceFirst('v', '');
        if (_compareVersions(latest, currentApp) > 0) {
          final assets = (latestAppRelease['assets'] as List)
              .cast<Map<String, dynamic>>();
          String? downloadUrl;
          if (Platform.isAndroid) {
            final apk = assets
                .where((a) => (a['name'] as String).endsWith('.apk'))
                .firstOrNull;
            downloadUrl = apk?['browser_download_url'] as String?;
          } else if (Platform.isWindows) {
            final zip = assets
                .where((a) => (a['name'] as String).endsWith('.zip'))
                .firstOrNull;
            downloadUrl = zip?['browser_download_url'] as String?;
          }
          if (downloadUrl != null) {
            updates.add(UpdateInfo(
              version: latest,
              downloadUrl: downloadUrl,
              releaseUrl: latestAppRelease['html_url'] as String,
              type: UpdateType.app,
            ));
          }
        }
      }

      // Проверка обновления расширения (только Windows)
      if (Platform.isWindows && latestExtRelease != null) {
        final tag = latestExtRelease['tag_name'] as String;
        final extVersion = tag.replaceFirst('ext-', '');
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getString(_prefKeyDismissedExt) ?? '0.0.0';
        if (_compareVersions(extVersion, dismissed) > 0) {
          updates.add(UpdateInfo(
            version: extVersion,
            downloadUrl: latestExtRelease['html_url'] as String,
            releaseUrl: latestExtRelease['html_url'] as String,
            type: UpdateType.extension,
          ));
        }
      }
    } catch (_) {}
    return updates;
  }

  static Future<void> dismissExtensionUpdate(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyDismissedExt, version);
  }

  // возвращает >0 если a > b
  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final diff =
          (pa.elementAtOrNull(i) ?? 0) - (pb.elementAtOrNull(i) ?? 0);
      if (diff != 0) return diff;
    }
    return 0;
  }

  static Future<void> openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
