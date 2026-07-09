import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import '../../services/driver_service.dart';
import '../../utils/date_picker.dart';
import '../../widgets/dialog_scroll_content.dart';

class ExpiryEditDialog extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback onSaved;
  const ExpiryEditDialog({super.key, required this.task, required this.onSaved});

  @override
  ConsumerState<ExpiryEditDialog> createState() => ExpiryEditDialogState();
}

class ExpiryEditDialogState extends ConsumerState<ExpiryEditDialog> {
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
        content: const DialogScrollContent(
            child: Text('Дата окончания срока будет обновлена.')),
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
          final updated = _updatedVehicle(v, taskTitle, _newDate!);
          if (updated != null) {
            await ref.read(vehicleServiceProvider).update(v.id, updated);
            ref.invalidate(vehiclesProvider);
          }
        }
      } else if (widget.task.driverId != null) {
        final drivers = await ref.read(driverServiceProvider).getAll();
        final d =
            drivers.where((d) => d.id == widget.task.driverId).firstOrNull;
        if (d != null) {
          final updated = taskTitle.startsWith('Вод.')
              ? d.copyWith(licenseExpiry: _newDate)
              : d.copyWith(medicalExpiry: _newDate);
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

  /// Определяет, какое поле ТС соответствует задаче, по её заголовку
  /// (см. sync_expiry_tasks() — ровно эти 5 префиксов). Для вычисляемых
  /// «ТО автомобиля»/«ТО оборудования» (nextToDate = toDate + период)
  /// новая дата — это желаемая следующая дата ТО, поэтому пересчитываем
  /// исходную toDate/equipmentToDate в обратную сторону, на период назад.
  /// null — заголовок не распознан, запись не трогаем (лучше ничего не
  /// сохранить, чем молча записать дату не в то поле).
  Vehicle? _updatedVehicle(Vehicle v, String taskTitle, DateTime newDate) {
    if (taskTitle.startsWith('Техосмотр')) {
      return v.copyWith(inspectionDate: newDate);
    }
    if (taskTitle.startsWith('Страховка')) {
      return v.copyWith(insuranceDate: newDate);
    }
    if (taskTitle.startsWith('Спец. разрешение')) {
      return v.copyWith(specialPermitDate: newDate);
    }
    if (taskTitle.startsWith('ТО автомобиля')) {
      final months = v.toPeriodMonths ?? 0;
      return v.copyWith(
          toDate: DateTime(newDate.year, newDate.month - months, newDate.day));
    }
    if (taskTitle.startsWith('ТО оборудования')) {
      final months = v.equipmentToPeriodMonths ?? 0;
      return v.copyWith(
          equipmentToDate:
              DateTime(newDate.year, newDate.month - months, newDate.day));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _newDate != null
        ? '${_newDate!.day.toString().padLeft(2, '0')}.${_newDate!.month.toString().padLeft(2, '0')}.${_newDate!.year}'
        : 'Не указана';

    return AlertDialog(
      title: const Text('Обновить срок'),
      content: DialogScrollContent(
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
                    final d = await showAppDatePicker(
                      context,
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
