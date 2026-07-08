import 'package:flutter/material.dart';
import '../platform/app_platform.dart';
import '../services/update_service.dart';
import 'dialog_scroll_content.dart';

Future<void> checkForUpdates(BuildContext context) async {
  final updates = await UpdateService.checkForUpdates();
  for (final update in updates) {
    if (!context.mounted) return;
    await _showUpdateDialog(context, update);
  }
}

Future<void> _showUpdateDialog(BuildContext context, UpdateInfo update) async {
if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text(update.type == UpdateType.extension
          ? 'Обновление расширения'
          : 'Доступно обновление'),
      content: DialogScrollContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.type == UpdateType.extension) ...[
            Text(
                'Доступна новая версия браузерного расширения ATControl — ${update.version}.'),
            const SizedBox(height: 8),
            const Text(
              'Нажмите «Скачать» — новый установщик уже включает обновлённое расширение.\n'
              'Запустите его — приложение и расширение обновятся автоматически.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ] else ...[
            Text('Версия ${update.version} готова к установке.'),
            const SizedBox(height: 8),
            if (AppPlatform.isAndroid)
              const Text(
                'Нажмите «Скачать» — откроется загрузка APK.\n'
                'После загрузки установите поверх текущей версии.',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            if (AppPlatform.isWindows)
              const Text(
                'Нажмите «Скачать» — откроется загрузка установщика (.exe).\n'
                'Запустите его — он заменит текущую версию автоматически.',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            if (update.type == UpdateType.extension) {
              await UpdateService.dismissExtensionUpdate(update.version);
            }
          },
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            if (update.type == UpdateType.extension) {
              await UpdateService.dismissExtensionUpdate(update.version);
            }
            UpdateService.openDownload(update.downloadUrl);
          },
          child: const Text('Скачать'),
        ),
      ],
    ),
  );
}
