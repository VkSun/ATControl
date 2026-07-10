import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';
import '../../widgets/dialog_scroll_content.dart';

Future<void> showAboutAppDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const AboutAppDialog(),
  );
}

class AboutAppDialog extends StatefulWidget {
  const AboutAppDialog({super.key});

  @override
  State<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<AboutAppDialog> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://atcontrol.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final info = _info;
    final versionLine = info == null
        ? ' '
        : 'Версия ${info.version}'
            '${info.buildNumber.isNotEmpty ? ' (${info.buildNumber})' : ''}';

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      content: DialogScrollContent(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('ATControl',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(versionLine,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 14),
            const Text('Система управления автопарком',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _openWebsite,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 14, color: colors.accent),
                    const SizedBox(width: 6),
                    Text('ATControl.com',
                        style: TextStyle(
                            fontSize: 13,
                            color: colors.accent,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text('Автор: Webchik',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 22),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('ПОСТРОЕНО НА',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _TechChip('Flutter', colors: colors),
                _TechChip('Dart', colors: colors),
                _TechChip('Supabase', colors: colors),
                _TechChip('Riverpod', colors: colors),
                _TechChip('go_router', colors: colors),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  final AppColors colors;
  const _TechChip(this.label, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
