import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/driver.dart';
import 'package:atcontrol/models/task.dart';
import 'package:atcontrol/models/vehicle.dart';
import 'package:atcontrol/screens/home/home_screen.dart';
import 'package:atcontrol/services/auth_service.dart';
import 'package:atcontrol/services/driver_service.dart';
import 'package:atcontrol/services/task_service.dart';
import 'package:atcontrol/services/vehicle_service.dart';

import 'helpers.dart';

void main() {
  testWidgets('сводка: истекающие сроки и задачи из мокнутых провайдеров',
      (tester) async {
    await pumpApp(tester, const Scaffold(body: HomeScreen()), overrides: [
      vehiclesProvider.overrideWith((ref) async => [vehicleFixture()]),
      driversProvider.overrideWith((ref) async => [driverFixture()]),
      tasksProvider.overrideWith((ref) async => [taskFixture()]),
      currentUserRoleProvider.overrideWith((ref) async => adminRole()),
    ]);

    // Истекающие сроки: ТС с гос. номером в подзаголовке и водитель.
    expect(find.text('Истекающие сроки'), findsOneWidget);
    expect(find.text('МАЗ 631228'), findsOneWidget);
    expect(find.text('Техосмотр · ВВ0312-5'), findsOneWidget);
    expect(find.text('Иванов Иван'), findsOneWidget);
    expect(find.text('Мед. справка'), findsOneWidget);

    // Задачи на сегодня.
    expect(find.text('Задачи на сегодня и завтра'), findsOneWidget);
    expect(find.text('Заменить масло'), findsOneWidget);
  });

  testWidgets('loading: спиннер, пока данные не загружены', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: HomeScreen()),
      settle: false, // вечный loading — pumpAndSettle не завершится
      overrides: [
        vehiclesProvider
            .overrideWith((ref) => Completer<List<Vehicle>>().future),
        driversProvider.overrideWith((ref) => Completer<List<Driver>>().future),
        tasksProvider.overrideWith((ref) => Completer<List<Task>>().future),
        currentUserRoleProvider.overrideWith((ref) async => adminRole()),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Нет истекающих сроков'), findsNothing);
  });

  testWidgets('error: ошибка задач видна с кнопкой «Повторить»',
      (tester) async {
    await pumpApp(tester, const Scaffold(body: HomeScreen()), overrides: [
      vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
      driversProvider.overrideWith((ref) async => <Driver>[]),
      tasksProvider
          .overrideWith((ref) async => throw Exception('нет соединения')),
      currentUserRoleProvider.overrideWith((ref) async => adminRole()),
    ]);

    expect(find.textContaining('нет соединения'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Повторить'), findsOneWidget);
  });

  testWidgets('пустой список задач: кнопка «Добавить задачу» при праве записи',
      (tester) async {
    await pumpApp(tester, const Scaffold(body: HomeScreen()), overrides: [
      vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
      driversProvider.overrideWith((ref) async => <Driver>[]),
      tasksProvider.overrideWith((ref) async => <Task>[]),
      currentUserRoleProvider.overrideWith((ref) async => adminRole()),
    ]);

    expect(find.text('Задач на сегодня и завтра нет'), findsOneWidget);
    expect(find.text('Добавить задачу'), findsOneWidget);
  });

  testWidgets('пустой список задач: без права записи кнопки нет',
      (tester) async {
    await pumpApp(tester, const Scaffold(body: HomeScreen()), overrides: [
      vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
      driversProvider.overrideWith((ref) async => <Driver>[]),
      tasksProvider.overrideWith((ref) async => <Task>[]),
      currentUserRoleProvider.overrideWith((ref) async => readOnlyRole()),
    ]);

    expect(find.text('Задач на сегодня и завтра нет'), findsOneWidget);
    expect(find.text('Добавить задачу'), findsNothing);
  });
}
