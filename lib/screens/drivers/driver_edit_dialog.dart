import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/department.dart';
import '../../models/driver.dart';
import '../../services/department_service.dart';
import '../../services/driver_service.dart';
import '../../services/vehicle_service.dart';
import '../../utils/date_picker.dart';

class DriverEditDialog extends ConsumerStatefulWidget {
  final Driver? driver;
  final VoidCallback onSaved;

  const DriverEditDialog({super.key, this.driver, required this.onSaved});

  @override
  ConsumerState<DriverEditDialog> createState() => _DriverEditDialogState();
}

class _DriverEditDialogState extends ConsumerState<DriverEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tabNumber, _lastName, _firstName, _middleName;
  late TextEditingController _phone, _licenseNumber, _licenseCategories, _notes;
  DateTime? _birthDate, _licenseExpiry, _medicalExpiry;
  List<String> _selectedVehicleIds = [];
  String? _departmentId, _sectionId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _tabNumber = TextEditingController(text: d?.tabNumber ?? '');
    _lastName = TextEditingController(text: d?.lastName ?? '');
    _firstName = TextEditingController(text: d?.firstName ?? '');
    _middleName = TextEditingController(text: d?.middleName ?? '');
    _phone = TextEditingController(text: d?.phone ?? '');
    _licenseNumber = TextEditingController(text: d?.licenseNumber ?? '');
    _licenseCategories = TextEditingController(text: d?.licenseCategories ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _birthDate = d?.birthDate;
    _licenseExpiry = d?.licenseExpiry;
    _medicalExpiry = d?.medicalExpiry;
    _selectedVehicleIds = List.from(d?.vehicleIds ?? []);
    _departmentId = d?.departmentId;
    _sectionId = d?.sectionId;
  }

  @override
  void dispose() {
    for (final c in [_tabNumber, _lastName, _firstName, _middleName,
      _phone, _licenseNumber, _licenseCategories, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.driver != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(isEdit ? 'Сохранить изменения?' : 'Добавить водителя?'),
        content: Text(isEdit
            ? 'Данные водителя будут обновлены.'
            : 'Водитель будет добавлен в систему.'),
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
      final service = ref.read(driverServiceProvider);
      final driver = Driver(
        id: widget.driver?.id ?? '',
        tabNumber: _tabNumber.text.trim(),
        lastName: _lastName.text.trim(),
        firstName: _firstName.text.trim(),
        middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        licenseNumber: _licenseNumber.text.trim().isEmpty ? null : _licenseNumber.text.trim(),
        licenseCategories: _licenseCategories.text.trim().isEmpty ? null : _licenseCategories.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        birthDate: _birthDate,
        licenseExpiry: _licenseExpiry,
        medicalExpiry: _medicalExpiry,
        vehicleIds: _selectedVehicleIds,
        departmentId: _departmentId,
        sectionId: _sectionId,
      );
      if (widget.driver == null) {
        await service.create(driver);
      } else {
        await service.update(widget.driver!.id, driver);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime?> onPicked) async {
    final date = await showAppDatePicker(
      context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2040),
    );
    if (date != null) onPicked(date);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.driver == null ? 'Добавить водителя' : 'Редактировать водителя';
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final departments = ref.watch(departmentsProvider).value ?? [];
    final deptSections = (ref.watch(sectionsProvider).value ?? [])
        .where((s) => s.departmentId == _departmentId)
        .toList();

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: Text(title),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: _field(_lastName, 'Фамилия', required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_firstName, 'Имя', required: true)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_middleName, 'Отчество')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_tabNumber, 'Таб. номер', required: true)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field(_phone, 'Телефон')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_licenseNumber, 'Номер вод. удост.')),
                ]),
                const SizedBox(height: 10),
                _field(_licenseCategories, 'Категории (BE, CE...)'),
                const SizedBox(height: 10),
                _datePicker('Дата рождения', _birthDate,
                  (d) => setState(() => _birthDate = d)),
                const SizedBox(height: 10),
                _datePicker('Вод. удостоверение до', _licenseExpiry,
                  (d) => setState(() => _licenseExpiry = d)),
                const SizedBox(height: 10),
                _datePicker('Мед. справка до', _medicalExpiry,
                  (d) => setState(() => _medicalExpiry = d)),
                const SizedBox(height: 10),

                // Привязка к подразделению
                const SizedBox(height: 4),
                const Text('ПРИВЯЗКА',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                    color: Color(0xFF888888), letterSpacing: 0.5)),
                const SizedBox(height: 8),
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
                  const SizedBox(width: 10),
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
                const SizedBox(height: 10),

                // Выбор закреплённых ТС (мультиселект)
                vehiclesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (vehicles) => _VehicleMultiSelect(
                    vehicles: vehicles,
                    selected: _selectedVehicleIds,
                    onChanged: (ids) => setState(() => _selectedVehicleIds = ids),
                  ),
                ),
                const SizedBox(height: 10),
                _field(_notes, 'Заметки', maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: widget.driver == null ? null : () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(ctx).cardColor,
                surfaceTintColor: Colors.transparent,
                title: const Text('Удалить водителя?'),
                content: Text(
                  '${widget.driver!.fullName}\n\nЭто действие нельзя отменить.'),
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
              await ref.read(driverServiceProvider).delete(widget.driver!.id);
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

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Обязательное поле' : null
          : null,
    );
  }

  Widget _datePicker(String label, DateTime? date,
      ValueChanged<DateTime?> onPicked) {
    final text = date != null
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
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

class _VehicleMultiSelect extends StatelessWidget {
  final List<dynamic> vehicles;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _VehicleMultiSelect({
    required this.vehicles,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Закреплённые ТС',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 160),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFBBBBBB)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: vehicles.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Нет ТС в системе',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: vehicles.length,
                  itemBuilder: (context, i) {
                    final v = vehicles[i];
                    final isSelected = selected.contains(v.id as String);
                    return InkWell(
                      onTap: () {
                        final updated = List<String>.from(selected);
                        if (isSelected) {
                          updated.remove(v.id);
                        } else {
                          updated.add(v.id as String);
                        }
                        onChanged(updated);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 16,
                              color: isSelected
                                  ? const Color(0xFF4361EE)
                                  : const Color(0xFF888888),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${v.invNumber} — ${v.brandModel} (${v.govNumber})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Выбрано: ${selected.length}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF4361EE))),
          ),
      ],
    );
  }
}