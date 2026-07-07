import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/vehicle_service.dart';
import '../../services/driver_service.dart';
import '../../services/task_service.dart';
import '../../services/notification_service.dart';
import '../../utils/theme.dart';
import '../../utils/responsive.dart';
import '../settings/settings_screen.dart' show notifyDay7Provider, notifyDay14Provider, notifyDay30Provider;
import '../../widgets/main_layout.dart' show SplitHandle;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  double _dragStartX = 0;
  double _splitAtDragStart = 0;
  double _availWAtDragStart = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerNotifications());
  }

  void _triggerNotifications() {
    NotificationService.checkAndNotify(
      notify7: ref.read(notifyDay7Provider),
      notify14: ref.read(notifyDay14Provider),
      notify30: ref.read(notifyDay30Provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final mobile = isMobile(context);

    if (mobile) {
      return _MobileHome(colors: colors);
    }

    return Column(
      children: [
        _TopBar(colors: colors),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final split = ref.watch(homeSplitProvider);
                const gap = 16.0;
                final availW = constraints.maxWidth - gap;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: availW * split,
                      child: _ExpiryCard(colors: colors, limit: null),
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
                        ref.read(homeSplitProvider.notifier).set(newSplit);
                      },
                    ),
                    Expanded(child: _TasksCard(colors: colors)),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── MOBILE HOME ─────────────────────────────────────────────────────────────

class _MobileHome extends ConsumerWidget {
  final AppColors colors;
  const _MobileHome({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ExpiryCard(colors: colors, limit: 5),
        const SizedBox(height: 12),
        _TasksCard(colors: colors, limit: 5),
      ],
    );
  }
}

// ─── DESKTOP TOP BAR ─────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final AppColors colors;
  const _TopBar({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Главная', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

// ─── EXPIRY CARD ─────────────────────────────────────────────────────────────

class _ExpiryCard extends ConsumerWidget {
  final AppColors colors;
  final int? limit;
  const _ExpiryCard({required this.colors, this.limit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final driversAsync = ref.watch(driversProvider);
    final fmt = DateFormat('dd.MM.yy');
    final now = DateTime.now();
    final mobile = isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text('Истекающие сроки',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Builder(builder: (_) {
            if (vehiclesAsync.isLoading || driversAsync.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final items = <Map<String, dynamic>>[];
            final vehicles = vehiclesAsync.value ?? <Vehicle>[];
            for (final v in vehicles) {
              void check(DateTime? date, String type) {
                if (date == null) return;
                final diff = date.difference(now).inDays;
                if (diff <= 30) {
                  items.add({'label': type, 'subject': v.brandModel,
                    'extra': v.govNumber, 'date': date, 'diff': diff});
                }
              }
              check(v.inspectionDate, 'Техосмотр');
              check(v.insuranceDate, 'Страховка');
              check(v.specialPermitDate, 'Спец. разрешение');
            }

            final drivers = driversAsync.value ?? <Driver>[];
            for (final d in drivers) {
              void check(DateTime? date, String type) {
                if (date == null) return;
                final diff = date.difference(now).inDays;
                if (diff <= 30) {
                  items.add({'label': type, 'subject': d.fullName,
                    'extra': '', 'date': date, 'diff': diff});
                }
              }
              check(d.licenseExpiry, 'Вод. удостоверение');
              check(d.medicalExpiry, 'Мед. справка');
            }

            items.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Нет истекающих сроков')),
              );
            }

            final shown = limit != null ? items.take(limit!).toList() : items;

            final listWidget = ListView.builder(
              shrinkWrap: mobile,
              physics: mobile
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final item = shown[i];
                final diff = item['diff'] as int;
                final date = item['date'] as DateTime;
                Color badgeBg, badgeText;
                if (diff < 0 || diff <= 7) {
                  badgeBg = colors.badgeRed; badgeText = colors.badgeRedText;
                } else if (diff <= 14) {
                  badgeBg = colors.badgeAmber; badgeText = colors.badgeAmberText;
                } else {
                  badgeBg = colors.badgeGreen; badgeText = colors.badgeGreenText;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['subject'] as String,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                            Text(item['label'] as String,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .color)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(fmt.format(date),
                            style: TextStyle(
                                fontSize: 11,
                                color: badgeText,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                );
              },
            );

            return mobile ? listWidget : Expanded(child: listWidget);
          }),
        ],
      ),
    );
  }
}

// ─── TASKS CARD ──────────────────────────────────────────────────────────────

class _TasksCard extends ConsumerWidget {
  final AppColors colors;
  final int? limit;
  const _TasksCard({required this.colors, this.limit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final fmt = DateFormat('d MMMM', 'ru');
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final mobile = isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: mobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text('Задачи на сегодня и завтра',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          tasksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Ошибка: $e'),
            ),
            data: (allTasks) {
              var todayTasks = allTasks.where((t) =>
                t.dueDate != null &&
                t.dueDate!.year == today.year &&
                t.dueDate!.month == today.month &&
                t.dueDate!.day == today.day).toList();

              var tomorrowTasks = allTasks.where((t) =>
                t.dueDate != null &&
                t.dueDate!.year == tomorrow.year &&
                t.dueDate!.month == tomorrow.month &&
                t.dueDate!.day == tomorrow.day).toList();

              if (limit != null) {
                final remaining = limit!;
                if (todayTasks.length > remaining) {
                  todayTasks = todayTasks.take(remaining).toList();
                  tomorrowTasks = [];
                } else {
                  tomorrowTasks = tomorrowTasks
                      .take(remaining - todayTasks.length)
                      .toList();
                }
              }

              if (todayTasks.isEmpty && tomorrowTasks.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Задач на сегодня и завтра нет')),
                );
              }

              final content = ListView(
                shrinkWrap: mobile,
                physics: mobile
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  if (todayTasks.isNotEmpty) ...[
                    _dayLabel('Сегодня, ${fmt.format(today)}', colors, context),
                    ...todayTasks.map((t) => _TaskRow(task: t, colors: colors)),
                  ],
                  if (tomorrowTasks.isNotEmpty) ...[
                    _dayLabel('Завтра, ${fmt.format(tomorrow)}', colors, context),
                    ...tomorrowTasks.map((t) => _TaskRow(task: t, colors: colors)),
                  ],
                ],
              );

              return mobile ? content : Expanded(child: content);
            },
          ),
        ],
      ),
    );
  }

  Widget _dayLabel(String text, AppColors colors, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: colors.badgeAmberText, letterSpacing: 0.3)),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  final Task task;
  final AppColors colors;
  const _TaskRow({required this.task, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await ref.read(taskServiceProvider).toggleComplete(task.id, !task.isCompleted);
              ref.invalidate(tasksProvider);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: task.isCompleted ? const Color(0xFF4361EE) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: task.isCompleted ? const Color(0xFF4361EE) : colors.tableBorder,
                  width: 1.5,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(task.title,
              style: TextStyle(
                fontSize: 12,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (task.dueTime != null)
            Text(task.dueTime!.substring(0, 5),
              style: TextStyle(fontSize: 10, color: colors.badgeAmberText)),
        ],
      ),
    );
  }
}
