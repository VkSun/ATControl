import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/vehicle_service.dart';
import '../../services/driver_service.dart';
import '../../services/task_service.dart';
import '../../utils/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        _TopBar(colors: colors),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ExpiryCard(colors: colors)),
                const SizedBox(width: 16),
                Expanded(child: _TasksCard(colors: colors, ref: ref)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
          const Spacer(),
          const Icon(Icons.notifications_outlined, size: 20),
          const SizedBox(width: 12),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(profileProvider);
              final initials = profileAsync.value?.initials ?? 'АИ';
              final color = profileAsync.value?.avatarColor ?? '#4361EE';
              final avatarColor = Color(int.parse(color.replaceFirst('#', '0xFF')));
              return GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const ProfileDialog(),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: avatarColor,
                  child: Text(initials,
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExpiryCard extends ConsumerWidget {
  final AppColors colors;
  const _ExpiryCard({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final driversAsync = ref.watch(driversProvider);
    final fmt = DateFormat('dd.MM.yyyy');
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Истекающие сроки', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: Builder(builder: (_) {
              if (vehiclesAsync.isLoading || driversAsync.isLoading) {
                return const Center(child: CircularProgressIndicator());
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
                return const Center(child: Text('Нет истекающих сроков'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final diff = item['diff'] as int;
                  final date = item['date'] as DateTime;
                  Color badgeBg, badgeText;
                  if (diff < 0 || diff <= 7) {
                    badgeBg = colors.badgeRed;
                    badgeText = colors.badgeRedText;
                  } else if (diff <= 14) {
                    badgeBg = colors.badgeAmber;
                    badgeText = colors.badgeAmberText;
                  } else {
                    badgeBg = colors.badgeGreen;
                    badgeText = colors.badgeGreenText;
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(item['label'] as String,
                            style: TextStyle(fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall!.color)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['subject'] as String,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              if ((item['extra'] as String).isNotEmpty)
                                Text(item['extra'] as String,
                                  style: TextStyle(fontSize: 10,
                                      color: Theme.of(context).textTheme.bodySmall!.color)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: badgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(fmt.format(date),
                            style: TextStyle(fontSize: 11, color: badgeText,
                                fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TasksCard extends ConsumerWidget {
  final AppColors colors;
  final WidgetRef ref;
  const _TasksCard({required this.colors, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final fmt = DateFormat('d MMMM', 'ru');
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text('Задачи на сегодня и завтра',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (allTasks) {
                final todayTasks = allTasks.where((t) =>
                  t.dueDate != null &&
                  t.dueDate!.year == today.year &&
                  t.dueDate!.month == today.month &&
                  t.dueDate!.day == today.day).toList();

                final tomorrowTasks = allTasks.where((t) =>
                  t.dueDate != null &&
                  t.dueDate!.year == tomorrow.year &&
                  t.dueDate!.month == tomorrow.month &&
                  t.dueDate!.day == tomorrow.day).toList();

                if (todayTasks.isEmpty && tomorrowTasks.isEmpty) {
                  return const Center(child: Text('Задач на сегодня и завтра нет'));
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    if (todayTasks.isNotEmpty) ...[
                      _dayLabel('Сегодня, ${fmt.format(today)}', colors),
                      ...todayTasks.map((t) => _TaskRow(task: t, colors: colors)),
                    ],
                    if (tomorrowTasks.isNotEmpty) ...[
                      _dayLabel('Завтра, ${fmt.format(tomorrow)}', colors),
                      ...tomorrowTasks.map((t) => _TaskRow(task: t, colors: colors)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayLabel(String text, AppColors colors) {
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