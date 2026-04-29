import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/theme.dart';
import '../services/vehicle_service.dart';
import '../services/driver_service.dart';
import '../screens/profile/profile_dialog.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../services/weather_service.dart';

final pendingCountProvider = FutureProvider<int>((ref) async {
  final now = DateTime.now();
  int count = 0;

  final vehicles = await ref.read(vehicleServiceProvider).getAll();
  for (final v in vehicles) {
    for (final date in [v.inspectionDate, v.insuranceDate, v.specialPermitDate]) {
      if (date == null) continue;
      if (date.difference(now).inDays <= 7) count++;
    }
  }

  final drivers = await ref.read(driverServiceProvider).getAll();
  for (final d in drivers) {
    for (final date in [d.licenseExpiry, d.medicalExpiry]) {
      if (date == null) continue;
      if (date.difference(now).inDays <= 7) count++;
    }
  }

  return count;
});

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final themeMode = ref.watch(themeModeProvider);
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            colors: colors,
            now: _now,
            currentLocation: location,
            themeMode: themeMode,
            onThemeToggle: () {
              ref.read(themeModeProvider.notifier).state =
                  themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AppColors colors;
  final DateTime now;
  final String currentLocation;
  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;

  const _Sidebar({
    required this.colors,
    required this.now,
    required this.currentLocation,
    required this.themeMode,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: colors.sidebarBg,
      child: Column(
        children: [
          _SidebarTop(colors: colors, now: now, themeMode: themeMode, onThemeToggle: onThemeToggle),
          Expanded(child: _SidebarNav(colors: colors, currentLocation: currentLocation)),
          _SidebarBottom(),
        ],
      ),
    );
  }
}

class _SidebarTop extends StatelessWidget {
  final AppColors colors;
  final DateTime now;
  final ThemeMode themeMode;
  final VoidCallback onThemeToggle;

  const _SidebarTop({
    required this.colors,
    required this.now,
    required this.themeMode,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('EEEE, d MMMM', 'ru').format(now);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: colors.sidebarActive,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text('ATControl', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          Text(timeStr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          // Погода
          Consumer(
            builder: (context, ref, _) {
              final weatherAsync = ref.watch(weatherProvider);
              return weatherAsync.when(
                loading: () => Text('загрузка погоды...',
                  style: Theme.of(context).textTheme.bodySmall),
                error: (_, __) => Text('погода недоступна',
                  style: Theme.of(context).textTheme.bodySmall),
                data: (w) => Row(
                  children: [
                    Text(w.icon, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text('${w.temp.round()}°C • ${w.description}',
                      style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 13),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onThemeToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36, height: 20,
                  decoration: BoxDecoration(
                    color: themeMode == ThemeMode.dark
                        ? colors.sidebarActive : colors.tableBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: themeMode == ThemeMode.dark
                      ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.nightlight_round, size: 13),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label, path;
  final IconData icon;
  final int badge;
  const _NavItem(this.label, this.path, this.icon, {this.badge = 0});
}

class _SidebarNav extends ConsumerWidget {
  final AppColors colors;
  final String currentLocation;

  const _SidebarNav({required this.colors, required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider).value ?? 0;

    final items = [
      const _NavItem('Главная', '/', Icons.home_outlined),
      const _NavItem('Транспорт', '/transport', Icons.directions_car_outlined),
      const _NavItem('Водители', '/drivers', Icons.people_outlined),
      _NavItem('Планировщик', '/planner', Icons.calendar_month_outlined, badge: pendingCount),
      const _NavItem('Настройки', '/settings', Icons.settings_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(8),
      children: items.map((item) {
        final isActive = currentLocation == item.path;
        return GestureDetector(
          onTap: () => context.go(item.path),
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isActive ? colors.sidebarActive : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 16,
                  color: isActive ? Colors.white : Theme.of(context).textTheme.bodySmall!.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                ),
                if (item.badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white24 : colors.badgeRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${item.badge}',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white : colors.badgeRedText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SidebarBottom extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Text('Версия 1.0 Beta',
        style: Theme.of(context).textTheme.bodySmall),
    );
  }
}