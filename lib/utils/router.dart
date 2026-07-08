import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/transport/transport_screen.dart';
import '../screens/drivers/drivers_screen.dart';
import '../screens/planner/planner_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/users/users_screen.dart';
import '../services/auth_service.dart';
import '../services/vehicle_service.dart';
import '../widgets/main_layout.dart';
import '../screens/auth/invite_screen.dart';

/// Пробрасывает события Stream в Listenable для GoRouter.refreshListenable.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Чистое решение о редиректе — без побочных эффектов.
@visibleForTesting
String? redirectFor({required bool isLoggedIn, required String location}) {
  final isAuthRoute =
      location == '/login' || location == '/register' || location == '/invite';

  if (!isLoggedIn && !isAuthRoute) return '/login';
  if (isLoggedIn && isAuthRoute) return '/';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Выход заблокированного пользователя — побочный эффект, поэтому не в
  // redirect: как только роль загружается с is_active == false, разлогиниваем;
  // signOut даёт событие в onAuthStateChange → refreshListenable → redirect
  // уводит на /login с любого экрана.
  ref.listen(currentUserRoleProvider, (previous, next) {
    final role = next.value;
    if (role != null && !role.isActive) {
      supabase.auth.signOut();
    }
  });

  // GoRouter создаётся один раз (никаких ref.watch — навигационный стек
  // не теряется); на смену auth-состояния реагирует refreshListenable.
  final refresh = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      isLoggedIn: supabase.auth.currentSession != null,
      location: state.uri.toString(),
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (c, s) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/invite',
        builder: (c, s) => const InviteScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/transport', builder: (c, s) => const TransportScreen()),
          GoRoute(path: '/drivers', builder: (c, s) => const DriversScreen()),
          GoRoute(path: '/planner', builder: (c, s) => const PlannerScreen()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
          GoRoute(path: '/users', builder: (c, s) => const UsersScreen()),
        ],
      ),
    ],
  );
});
