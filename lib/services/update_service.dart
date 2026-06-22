import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseUrl;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
  });
}

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/VkSun/ATControl/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final res = await http.get(Uri.parse(_apiUrl), headers: {
        'Accept': 'application/vnd.github+json',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String;
      // пропускаем теги расширения (newtab-v...)
      if (tagName.startsWith('newtab-')) return null;
      final latest = tagName.replaceFirst('v', '');
      if (latest == current) return null;
      if (_compareVersions(latest, current) <= 0) return null;

      final assets = (json['assets'] as List).cast<Map<String, dynamic>>();
      String? downloadUrl;

      if (Platform.isAndroid) {
        final apk = assets.where(
          (a) => (a['name'] as String).endsWith('.apk')).firstOrNull;
        downloadUrl = apk?['browser_download_url'] as String?;
      } else if (Platform.isWindows) {
        final zip = assets.where(
          (a) => (a['name'] as String).endsWith('.zip')).firstOrNull;
        downloadUrl = zip?['browser_download_url'] as String?;
      }

      if (downloadUrl == null) return null;

      return UpdateInfo(
        version: latest,
        downloadUrl: downloadUrl,
        releaseUrl: json['html_url'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  // возвращает >0 если a > b
  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.tryParse).toList();
    final pb = b.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final diff = (pa.elementAtOrNull(i) ?? 0) - (pb.elementAtOrNull(i) ?? 0);
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
