import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../utils/theme.dart';
import '../../utils/date_utils.dart';
import '../../utils/permissions.dart';
import '../../utils/responsive.dart';
import '../../widgets/main_layout.dart' show SplitHandle;
import '../../widgets/async_value_view.dart';
import 'add_task_dialog.dart';
import 'mini_calendar.dart';
import 'notes_card.dart';
import 'task_list.dart';

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
  double _dragStartX = 0;
  double _splitAtDragStart = 0;
  double _availWAtDragStart = 1;

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
      if (mounted) _notesCtrl.text = data['content'] as String? ?? '';
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
      await ref.read(taskServiceProvider).syncExpiryTasks();
      ref.invalidate(tasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось обновить сроки: $e')));
      }
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
    final mobile = isPhone(context);

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final split = ref.watch(plannerSplitProvider);
                const gap = 16.0;
                final availW = constraints.maxWidth - gap;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: availW * split,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.tableBorder, width: 0.5),
                        ),
                        child: AsyncValueView(
                          value: tasksAsync,
                          onRetry: tasksProvider,
                          builder: (tasks) => TaskList(tasks: tasks, colors: colors, ref: ref),
                        ),
                      ),
                    ),
                    SplitHandle(
                      gap: gap,
                      colors: colors,
                      onDragStart: (d) {
                        _dragStartX = d.globalPosition.dx;
                        _splitAtDragStart = split;
                        _availWAtDragStart = availW;
                      },
                      onDrag: (d) {
                        final dx = d.globalPosition.dx - _dragStartX;
                        final newSplit = (_splitAtDragStart + dx / _availWAtDragStart).clamp(0.2, 0.8);
                        ref.read(plannerSplitProvider.notifier).set(newSplit);
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          NotesCard(
                            controller: _notesCtrl,
                            saving: _notesSaving,
                            onChanged: _onNotesChanged,
                            colors: colors,
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
                              data: (tasks) => MiniCalendar(
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
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context, AppColors colors, AsyncValue<List<Task>> tasksAsync) {
    final perms = ref.watch(permissionsProvider);
    // В альбомной ориентации закреплённый календарь не помещается по высоте —
    // тогда он уходит внутрь прокручиваемого списка задач.
    final compactHeight = MediaQuery.sizeOf(context).height < 500;

    Widget buildCalendar(List<Task> tasks) => MiniCalendar(
          month: _calendarMonth,
          tasks: tasks,
          colors: colors,
          onMonthChanged: (m) => setState(() => _calendarMonth = m),
        );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // Календарь закреплён сверху (только если хватает высоты)
            if (!compactHeight)
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: tasksAsync.when(
                  loading: () => const SizedBox(height: 180),
                  error: (_, __) => const SizedBox(height: 180),
                  data: buildCalendar,
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
                  AsyncValueView(
                    value: tasksAsync,
                    onRetry: tasksProvider,
                    builder: (tasks) {
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
                      return RefreshIndicator(
                        onRefresh: () => ref.refresh(tasksProvider.future),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 80),
                          children: [
                          if (compactHeight)
                            Container(
                              color: Theme.of(context).cardColor,
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                              // Ширина ограничена, иначе сетка календаря
                              // растёт по высоте пропорционально ширине.
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  child: buildCalendar(tasks),
                                ),
                              ),
                            ),
                          ...keys.map((dateKey) {
                          final dateTasks = grouped[dateKey]!;
                          String label;
                          if (dateKey == 'Без даты') {
                            label = 'Без даты';
                          } else {
                            final d = DateTime.parse(dateKey);
                            final diff = daysUntil(d);
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
                                  TaskRow(task: t, colors: colors, ref: ref)),
                            ],
                          );
                        }),
                          ],
                        ),
                      );
                    },
                  ),
                  // Вкладка Заметки
                  NotesTab(
                    controller: _notesCtrl,
                    saving: _notesSaving,
                    onChanged: _onNotesChanged,
                    colors: colors,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: (perms.canAddTask || perms.isLoading)
            ? FloatingActionButton(
                onPressed: perms.isLoading ? null : () => _openAddTask(context),
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
          AddTaskDialog(onSaved: () => ref.invalidate(tasksProvider)),
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
              if (perms.canAddTask || perms.isLoading)
                FilledButton.icon(
                  onPressed: perms.isLoading ? null : onAddTask,
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
              if (perms.isAdmin || perms.isLoading)
                OutlinedButton.icon(
                  onPressed: (syncing || perms.isLoading) ? null : onSync,
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
            ],
          ),
        );
      },
    );
  }
}
