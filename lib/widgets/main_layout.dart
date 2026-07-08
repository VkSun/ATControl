import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:async';
import 'dart:io';
import '../utils/theme.dart';
import '../utils/date_utils.dart';
import '../utils/responsive.dart';
import '../services/weather_service.dart';
import '../services/vehicle_service.dart';
import '../services/driver_service.dart';
import '../services/task_service.dart';
import '../services/offline_state.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/update_service.dart';
import '../screens/profile/profile_dialog.dart';
import '../screens/settings/settings_screen.dart' show closeToTrayProvider;

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with WidgetsBindingObserver, WindowListener, TrayListener {
  late Timer _timer;
  late DateTime _now;
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
      if (Platform.isWindows) _setupTray();
    });
    if (Platform.isWindows) {
      windowManager.addListener(this);
      trayManager.addListener(this);
    }
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon('assets/icons/app_icon.ico');
    await trayManager.setToolTip('ATControl');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Развернуть ATControl'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Закрыть ATControl'),
    ]));
  }

  // WindowListener
  @override
  void onWindowClose() async {
    if (!mounted) return;
    final closeToTray = ref.read(closeToTrayProvider);
    if (closeToTray) {
      await windowManager.hide();
    } else {
      await _showCloseConfirmation();
    }
  }

  // TrayListener
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'quit') {
      _showCloseConfirmation();
    }
  }

  Future<void> _showCloseConfirmation() async {
    if (!mounted) return;
    final isOffline = isOfflineNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Завершить ATControl?'),
        content: isOffline
            ? const Text(
                'Есть несинхронизированные изменения.\n'
                'При закрытии они могут быть потеряны.',
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await windowManager.destroy();
    }
  }

  Future<void> _checkForUpdate() async {
    final updates = await UpdateService.checkForUpdates();
    for (final update in updates) {
      if (!mounted) return;
      await _showUpdateDialog(update);
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo update) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(update.type == UpdateType.extension
            ? 'Обновление расширения'
            : 'Доступно обновление'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.type == UpdateType.extension) ...[
              Text(
                  'Доступна новая версия браузерного расширения ATControl — ${update.version}.'),
              const SizedBox(height: 8),
              const Text(
                'Нажмите «Скачать» — новый установщик уже включает обновлённое расширение.\n'
                'Запустите его — приложение и расширение обновятся автоматически.',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ] else ...[
              Text('Версия ${update.version} готова к установке.'),
              const SizedBox(height: 8),
              if (Platform.isAndroid)
                const Text(
                  'Нажмите «Скачать» — откроется загрузка APK.\n'
                  'После загрузки установите поверх текущей версии.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
              if (Platform.isWindows)
                const Text(
                  'Нажмите «Скачать» — откроется загрузка установщика (.exe).\n'
                  'Запустите его — он заменит текущую версию автоматически.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (update.type == UpdateType.extension) {
                await UpdateService.dismissExtensionUpdate(update.version);
              }
            },
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (update.type == UpdateType.extension) {
                await UpdateService.dismissExtensionUpdate(update.version);
              }
              UpdateService.openDownload(update.downloadUrl);
            },
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isOfflineNotifier.value) {
      _retryConnection();
    }
  }

  void _retryConnection() {
    ref.invalidate(vehiclesProvider);
    ref.invalidate(driversProvider);
    ref.invalidate(tasksProvider);
    ref.invalidate(todayTasksProvider);
    ref.invalidate(pendingCountProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.of(context).size.width;
    if (_lastWidth == null) {
      if (width < 900) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(sidebarCollapsedProvider.notifier).state = true;
        });
      }
    } else if (_lastWidth! >= 900 && width < 900) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(sidebarCollapsedProvider.notifier).state = true;
      });
    } else if (_lastWidth! < 900 && width >= 900) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(sidebarCollapsedProvider.notifier).state = false;
      });
    }
    _lastWidth = width;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final themeMode = ref.watch(themeModeProvider);
    final location = GoRouterState.of(context).uri.toString();
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final mobile = isPhone(context);

    if (mobile) {
      return _MobileLayout(child: widget.child, location: location, colors: colors, now: _now);
    }

    return Scaffold(
      body: Column(
        children: [
          _OfflineBanner(onRetry: _retryConnection),
          Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: collapsed ? 56 : 220,
                  child: _Sidebar(
                    colors: colors,
                    now: _now,
                    currentLocation: location,
                    themeMode: themeMode,
                    collapsed: collapsed,
                    onThemeToggle: () {
                      ref.read(themeModeProvider.notifier).set(
                          themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
                    },
                    onToggleCollapse: () {
                      ref.read(sidebarCollapsedProvider.notifier).state = !collapsed;
                    },
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MOBILE LAYOUT ──────────────────────────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  final Widget child;
  final String location;
  final AppColors colors;
  final DateTime now;

  const _MobileLayout({
    required this.child,
    required this.location,
    required this.colors,
    required this.now,
  });

  int _locationToIndex(String loc) {
    switch (loc) {
      case '/transport': return 1;
      case '/drivers':   return 2;
      case '/planner':   return 3;
      case '/settings':  return 4;
      default:           return 0;
    }
  }

  String _indexToLocation(int i) {
    switch (i) {
      case 1: return '/transport';
      case 2: return '/drivers';
      case 3: return '/planner';
      case 4: return '/settings';
      default: return '/';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(currentUserRoleProvider).value;
    final pendingCount = ref.watch(pendingCountProvider).value ?? 0;
    final profileAsync = ref.watch(profileProvider);
    final initials = profileAsync.value?.initials ?? 'АИ';
    final avatarHex = profileAsync.value?.avatarColor ?? '#4361EE';
    final avatarColor = Color(int.parse(avatarHex.replaceFirst('#', '0xFF')));
    final themeMode = ref.watch(themeModeProvider);
    final currentIdx = _locationToIndex(location);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _OfflineBanner(onRetry: () {
              ref.invalidate(vehiclesProvider);
              ref.invalidate(driversProvider);
              ref.invalidate(tasksProvider);
              ref.invalidate(todayTasksProvider);
              ref.invalidate(pendingCountProvider);
            }),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 0.5, thickness: 0.5, color: colors.tableBorder),
          NavigationBar(
            height: 60,
            selectedIndex: currentIdx,
            onDestinationSelected: (i) => context.go(_indexToLocation(i)),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Главная',
              ),
              const NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: 'Транспорт',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: 'Водители',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.calendar_month_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.calendar_month),
                ),
                label: 'Планировщик',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Настройки',
              ),
            ],
          ),
          // Нижняя панель: профиль + тема + пользователи
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                GestureDetector(
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
                      const SizedBox(width: 8),
                      Text(profileAsync.value?.fullName ?? '',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                if (userRole?.isAdmin == true)
                  IconButton(
                    icon: const Icon(Icons.manage_accounts_outlined, size: 20),
                    onPressed: () => context.go('/users'),
                    tooltip: 'Пользователи',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                IconButton(
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_round,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).set(
                        themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DESKTOP SIDEBAR ────────────────────────────────────────────────────────

class _Sidebar extends StatefulWidget {
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
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
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
  void didUpdateWidget(_Sidebar old) {
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
            now: widget.now,
            themeMode: widget.themeMode,
            collapsed: widget.collapsed,
            textVisible: _textVisible,
            textOpacity: _textOpacity,
            onThemeToggle: widget.onThemeToggle,
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
  final DateTime now;
  final ThemeMode themeMode;
  final bool collapsed;
  final bool textVisible;
  final double textOpacity;
  final VoidCallback onThemeToggle;
  final VoidCallback onToggleCollapse;

  const _SidebarTop({
    required this.colors,
    required this.now,
    required this.themeMode,
    required this.collapsed,
    required this.textVisible,
    required this.textOpacity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
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
    final avatarHex = profileAsync.value?.avatarColor ?? '#4361EE';
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
      final result = await InternetAddress.lookup('supabase.co')
          .timeout(const Duration(seconds: 5));
      final ok = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted) setState(() => _connected = ok);
    } catch (_) {
      if (mounted) setState(() => _connected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connected;
    final isOnline = connected == true;
    final dotColor = connected == null
        ? const Color(0xFF888888)
        : isOnline
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE24B4A);
    final label = connected == null
        ? 'Проверка...'
        : isOnline
            ? 'Подключено'
            : 'Нет подключения';

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
        child: Text('Версия $_version',
          style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

// ─── Offline banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends ConsumerWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider).value;
    if (!isOffline) return const SizedBox.shrink();
    final queueCount = ref.watch(offlineQueueCountProvider).value;
    return Material(
      color: const Color(0xFFF57C00),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                queueCount > 0
                    ? 'Офлайн · $queueCount изм. ожидают синхронизации'
                    : 'Нет подключения к интернету',
                style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Обновить',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Expiring documents badge count ──────────────────────────────────────────

final pendingCountProvider = FutureProvider<int>((ref) async {
  int count = 0;
  final vehicles = await ref.read(vehicleServiceProvider).getAll();
  for (final v in vehicles) {
    for (final date in [v.inspectionDate, v.insuranceDate, v.specialPermitDate]) {
      if (date == null) continue;
      if (daysUntil(date) <= 7) count++;
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

class SplitHandle extends StatelessWidget {
  final double gap;
  final AppColors colors;
  final void Function(DragStartDetails) onDragStart;
  final void Function(DragUpdateDetails) onDrag;

  const SplitHandle({
    super.key,
    required this.gap,
    required this.colors,
    required this.onDragStart,
    required this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onPanStart: onDragStart,
        onPanUpdate: onDrag,
        child: SizedBox(
          width: gap,
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: colors.tableBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
