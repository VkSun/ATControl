import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atcontrol/models/driver.dart';
import 'package:atcontrol/models/task.dart';
import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/models/vehicle.dart';
import 'package:atcontrol/utils/theme.dart';

/// Общий каркас widget-тестов: ProviderScope + MaterialApp с локализацией ru
/// (как в main.dart, но без роутера и Supabase — данные через overrides).
///
/// settle: false — для экранов с вечным loading, где pumpAndSettle не
/// завершится (спиннер анимируется бесконечно).
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
  Size size = const Size(400, 800),
  bool settle = true,
}) async {
  await initializeDateFormatting('ru', null);
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('ru'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ru')],
      home: home,
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Телефон (портрет) и десктоп — размеры, используемые в тестах раскладок.
const phoneSize = Size(400, 800);
const desktopSize = Size(1280, 800);

// ─── Фикстуры ────────────────────────────────────────────────────────────────

UserRole role({
  String id = 'r1',
  String fullName = 'Петров Пётр',
  bool isAdmin = false,
  bool fullAccess = false,
  bool edit = false,
  bool execute = false,
  bool read = true,
  bool write = false,
  bool isActive = true,
}) =>
    UserRole(
      id: id,
      userId: 'u-$id',
      fullName: fullName,
      position: 'Механик',
      initials: 'ПП',
      avatarColor: '#4361EE',
      isAdmin: isAdmin,
      permFullAccess: fullAccess,
      permEdit: edit,
      permExecute: execute,
      permRead: read,
      permWrite: write,
      permOwnOnly: false,
      isActive: isActive,
    );

UserRole adminRole() => role(
    id: 'r-admin',
    fullName: 'Админ Админов',
    isAdmin: true,
    fullAccess: true,
    edit: true,
    execute: true,
    write: true);

/// Только чтение: без записи, изменения и полного доступа.
UserRole readOnlyRole() => role(id: 'r-read', fullName: 'Читатель Чтецов');

Vehicle vehicleFixture({String id = 'v1', int? daysToInspection = 5}) =>
    Vehicle(
      id: id,
      invNumber: '770589',
      brand: 'МАЗ',
      model: '631228',
      govNumber: 'ВВ0312-5',
      inspectionDate: daysToInspection != null
          ? DateTime.now().add(Duration(days: daysToInspection))
          : null,
    );

Driver driverFixture({String id = 'd1', int? daysToMedical = 10}) => Driver(
      id: id,
      tabNumber: '4501',
      lastName: 'Иванов',
      firstName: 'Иван',
      medicalExpiry: daysToMedical != null
          ? DateTime.now().add(Duration(days: daysToMedical))
          : null,
    );

Task taskFixture({String id = 't1', String title = 'Заменить масло'}) => Task(
      id: id,
      title: title,
      dueDate: DateTime.now(),
    );
