import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/department.dart';
import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/screens/transport/transport_screen.dart';
import 'package:atcontrol/services/auth_service.dart';
import 'package:atcontrol/services/department_service.dart';
import 'package:atcontrol/services/vehicle_service.dart';

import 'helpers.dart';

List<Override> overridesFor(UserRole userRole) => [
      vehiclesProvider.overrideWith((ref) async => [vehicleFixture()]),
      departmentsProvider.overrideWith((ref) async => <Department>[]),
      sectionsProvider.overrideWith((ref) async => <Section>[]),
      currentUserRoleProvider.overrideWith((ref) async => userRole),
    ];

void main() {
  group('транспорт, телефон', () {
    testWidgets('админ видит FAB добавления', (tester) async {
      await pumpApp(tester, const TransportScreen(),
          overrides: overridesFor(adminRole()));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('read-only роль: FAB скрыт, строки не открывают форму',
        (tester) async {
      await pumpApp(tester, const TransportScreen(),
          overrides: overridesFor(readOnlyRole()));
      expect(find.byType(FloatingActionButton), findsNothing);

      // Тап по строке не открывает форму редактирования.
      await tester.tap(find.text('770589'));
      await tester.pumpAndSettle();
      expect(find.text('Редактировать транспорт'), findsNothing);
    });
  });

  group('транспорт, десктоп', () {
    testWidgets('админ видит «Добавить» и карандаш в строке', (tester) async {
      await pumpApp(tester, const Scaffold(body: TransportScreen()),
          size: desktopSize, overrides: overridesFor(adminRole()));
      expect(find.text('Добавить'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('read-only роль: ни «Добавить», ни карандаша',
        (tester) async {
      await pumpApp(tester, const Scaffold(body: TransportScreen()),
          size: desktopSize, overrides: overridesFor(readOnlyRole()));
      expect(find.text('Добавить'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      // Данные при этом видны.
      expect(find.text('770589'), findsOneWidget);
    });
  });
}
