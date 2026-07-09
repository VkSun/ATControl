import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atcontrol/models/department.dart';
import 'package:atcontrol/models/profile.dart';
import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/models/vehicle.dart';
import 'package:atcontrol/screens/transport/transport_screen.dart';
import 'package:atcontrol/services/auth_service.dart';
import 'package:atcontrol/services/department_service.dart';
import 'package:atcontrol/services/profile_service.dart';
import 'package:atcontrol/services/vehicle_service.dart';
import 'package:atcontrol/services/weather_service.dart';
import 'package:atcontrol/utils/theme.dart';
import 'package:atcontrol/widgets/sidebar.dart';

UserRole adminRole() => UserRole(
      id: 'r1', userId: 'u1', fullName: 'Админ Админов', initials: 'АА',
      avatarColor: '#4361EE', isAdmin: true, permFullAccess: true,
      permEdit: true, permExecute: true, permRead: true, permWrite: true,
      permOwnOnly: false, isActive: true,
    );

Vehicle vehicle(int i) => Vehicle(
      id: 'v$i', invNumber: (100000 + i).toString(), brand: 'КАМАЗ', model: '43118',
      govNumber: 'А$iБВ', inspectionDate: DateTime(2026, 8, 1),
      toDate: DateTime(2026, 5, 1), toPeriodMonths: 3, toMileage: 10000,
      toPeriodKm: 10000,
    );

List<Override> overrides() => [
      vehiclesProvider.overrideWith((ref) async => List.generate(200, vehicle)),
      currentUserRoleProvider.overrideWith((ref) async => adminRole()),
      departmentsProvider.overrideWith((ref) async => <Department>[]),
      sectionsProvider.overrideWith((ref) async => <Section>[]),
      weatherProvider.overrideWith((ref) async =>
          WeatherData(temp: 21, description: 'ясно', icon: '☀️')),
      profileProvider.overrideWith((ref) async => Profile(
          id: 'u1', fullName: 'Админ Админов', position: 'Механик',
          initials: 'АА', avatarColor: '#4361EE')),
      pendingCountProvider.overrideWith((ref) async => 2),
    ];

/// Сайдбар держит таймеры (часы 1с, проверка сети 30с + 5с timeout у
/// DNS-запроса) — в конце теста сносим дерево и доводим тестовые часы.
Future<void> disposeSidebarTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 31));
}

Future<void> pumpApp(WidgetTester tester, Size size, Widget home) async {
  await initializeDateFormatting('ru', null);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(),
    child: MaterialApp(theme: AppTheme.lightTheme, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('таблица транспорта (десктоп)', () {
    for (final (size, minRows) in [(const Size(1920, 1080), 15), (const Size(1280, 700), 8)]) {
      testWidgets('строки 52px, без полосы после шапки (${size.height.toInt()}px)',
          (tester) async {
        await pumpApp(tester, size, const Scaffold(body: TransportScreen()));

        final r1 = tester.getRect(find.text('100000'));
        final r2 = tester.getRect(find.text('100001'));
        // фиксированный шаг строки 52 (48–56)
        expect(r2.top - r1.top, 52.0);
        // первая строка начинается сразу под шапкой (граница + центровка текста)
        final header = tester.getRect(find.text('Инв. номер'));
        expect(r1.top - header.bottom, lessThan(32));
        // ленивый список показывает достаточно записей
        final visible = find.textContaining(RegExp(r'^1000')).evaluate().length;
        expect(visible, greaterThanOrEqualTo(minRows),
            reason: 'видно $visible строк на ${size.height.toInt()}px');
      });
    }

    testWidgets('900x420 — мобильная раскладка (не десктоп), без ошибок',
        (tester) async {
      await pumpApp(
          tester, const Size(900, 420), const Scaffold(body: TransportScreen()));
      // мобильный признак: FAB добавления вместо десктопного топбара
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Инв. номер'), findsNothing);
    });
  });

  group('сайдбар (десктоп)', () {
    Widget sidebar() => Scaffold(
          body: Row(children: [
            SizedBox(
              width: 220,
              child: Sidebar(
                colors: AppTheme.lightTheme.extension<AppColors>()!,
                currentLocation: '/',
                collapsed: false,
                onToggleCollapse: () {},
              ),
            ),
            const Expanded(child: SizedBox()),
          ]),
        );

    testWidgets('1080px: полный блок — дата и описание погоды видны',
        (tester) async {
      await pumpApp(tester, const Size(1920, 1080), sidebar());
      expect(find.textContaining('°C • ясно'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Админ Админов'), findsOneWidget); // профиль закреплён
      expect(find.byType(ListView), findsWidgets); // меню в скролле
      await disposeSidebarTimers(tester);
    });

    testWidgets('620px: компактный блок — одна строка время+температура',
        (tester) async {
      await pumpApp(tester, const Size(1280, 620), sidebar());
      // компакт: температура без описания, даты нет
      expect(find.textContaining('☀️ 21°C'), findsOneWidget);
      expect(find.textContaining('ясно'), findsNothing);
      // все пункты меню и профиль доступны, ничего не перекрыто
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Админ Админов'), findsOneWidget);
      final profile = tester.getRect(find.text('Админ Админов'));
      final lastItem = tester.getRect(find.text('Настройки'));
      expect(lastItem.bottom, lessThanOrEqualTo(profile.top),
          reason: 'пункты меню не перекрываются профилем');
      await disposeSidebarTimers(tester);
    });

    testWidgets('тумблера темы в сайдбаре больше нет', (tester) async {
      await pumpApp(tester, const Size(1920, 1080), sidebar());
      expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);
      expect(find.byIcon(Icons.nightlight_round), findsNothing);
      await disposeSidebarTimers(tester);
    });
  });
}
