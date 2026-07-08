import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/app_platform.dart';
import '../services/offline_state.dart';
import '../screens/settings/settings_screen.dart' show closeToTrayProvider;
import 'dialog_scroll_content.dart';

/// Пользователь закрывает окно (Windows): в трей или диалог подтверждения.
Future<void> handleWindowCloseRequest(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;
  final closeToTray = ref.read(closeToTrayProvider);
  if (closeToTray) {
    await AppPlatform.window.hide();
  } else {
    await showCloseConfirmation(context);
  }
}

Future<void> showCloseConfirmation(BuildContext context) async {
  if (!context.mounted) return;
  final pendingCount = queueCountNotifier.value;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      surfaceTintColor: Colors.transparent,
      title: const Text('Завершить ATControl?'),
      content: pendingCount > 0
          ? DialogScrollContent(
              child: Text(
                'Несинхронизированных изменений: $pendingCount.\n'
                'При закрытии они могут быть потеряны.',
              ),
            )
          : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Завершить'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await AppPlatform.window.destroy();
  }
}
