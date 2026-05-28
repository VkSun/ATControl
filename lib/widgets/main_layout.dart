import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:async';
import '../utils/theme.dart';
import '../services/weather_service.dart';
import '../services/vehicle_service.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

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
    final collapsed = ref.watch(sidebarCollapsedProvider);

    // Автосворачивание при узком окне
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      if (width < 900 && !collapsed) {
        ref.read(sidebarCollapsedProvider.notifier).state = true;
      } else if (width >= 900 && collapsed) {
        ref.read(sidebarCollapsedProvider.notifier).state = false;
      }
    });

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: collapsed ? 56 : 220,
            child: _Sidebar(
              colors: colors,
              now: _now,
              currentLocation: location,
              themeMode: themeMode,
              collapsed: collapsed,
              onThemeToggle: () {
                ref.read(themeModeProvider.notifier).state =
                    themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              },
              onToggleCollapse: () {
                ref.read(sidebarCollapsedProvider.notifier).state = !collapsed;
              },
            ),
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
  final bool collapsed;
  final VoidCallback onThemeToggle;
  final VoidCallback onToggleCollapse;

  const _Sidebar({
    required this.colors,
    required this.now,
    required this.currentLocation,
    required this.themeMode,
    required this.collapsed,
    required this.onThemeToggle,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.sidebarBg,
      child: Column(
        children: [
          _SidebarTop(
            colors: colors,
            now: now,
            themeMode: themeMode,
            collapsed: collapsed,
            onThemeToggle: onThemeToggle,
            onToggleCollapse: onToggleCollapse,
          ),
          Expanded(
            child: _SidebarNav(
              colors: colors,
              currentLocation: currentLocation,
              collapsed: collapsed,
            ),
          ),
          _SidebarBottom(collapsed: collapsed),
        ],
      ),
    );
  }
}

class _SidebarTop extends StatelessWidget {
  final AppColors colors;
  final DateTime now;
  final ThemeMode themeMode;
  final bool collapsed;
  final VoidCallback onThemeToggle;
  final VoidCallback onToggleCollapse;

  const _SidebarTop({
    required this.colors,
    required this.now,
    required this.themeMode,
    required this.collapsed,
    required this.onThemeToggle,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('EEEE, d MMMM', 'ru').format(now);

    return Container(
      padding: EdgeInsets.all(collapsed ? 8 : 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
  children: [
    GestureDetector(
      onTap: onToggleCollapse,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: colors.sidebarActive,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.directions_car, color: Colors.white, size: 18),
      ),
    ),
    if (!collapsed) ...[
      const SizedBox(width: 8),
      Expanded(
        child: Text('ATControl',
          style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton(
        onPressed: onToggleCollapse,
        icon: const Icon(Icons.chevron_left, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        color: Theme.of(context).textTheme.bodySmall!.color,
      ),
    ],
  ],
),
          if (!collapsed) ...[
            const SizedBox(height: 14),
            Text(timeStr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Consumer(
              builder: (context, ref, _) {
                final weatherAsync = ref.watch(weatherProvider);
                return weatherAsync.when(
                  loading: () => Text('загрузка...',
                    style: Theme.of(context).textTheme.bodySmall),
                  error: (_, __) => Text('погода недоступна',
                    style: Theme.of(context).textTheme.bodySmall),
                  data: (w) => Row(
                    children: [
                      Text(w.icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${w.temp.round()}°C • ${w.description}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis),
                      ),
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
  final bool collapsed;

  const _SidebarNav({
    required this.colors,
    required this.currentLocation,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider).value ?? 0;

    final userRole = ref.watch(currentUserRoleProvider).value;
   
final items = [
  const _NavItem('Главная', '/', Icons.home_outlined),
  const _NavItem('Транспорт', '/transport', Icons.directions_car_outlined),
  const _NavItem('Водители', '/drivers', Icons.people_outlined),
  _NavItem('Планировщик', '/planner', Icons.calendar_month_outlined, badge: pendingCount),
  if (userRole?.isAdmin == true)
    const _NavItem('Пользователи', '/users', Icons.manage_accounts_outlined),
  const _NavItem('Настройки', '/settings', Icons.settings_outlined),
];

    return ListView(
      padding: const EdgeInsets.all(8),
      children: items.map((item) {
        final isActive = currentLocation == item.path;
        return Tooltip(
          message: collapsed ? item.label : '',
          preferBelow: false,
          child: GestureDetector(
            onTap: () => context.go(item.path),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 10,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: isActive ? colors.sidebarActive : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: collapsed
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(item.icon, size: 20,
                          color: isActive ? Colors.white
                              : Theme.of(context).textTheme.bodySmall!.color),
                        if (item.badge > 0)
                          Positioned(
                            top: 0, right: 4,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: colors.badgeRed,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${item.badge}',
                                  style: TextStyle(fontSize: 8,
                                      fontWeight: FontWeight.w500,
                                      color: colors.badgeRedText)),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(item.icon, size: 16,
                          color: isActive ? Colors.white
                              : Theme.of(context).textTheme.bodySmall!.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: isActive ? Colors.white
                                  : Theme.of(context).textTheme.bodyMedium!.color,
                            ),
                          ),
                        ),
                        if (item.badge > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
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
          ),
        );
      }).toList(),
    );
  }
}

class _SidebarBottom extends StatefulWidget {
  final bool collapsed;
  const _SidebarBottom({required this.collapsed});

  @override
  State<_SidebarBottom> createState() => _SidebarBottomState();
}

class _SidebarBottomState extends State<_SidebarBottom> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) return const SizedBox(height: 14);
    return Container(
      padding: const EdgeInsets.all(14),
      child: Text('Версия $_version',
        style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

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