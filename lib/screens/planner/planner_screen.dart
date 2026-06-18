import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/task_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/driver_service.dart';
import '../../utils/theme.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';
import '../../utils/permissions.dart';
import '../../utils/responsive.dart';

final notesProvider = StateProvider<String>((ref) => '');

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late TextEditingController _notesCtrl;
  Timer? _debounceTimer;
  DateTime _calendarMonth = DateTime.now();
  bool _notesSaving = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _loadNotes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpiryTasks());
  }

  Future<void> _loadNotes() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .single();
      if (mounted) _notesCtrl.text = data['content'] ?? '';
    } catch (_) {
      // Заметки ещё не созданы для этого пользователя
      if (mounted) _notesCtrl.text = '';
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _notesSaving = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final existing = await Supabase.instance.client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .limit(1);

      if ((existing as List).isEmpty) {
        await Supabase.instance.client.from('notes').insert({
          'content': _notesCtrl.text,
          'user_id': userId,
        });
      } else {
        await Supabase.instance.client
            .from('notes')
            .update({'content': _notesCtrl.text}).eq('user_id', userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
      }
    } finally {
      if (mounted) setState(() => _notesSaving = false);
    }
  }

  Future<void> _syncExpiryTasks() async {
    setState(() => _syncing = true);
    try {
      final now = DateTime.now();
      final items = <Map<String, dynamic>>[];

      final vehicles = await ref.read(vehicleServiceProvider).getAll();
      for (final v in vehicles) {
        void check(DateTime? date, String type) {
          if (date == null) return;
          final diff = date.difference(now).inDays;
          if (diff <= 30) {
            items.add({
              'title': '$type — ${v.brandModel} (${v.govNumber})',
              'date': date,
              'diff': diff,
              'vehicle_id': v.id,
              'driver_id': null,
            });
          }
        }

        check(v.inspectionDate, 'Техосмотр');
        check(v.insuranceDate, 'Страховка');
        check(v.specialPermitDate, 'Спец. разрешение');
      }

      final drivers = await ref.read(driverServiceProvider).getAll();
      for (final d in drivers) {
        void check(DateTime? date, String type) {
          if (date == null) return;
          final diff = date.difference(now).inDays;
          if (diff <= 30) {
            items.add({
              'title': '$type — ${d.fullName}',
              'date': date,
              'diff': diff,
              'vehicle_id': null,
              'driver_id': d.id,
            });
          }
        }

        check(d.licenseExpiry, 'Вод. удостоверение');
        check(d.medicalExpiry, 'Мед. справка');
      }

      await ref.read(taskServiceProvider).syncExpiryTasks(items);
      ref.invalidate(tasksProvider);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _onNotesChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), _saveNotes);
  }

  @override
  void dispose() {
    if (_debounceTimer?.isActive == true) {
      _debounceTimer!.cancel();
      _saveNotes();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final tasksAsync = ref.watch(tasksProvider);
    final mobile = isMobile(context);

    if (mobile) {
      return _buildMobile(context, colors, tasksAsync);
    }

    return Column(
      children: [
        _TopBar(
          colors: colors,
          syncing: _syncing,
          onAddTask: () => _openAddTask(context),
          onSync: _syncExpiryTasks,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.tableBorder, width: 0.5),
                    ),
                    child: tasksAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                      data: (tasks) => _TaskList(tasks: tasks, colors: colors, ref: ref),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Container(
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
                                if (_notesSaving)
                                  const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesCtrl,
                              onChanged: _onNotesChanged,
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
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.tableBorder, width: 0.5),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: tasksAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                          data: (tasks) => _MiniCalendar(
                            month: _calendarMonth,
                            tasks: tasks,
                            colors: colors,
                            onMonthChanged: (m) => setState(() => _calendarMonth = m),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context, AppColors colors, AsyncValue<List<Task>> tasksAsync) {
    final perms = ref.watch(permissionsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // Календарь закреплён сверху
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: tasksAsync.when(
                loading: () => const SizedBox(height: 180),
                error: (_, __) => const SizedBox(height: 180),
                data: (tasks) => _MiniCalendar(
                  month: _calendarMonth,
                  tasks: tasks,
                  colors: colors,
                  onMonthChanged: (m) => setState(() => _calendarMonth = m),
                ),
              ),
            ),
            // Табы: Задачи / Заметки
            TabBar(
              tabs: const [
                Tab(text: 'Задачи'),
                Tab(text: 'Заметки'),
              ],
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            // Содержимое вкладок
            Expanded(
              child: TabBarView(
                children: [
                  // Вкладка Задачи
                  tasksAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Ошибка: $e')),
                    data: (tasks) {
                      final fmt = DateFormat('dd MMMM', 'ru');
                      final today = DateTime.now();
                      final todayStr = DateFormat('yyyy-MM-dd').format(today);
                      final Map<String, List<Task>> grouped = {};
                      for (final t in tasks) {
                        final key = t.dueDate != null
                            ? DateFormat('yyyy-MM-dd').format(t.dueDate!)
                            : 'Без даты';
                        grouped.putIfAbsent(key, () => []).add(t);
                      }
                      final keys = grouped.keys.toList()..sort();
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 80),
                        children: keys.map((dateKey) {
                          final dateTasks = grouped[dateKey]!;
                          String label;
                          if (dateKey == 'Без даты') {
                            label = 'Без даты';
                          } else {
                            final d = DateTime.parse(dateKey);
                            final diff = d.difference(today).inDays;
                            if (dateKey == todayStr)
                              label = 'Сегодня, ${fmt.format(d)}';
                            else if (diff == 1)
                              label = 'Завтра, ${fmt.format(d)}';
                            else
                              label = fmt.format(d);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                                child: Text(label,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: colors.badgeAmberText)),
                              ),
                              ...dateTasks.map((t) =>
                                  _TaskRow(task: t, colors: colors, ref: ref)),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                  // Вкладка Заметки
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        if (_notesSaving)
                          const Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _notesCtrl,
                            onChanged: _onNotesChanged,
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
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: perms.canAddTask
            ? FloatingActionButton(
                onPressed: () => _openAddTask(context),
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  void _openAddTask(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) =>
          _AddTaskDialog(onSaved: () => ref.invalidate(tasksProvider)),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppColors colors;
  final bool syncing;
  final VoidCallback onAddTask;
  final VoidCallback onSync;

  const _TopBar({
    required this.colors,
    required this.syncing,
    required this.onAddTask,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final perms = ref.watch(permissionsProvider);
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
                bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
          ),
          child: Row(
            children: [
              Text('Планировщик',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              if (perms.canAddTask)
                FilledButton.icon(
                  onPressed: onAddTask,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Добавить задачу',
                      style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    minimumSize: Size.zero,
                  ),
                ),
              const SizedBox(width: 8),
              if (perms.isAdmin)
                OutlinedButton.icon(
                  onPressed: syncing ? null : onSync,
                  icon: syncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5))
                      : const Icon(Icons.sync, size: 14),
                  label: const Text('Обновить сроки',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    minimumSize: Size.zero,
                  ),
                ),
              const Spacer(),
              if (isMobile(context)) ...[
                const Icon(Icons.notifications_outlined, size: 20),
                const SizedBox(width: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final profileAsync = ref.watch(profileProvider);
                    final initials = profileAsync.value?.initials ?? 'АИ';
                    final color = profileAsync.value?.avatarColor ?? '#4361EE';
                    final avatarColor =
                        Color(int.parse(color.replaceFirst('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) => const ProfileDialog()),
                      child: CircleAvatar(
                          radius: 16,
                          backgroundColor: avatarColor,
                          child: Text(initials,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white))),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final AppColors colors;
  final WidgetRef ref;

  const _TaskList(
      {required this.tasks, required this.colors, required this.ref});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMMM', 'ru');
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

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
                final diff = d.difference(today).inDays;
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
                      .map((t) => _TaskRow(task: t, colors: colors, ref: ref)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;
  final AppColors colors;
  final WidgetRef ref;

  const _TaskRow({required this.task, required this.colors, required this.ref});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Удалить задачу?'),
        content: Text('«${task.title}»\n\nЭто действие нельзя отменить.'),
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
        builder: (_) => _AddTaskDialog(
          task: task,
          onSaved: () => ref.invalidate(tasksProvider),
        ),
      );
    }
  }

  void _openExpiryEdit(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ExpiryEditDialog(
          task: task, onSaved: () => ref.invalidate(tasksProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpiry = task.type == 'expiry';
    final isHighPriority = task.priority == 'high';

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
                          ? const Color(0xFF4361EE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: task.isCompleted
                            ? const Color(0xFF4361EE)
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
                    size: 16,
                    color: isHighPriority
                        ? colors.badgeRedText
                        : colors.badgeAmberText),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: perms.canEdit ? () => _openEdit(context) : null,
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpiry
                          ? (isHighPriority
                              ? colors.badgeRedText
                              : colors.badgeAmberText)
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
              if (perms.canDeleteTask)
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

class _ExpiryEditDialog extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback onSaved;
  const _ExpiryEditDialog({required this.task, required this.onSaved});

  @override
  ConsumerState<_ExpiryEditDialog> createState() => _ExpiryEditDialogState();
}

class _ExpiryEditDialogState extends ConsumerState<_ExpiryEditDialog> {
  DateTime? _newDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _newDate = widget.task.dueDate;
  }

  Future<void> _save() async {
    if (_newDate == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Обновить срок?'),
        content: const Text('Дата окончания срока будет обновлена.'),
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
      final taskTitle = widget.task.title;

      // Обновляем дату в соответствующей таблице
      if (widget.task.vehicleId != null) {
        final vehicles = await ref.read(vehicleServiceProvider).getAll();
        final v =
            vehicles.where((v) => v.id == widget.task.vehicleId).firstOrNull;
        if (v != null) {
          Vehicle updated;
          if (taskTitle.startsWith('Техосмотр')) {
            updated = Vehicle(
                id: v.id,
                invNumber: v.invNumber,
                brand: v.brand,
                model: v.model,
                govNumber: v.govNumber,
                year: v.year,
                color: v.color,
                vin: v.vin,
                inspectionDate: _newDate,
                insuranceDate: v.insuranceDate,
                specialPermitDate: v.specialPermitDate,
                toDate: v.toDate,
                toMileage: v.toMileage,
                equipmentType: v.equipmentType,
                equipmentToDate: v.equipmentToDate,
                equipmentHours: v.equipmentHours,
                notes: v.notes);
          } else if (taskTitle.startsWith('Страховка')) {
            updated = Vehicle(
                id: v.id,
                invNumber: v.invNumber,
                brand: v.brand,
                model: v.model,
                govNumber: v.govNumber,
                year: v.year,
                color: v.color,
                vin: v.vin,
                inspectionDate: v.inspectionDate,
                insuranceDate: _newDate,
                specialPermitDate: v.specialPermitDate,
                toDate: v.toDate,
                toMileage: v.toMileage,
                equipmentType: v.equipmentType,
                equipmentToDate: v.equipmentToDate,
                equipmentHours: v.equipmentHours,
                notes: v.notes);
          } else {
            updated = Vehicle(
                id: v.id,
                invNumber: v.invNumber,
                brand: v.brand,
                model: v.model,
                govNumber: v.govNumber,
                year: v.year,
                color: v.color,
                vin: v.vin,
                inspectionDate: v.inspectionDate,
                insuranceDate: v.insuranceDate,
                specialPermitDate: _newDate,
                toDate: v.toDate,
                toMileage: v.toMileage,
                equipmentType: v.equipmentType,
                equipmentToDate: v.equipmentToDate,
                equipmentHours: v.equipmentHours,
                notes: v.notes);
          }
          await ref.read(vehicleServiceProvider).update(v.id, updated);
          ref.invalidate(vehiclesProvider);
        }
      } else if (widget.task.driverId != null) {
        final drivers = await ref.read(driverServiceProvider).getAll();
        final d =
            drivers.where((d) => d.id == widget.task.driverId).firstOrNull;
        if (d != null) {
          Driver updated;
          if (taskTitle.startsWith('Вод.')) {
            updated = Driver(
                id: d.id,
                tabNumber: d.tabNumber,
                lastName: d.lastName,
                firstName: d.firstName,
                middleName: d.middleName,
                birthDate: d.birthDate,
                phone: d.phone,
                address: d.address,
                licenseNumber: d.licenseNumber,
                licenseCategories: d.licenseCategories,
                licenseExpiry: _newDate,
                medicalExpiry: d.medicalExpiry,
                vehicleIds: d.vehicleIds,
                notes: d.notes);
          } else {
            updated = Driver(
                id: d.id,
                tabNumber: d.tabNumber,
                lastName: d.lastName,
                firstName: d.firstName,
                middleName: d.middleName,
                birthDate: d.birthDate,
                phone: d.phone,
                address: d.address,
                licenseNumber: d.licenseNumber,
                licenseCategories: d.licenseCategories,
                licenseExpiry: d.licenseExpiry,
                medicalExpiry: _newDate,
                vehicleIds: d.vehicleIds,
                notes: d.notes);
          }
          await ref.read(driverServiceProvider).update(d.id, updated);
          ref.invalidate(driversProvider);
        }
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
    final dateStr = _newDate != null
        ? '${_newDate!.day.toString().padLeft(2, '0')}.${_newDate!.month.toString().padLeft(2, '0')}.${_newDate!.year}'
        : 'Не указана';

    return AlertDialog(
      title: const Text('Обновить срок'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const Text('Новая дата окончания срока:',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _newDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2040),
                    );
                    if (d != null) setState(() => _newDate = d);
                  },
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(dateStr, style: const TextStyle(fontSize: 13)),
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
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  final DateTime month;
  final List<Task> tasks;
  final AppColors colors;
  final ValueChanged<DateTime> onMonthChanged;

  const _MiniCalendar({
    required this.month,
    required this.tasks,
    required this.colors,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM yyyy', 'ru');
    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday - 1;

    final taskDays = <int>{};
    for (final t in tasks) {
      if (t.dueDate != null &&
          t.dueDate!.year == month.year &&
          t.dueDate!.month == month.month) {
        taskDays.add(t.dueDate!.day);
      }
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 16),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            Expanded(
              child: Text(fmt.format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 16),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month + 1)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
              .map((d) => Expanded(
                  child: Text(d,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF888888)))))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1.2,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, i) {
            if (i < startWeekday) return const SizedBox();
            final day = i - startWeekday + 1;
            final isToday = today.year == month.year &&
                today.month == month.month &&
                today.day == day;
            final hasTask = taskDays.contains(day);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color:
                        isToday ? const Color(0xFF4361EE) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('$day',
                      style: TextStyle(
                          fontSize: 11,
                          color: isToday
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyMedium!.color)),
                ),
                if (hasTask && !isToday)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: colors.badgeRedText, shape: BoxShape.circle),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddTaskDialog extends ConsumerStatefulWidget {
  final Task? task;
  final VoidCallback onSaved;
  const _AddTaskDialog({this.task, required this.onSaved});

  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
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
        content: Text(isEdit ? 'Задача будет обновлена.' : 'Задача будет добавлена в планировщик.'),
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
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
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
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
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
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Время (ЧЧ:ММ)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: _dueTime),
                    onChanged: (v) => _dueTime = v,
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