import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import '../../services/department_service.dart';
import '../../utils/theme.dart';
import 'vehicle_edit_dialog.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';
import '../../utils/permissions.dart';
import '../../utils/responsive.dart';
import '../../utils/inv_sort.dart';
import '../../widgets/async_value_view.dart';

enum VehicleSort {
  invNumber, brand, govNumber,
  inspectionDate, insuranceDate, specialPermitDate,
  toDate, equipmentToDate,
}

final vehicleSortProvider = StateProvider<VehicleSort>((ref) => VehicleSort.invNumber);
final vehicleSortAscProvider = StateProvider<bool>((ref) => true);
final vehicleSearchProvider = StateProvider<String>((ref) => '');

class TransportScreen extends ConsumerWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final sort = ref.watch(vehicleSortProvider);
    final asc = ref.watch(vehicleSortAscProvider);
    final search = ref.watch(vehicleSearchProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final mobile = isPhone(context);
    final perms = ref.watch(permissionsProvider);

    List<Vehicle> buildList(List<Vehicle> vehicles) {
      var list = vehicles;
      if (search.isNotEmpty) {
        final tokens = search.toLowerCase().split(RegExp(r'\s+'));
        list = list.where((v) {
          final fields = [
            v.invNumber.toLowerCase(),
            v.brandModel.toLowerCase(),
            v.govNumber.toLowerCase(),
          ];
          return tokens.every((t) => fields.any((f) => f.contains(t)));
        }).toList();
      }
      list = [...list];
      list.sort((a, b) {
        final r = switch (sort) {
          VehicleSort.invNumber       => compareInvNumbers(a.invNumber, b.invNumber),
          VehicleSort.brand           => a.brandModel.compareTo(b.brandModel),
          VehicleSort.govNumber       => a.govNumber.compareTo(b.govNumber),
          VehicleSort.inspectionDate  => (a.inspectionDate ?? DateTime(2099)).compareTo(b.inspectionDate ?? DateTime(2099)),
          VehicleSort.insuranceDate   => (a.insuranceDate ?? DateTime(2099)).compareTo(b.insuranceDate ?? DateTime(2099)),
          VehicleSort.specialPermitDate => (a.specialPermitDate ?? DateTime(2099)).compareTo(b.specialPermitDate ?? DateTime(2099)),
          VehicleSort.toDate          => (a.nextToDate ?? a.toDate ?? DateTime(2099)).compareTo(b.nextToDate ?? b.toDate ?? DateTime(2099)),
          VehicleSort.equipmentToDate => (a.nextEquipmentToDate ?? a.equipmentToDate ?? DateTime(2099)).compareTo(b.nextEquipmentToDate ?? b.equipmentToDate ?? DateTime(2099)),
        };
        return asc ? r : -r;
      });
      return list;
    }

    if (mobile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _SearchBar(
              colors: colors,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            ),
            Expanded(
              child: AsyncValueView(
                value: vehiclesAsync,
                onRetry: vehiclesProvider,
                builder: (vehicles) => _VehicleTable(
                  vehicles: buildList(vehicles),
                  colors: colors,
                  mobile: true,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: (perms.canAddVehicle || perms.isLoading)
            ? FloatingActionButton(
                onPressed: perms.isLoading ? null : () => showDialog(
                  context: context,
                  builder: (_) => VehicleEditDialog(
                    onSaved: () => ref.invalidate(vehiclesProvider),
                  ),
                ),
                child: const Icon(Icons.add),
              )
            : null,
      );
    }

    return Column(
      children: [
        _TopBar(colors: colors, ref: ref),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.tableBorder, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SearchBar(colors: colors),
                  Expanded(
                    child: AsyncValueView(
                      value: vehiclesAsync,
                      onRetry: vehiclesProvider,
                      builder: (vehicles) => _VehicleTable(
                        vehicles: buildList(vehicles),
                        colors: colors,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppColors colors;
  final WidgetRef ref;
  const _TopBar({required this.colors, required this.ref});

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final showFilter = perms.isAdmin || perms.canFullAccess;
    final departmentsAsync = showFilter ? ref.watch(departmentsProvider) : null;
    final sectionsAsync = showFilter ? ref.watch(sectionsProvider) : null;
    final selectedDept = showFilter ? ref.watch(selectedDepartmentProvider) : null;
    final selectedSec = showFilter ? ref.watch(selectedSectionProvider) : null;

    final departments = departmentsAsync?.value ?? [];
    final deptSections = (sectionsAsync?.value ?? [])
        .where((s) => s.departmentId == selectedDept)
        .toList();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Транспорт', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          if (perms.canAddVehicle || perms.isLoading)
            FilledButton.icon(
              onPressed: perms.isLoading ? null : () => showDialog(
                context: context,
                builder: (_) => VehicleEditDialog(
                  onSaved: () => ref.invalidate(vehiclesProvider),
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Добавить', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: Size.zero,
              ),
            ),
          const Spacer(),
          // Фильтр по подразделению (только admin/full_access)
          if (showFilter && departments.isNotEmpty) ...[
            _DeptFilterDropdown(
              label: 'Подразделение',
              value: selectedDept,
              items: departments.map((d) => (d.id, d.name)).toList(),
              onChanged: (id) {
                ref.read(selectedDepartmentProvider.notifier).state = id;
                ref.read(selectedSectionProvider.notifier).state = null;
              },
              colors: colors,
            ),
            if (deptSections.isNotEmpty) ...[
              const SizedBox(width: 8),
              _DeptFilterDropdown(
                label: 'Участок',
                value: selectedSec,
                items: deptSections.map((s) => (s.id, s.name)).toList(),
                onChanged: (id) =>
                    ref.read(selectedSectionProvider.notifier).state = id,
                colors: colors,
              ),
            ],
            const SizedBox(width: 8),
          ],
          if (isPhone(context)) ...[
            const Icon(Icons.notifications_outlined, size: 20),
            const SizedBox(width: 12),
            Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(profileProvider);
                final initials = profileAsync.value?.initials ?? 'АИ';
                final color = profileAsync.value?.avatarColor ?? '#435EBE';
                final avatarColor = Color(int.parse(
                    color.replaceFirst('#', '0xFF')));
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
        ],
      ),
    );
  }
}

class _DeptFilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;
  final AppColors colors;

  const _DeptFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.tableBorder),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
          hint: Text(label,
              style: TextStyle(fontSize: 12, color: colors.tableBorder)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Все ($label)',
                  style: const TextStyle(fontSize: 12)),
            ),
            ...items.map((e) => DropdownMenuItem<String?>(
                  value: e.$1,
                  child: Text(e.$2, style: const TextStyle(fontSize: 12)),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  final AppColors colors;
  final EdgeInsets padding;
  const _SearchBar({
    required this.colors,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 8),
  });

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(vehicleSearchProvider));
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    ref.read(vehicleSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _ctrl,
        onChanged: (v) => ref.read(vehicleSearchProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Поиск по марке, модели, гос. номеру или инв. номеру...',
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 16),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: _clear,
                  splashRadius: 14,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.colors.tableBorder),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}

class _VehicleTable extends ConsumerStatefulWidget {
  final List<Vehicle> vehicles;
  final AppColors colors;
  final bool mobile;

  const _VehicleTable({required this.vehicles, required this.colors, this.mobile = false});

  @override
  ConsumerState<_VehicleTable> createState() => _VehicleTableState();
}

class _VehicleTableState extends ConsumerState<_VehicleTable> {
  static const _prefsKey = 'vehicle_col_widths';
  static const _labels = ['Инв. номер', 'Марка/модель', 'Гос. номер', 'Техосмотр', 'Страховка', 'Спец. разр.', 'ТО авто', 'ТО оборуд.'];
  static const _defaults = [90.0, 130.0, 100.0, 100.0, 100.0, 100.0, 140.0, 140.0];
  static const _sortCols = <VehicleSort?>[
    VehicleSort.invNumber,
    VehicleSort.brand,
    VehicleSort.govNumber,
    VehicleSort.inspectionDate,
    VehicleSort.insuranceDate,
    VehicleSort.specialPermitDate,
    VehicleSort.toDate,
    VehicleSort.equipmentToDate,
  ];
  late List<double> _widths;

  @override
  void initState() {
    super.initState();
    _widths = List.of(_defaults);
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList(_prefsKey);
    if (saved != null && saved.length == _defaults.length) {
      setState(() => _widths = saved.map(double.parse).toList());
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_prefsKey, _widths.map((w) => w.toStringAsFixed(1)).toList());
  }

  Widget _resizableHeader(int i, VehicleSort currentSort, bool currentAsc, Color primary) {
    final sortCol = _sortCols[i];
    final isActive = sortCol != null && sortCol == currentSort;

    return SizedBox(
      width: _widths[i],
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (currentSort == sortCol) {
                    ref.read(vehicleSortAscProvider.notifier).state = !currentAsc;
                  } else {
                    ref.read(vehicleSortProvider.notifier).state = sortCol!;
                    ref.read(vehicleSortAscProvider.notifier).state = true;
                  }
                },
                child: Row(
                  children: [
                    Flexible(
                      child: Text(_labels[i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? primary : const Color(0xFF888888),
                        )),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 2),
                      Icon(
                        currentAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 11,
                        color: primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => setState(() {
                _widths[i] = (_widths[i] + d.delta.dx).clamp(50.0, 500.0);
              }),
              onHorizontalDragEnd: (_) => _save(),
              child: SizedBox(
                width: 8, height: 24,
                child: Center(
                  child: Container(width: 1, height: 16, color: widget.colors.tableBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final perms = ref.watch(permissionsProvider);
    final currentSort = ref.watch(vehicleSortProvider);
    final currentAsc = ref.watch(vehicleSortAscProvider);
    final primary = Theme.of(context).colorScheme.primary;

    if (widget.mobile) {
      return ListView.builder(
        // bottom: 96 — FAB не перекрывает последнюю строку списка
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: widget.vehicles.length,
        itemBuilder: (context, i) => _VehicleRow(
          vehicle: widget.vehicles[i],
          colors: widget.colors,
          fmt: fmt,
          canEdit: perms.canEditVehicle,
          onEdit: () => _openEdit(context, widget.vehicles[i]),
          mobile: true,
          widths: _widths,
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: widget.colors.tableBorder, width: 0.5)),
          ),
          child: Row(
            children: [
              for (int i = 0; i < _labels.length; i++)
                _resizableHeader(i, currentSort, currentAsc, primary),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.vehicles.length,
            itemBuilder: (context, i) => _VehicleRow(
              vehicle: widget.vehicles[i],
              colors: widget.colors,
              fmt: fmt,
              canEdit: perms.canEditVehicle,
              onEdit: () => _openEdit(context, widget.vehicles[i]),
              widths: _widths,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Записей: ${widget.vehicles.length}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  void _openEdit(BuildContext context, Vehicle v) {
    showDialog(
      context: context,
      builder: (_) => VehicleEditDialog(vehicle: v, onSaved: () => ref.invalidate(vehiclesProvider)),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  final Vehicle vehicle;
  final AppColors colors;
  final DateFormat fmt;
  final VoidCallback onEdit;
  final bool canEdit;
  final bool mobile;
  final List<double> widths;

  const _VehicleRow({
    required this.vehicle,
    required this.colors,
    required this.fmt,
    required this.onEdit,
    required this.canEdit,
    required this.widths,
    this.mobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return InkWell(
        onTap: canEdit ? onEdit : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(vehicle.invNumber,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Text(vehicle.brandModel,
                    style: const TextStyle(fontSize: 12)),
              ),
              Text(vehicle.govNumber,
                  style: TextStyle(fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall!.color)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF888888)),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: canEdit ? onEdit : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(width: widths[0],
              child: Text(vehicle.invNumber, style: const TextStyle(fontSize: 12))),
            SizedBox(width: widths[1],
              child: Text(vehicle.brandModel, style: const TextStyle(fontSize: 12))),
            SizedBox(width: widths[2],
              child: Text(vehicle.govNumber, style: const TextStyle(fontSize: 12))),
            SizedBox(width: widths[3],
              child: _DateCell(date: vehicle.inspectionDate, fmt: fmt, colors: colors)),
            SizedBox(width: widths[4],
              child: _DateCell(date: vehicle.insuranceDate, fmt: fmt, colors: colors)),
            SizedBox(width: widths[5],
              child: _DateCell(date: vehicle.specialPermitDate, fmt: fmt, colors: colors)),
            SizedBox(width: widths[6],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateCell(
                    date: vehicle.nextToDate ?? vehicle.toDate,
                    fmt: fmt, colors: colors,
                    isNext: vehicle.nextToDate != null,
                  ),
                  if (vehicle.nextToMileage != null)
                    Text('${vehicle.nextToMileage} км',
                      style: TextStyle(fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall!.color))
                  else if (vehicle.toMileage != null && vehicle.nextToDate == null)
                    Text('${vehicle.toMileage} км',
                      style: TextStyle(fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall!.color)),
                ],
              ),
            ),
            SizedBox(width: widths[7],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateCell(
                    date: vehicle.nextEquipmentToDate ?? vehicle.equipmentToDate,
                    fmt: fmt, colors: colors,
                    isNext: vehicle.nextEquipmentToDate != null,
                  ),
                  if (vehicle.nextEquipmentToHours != null)
                    Text('${vehicle.nextEquipmentToHours} м/ч',
                      style: TextStyle(fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall!.color))
                  else if (vehicle.equipmentHours != null && vehicle.nextEquipmentToDate == null)
                    Text('${vehicle.equipmentHours} м/ч',
                      style: TextStyle(fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall!.color)),
                ],
              ),
            ),
            const Spacer(),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  final DateTime? date;
  final DateFormat fmt;
  final AppColors colors;
  // true → дата является вычисленным "следующим ТО", показать иконку
  final bool isNext;

  const _DateCell({
    required this.date,
    required this.fmt,
    required this.colors,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    if (date == null) return const Text('—', style: TextStyle(fontSize: 12));
    final status = Vehicle.dateStatus(date);
    Color textColor;
    switch (status) {
      case 3: textColor = colors.badgeRedText;
      case 4: textColor = colors.badgeRedText;
      case 2: textColor = colors.badgeAmberText;
      case 1: textColor = colors.badgeGreenText;
      default: textColor = Theme.of(context).textTheme.bodyMedium!.color!;
    }
    final label = fmt.format(date!);
    if (!isNext) {
      return Text(label,
        style: TextStyle(fontSize: 12,
            fontWeight: status > 0 ? FontWeight.w500 : FontWeight.normal,
            color: textColor));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_repeat_outlined, size: 11, color: textColor),
        const SizedBox(width: 3),
        Text(label,
          style: TextStyle(fontSize: 12,
              fontWeight: status > 0 ? FontWeight.w500 : FontWeight.normal,
              color: textColor)),
      ],
    );
  }
}
