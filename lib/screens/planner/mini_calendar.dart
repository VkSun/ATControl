import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../utils/theme.dart';

class MiniCalendar extends StatelessWidget {
  final DateTime month;
  final List<Task> tasks;
  final AppColors colors;
  final ValueChanged<DateTime> onMonthChanged;

  const MiniCalendar({
    super.key,
    required this.month,
    required this.tasks,
    required this.colors,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    // LLLL — standalone-форма месяца («Июль», не «июля» как в 'd MMMM').
    final fmt = DateFormat('LLLL yyyy', 'ru');
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
              child: Text(toBeginningOfSentenceCase(fmt.format(month)),
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
