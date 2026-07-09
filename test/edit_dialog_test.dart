import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/department.dart';
import 'package:atcontrol/models/driver.dart';
import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/models/vehicle.dart';
import 'package:atcontrol/screens/drivers/driver_edit_dialog.dart';
import 'package:atcontrol/screens/transport/vehicle_edit_dialog.dart';
import 'package:atcontrol/screens/users/providers.dart';
import 'package:atcontrol/screens/users/users_tab.dart';
import 'package:atcontrol/services/department_service.dart';
import 'package:atcontrol/services/driver_service.dart';
import 'package:atcontrol/services/vehicle_service.dart';
import 'package:atcontrol/utils/theme.dart';

// Фейки перехватывают вызовы вместо Supabase.
class FakeVehicleService extends VehicleService {
  final updated = <String>[];
  final deleted = <String>[];

  @override
  Future<Vehicle> update(String id, Vehicle v) async {
    updated.add(id);
    return v;
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

class FakeDriverService extends DriverService {
  final deleted = <String>[];

  @override
  Future<List<Driver>> getAll({String? departmentId, String? sectionId}) async => [];

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

final maz = Vehicle(
  id: 'v1', invNumber: '631228', brand: 'МАЗ', model: '631228 А',
  govNumber: 'ВВ0312-5',
);

final ivanov = Driver(
  id: 'd1', tabNumber: '4501', lastName: 'Иванов', firstName: 'Иван',
);

Future<(FakeVehicleService, FakeDriverService)> pumpDialog(
  WidgetTester tester,
  Size size,
  Widget Function() dialog, {
  VoidCallback? onSaved,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final vs = FakeVehicleService();
  final ds = FakeDriverService();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      vehicleServiceProvider.overrideWithValue(vs),
      driverServiceProvider.overrideWithValue(ds),
      vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
      departmentsProvider.overrideWith((ref) async => <Department>[]),
      sectionsProvider.overrideWith((ref) async => <Section>[]),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => showDialog(context: ctx, builder: (_) => dialog()),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (vs, ds);
}

void main() {
  group('телефон (isPhone)', () {
    testWidgets('транспорт: full-screen форма, ✕/Сохранить в AppBar, удаление через ⋮',
        (tester) async {
      var saved = false;
      final (vs, _) = await pumpDialog(
        tester,
        const Size(400, 800),
        () => VehicleEditDialog(vehicle: maz, onSaved: () => saved = true),
      );

      // full-screen: AppBar с ✕ и «Сохранить», ряда Отмена/Удалить нет
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Сохранить'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Отмена'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Удалить'), findsNothing);

      // удаление: ⋮ → Удалить → подтверждение с идентификацией записи
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить МАЗ 631228 А (ВВ0312-5)?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pumpAndSettle();

      expect(vs.deleted, ['v1']);
      expect(saved, true);
      expect(find.byType(AppBar), findsNothing); // форма закрылась
    });

    testWidgets('водитель: full-screen, удаление через ⋮ с ФИО в вопросе',
        (tester) async {
      final (_, ds) = await pumpDialog(
        tester,
        const Size(400, 800),
        () => DriverEditDialog(driver: ivanov, onSaved: () {}),
      );

      expect(find.byType(AppBar), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить Иванов Иван?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pumpAndSettle();
      expect(ds.deleted, ['d1']);
    });
  });

  group('Windows/планшет', () {
    testWidgets('транспорт: AlertDialog, Отмена/Сохранить, удаление только в ⋮',
        (tester) async {
      var saved = false;
      final (vs, _) = await pumpDialog(
        tester,
        const Size(1280, 800),
        () => VehicleEditDialog(vehicle: maz, onSaved: () => saved = true),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.widgetWithText(TextButton, 'Отмена'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Сохранить'), findsOneWidget);
      // «Удалить» больше не стоит в ряду кнопок
      expect(find.text('Удалить'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // сохранение работает как раньше (подтверждение → update → закрытие)
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить изменения?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить').last);
      await tester.pumpAndSettle();
      expect(vs.updated, ['v1']);
      expect(saved, true);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('транспорт: удаление через ⋮ и подтверждение', (tester) async {
      final (vs, _) = await pumpDialog(
        tester,
        const Size(1280, 800),
        () => VehicleEditDialog(vehicle: maz, onSaved: () {}),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить МАЗ 631228 А (ВВ0312-5)?'), findsOneWidget);
      // Отмена не удаляет
      await tester.tap(find.widgetWithText(TextButton, 'Отмена').last);
      await tester.pumpAndSettle();
      expect(vs.deleted, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget); // форма осталась
    });
  });

  testWidgets('блокировка пользователя — подтверждение с ФИО', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final user = UserRole(
      id: 'r1', userId: 'u1', fullName: 'Иван Иванович', initials: 'ИИ',
      avatarColor: '#4361EE', isAdmin: false, permFullAccess: false,
      permEdit: false, permExecute: false, permRead: true, permWrite: false,
      permOwnOnly: false, isActive: true,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        usersProvider.overrideWith((ref) async => [user]),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => UsersTab(
              colors: AppTheme.lightTheme.extension<AppColors>()!,
              ref: ref,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.block_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Заблокировать Иван Иванович?'), findsOneWidget);
    // Отмена ничего не меняет
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
