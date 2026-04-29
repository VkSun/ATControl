import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/transport/transport_screen.dart';
import '../screens/drivers/drivers_screen.dart';
import '../screens/planner/planner_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../widgets/main_layout.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/transport', builder: (c, s) => const TransportScreen()),
          GoRoute(path: '/drivers', builder: (c, s) => const DriversScreen()),
          GoRoute(path: '/planner', builder: (c, s) => const PlannerScreen()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
  );
});