import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
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
