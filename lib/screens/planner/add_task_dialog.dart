import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../utils/date_picker.dart';
import '../../widgets/dialog_scroll_content.dart';

class AddTaskDialog extends ConsumerStatefulWidget {
  final Task? task;
  final VoidCallback onSaved;
  const AddTaskDialog({super.key, this.task, required this.onSaved});

  @override
  ConsumerState<AddTaskDialog> createState() => AddTaskDialogState();
}

class AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  late TextEditingController _titleCtrl;
  DateTime? _dueDate;
  String _dueTime = '';
  String _priority = 'normal';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _dueDate = widget.task?.dueDate;
    _dueTime = widget.task?.dueTime?.substring(0, 5) ?? '';
    _priority = widget.task?.priority ?? 'normal';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final isEdit = widget.task != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(isEdit ? 'Сохранить изменения?' : 'Добавить задачу?'),
        content: DialogScrollContent(
            child: Text(isEdit
                ? 'Задача будет обновлена.'
                : 'Задача будет добавлена в планировщик.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final task = Task(
        id: widget.task?.id ?? '',
        title: _titleCtrl.text.trim(),
        dueDate: _dueDate,
        dueTime: _dueTime.isEmpty ? null : '$_dueTime:00',
        priority: _priority,
        isCompleted: widget.task?.isCompleted ?? false,
      );
      if (widget.task == null) {
        await ref.read(taskServiceProvider).create(task);
      } else {
        await ref.read(taskServiceProvider).update(task.id, task);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    return AlertDialog(
      title: Text(isEdit ? 'Редактировать задачу' : 'Новая задача'),
      content: DialogScrollContent(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Название задачи',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final d = await showAppDatePicker(
                        context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      _dueDate != null
                          ? '${_dueDate!.day.toString().padLeft(2, '0')}.${_dueDate!.month.toString().padLeft(2, '0')}.${_dueDate!.year}'
                          : 'Дата',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final parts = _dueTime.split(':');
                      final initial = TimeOfDay(
                        hour: int.tryParse(parts.elementAtOrNull(0) ?? '') ?? TimeOfDay.now().hour,
                        minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0,
                      );
                      final t = await showAppTimePicker(context, initialTime: initial);
                      if (t != null) {
                        setState(() => _dueTime =
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Время',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _dueTime.isEmpty ? '--:--' : _dueTime,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Приоритет:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'normal',
                        label: Text('Обычный', style: TextStyle(fontSize: 11))),
                    ButtonSegment(
                        value: 'high',
                        label: Text('Высокий', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(0, 32)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}
