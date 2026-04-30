import 'package:flutter/material.dart';
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
import '../widgets/main_layout.dart';
import '../screens/auth/invite_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isAuthRoute = state.uri.toString() == '/login' ||
          state.uri.toString() == '/register' ||
          state.uri.toString() == '/invite';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
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