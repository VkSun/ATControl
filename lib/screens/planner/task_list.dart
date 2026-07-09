import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../utils/theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/permissions.dart';
import '../../widgets/dialog_scroll_content.dart';
import 'add_task_dialog.dart';
import 'expiry_edit_dialog.dart';

class TaskList extends StatelessWidget {
  final List<Task> tasks;
  final AppColors colors;
  final WidgetRef ref;

  const TaskList(
      {super.key, required this.tasks, required this.colors, required this.ref});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMMM', 'ru');
    final todayStr = toDateString(DateTime.now());

    final Map<String, List<Task>> grouped = {};
    for (final t in tasks) {
      final key = t.dueDate != null
          ? DateFormat('yyyy-MM-dd').format(t.dueDate!)
          : 'Без даты';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final keys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text('Список задач',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: keys.map((dateKey) {
              final dateTasks = grouped[dateKey]!;
              String label;
              if (dateKey == 'Без даты') {
                label = 'Без даты';
              } else {
                final d = DateTime.parse(dateKey);
                final diff = daysUntil(d);
                if (dateKey == todayStr) {
                  label = 'Сегодня, ${fmt.format(d)}';
                } else if (diff == 1)
                  label = 'Завтра, ${fmt.format(d)}';
                else
                  label = fmt.format(d);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.badgeAmberText,
                            letterSpacing: 0.3)),
                  ),
                  ...dateTasks
                      .map((t) => TaskRow(task: t, colors: colors, ref: ref)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class TaskRow extends StatelessWidget {
  final Task task;
  final AppColors colors;
  final WidgetRef ref;

  const TaskRow({super.key, required this.task, required this.colors, required this.ref});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Удалить задачу?'),
        content: DialogScrollContent(
            child: Text('«${task.title}»\n\nЭто действие нельзя отменить.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE24B4A)),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(taskServiceProvider).delete(task.id);
      ref.invalidate(tasksProvider);
    }
  }

  void _openEdit(BuildContext context) {
    if (task.type == 'expiry') {
      _openExpiryEdit(context);
    } else {
      showDialog(
        context: context,
        builder: (_) => AddTaskDialog(
          task: task,
          onSaved: () => ref.invalidate(tasksProvider),
        ),
      );
    }
  }

  void _openExpiryEdit(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ExpiryEditDialog(
          task: task, onSaved: () => ref.invalidate(tasksProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpiry = task.type == 'expiry';
    final isHighPriority = task.priority == 'high';
    // Как на главной: красный (просрочено/≤7 дней), жёлтый (≤14),
    // зелёный (дальше). priority у задачи-срока бинарный ('high'/'normal'),
    // поэтому третий уровень считаем от даты, а не от priority.
    final expiryDiff = task.dueDate != null ? daysUntil(task.dueDate!) : null;
    final expiryColor = expiryDiff == null
        ? colors.badgeAmberText
        : expiryDiff < 0 || expiryDiff <= 7
            ? colors.badgeRedText
            : expiryDiff <= 14
                ? colors.badgeAmberText
                : colors.badgeGreenText;

    return Consumer(
      builder: (context, ref, _) {
        final perms = ref.watch(permissionsProvider);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHighPriority && isExpiry
                  ? colors.badgeRed
                  : colors.tableBorder,
              width: isHighPriority && isExpiry ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              if (!isExpiry && perms.canCompleteTask)
                GestureDetector(
                  onTap: () async {
                    await ref
                        .read(taskServiceProvider)
                        .toggleComplete(task.id, !task.isCompleted);
                    ref.invalidate(tasksProvider);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: task.isCompleted
                            ? AppTheme.primaryColor
                            : colors.tableBorder,
                        width: 1.5,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                )
              else if (!isExpiry)
                const SizedBox(width: 16, height: 16)
              else
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: expiryColor),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: perms.canEdit ? () => _openEdit(context) : null,
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpiry
                          ? expiryColor
                          : Theme.of(context).textTheme.bodyMedium!.color,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
              if (task.dueTime != null)
                Text(task.dueTime!.substring(0, 5),
                    style:
                        TextStyle(fontSize: 10, color: colors.badgeAmberText)),
              const SizedBox(width: 8),
              // Задачи-сроки генерируются автоматически: вручную не удаляются,
              // исчезнут сами после обновления даты у записи.
              if (perms.canDeleteTask && !isExpiry)
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Icon(Icons.close,
                      size: 14,
                      color: Theme.of(context).textTheme.bodySmall!.color),
                ),
            ],
          ),
        );
      },
    );
  }
}
