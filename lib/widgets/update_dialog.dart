import 'dart:async';

import 'package:flutter/material.dart';
import '../platform/app_platform.dart';
import '../services/update_service.dart';
import '../l10n/gen/app_localizations.dart';
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
  final l10n = AppLocalizations.of(context);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text(update.type == UpdateType.extension
          ? l10n.extensionUpdateTitle
          : l10n.appUpdateTitle),
      content: DialogScrollContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.type == UpdateType.extension) ...[
            Text(l10n.extensionUpdateBody(update.version)),
            const SizedBox(height: 8),
            Text(
              l10n.extensionUpdateHint,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ] else ...[
            Text(l10n.appUpdateBody(update.version)),
            const SizedBox(height: 8),
            if (AppPlatform.isAndroid)
              Text(
                l10n.appUpdateHintAndroid,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            if (AppPlatform.isWindows)
              Text(
                l10n.appUpdateHintWindows,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
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
          child: Text(l10n.updateLaterButton),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            if (update.type == UpdateType.extension) {
              await UpdateService.dismissExtensionUpdate(update.version);
            }
            // Открывает внешний браузер — ждать здесь больше нечего.
            unawaited(UpdateService.openDownload(update.downloadUrl));
          },
          child: Text(l10n.updateDownloadButton),
        ),
      ],
    ),
  );
}
