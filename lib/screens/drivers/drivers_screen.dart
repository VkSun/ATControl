import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/driver.dart';
import '../../services/driver_service.dart';
import '../../utils/theme.dart';
import 'driver_edit_dialog.dart';
import '../../services/vehicle_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';

enum DriverSort { fullName, licenseExpiry, medicalExpiry, birthDate }

final driverSortProvider = StateProvider<DriverSort>((ref) => DriverSort.fullName);
final driverSearchProvider = StateProvider<String>((ref) => '');

class DriversScreen extends ConsumerWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final sort = ref.watch(driverSortProvider);
    final search = ref.watch(driverSearchProvider);
    final driversAsync = ref.watch(driversProvider);

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
                    child: driversAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                      data: (drivers) {
                        var list = drivers;
                        if (search.isNotEmpty) {
                          final q = search.toLowerCase();
                          list = list.where((d) => d.fullName.toLowerCase().contains(q)).toList();
                        }
                        list = [...list];
                        switch (sort) {
                          case DriverSort.licenseExpiry:
                            list.sort((a, b) => (a.licenseExpiry ?? DateTime(2099)).compareTo(b.licenseExpiry ?? DateTime(2099)));
                          case DriverSort.medicalExpiry:
                            list.sort((a, b) => (a.medicalExpiry ?? DateTime(2099)).compareTo(b.medicalExpiry ?? DateTime(2099)));
                          case DriverSort.birthDate:
                            list.sort((a, b) => (a.birthDate ?? DateTime(2099)).compareTo(b.birthDate ?? DateTime(2099)));
                          case DriverSort.fullName:
                            list.sort((a, b) => a.fullName.compareTo(b.fullName));
                        }
                        return _DriverTable(drivers: list, colors: colors, ref: ref);
                      },
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
          FilledButton.icon(
            onPressed: () => showDialog(
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
            textStyle: const TextStyle(fontSize: 13),
          ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_outlined, size: 20),
          const SizedBox(width: 12),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(profileProvider);
              final initials = profileAsync.value?.initials ?? 'АИ';
              final color = profileAsync.value?.avatarColor ?? '#4361EE';
              final avatarColor = Color(int.parse(color.replaceFirst('#', '0xFF')));
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
      ),
    );
  }
}

class _SearchAndSort extends StatelessWidget {
  final AppColors colors;
  final DriverSort sort;
  final WidgetRef ref;

  const _SearchAndSort({required this.colors, required this.sort, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => ref.read(driverSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Поиск по ФИО...',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
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
          _SortBtn('ФИО', DriverSort.fullName, sort, ref, colors),
          const SizedBox(width: 4),
          _SortBtn('Вод. удост.', DriverSort.licenseExpiry, sort, ref, colors),
          const SizedBox(width: 4),
          _SortBtn('Мед. справка', DriverSort.medicalExpiry, sort, ref, colors),
          const SizedBox(width: 4),
          _SortBtn('Дата рожд.', DriverSort.birthDate, sort, ref, colors),
        ],
      ),
    );
  }
}

class _SortBtn extends StatelessWidget {
  final String label;
  final DriverSort value;
  final DriverSort current;
  final WidgetRef ref;
  final AppColors colors;

  const _SortBtn(this.label, this.value, this.current, this.ref, this.colors);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => ref.read(driverSortProvider.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4361EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFF4361EE) : colors.tableBorder),
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

class _DriverTable extends StatelessWidget {
  final List<Driver> drivers;
  final AppColors colors;
  final WidgetRef ref;

  const _DriverTable({required this.drivers, required this.colors, required this.ref});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
          ),
          child: Row(
            children: [
              _th('ФИО', 200),
              _th('Таб. номер', 90),
              _th('Инв. ТС', 90),
              _th('Вод. удостоверение', 140),
              _th('Мед. справка', 120),
              _th('Дата рождения', 120),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, i) {
              final d = drivers[i];
              return InkWell(
                onTap: () => _openEdit(context, d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 200, child: Text(d.fullName, style: const TextStyle(fontSize: 12))),
                      SizedBox(width: 90, child: Text(d.tabNumber, style: const TextStyle(fontSize: 12))),
                      SizedBox(width: 90, child: _VehicleCell(vehicleId: d.vehicleId, ref: ref)),
                      SizedBox(width: 140, child: _DateCell(date: d.licenseExpiry, fmt: fmt, colors: colors)),
                      SizedBox(width: 120, child: _DateCell(date: d.medicalExpiry, fmt: fmt, colors: colors)),
                      SizedBox(width: 120, child: Text(d.birthDate != null ? fmt.format(d.birthDate!) : '—', style: const TextStyle(fontSize: 12))),
                      const Spacer(),
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
          child: Row(
            children: [
              Text('Записей: ${drivers.length}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _th(String label, double width) => SizedBox(
    width: width,
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF888888))),
  );

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
    final now = DateTime.now();
    final diff = date!.difference(now).inDays;
    Color textColor;
    if (diff < 0 || diff <= 7) {
      textColor = colors.badgeRedText;
    } else if (diff <= 30) {
      textColor = colors.badgeAmberText;
    } else {
      textColor = Theme.of(context).textTheme.bodyMedium!.color!;
    }
    return Text(fmt.format(date!),
      style: TextStyle(fontSize: 12, fontWeight: diff <= 30 ? FontWeight.w500 : FontWeight.normal, color: textColor),
      );
  }
}
class _VehicleCell extends ConsumerWidget {
  final String? vehicleId;
  final WidgetRef ref;
  const _VehicleCell({required this.vehicleId, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (vehicleId == null) return const Text('—', style: TextStyle(fontSize: 12));
    final vehiclesAsync = ref.watch(vehiclesProvider);
    return vehiclesAsync.when(
      loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (_, __) => const Text('—', style: TextStyle(fontSize: 12)),
      data: (vehicles) {
        final v = vehicles.where((v) => v.id == vehicleId).firstOrNull;
        return Text(v?.invNumber ?? '—', style: const TextStyle(fontSize: 12));
      },
    );
  }
}