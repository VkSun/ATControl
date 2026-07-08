import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/department_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/driver_service.dart';
import '../../utils/date_picker.dart';
import '../../utils/date_utils.dart';
import '../../widgets/dialog_scroll_content.dart';

class VehicleEditDialog extends ConsumerStatefulWidget {
  final Vehicle? vehicle;
  final VoidCallback onSaved;

  const VehicleEditDialog({super.key, this.vehicle, required this.onSaved});

  @override
  ConsumerState<VehicleEditDialog> createState() => _VehicleEditDialogState();
}

class _VehicleEditDialogState extends ConsumerState<VehicleEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _invNumber, _brand, _model, _govNumber;
  late TextEditingController _year, _notes, _toMileage, _toPeriodKm, _toPeriodMonths;
  late TextEditingController _equipmentType, _equipmentHours;
  late TextEditingController _equipmentToPeriodHours, _equipmentToPeriodMonths;
  DateTime? _inspectionDate, _insuranceDate, _specialPermitDate, _toDate, _equipmentToDate;
  String? _departmentId, _sectionId;
  String? _assignedDriverId;
  String? _originalDriverId;
  List<Driver> _allDrivers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _invNumber = TextEditingController(text: v?.invNumber ?? '');
    _brand = TextEditingController(text: v?.brand ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _govNumber = TextEditingController(text: v?.govNumber ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _notes = TextEditingController(text: v?.notes ?? '');
    _toMileage = TextEditingController(text: v?.toMileage?.toString() ?? '');
    _toPeriodKm = TextEditingController(text: v?.toPeriodKm?.toString() ?? '');
    _toPeriodMonths = TextEditingController(text: v?.toPeriodMonths?.toString() ?? '');
    _equipmentType = TextEditingController(text: v?.equipmentType ?? '');
    _equipmentHours = TextEditingController(text: v?.equipmentHours?.toString() ?? '');
    _equipmentToPeriodHours = TextEditingController(text: v?.equipmentToPeriodHours?.toString() ?? '');
    _equipmentToPeriodMonths = TextEditingController(text: v?.equipmentToPeriodMonths?.toString() ?? '');
    _inspectionDate = v?.inspectionDate;
    _insuranceDate = v?.insuranceDate;
    _specialPermitDate = v?.specialPermitDate;
    _toDate = v?.toDate;
    _equipmentToDate = v?.equipmentToDate;
    _departmentId = v?.departmentId;
    _sectionId = v?.sectionId;
    // Rebuild when period fields change to update preview
    for (final c in [_toMileage, _toPeriodKm, _toPeriodMonths,
                     _equipmentHours, _equipmentToPeriodHours, _equipmentToPeriodMonths]) {
      c.addListener(() => setState(() {}));
    }

    // Load all drivers and find which one is assigned to this vehicle
    if (widget.vehicle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final drivers = await ref.read(driverServiceProvider).getAll();
        if (!mounted) return;
        Driver? assigned;
        for (final d in drivers) {
          if (d.vehicleIds.contains(widget.vehicle!.id)) {
            assigned = d;
            break;
          }
        }
        setState(() {
          _allDrivers = drivers;
          _assignedDriverId = assigned?.id;
          _originalDriverId = assigned?.id;
        });
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_invNumber, _brand, _model, _govNumber, _year, _notes,
      _toMileage, _toPeriodKm, _toPeriodMonths,
      _equipmentType, _equipmentHours, _equipmentToPeriodHours, _equipmentToPeriodMonths]) {
      c.dispose();
    }
    super.dispose();
  }

  // Вычисляемые "следующее ТО" для предпросмотра в форме
  DateTime? get _nextToDate {
    if (_toDate == null) return null;
    final months = int.tryParse(_toPeriodMonths.text);
    if (months == null || months == 0) return null;
    return DateTime(_toDate!.year, _toDate!.month + months, _toDate!.day);
  }

  int? get _nextToMileage {
    final base = int.tryParse(_toMileage.text);
    final period = int.tryParse(_toPeriodKm.text);
    if (base == null || period == null || period == 0) return null;
    return base + period;
  }

  DateTime? get _nextEquipmentToDate {
    if (_equipmentToDate == null) return null;
    final months = int.tryParse(_equipmentToPeriodMonths.text);
    if (months == null || months == 0) return null;
    return DateTime(_equipmentToDate!.year, _equipmentToDate!.month + months, _equipmentToDate!.day);
  }

  int? get _nextEquipmentToHours {
    final base = int.tryParse(_equipmentHours.text);
    final period = int.tryParse(_equipmentToPeriodHours.text);
    if (base == null || period == null || period == 0) return null;
    return base + period;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.vehicle != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(isEdit ? 'Сохранить изменения?' : 'Добавить транспорт?'),
        content: DialogScrollContent(
            child: Text(isEdit
                ? 'Данные транспортного средства будут обновлены.'
                : 'Транспортное средство будет добавлено в систему.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(vehicleServiceProvider);
      final vehicle = Vehicle(
        id: widget.vehicle?.id ?? '',
        invNumber: _invNumber.text.trim(),
        brand: _brand.text.trim(),
        model: _model.text.trim(),
        govNumber: _govNumber.text.trim(),
        year: int.tryParse(_year.text),
        inspectionDate: _inspectionDate,
        insuranceDate: _insuranceDate,
        specialPermitDate: _specialPermitDate,
        toDate: _toDate,
        toMileage: int.tryParse(_toMileage.text),
        toPeriodKm: int.tryParse(_toPeriodKm.text),
        toPeriodMonths: int.tryParse(_toPeriodMonths.text),
        equipmentType: _equipmentType.text.trim().isEmpty ? null : _equipmentType.text.trim(),
        equipmentToDate: _equipmentToDate,
        equipmentHours: int.tryParse(_equipmentHours.text),
        equipmentToPeriodHours: int.tryParse(_equipmentToPeriodHours.text),
        equipmentToPeriodMonths: int.tryParse(_equipmentToPeriodMonths.text),
        notes: _notes.text.trim(),
        departmentId: _departmentId,
        sectionId: _sectionId,
      );
      if (widget.vehicle == null) {
        await service.create(vehicle);
      } else {
        await service.update(widget.vehicle!.id, vehicle);

        // Update driver assignment if changed
        if (_assignedDriverId != _originalDriverId) {
          final driverService = ref.read(driverServiceProvider);
          final vehicleId = widget.vehicle!.id;

          if (_originalDriverId != null) {
            final orig = _allDrivers.firstWhere(
                (d) => d.id == _originalDriverId,
                orElse: () => throw Exception('Driver not found'));
            final updatedIds =
                orig.vehicleIds.where((id) => id != vehicleId).toList();
            await driverService.update(
                _originalDriverId!, orig.copyWith(vehicleIds: updatedIds));
          }

          if (_assignedDriverId != null) {
            final next = _allDrivers
                .firstWhere((d) => d.id == _assignedDriverId);
            if (!next.vehicleIds.contains(vehicleId)) {
              final updatedIds = [...next.vehicleIds, vehicleId];
              await driverService.update(
                  _assignedDriverId!, next.copyWith(vehicleIds: updatedIds));
            }
          }
        }
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime?> onPicked) async {
    final date = await showAppDatePicker(
      context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (date != null) onPicked(date);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final title = widget.vehicle == null ? 'Добавить транспорт' : 'Редактировать транспорт';
    final departments = ref.watch(departmentsProvider).value ?? [];
    final deptSections = (ref.watch(sectionsProvider).value ?? [])
        .where((s) => s.departmentId == _departmentId)
        .toList();
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text(title),
      content: DialogScrollContent(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Основная информация
                _sectionLabel('Основная информация'),
                Row(children: [
                  Expanded(child: _field(_invNumber, 'Инв. номер', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_govNumber, 'Гос. номер', required: true)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_brand, 'Марка', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_model, 'Модель', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_year, 'Год выпуска')),
                ]),
                const SizedBox(height: 14),

                // Сроки документов
                _sectionLabel('Сроки документов'),
                _datePicker('Техосмотр', _inspectionDate,
                  (d) => setState(() => _inspectionDate = d)),
                const SizedBox(height: 8),
                _datePicker('Страховка', _insuranceDate,
                  (d) => setState(() => _insuranceDate = d)),
                const SizedBox(height: 8),
                _datePicker('Спец. разрешение', _specialPermitDate,
                  (d) => setState(() => _specialPermitDate = d)),
                const SizedBox(height: 14),

                // ТО автомобиля
                _sectionLabel('ТО автомобиля'),
                _datePicker('Дата последнего ТО', _toDate,
                  (d) => setState(() => _toDate = d)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field(_toMileage, 'Пробег на момент ТО (км)',
                    keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _periodField(_toPeriodKm, 'Периодичность, км',
                    suffix: 'км')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  Expanded(child: _periodField(_toPeriodMonths, 'Периодичность, мес.',
                    suffix: 'мес.')),
                ]),
                if (_nextToDate != null || _nextToMileage != null) ...[
                  const SizedBox(height: 6),
                  _nextToPreview(
                    label: 'Следующее ТО:',
                    date: _nextToDate,
                    km: _nextToMileage,
                    fmt: fmt,
                  ),
                ],
                const SizedBox(height: 14),

                // ТО оборудования
                _sectionLabel('ТО оборудования'),
                _field(_equipmentType, 'Тип оборудования',
                  hint: 'Гидроманипулятор, Кран, Погрузчик...'),
                const SizedBox(height: 8),
                _datePicker('Дата последнего ТО оборудования', _equipmentToDate,
                  (d) => setState(() => _equipmentToDate = d)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field(_equipmentHours, 'Наработка моточасов',
                    keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _periodField(_equipmentToPeriodHours, 'Периодичность, м/ч',
                    suffix: 'м/ч')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  Expanded(child: _periodField(_equipmentToPeriodMonths, 'Периодичность, мес.',
                    suffix: 'мес.')),
                ]),
                if (_nextEquipmentToDate != null || _nextEquipmentToHours != null) ...[
                  const SizedBox(height: 6),
                  _nextToPreview(
                    label: 'Следующее ТО оборудования:',
                    date: _nextEquipmentToDate,
                    hours: _nextEquipmentToHours,
                    fmt: fmt,
                  ),
                ],
                const SizedBox(height: 14),

                // Привязка к подразделению
                _sectionLabel('Привязка'),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _departmentId,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Цех / подразделение',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— не указан —')),
                        ...departments.map((d) => DropdownMenuItem(
                          value: d.id, child: Text(d.name))),
                      ],
                      onChanged: (id) => setState(() {
                        _departmentId = id;
                        _sectionId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _sectionId,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Участок',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— не указан —')),
                        ...deptSections.map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (id) => setState(() => _sectionId = id),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // Закреплённый водитель (только при редактировании)
                if (widget.vehicle != null) ...[
                  _sectionLabel('Водитель'),
                  _DriverSelectorField(
                    drivers: _allDrivers,
                    selectedId: _assignedDriverId,
                    onChanged: (id) =>
                        setState(() => _assignedDriverId = id),
                  ),
                  const SizedBox(height: 14),
                ],

                // Заметки
                _sectionLabel('Заметки'),
                _field(_notes, 'Заметки', maxLines: 2),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: widget.vehicle == null ? null : () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(ctx).cardColor,
                surfaceTintColor: Colors.transparent,
                title: const Text('Удалить транспорт?'),
                content: DialogScrollContent(
                    child: Text(
                        '${widget.vehicle!.brandModel} (${widget.vehicle!.govNumber})\n\nЭто действие нельзя отменить.')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(vehicleServiceProvider).delete(widget.vehicle!.id);
              widget.onSaved();
              if (mounted) Navigator.pop(context);
            }
          },
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE24B4A)),
          child: const Text('Удалить'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
          color: Color(0xFF888888), letterSpacing: 0.5)),
  );

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, int maxLines = 1,
        TextInputType? keyboardType, String? hint}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Обязательное поле' : null
          : null,
    );
  }

  Widget _periodField(TextEditingController ctrl, String label, {String? suffix}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.replay_outlined, size: 16),
      ),
    );
  }

  Widget _nextToPreview({
    required String label,
    required DateFormat fmt,
    DateTime? date,
    int? km,
    int? hours,
  }) {
    final diff = date != null ? daysUntil(date) : null;
    Color color = const Color(0xFF888888);
    if (diff != null) {
      if (diff < 0) color = const Color(0xFFE24B4A);
      else if (diff <= 7) color = const Color(0xFFE24B4A);
      else if (diff <= 30) color = const Color(0xFFEF9F27);
      else color = const Color(0xFF639922);
    }
    final parts = <String>[];
    if (date != null) parts.add(fmt.format(date));
    if (km != null) parts.add('$km км');
    if (hours != null) parts.add('$hours м/ч');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_repeat_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(parts.join(' / '),
            style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, ValueChanged<DateTime?> onPicked) {
    final text = date != null
        ? '${date.day.toString().padLeft(2,'0')}.${date.month.toString().padLeft(2,'0')}.${date.year}'
        : 'Не указана';
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        TextButton.icon(
          onPressed: () => _pickDate(date, onPicked),
          icon: const Icon(Icons.calendar_today, size: 14),
          label: Text(text, style: const TextStyle(fontSize: 12)),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 14),
            onPressed: () => onPicked(null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
      ],
    );
  }
}

class _DriverSelectorField extends StatelessWidget {
  final List<Driver> drivers;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _DriverSelectorField({
    required this.drivers,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = drivers.cast<Driver?>().firstWhere(
          (d) => d?.id == selectedId,
          orElse: () => null,
        );
    final isEmpty = selected == null;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Выбрать водителя',
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () async {
            final result = await showDialog<String?>(
              context: context,
              builder: (_) => _DriverPickerDialog(
                drivers: drivers,
                selectedId: selectedId,
              ),
            );
            if (result != null) onChanged(result == '' ? null : result);
          },
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFBBBBBB)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isEmpty ? '— не закреплён —' : selected.fullName,
              style: TextStyle(
                fontSize: 13,
                color: isEmpty ? const Color(0xFF888888) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverPickerDialog extends StatefulWidget {
  final List<Driver> drivers;
  final String? selectedId;

  const _DriverPickerDialog({
    required this.drivers,
    required this.selectedId,
  });

  @override
  State<_DriverPickerDialog> createState() => _DriverPickerDialogState();
}

class _DriverPickerDialogState extends State<_DriverPickerDialog> {
  late String? _selected;
  late TextEditingController _searchCtrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.drivers.where((d) {
      if (_search.isEmpty) return true;
      return d.fullName.toLowerCase().contains(_search.toLowerCase()) ||
          d.tabNumber.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: const Text('Закреплённый водитель'),
      content: SizedBox(
        width: 400,
        // Список прокручивается внутри; высота лишь ограничивается экраном.
        height: math.min(400, dialogMaxHeight(context)),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Поиск по ФИО, таб. номеру...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  // Пункт "не закреплён"
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => setState(() => _selected = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 7),
                      child: Row(
                        children: [
                          Icon(
                            _selected == null
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: _selected == null
                                ? const Color(0xFF4361EE)
                                : const Color(0xFF888888),
                          ),
                          const SizedBox(width: 10),
                          const Text('— не закреплён —',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF888888))),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ...filtered.map((d) {
                    final isSelected = _selected == d.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _selected = d.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected
                                  ? const Color(0xFF4361EE)
                                  : const Color(0xFF888888),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.fullName,
                                      style: const TextStyle(fontSize: 13)),
                                  if (d.tabNumber.isNotEmpty)
                                    Text('Таб. ${d.tabNumber}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF888888))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
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
          onPressed: () => Navigator.pop(context, _selected ?? ''),
          child: const Text('Применить'),
        ),
      ],
    );
  }
}
