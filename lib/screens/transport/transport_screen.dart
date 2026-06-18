import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../services/vehicle_service.dart';
import '../../utils/theme.dart';
import 'vehicle_edit_dialog.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';
import '../../utils/permissions.dart';
import '../../utils/responsive.dart';

enum VehicleSort { invNumber, brand, govNumber }

final vehicleSortProvider = StateProvider<VehicleSort>((ref) => VehicleSort.invNumber);
final vehicleSearchProvider = StateProvider<String>((ref) => '');

class TransportScreen extends ConsumerWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final sort = ref.watch(vehicleSortProvider);
    final search = ref.watch(vehicleSearchProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final mobile = isMobile(context);
    final perms = ref.watch(permissionsProvider);

    List<Vehicle> buildList(List<Vehicle> vehicles) {
      var list = vehicles;
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        list = list.where((v) =>
          v.invNumber.toLowerCase().contains(q) ||
          v.brandModel.toLowerCase().contains(q) ||
          v.govNumber.toLowerCase().contains(q)).toList();
      }
      list = [...list];
      switch (sort) {
        case VehicleSort.brand:
          list.sort((a, b) => a.brandModel.compareTo(b.brandModel));
        case VehicleSort.govNumber:
          list.sort((a, b) => a.govNumber.compareTo(b.govNumber));
        case VehicleSort.invNumber:
          list.sort((a, b) => a.invNumber.compareTo(b.invNumber));
      }
      return list;
    }

    if (mobile) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                onChanged: (v) =>
                    ref.read(vehicleSearchProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Поиск транспорта...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Expanded(
              child: vehiclesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
                data: (vehicles) => _VehicleTable(
                  vehicles: buildList(vehicles),
                  colors: colors,
                  mobile: true,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: perms.canAddVehicle
            ? FloatingActionButton(
                onPressed: () => showDialog(
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.tableBorder, width: 0.5),
              ),
              child: Column(
                children: [
                  _SearchAndSort(colors: colors, sort: sort, ref: ref),
                  Expanded(
                    child: vehiclesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                      data: (vehicles) => _VehicleTable(
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
          if (perms.canAddVehicle)
            FilledButton.icon(
              onPressed: () => showDialog(
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
          if (isMobile(context)) ...[
            const Icon(Icons.notifications_outlined, size: 20),
            const SizedBox(width: 12),
            Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(profileProvider);
                final initials = profileAsync.value?.initials ?? 'АИ';
                final color = profileAsync.value?.avatarColor ?? '#4361EE';
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

class _SearchAndSort extends StatelessWidget {
  final AppColors colors;
  final VehicleSort sort;
  final WidgetRef ref;

  const _SearchAndSort({required this.colors, required this.sort, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Введите для поиска марку, модель, гос.номер или инвентарный номер',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => ref.read(vehicleSearchProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Поиск...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.tableBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Сортировать по:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              _SortBtn('Инв. номер', VehicleSort.invNumber, sort, ref, colors),
              const SizedBox(width: 4),
              _SortBtn('Марка', VehicleSort.brand, sort, ref, colors),
              const SizedBox(width: 4),
              _SortBtn('Гос. номер', VehicleSort.govNumber, sort, ref, colors),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortBtn extends StatelessWidget {
  final String label;
  final VehicleSort value;
  final VehicleSort current;
  final WidgetRef ref;
  final AppColors colors;

  const _SortBtn(this.label, this.value, this.current, this.ref, this.colors);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => ref.read(vehicleSortProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4361EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFF4361EE) : colors.tableBorder,
          ),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.white : Theme.of(context).textTheme.bodySmall!.color,
          ),
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

  Widget _resizableHeader(int i) {
    return SizedBox(
      width: _widths[i],
      child: Row(
        children: [
          Expanded(
            child: Text(_labels[i],
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF888888))),
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
                width: 8,
                height: 24,
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

    if (widget.mobile) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
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
              for (int i = 0; i < _labels.length; i++) _resizableHeader(i),
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
                  _DateCell(date: vehicle.toDate, fmt: fmt, colors: colors),
                  if (vehicle.toMileage != null)
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
                  _DateCell(date: vehicle.equipmentToDate, fmt: fmt, colors: colors),
                  if (vehicle.equipmentHours != null)
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

  const _DateCell({required this.date, required this.fmt, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const Text('—', style: TextStyle(fontSize: 12));
    final status = Vehicle.dateStatus(date);
    Color textColor;
    switch (status) {
      case 2: textColor = colors.badgeRedText;
      case 3: textColor = colors.badgeRedText;
      case 1: textColor = colors.badgeAmberText;
      default: textColor = Theme.of(context).textTheme.bodyMedium!.color!;
    }
    return Text(fmt.format(date!),
      style: TextStyle(fontSize: 12, fontWeight: status > 0 ? FontWeight.w500 : FontWeight.normal, color: textColor),
    );
  }
}