import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';
import '../../services/department_service.dart';
import '../../utils/theme.dart';
import '../../utils/date_utils.dart';
import 'driver_edit_dialog.dart';
import '../../services/vehicle_service.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';
import '../../utils/permissions.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_value_view.dart';

enum DriverSort { fullName, tabNumber, licenseExpiry, medicalExpiry, birthDate }

final driverSortProvider = StateProvider<DriverSort>((ref) => DriverSort.fullName);
final driverSortAscProvider = StateProvider<bool>((ref) => true);
final driverSearchProvider = StateProvider<String>((ref) => '');

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});

  List<Driver> _buildList(List<Driver> drivers, String search, DriverSort sort, bool asc) {
    var list = drivers;
    if (search.isNotEmpty) {
      final tokens = search.toLowerCase().split(RegExp(r'\s+'));
      list = list.where((d) {
        final fields = [d.fullName.toLowerCase(), d.tabNumber.toLowerCase()];
        return tokens.every((t) => fields.any((f) => f.contains(t)));
      }).toList();
    }
    list = [...list];
    list.sort((a, b) {
      final r = switch (sort) {
        DriverSort.fullName      => a.fullName.compareTo(b.fullName),
        DriverSort.tabNumber     => a.tabNumber.compareTo(b.tabNumber),
        DriverSort.licenseExpiry => (a.licenseExpiry ?? DateTime(2099)).compareTo(b.licenseExpiry ?? DateTime(2099)),
        DriverSort.medicalExpiry => (a.medicalExpiry ?? DateTime(2099)).compareTo(b.medicalExpiry ?? DateTime(2099)),
        DriverSort.birthDate     => (a.birthDate ?? DateTime(2099)).compareTo(b.birthDate ?? DateTime(2099)),
      };
      return asc ? r : -r;
    });
    return list;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final sort = ref.watch(driverSortProvider);
    final asc = ref.watch(driverSortAscProvider);
    final search = ref.watch(driverSearchProvider);
    final driversAsync = ref.watch(driversProvider);
    final mobile = isPhone(context);
    final perms = ref.watch(permissionsProvider);

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
                value: driversAsync,
                onRetry: driversProvider,
                builder: (drivers) => _DriverTable(
                  drivers: _buildList(drivers, search, sort, asc),
                  colors: colors,
                  mobile: true,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: (perms.canAddDriver || perms.isLoading)
            ? FloatingActionButton(
                onPressed: perms.isLoading ? null : () => showDialog(
                  context: context,
                  builder: (_) => DriverEditDialog(
                    onSaved: () => ref.invalidate(driversProvider),
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
                      value: driversAsync,
                      onRetry: driversProvider,
                      builder: (drivers) => _DriverTable(
                        drivers: _buildList(drivers, search, sort, asc),
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
          Text('Водители', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          if (perms.canAddDriver || perms.isLoading)
            FilledButton.icon(
              onPressed: perms.isLoading ? null : () => showDialog(
                context: context,
                builder: (_) => DriverEditDialog(
                  onSaved: () => ref.invalidate(driversProvider),
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
                final avatarColor = Color(int.parse(color.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => showDialog(context: context,
                    builder: (_) => const ProfileDialog()),
                  child: CircleAvatar(radius: 16, backgroundColor: avatarColor,
                    child: Text(initials,
                      style: const TextStyle(fontSize: 11, color: Colors.white))),
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
    _ctrl = TextEditingController(text: ref.read(driverSearchProvider));
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    ref.read(driverSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _ctrl,
        onChanged: (v) => ref.read(driverSearchProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Поиск по ФИО...',
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

class _DriverTable extends ConsumerStatefulWidget {
  final List<Driver> drivers;
  final AppColors colors;
  final bool mobile;

  const _DriverTable({required this.drivers, required this.colors, this.mobile = false});

  @override
  ConsumerState<_DriverTable> createState() => _DriverTableState();
}

class _DriverTableState extends ConsumerState<_DriverTable> {
  static const _prefsKey = 'driver_col_widths';
  static const _labels = ['ФИО', 'Таб. номер', 'Инв. ТС', 'Вод. удостоверение', 'Мед. справка', 'Дата рождения'];
  static const _defaults = [200.0, 90.0, 90.0, 140.0, 120.0, 120.0];
  static const _sortCols = <DriverSort?>[
    DriverSort.fullName,
    DriverSort.tabNumber,
    null,                    // Инв. ТС — асинхронный lookup
    DriverSort.licenseExpiry,
    DriverSort.medicalExpiry,
    DriverSort.birthDate,
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

  Widget _resizableHeader(int i, DriverSort currentSort, bool currentAsc, Color primary) {
    final sortCol = _sortCols[i];
    final isActive = sortCol != null && sortCol == currentSort;

    return SizedBox(
      width: _widths[i],
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: sortCol != null ? SystemMouseCursors.click : MouseCursor.defer,
              child: GestureDetector(
                onTap: sortCol == null ? null : () {
                  if (currentSort == sortCol) {
                    ref.read(driverSortAscProvider.notifier).state = !currentAsc;
                  } else {
                    ref.read(driverSortProvider.notifier).state = sortCol;
                    ref.read(driverSortAscProvider.notifier).state = true;
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
    final currentSort = ref.watch(driverSortProvider);
    final currentAsc = ref.watch(driverSortAscProvider);
    final primary = Theme.of(context).colorScheme.primary;

    if (widget.mobile) {
      return ListView.builder(
        // bottom: 96 — FAB не перекрывает последнюю строку списка
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: widget.drivers.length,
        itemBuilder: (context, i) {
          final d = widget.drivers[i];
          return InkWell(
            onTap: perms.canEditDriver ? () => _openEdit(context, d) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: widget.colors.tableBorder, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d.fullName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Text(d.tabNumber,
                      style: TextStyle(fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall!.color)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF888888)),
                ],
              ),
            ),
          );
        },
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
            // Компактные строки фиксированной высоты: больше записей на экран
            itemExtent: 52,
            itemCount: widget.drivers.length,
            itemBuilder: (context, i) {
              final d = widget.drivers[i];
              return InkWell(
                onTap: perms.canEditDriver ? () => _openEdit(context, d) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: widget.colors.tableBorder, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: _widths[0], child: Text(d.fullName, style: const TextStyle(fontSize: 12))),
                      SizedBox(width: _widths[1], child: Text(d.tabNumber, style: const TextStyle(fontSize: 12))),
                      SizedBox(width: _widths[2], child: _VehicleCell(vehicleIds: d.vehicleIds, ref: ref)),
                      SizedBox(width: _widths[3], child: _DateCell(date: d.licenseExpiry, fmt: fmt, colors: widget.colors)),
                      SizedBox(width: _widths[4], child: _DateCell(date: d.medicalExpiry, fmt: fmt, colors: widget.colors)),
                      SizedBox(width: _widths[5], child: Text(d.birthDate != null ? fmt.format(d.birthDate!) : '—',
                        style: const TextStyle(fontSize: 12))),
                      const Spacer(),
                      if (perms.canEditDriver)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _openEdit(context, d),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Записей: ${widget.drivers.length}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  void _openEdit(BuildContext context, Driver d) {
    showDialog(
      context: context,
      builder: (_) => DriverEditDialog(driver: d, onSaved: () => ref.invalidate(driversProvider)),
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
    final diff = daysUntil(date!);
    Color textColor;
    if (diff < 0 || diff <= 7) {
      textColor = colors.badgeRedText;
    } else if (diff <= 14) {
      textColor = colors.badgeAmberText;
    } else if (diff <= 30) {
      textColor = colors.badgeGreenText;
    } else {
      textColor = Theme.of(context).textTheme.bodyMedium!.color!;
    }
    return Text(fmt.format(date!),
      style: TextStyle(fontSize: 12, fontWeight: diff <= 30 ? FontWeight.w500 : FontWeight.normal, color: textColor),
    );
  }
}

class _VehicleCell extends ConsumerWidget {
  final List<String> vehicleIds;
  final WidgetRef ref;
  const _VehicleCell({required this.vehicleIds, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vehicleIds.isEmpty) return const Text('—', style: TextStyle(fontSize: 12));
    final vehiclesAsync = ref.watch(vehiclesProvider);
    return vehiclesAsync.when(
      loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (_, __) => const Text('—', style: TextStyle(fontSize: 12)),
      data: (vehicles) {
        final invNums = vehicleIds
            .map((id) => vehicles.where((v) => v.id == id).firstOrNull?.invNumber)
            .whereType<String>()
            .join(', ');
        return Text(invNums.isEmpty ? '—' : invNums,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis);
      },
    );
  }
}
