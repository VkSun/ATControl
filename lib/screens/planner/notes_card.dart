import 'package:flutter/material.dart';
import '../../utils/theme.dart';

/// Быстрые заметки. Состояние (контроллер, автосохранение) живёт в
/// PlannerScreen — здесь только представление.
class NotesCard extends StatelessWidget {
  final TextEditingController controller;
  final bool saving;
  final ValueChanged<String> onChanged;
  final AppColors colors;

  const NotesCard({
    super.key,
    required this.controller,
    required this.saving,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Быстрые заметки',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (saving)
                const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Введите заметку...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.tableBorder),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Мобильная вкладка «Заметки».
class NotesTab extends StatelessWidget {
  final TextEditingController controller;
  final bool saving;
  final ValueChanged<String> onChanged;
  final AppColors colors;

  const NotesTab({
    super.key,
    required this.controller,
    required this.saving,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          if (saving)
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Введите заметку...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.tableBorder),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
