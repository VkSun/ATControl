import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../platform/app_platform.dart';
import '../utils/theme.dart';
import '../utils/date_utils.dart';
import '../services/weather_service.dart';
import '../services/vehicle_service.dart';
import '../services/driver_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../screens/profile/profile_dialog.dart';
import '../l10n/gen/app_localizations.dart';
import 'weather_desc_text.dart';

// ─── Expiring documents badge count ──────────────────────────────────────────

final pendingCountProvider = FutureProvider<int>((ref) async {
  int count = 0;
  final vehicles = await ref.read(vehicleServiceProvider).getAll();
  for (final v in vehicles) {
    // Все 5 типов сроков ТС (включая вычисляемые ТО автомобиля/оборудования).
    for (final entry in v.expiryDates()) {
      if (entry.date == null) continue;
      if (daysUntil(entry.date!) <= 7) count++;
    }
  }
  final drivers = await ref.read(driverServiceProvider).getAll();
  for (final d in drivers) {
    for (final date in [d.licenseExpiry, d.medicalExpiry]) {
      if (date == null) continue;
      if (daysUntil(date) <= 7) count++;
    }
  }
  return count;
});

/// Часы и дата в сайдбаре: собственный таймер, чтобы ежесекундный setState
/// не перерисовывал весь layout.
class SidebarClock extends StatefulWidget {
  /// true — одна строка (только время), для сайдбара на малой высоте.
  final bool compact;

  const SidebarClock({super.key, this.compact = false});

  @override
  State<SidebarClock> createState() => _SidebarClockState();
}

class _SidebarClockState extends State<SidebarClock> {
  late DateTime _now;
  late Timer _timer;

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
    final timeStr = DateFormat('HH:mm').format(_now);
    if (widget.compact) {
      return Text(timeStr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500));
    }
    final dateStr = DateFormat('EEEE, d MMMM', 'ru').format(_now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.centerLeft,
            child: Text(timeStr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          child: Text(dateStr,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ─── DESKTOP SIDEBAR ────────────────────────────────────────────────────────

class Sidebar extends StatefulWidget {
  final AppColors colors;
  final String currentLocation;

  final bool collapsed;

  final VoidCallback onToggleCollapse;

  const Sidebar({
    super.key,
    required this.colors,
    required this.currentLocation,

    required this.collapsed,

    required this.onToggleCollapse,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _textVisible = true;
  double _textOpacity = 1.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _textVisible = !widget.collapsed;
    _textOpacity = widget.collapsed ? 0.0 : 1.0;
  }

  @override
  void didUpdateWidget(Sidebar old) {
    super.didUpdateWidget(old);
    if (old.collapsed != widget.collapsed) {
      _timer?.cancel();
      if (widget.collapsed) {
        // Fade text out, then remove from tree after fade completes
        setState(() => _textOpacity = 0.0);
        _timer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _textVisible = false);
        });
      } else {
        // Add text to tree (invisible), then fade in after width expands
        setState(() { _textVisible = true; _textOpacity = 0.0; });
        _timer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _textOpacity = 1.0);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.colors.sidebarBg,
      child: Column(
        children: [
          _SidebarTop(
            colors: widget.colors,

            collapsed: widget.collapsed,
            textVisible: _textVisible,
            textOpacity: _textOpacity,

            onToggleCollapse: widget.onToggleCollapse,
          ),
          Expanded(
            child: _SidebarNav(
              colors: widget.colors,
              currentLocation: widget.currentLocation,
              collapsed: widget.collapsed,
              textVisible: _textVisible,
              textOpacity: _textOpacity,
            ),
          ),
          _SidebarBottomProfile(
            collapsed: widget.collapsed,
            colors: widget.colors,
            textVisible: _textVisible,
            textOpacity: _textOpacity,
          ),
          _SidebarNetworkStatus(
            collapsed: widget.collapsed,
            colors: widget.colors,
            textVisible: _textVisible,
            textOpacity: _textOpacity,
          ),
          _SidebarBottom(
            collapsed: widget.collapsed,
            textVisible: _textVisible,
            textOpacity: _textOpacity,
          ),
        ],
      ),
    );
  }
}

class _SidebarTop extends StatelessWidget {
  final AppColors colors;

  final bool collapsed;
  final bool textVisible;
  final double textOpacity;

  final VoidCallback onToggleCollapse;

  const _SidebarTop({
    required this.colors,

    required this.collapsed,
    required this.textVisible,
    required this.textOpacity,

    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
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
              if (textVisible) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: textOpacity,
                    duration: const Duration(milliseconds: 200),
                    child: Text('ATControl',
                      style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                AnimatedOpacity(
                  opacity: textOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    onPressed: onToggleCollapse,
                    icon: const Icon(Icons.chevron_left, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: Theme.of(context).textTheme.bodySmall!.color,
                  ),
                ),
              ],
            ],
          ),
          if (textVisible)
            AnimatedOpacity(
              opacity: textOpacity,
              duration: const Duration(milliseconds: 200),
              // Десктопная раскладка существует только при высоте ≥ 600
              // (isPhone смотрит на shortestSide), поэтому порог компактного
              // блока — 700: на тесной высоте часы+температура в одну строку,
              // дата и описание погоды скрываются.
              child: MediaQuery.sizeOf(context).height < 700
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const SidebarClock(compact: true),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final w = ref.watch(weatherProvider).value;
                                if (w == null) return const SizedBox.shrink();
                                return Text(
                                    '${w.icon} ${w.temp.round()}°C',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis);
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        const SidebarClock(),
                        const SizedBox(height: 4),
                        Consumer(
                          builder: (context, ref, _) {
                            final weatherAsync = ref.watch(weatherProvider);
                            final l10n = AppLocalizations.of(context);
                            return weatherAsync.when(
                              loading: () => Text(l10n.weatherLoading,
                                  style: Theme.of(context).textTheme.bodySmall),
                              error: (_, __) => Text(l10n.weatherUnavailable,
                                  style: Theme.of(context).textTheme.bodySmall),
                              data: (w) => Row(
                                children: [
                                  Text(w.icon,
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                        '${w.temp.round()}°C • ${weatherDescText(context, w)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
  final bool collapsed;
  final bool textVisible;
  final double textOpacity;

  const _SidebarNav({
    required this.colors,
    required this.currentLocation,
    required this.collapsed,
    required this.textVisible,
    required this.textOpacity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider).value ?? 0;
    final userRole = ref.watch(currentUserRoleProvider).value;
    final l10n = AppLocalizations.of(context);

    final items = [
      _NavItem(l10n.navHome, '/', Icons.home_outlined),
      _NavItem(l10n.navTransport, '/transport', Icons.directions_car_outlined),
      _NavItem(l10n.navDrivers, '/drivers', Icons.people_outlined),
      _NavItem(l10n.navPlanner, '/planner', Icons.calendar_month_outlined, badge: pendingCount),
      if (userRole?.isAdmin == true)
        _NavItem(l10n.navUsers, '/users', Icons.manage_accounts_outlined),
      _NavItem(l10n.navSettings, '/settings', Icons.settings_outlined),
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
              child: !textVisible
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
                  : AnimatedOpacity(
                      opacity: textOpacity,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
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
          ),
        );
      }).toList(),
    );
  }
}

// Профиль + уведомление внизу сайдбара (десктоп)
class _SidebarBottomProfile extends ConsumerWidget {
  final bool collapsed;
  final AppColors colors;
  final bool textVisible;
  final double textOpacity;

  const _SidebarBottomProfile({
    required this.collapsed,
    required this.colors,
    required this.textVisible,
    required this.textOpacity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final initials = profileAsync.value?.initials ?? 'АИ';
    final avatarHex = profileAsync.value?.avatarColor ?? AppTheme.primaryColorHex;
    final avatarColor = Color(int.parse(avatarHex.replaceFirst('#', '0xFF')));

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 12 : 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => const ProfileDialog(),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: avatarColor,
              child: Text(initials,
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
            if (textVisible) ...[
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedOpacity(
                  opacity: textOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profileAsync.value?.fullName ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      Text(profileAsync.value?.position ?? '',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF888888)),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarNetworkStatus extends StatefulWidget {
  final bool collapsed;
  final AppColors colors;
  final bool textVisible;
  final double textOpacity;
  const _SidebarNetworkStatus({
    required this.collapsed,
    required this.colors,
    required this.textVisible,
    required this.textOpacity,
  });

  @override
  State<_SidebarNetworkStatus> createState() => _SidebarNetworkStatusState();
}

class _SidebarNetworkStatusState extends State<_SidebarNetworkStatus> {
  bool? _connected;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final ok = await AppPlatform.checkConnectivity();
      if (mounted) setState(() => _connected = ok);
    } catch (_) {
      if (mounted) setState(() => _connected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connected = _connected;
    final isOnline = connected == true;
    final dotColor = connected == null
        ? const Color(0xFF888888)
        : isOnline
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE24B4A);
    final label = connected == null
        ? l10n.networkChecking
        : isOnline
            ? l10n.networkConnected
            : l10n.networkDisconnected;

    if (!widget.textVisible) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: Center(
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            opacity: widget.textOpacity,
            duration: const Duration(milliseconds: 200),
            child: Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          ),
        ],
      ),
    );
  }
}

class _SidebarBottom extends StatefulWidget {
  final bool collapsed;
  final bool textVisible;
  final double textOpacity;
  const _SidebarBottom({
    required this.collapsed,
    required this.textVisible,
    required this.textOpacity,
  });

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
    if (!widget.textVisible) return const SizedBox(height: 14);
    return AnimatedOpacity(
      opacity: widget.textOpacity,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Text(AppLocalizations.of(context).appVersion(_version),
          style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
