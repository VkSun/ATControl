import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'responsive.dart';

Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  if (!isPhone(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime(2040),
    );
  }

  DateTime selected = initialDate;
  final result = await showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    // Без isScrollControlled лист ограничен 9/16 высоты экрана —
    // в альбомной ориентации контент (~270dp) не помещается.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(ctx).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    const Spacer(),
                    const Text('Выберите дату',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 220,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  minimumDate: firstDate ?? DateTime(1950),
                  maximumDate: lastDate ?? DateTime(2040),
                  onDateTimeChanged: (d) => selected = d,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}

Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) async {
  if (!isPhone(context)) {
    return showTimePicker(context: context, initialTime: initialTime);
  }

  var selected = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);
  final result = await showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    // Без isScrollControlled лист ограничен 9/16 высоты экрана —
    // в альбомной ориентации контент (~230dp) не помещается.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(ctx).dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    const Spacer(),
                    const Text('Выберите время',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(
                          ctx, TimeOfDay(hour: selected.hour, minute: selected.minute)),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: selected,
                  onDateTimeChanged: (d) => selected = d,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result;
}
