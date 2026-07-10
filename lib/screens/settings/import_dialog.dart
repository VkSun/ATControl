import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vehicle.dart';
import '../../models/driver.dart';
import '../../services/vehicle_service.dart';
import '../../services/driver_service.dart';
import '../../services/excel_import_service.dart';
import '../../utils/theme.dart';
import '../../widgets/dialog_scroll_content.dart';

enum _Step { pick, preview, importing, done }

class _PickedFile {
  final String name;
  final Uint8List bytes;
  _PickedFile(this.name, this.bytes);
}

class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  _Step _step = _Step.pick;
  bool _loading = false;

  _PickedFile? _vehiclesFile;
  _PickedFile? _driversFile;
  _PickedFile? _hoursFile;

  List<VehicleImportRow> _parsedVehicles = [];
  List<DriverImportRow> _parsedDrivers = [];
  List<EngineHoursRow> _parsedHours = [];

  Map<String, Vehicle> _existingByInv = {};
  Map<String, Driver> _existingByTab = {};

  bool _replaceConflicts = true;

  String _progressText = '';
  int _progressCurrent = 0;
  int _progressTotal = 1;

  int _importedVehicles = 0;
  int _importedDrivers = 0;
  int _skippedVehicles = 0;
  int _skippedDrivers = 0;
  final List<String> _errors = [];

  bool get _canAnalyze => _vehiclesFile != null || _driversFile != null;

  int get _vehicleConflicts =>
      _parsedVehicles.where((v) => _existingByInv.containsKey(v.invNumber)).length;

  int get _driverConflicts =>
      _parsedDrivers.where((d) => _existingByTab.containsKey(d.tabNumber)).length;

  Future<_PickedFile?> _pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.bytes == null) return null;
    return _PickedFile(f.name, f.bytes!);
  }

  Future<void> _analyze() async {
    setState(() => _loading = true);
    try {
      final vehicles = await ref.read(vehicleServiceProvider).getAll();
      final drivers = await ref.read(driverServiceProvider).getAll();
      _existingByInv = {for (final v in vehicles) v.invNumber: v};
      _existingByTab = {for (final d in drivers) d.tabNumber: d};

      final svc = ExcelImportService();
      if (_vehiclesFile != null) _parsedVehicles = svc.parseVehicles(_vehiclesFile!.bytes);
      if (_driversFile != null) _parsedDrivers = svc.parseDrivers(_driversFile!.bytes);
      if (_hoursFile != null) _parsedHours = svc.parseEngineHours(_hoursFile!.bytes);

      if (_parsedVehicles.isEmpty && _parsedDrivers.isEmpty && _parsedHours.isEmpty) {
        throw Exception('Данные не найдены. Убедитесь, что выбраны правильные файлы.');
      }

      setState(() {
        _loading = false;
        _step = _Step.preview;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _import() async {
    setState(() {
      _step = _Step.importing;
      _importedVehicles = 0;
      _importedDrivers = 0;
      _skippedVehicles = 0;
      _skippedDrivers = 0;
      _errors.clear();
    });

    final vSvc = ref.read(vehicleServiceProvider);
    final dSvc = ref.read(driverServiceProvider);

    // invNumber → vehicleId (for driver linking after import)
    final invToId = <String, String>{
      for (final v in _existingByInv.values) v.invNumber: v.id,
    };

    final vehiclesToProcess = _replaceConflicts
        ? _parsedVehicles
        : _parsedVehicles.where((v) => !_existingByInv.containsKey(v.invNumber)).toList();
    final driversToProcess = _replaceConflicts
        ? _parsedDrivers
        : _parsedDrivers.where((d) => !_existingByTab.containsKey(d.tabNumber)).toList();

    _progressTotal = vehiclesToProcess.length + driversToProcess.length + 1;
    _progressCurrent = 0;

    // --- Import vehicles ---
    for (final row in vehiclesToProcess) {
      setState(() => _progressText = 'ТС: ${row.invNumber} ${row.brand} ${row.model}');
      try {
        final existing = _existingByInv[row.invNumber];
        final vehicle = Vehicle(
          id: existing?.id ?? '',
          invNumber: row.invNumber,
          brand: row.brand,
          model: row.model,
          govNumber: row.govNumber,
          year: existing?.year,
          inspectionDate: existing?.inspectionDate,
          insuranceDate: existing?.insuranceDate,
          specialPermitDate: existing?.specialPermitDate,
          toDate: existing?.toDate,
          toMileage: existing?.toMileage,
          equipmentType: existing?.equipmentType,
          equipmentToDate: existing?.equipmentToDate,
          equipmentHours: existing?.equipmentHours,
          notes: existing?.notes,
        );
        if (existing == null) {
          final created = await vSvc.create(vehicle);
          invToId[row.invNumber] = created.id;
        } else {
          await vSvc.update(existing.id, vehicle);
          invToId[row.invNumber] = existing.id;
        }
        _importedVehicles++;
      } catch (e) {
        _errors.add('ТС ${row.invNumber}: $e');
      }
      setState(() => _progressCurrent++);
    }

    _skippedVehicles = _parsedVehicles.length - vehiclesToProcess.length;

    // --- Update engine hours ---
    for (final row in _parsedHours) {
      final vid = invToId[row.invNumber];
      if (vid == null) continue;
      final existing = _existingByInv.values
          .where((v) => v.id == vid)
          .firstOrNull;
      if (existing == null) continue;
      try {
        await vSvc.update(vid, Vehicle(
          id: vid,
          invNumber: existing.invNumber,
          brand: existing.brand,
          model: existing.model,
          govNumber: existing.govNumber,
          year: existing.year,
          inspectionDate: existing.inspectionDate,
          insuranceDate: existing.insuranceDate,
          specialPermitDate: existing.specialPermitDate,
          toDate: existing.toDate,
          toMileage: existing.toMileage,
          equipmentType: existing.equipmentType,
          equipmentToDate: existing.equipmentToDate,
          equipmentHours: (existing.equipmentHours ?? 0) + row.hours,
          notes: existing.notes,
        ));
      } catch (e) {
        _errors.add('Моточасы ${row.invNumber}: $e');
      }
    }
    setState(() => _progressCurrent++);

    // --- Import drivers ---
    for (final row in driversToProcess) {
      setState(() => _progressText = 'Водитель: ${row.lastName} ${row.firstName}');
      try {
        final existing = _existingByTab[row.tabNumber];
        final vehicleIds = row.vehicleInvNumbers
            .map((inv) => invToId[inv])
            .whereType<String>()
            .toList();
        if (vehicleIds.isEmpty && existing != null) {
          vehicleIds.addAll(existing.vehicleIds);
        }

        final driver = Driver(
          id: existing?.id ?? '',
          tabNumber: row.tabNumber,
          lastName: row.lastName,
          firstName: row.firstName,
          middleName: row.middleName,
          licenseNumber: row.licenseNumber,
          medicalExpiry: row.medicalExpiry,
          vehicleIds: vehicleIds,
          licenseExpiry: existing?.licenseExpiry,
          licenseCategories: existing?.licenseCategories,
          birthDate: existing?.birthDate,
          phone: existing?.phone,
          notes: existing?.notes,
        );

        if (existing == null) {
          await dSvc.create(driver);
        } else {
          await dSvc.update(existing.id, driver);
        }
        _importedDrivers++;
      } catch (e) {
        _errors.add('Водитель ${row.tabNumber}: $e');
      }
      setState(() => _progressCurrent++);
    }

    _skippedDrivers = _parsedDrivers.length - driversToProcess.length;
    setState(() => _step = _Step.done);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          const Icon(Icons.upload_file, size: 20),
          const SizedBox(width: 8),
          Text(_stepTitle),
        ],
      ),
      content: DialogScrollContent(
        width: 520,
        child: _buildContent(),
      ),
      actions: _buildActions(),
    );
  }

  String get _stepTitle => switch (_step) {
        _Step.pick => 'Импорт из Excel',
        _Step.preview => 'Предпросмотр',
        _Step.importing => 'Импорт данных...',
        _Step.done => 'Готово',
      };

  Widget _buildContent() => switch (_step) {
        _Step.pick => _buildPickStep(),
        _Step.preview => _buildPreviewStep(),
        _Step.importing => _buildImportingStep(),
        _Step.done => _buildDoneStep(),
      };

  // ---------- Шаг 1: выбор файлов ----------

  Widget _buildPickStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите файлы Excel для импорта.',
            style: TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Хотя бы один из первых двух файлов обязателен.',
            style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
        const SizedBox(height: 16),
        _filePicker(
          label: 'Список подвижного состава',
          required: true,
          file: _vehiclesFile,
          onPick: () async {
            final f = await _pickExcel();
            if (f != null) setState(() => _vehiclesFile = f);
          },
          onClear: () => setState(() => _vehiclesFile = null),
        ),
        const SizedBox(height: 10),
        _filePicker(
          label: 'Водители',
          required: true,
          file: _driversFile,
          onPick: () async {
            final f = await _pickExcel();
            if (f != null) setState(() => _driversFile = f);
          },
          onClear: () => setState(() => _driversFile = null),
        ),
        const SizedBox(height: 10),
        _filePicker(
          label: 'Моточасы',
          required: false,
          file: _hoursFile,
          onPick: () async {
            final f = await _pickExcel();
            if (f != null) setState(() => _hoursFile = f);
          },
          onClear: () => setState(() => _hoursFile = null),
        ),
      ],
    );
  }

  Widget _filePicker({
    required String label,
    required bool required,
    required _PickedFile? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (!required)
                    const Text(' (необязательно)',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                ],
              ),
              if (file != null)
                Text(file.name,
                    style: TextStyle(fontSize: 11,
                        color: Theme.of(context).extension<AppColors>()!.accent),
                    overflow: TextOverflow.ellipsis)
              else
                const Text('Файл не выбран',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (file != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        OutlinedButton(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: Text(file == null ? 'Выбрать...' : 'Изменить'),
        ),
      ],
    );
  }

  // ---------- Шаг 2: предпросмотр ----------

  Widget _buildPreviewStep() {
    final newV = _parsedVehicles.where((v) => !_existingByInv.containsKey(v.invNumber)).length;
    final newD = _parsedDrivers.where((d) => !_existingByTab.containsKey(d.tabNumber)).length;
    final hasConflicts = _vehicleConflicts > 0 || _driverConflicts > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_parsedVehicles.isNotEmpty) ...[
          _previewCard(
            icon: Icons.directions_car,
            label: 'Транспортные средства',
            total: _parsedVehicles.length,
            newCount: newV,
            conflicts: _vehicleConflicts,
          ),
          const SizedBox(height: 8),
        ],
        if (_parsedDrivers.isNotEmpty) ...[
          _previewCard(
            icon: Icons.person,
            label: 'Водители',
            total: _parsedDrivers.length,
            newCount: newD,
            conflicts: _driverConflicts,
          ),
          const SizedBox(height: 8),
        ],
        if (_parsedHours.isNotEmpty) ...[
          _previewCard(
            icon: Icons.timer,
            label: 'Моточасы (добавляются к существующим)',
            total: _parsedHours.length,
            newCount: _parsedHours.length,
            conflicts: 0,
          ),
          const SizedBox(height: 8),
        ],
        if (hasConflicts) ...[
          const SizedBox(height: 8),
          const Text('Действие при совпадении:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          _RadioOption(
            label: 'Заменить существующие записи',
            value: true,
            selected: _replaceConflicts,
            onTap: () => setState(() => _replaceConflicts = true),
          ),
          const SizedBox(height: 4),
          _RadioOption(
            label: 'Пропустить существующие записи',
            value: false,
            selected: _replaceConflicts,
            onTap: () => setState(() => _replaceConflicts = false),
          ),
        ],
      ],
    );
  }

  Widget _previewCard({
    required IconData icon,
    required String label,
    required int total,
    required int newCount,
    required int conflicts,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).extension<AppColors>()!.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Всего: $total', style: const TextStyle(fontSize: 11)),
              Text('Новых: $newCount',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF639922))),
              if (conflicts > 0)
                Text('Совпадений: $conflicts',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFEF9F27))),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Шаг 3: импорт ----------

  Widget _buildImportingStep() {
    final progress = _progressTotal > 0 ? _progressCurrent / _progressTotal : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, minHeight: 6),
        const SizedBox(height: 12),
        Text(_progressText,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------- Шаг 4: результат ----------

  Widget _buildDoneStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF639922), size: 32),
            const SizedBox(width: 10),
            const Text('Импорт завершён', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 14),
        _resultRow(Icons.directions_car, 'Транспорт',
            'импортировано $_importedVehicles, пропущено $_skippedVehicles'),
        const SizedBox(height: 6),
        _resultRow(Icons.person, 'Водители',
            'импортировано $_importedDrivers, пропущено $_skippedDrivers'),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Ошибки (${_errors.length}):',
              style: const TextStyle(fontSize: 12, color: Color(0xFFE24B4A),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          ..._errors.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $e',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFE24B4A))),
              )),
          if (_errors.length > 5)
            Text('... и ещё ${_errors.length - 5}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
        ],
      ],
    );
  }

  Widget _resultRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF888888)),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  // ---------- Actions ----------

  List<Widget> _buildActions() => switch (_step) {
        _Step.pick => [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: (_canAnalyze && !_loading) ? _analyze : null,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Анализировать'),
            ),
          ],
        _Step.preview => [
            TextButton(
              onPressed: () => setState(() => _step = _Step.pick),
              child: const Text('Назад'),
            ),
            FilledButton(
              onPressed: _import,
              child: const Text('Импортировать'),
            ),
          ],
        _Step.importing => [],
        _Step.done => [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
      };
}

class _RadioOption extends StatelessWidget {
  final String label;
  final bool value;
  final bool selected;
  final VoidCallback onTap;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          Radio<bool>(
            value: value,
            groupValue: selected,
            onChanged: (_) => onTap(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
