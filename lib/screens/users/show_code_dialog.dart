import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/dialog_scroll_content.dart';

class ShowCodeDialog extends StatelessWidget {
  final String code;
  const ShowCodeDialog({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Код приглашения создан'),
      content: DialogScrollContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Передайте этот код пользователю:',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3DE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(code,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                    color: Color(0xFF27500A))),
          ),
          const SizedBox(height: 12),
          const Text(
              'Код действителен 7 дней и может быть использован только один раз.',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Код скопирован'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  width: 200),
            );
          },
          tooltip: 'Копировать',
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
