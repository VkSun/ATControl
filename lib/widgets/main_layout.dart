import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../platform/app_platform.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';
import '../services/vehicle_service.dart';
import '../services/driver_service.dart';
import '../services/task_service.dart';
import '../services/offline_state.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../screens/profile/profile_dialog.dart';
import 'sidebar.dart';
import 'sync_sheet.dart';
import 'update_dialog.dart';
import 'window_close.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with WidgetsBindingObserver {
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdates(context);
      AppPlatform.window.setupTray(); // no-op вне Windows
    });
    AppPlatform.window.addHandlers(WindowHandlers(
      onCloseRequested: () => handleWindowCloseRequest(context, ref),
      onQuitRequested: () => showCloseConfirmation(context),
    ));
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
    AppPlatform.window.removeHandlers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final location = GoRouterState.of(context).uri.toString();
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final mobile = isPhone(context);

    if (mobile) {
      return _MobileLayout(child: widget.child, location: location, colors: colors);
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
                  child: Sidebar(
                    colors: colors,
                    currentLocation: location,
                    collapsed: collapsed,
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

  const _MobileLayout({
    required this.child,
    required this.location,
    required this.colors,
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
    final avatarHex = profileAsync.value?.avatarColor ?? AppTheme.primaryColorHex;
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

// ─── Offline banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends ConsumerWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider).value;
    final queueCount = ref.watch(offlineQueueCountProvider).value;
    // Баннер виден и после восстановления сети, пока очередь не пуста.
    if (!isOffline && queueCount == 0) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFF57C00),
      child: InkWell(
        // Тап по индикатору — шторка «Синхронизация»
        onTap: () => showSyncSheet(context),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOffline
                    ? (queueCount > 0
                        ? 'Офлайн · изменения ожидают синхронизации'
                        : 'Нет подключения к интернету')
                    : 'Изменения ожидают синхронизации',
                style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (queueCount > 0) ...[
              // Бейдж с числом несинхронизированных операций
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$queueCount',
                    style: const TextStyle(
                        color: Color(0xFFF57C00),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
            ],
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
      ),
    );
  }
}

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

