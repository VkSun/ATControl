import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/driver.dart';
import '../../models/vehicle.dart';
import '../../services/department_service.dart';
import '../../services/driver_service.dart';
import '../../services/vehicle_service.dart';
import '../../utils/date_picker.dart';
import '../../utils/list_diff.dart';
import '../../utils/responsive.dart';
import '../../utils/theme.dart';
import '../../widgets/dialog_scroll_content.dart';

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
  // Снимок vehicleIds на момент открытия диалога — не меняется после,
  // нужен только чтобы понять, трогал ли пользователь пикер ТС в этой
  // сессии редактирования (сравнение с _selectedVehicleIds).
  late final List<String> _initialVehicleIds;
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
    _initialVehicleIds = List.from(d?.vehicleIds ?? []);
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
        content: DialogScrollContent(
            child: Text(isEdit
                ? 'Данные водителя будут обновлены.'
                : 'Водитель будет добавлен в систему.')),
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

      if (widget.driver == null) {
        await service.create(_buildDriver(id: '', vehicleIds: _selectedVehicleIds));
      } else {
        final driverId = widget.driver!.id;

        // Пикер ТС трогали в этой сессии, если текущий выбор отличается
        // от снимка на момент открытия — не от того, что сейчас на сервере.
        final vehicleIdsTouched =
            listsDiffer(_initialVehicleIds, _selectedVehicleIds);

        List<String> vehicleIdsForSave;
        if (vehicleIdsTouched) {
          // vehicle_ids мог измениться параллельно (VehicleEditDialog) —
          // перечитываем свежую запись и применяем СВОЮ правку поверх нее,
          // а не поверх устаревшего снимка, с которым диалог открылся.
          final fresh = await service.getById(driverId);
          vehicleIdsForSave = mergeListDiff(
            original: _initialVehicleIds,
            current: _selectedVehicleIds,
            fresh: fresh?.vehicleIds ?? widget.driver!.vehicleIds,
          );
        } else {
          // Не трогали — не наш источник истины прямо сейчас.
          vehicleIdsForSave = widget.driver!.vehicleIds;
        }

        final resultingDriver =
            _buildDriver(id: driverId, vehicleIds: vehicleIdsForSave);
        final fields = resultingDriver.toJson();
        if (!vehicleIdsTouched) {
          // Частичный патч без vehicle_ids — поле не наше, не перезаписываем.
          fields.remove('vehicle_ids');
        }
        await service.updateFields(driverId, fields,
            resultingDriver: resultingDriver);
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

  /// Собирает Driver из текущих полей формы; [vehicleIds] передаётся
  /// отдельно — источник зависит от того, трогали ли пикер ТС (см. _save).
  Driver _buildDriver({required String id, required List<String> vehicleIds}) => Driver(
        id: id,
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
        vehicleIds: vehicleIds,
        departmentId: _departmentId,
        sectionId: _sectionId,
      );

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
    final departments = ref.watch(departmentsProvider).valueOrNull ?? [];
    final deptSections = (ref.watch(sectionsProvider).valueOrNull ?? [])
        .where((s) => s.departmentId == _departmentId)
        .toList();

    final form = Form(
      key: _formKey,
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
                      // не переполняется на узком экране телефона
                      isExpanded: true,
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
                      // не переполняется на узком экране телефона
                      isExpanded: true,
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

                // Закреплённые ТС
                vehiclesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox(),
                  data: (vehicles) => _VehicleSelectorField(
                    vehicles: vehicles,
                    selectedIds: _selectedVehicleIds,
                    onChanged: (ids) => setState(() => _selectedVehicleIds = ids),
                  ),
                ),
                const SizedBox(height: 10),
                _field(_notes, 'Заметки', maxLines: 2),
            ],
      ),
    );

    // Телефон: полноэкранная форма с одним скроллом; свой AppBar с «✕»,
    // заголовком и «Сохранить». Удаление — в меню «⋮», не в ряду кнопок.
    if (isPhone(context)) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Закрыть',
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(title),
            actions: [
              if (widget.driver != null) _overflowMenu(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: form,
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (widget.driver != null) _overflowMenu(),
        ],
      ),
      content: DialogScrollContent(
        width: 500,
        child: form,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  /// Меню «⋮» в шапке формы: удаление вынесено из ряда кнопок,
  /// чтобы промах по «Сохранить» не приводил к потере записи.
  Widget _overflowMenu() => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        tooltip: 'Ещё',
        onSelected: (v) {
          if (v == 'delete') _confirmDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'delete',
            child: Text('Удалить',
                style: TextStyle(color: Color(0xFFE24B4A))),
          ),
        ],
      );

  Future<void> _confirmDelete() async {
    final d = widget.driver!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        // Идентификация записи прямо в вопросе
        title: Text('Удалить ${d.fullName}?'),
        content: const DialogScrollContent(
            child: Text('Это действие нельзя отменить.')),
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
      await ref.read(driverServiceProvider).delete(d.id);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    }
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

class _VehicleSelectorField extends StatelessWidget {
  final List<Vehicle> vehicles;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _VehicleSelectorField({
    required this.vehicles,
    required this.selectedIds,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _VehiclePickerDialog(
        vehicles: vehicles,
        initialSelected: selectedIds,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final matched =
        vehicles.where((v) => selectedIds.contains(v.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Закреплённые ТС',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 6),
        // Каждое ТС — chip с крестиком; добавление — через общий пикер.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in matched)
              InputChip(
                label: Text(v.invNumber,
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                deleteButtonTooltipMessage: 'Открепить',
                onDeleted: () =>
                    onChanged([...selectedIds]..remove(v.id)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(matched.isEmpty ? 'Выбрать ТС' : 'Добавить',
                  style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onPressed: () => _openPicker(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehiclePickerDialog extends StatefulWidget {
  final List<Vehicle> vehicles;
  final List<String> initialSelected;

  const _VehiclePickerDialog({
    required this.vehicles,
    required this.initialSelected,
  });

  @override
  State<_VehiclePickerDialog> createState() => _VehiclePickerDialogState();
}

class _VehiclePickerDialogState extends State<_VehiclePickerDialog> {
  late List<String> _selected;
  late TextEditingController _searchCtrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.vehicles.where((v) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return '${v.invNumber} ${v.brandModel} ${v.govNumber}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: const Text('Закреплённые ТС'),
      content: SizedBox(
        width: 420,
        // Список прокручивается внутри; высота лишь ограничивается экраном.
        height: math.min(420, dialogMaxHeight(context)),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Поиск по номеру, марке...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Ничего не найдено',
                          style: TextStyle(color: Color(0xFF888888))))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final v = filtered[i];
                        final isSelected =
                            _selected.contains(v.id);
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(v.id);
                            } else {
                              _selected.add(v.id);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 7),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 18,
                                  color: isSelected
                                      ? Theme.of(context).extension<AppColors>()!.accent
                                      : const Color(0xFF888888),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${v.invNumber} — ${v.brandModel} (${v.govNumber})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Выбрано: ${_selected.length}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).extension<AppColors>()!.accent)),
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
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Применить'),
        ),
      ],
    );
  }
}