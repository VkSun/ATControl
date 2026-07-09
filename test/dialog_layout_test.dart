import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/department.dart';
import 'package:atcontrol/models/driver.dart';
import 'package:atcontrol/models/profile.dart';
import 'package:atcontrol/models/vehicle.dart';
import 'package:atcontrol/screens/drivers/driver_edit_dialog.dart';
import 'package:atcontrol/screens/profile/profile_dialog.dart';
import 'package:atcontrol/screens/settings/department_editor.dart';
import 'package:atcontrol/screens/settings/import_dialog.dart';
import 'package:atcontrol/screens/transport/vehicle_edit_dialog.dart';
import 'package:atcontrol/services/department_service.dart';
import 'package:atcontrol/services/driver_service.dart';
import 'package:atcontrol/services/profile_service.dart';
import 'package:atcontrol/services/vehicle_service.dart';
import 'package:atcontrol/utils/theme.dart';
import 'package:atcontrol/widgets/dialog_scroll_content.dart';

// Телефон в альбомной ориентации / маленькое окно Windows.
const shortScreen = Size(800, 400);
const normalScreen = Size(1280, 720);

class _FakeProfileService implements ProfileService {
  @override
  Future<Profile?> get() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeDepartmentService implements DepartmentService {
  @override
  Future<List<Department>> getDepartments() async => [];

  @override
  Future<List<Section>> getSections({String? departmentId}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

List<Override> _overrides() => [
      vehiclesProvider.overrideWith((ref) async => <Vehicle>[]),
      driversProvider.overrideWith((ref) async => <Driver>[]),
      departmentsProvider.overrideWith((ref) async => <Department>[]),
      sectionsProvider.overrideWith((ref) async => <Section>[]),
      profileServiceProvider.overrideWithValue(_FakeProfileService()),
      departmentServiceProvider.overrideWithValue(_FakeDepartmentService()),
    ];

Future<void> pumpDialog(
  WidgetTester tester,
  Size size,
  WidgetBuilder dialogBuilder,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () =>
                  showDialog(context: ctx, builder: dialogBuilder),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Кнопка целиком видна на экране (не вытеснена контентом за край).
void expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(-0.01));
  expect(rect.bottom, lessThanOrEqualTo(size.height + 0.01));
}

void main() {
  for (final size in [shortScreen, normalScreen]) {
    final label = size == shortScreen ? '400px' : '720px';

    testWidgets('ProfileDialog: кнопки на экране, поля доступны ($label)',
        (tester) async {
      await pumpDialog(tester, size, (_) => const ProfileDialog());

      final save = find.widgetWithText(FilledButton, 'Сохранить');
      final signOut = find.widgetWithText(TextButton, 'Выйти из системы');
      expectOnScreen(tester, save, size);
      expectOnScreen(tester, signOut, size);

      // Поле "Инициалы" прокручивается в зону видимости и не перекрывается
      // рядом кнопок (исходный баг: кнопка ложилась поверх поля).
      final initials = find.text('Инициалы (2–3 символа)');
      await tester.ensureVisible(initials);
      await tester.pumpAndSettle();
      expect(tester.getRect(initials).bottom,
          lessThanOrEqualTo(tester.getRect(save).top + 0.01));
    });

    // На телефоне (shortestSide < 600) формы транспорта/водителя теперь
    // полноэкранные: «Сохранить» — TextButton в AppBar сверху.
    testWidgets('DriverEditDialog: кнопки на экране, поля доступны ($label)',
        (tester) async {
      await pumpDialog(
          tester, size, (_) => DriverEditDialog(onSaved: () {}));

      final phone = size.shortestSide < 600;
      final save = phone
          ? find.widgetWithText(TextButton, 'Сохранить')
          : find.widgetWithText(FilledButton, 'Сохранить');
      expectOnScreen(tester, save, size);

      // Верхнее поле "Фамилия": floating-подпись не должна обрезаться.
      await tester.tap(find.widgetWithText(TextFormField, 'Фамилия'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Фамилия')).top,
          greaterThanOrEqualTo(0));

      // Нижнее поле прокручивается в зону видимости.
      final notes = find.text('Заметки').last;
      await tester.ensureVisible(notes);
      await tester.pumpAndSettle();
      expectOnScreen(tester, notes, size);
    });

    testWidgets('VehicleEditDialog: кнопки на экране, поля доступны ($label)',
        (tester) async {
      await pumpDialog(
          tester, size, (_) => VehicleEditDialog(onSaved: () {}));

      final phone = size.shortestSide < 600;
      final save = phone
          ? find.widgetWithText(TextButton, 'Сохранить')
          : find.widgetWithText(FilledButton, 'Сохранить');
      expectOnScreen(tester, save, size);

      final notes = find.text('Заметки').last;
      await tester.ensureVisible(notes);
      await tester.pumpAndSettle();
      expectOnScreen(tester, notes, size);
    });

    testWidgets('ImportDialog: кнопки на экране ($label)', (tester) async {
      await pumpDialog(tester, size, (_) => const ImportDialog());
      expectOnScreen(
          tester, find.widgetWithText(FilledButton, 'Анализировать'), size);
      expectOnScreen(
          tester, find.widgetWithText(TextButton, 'Отмена'), size);
    });

    testWidgets('DepartmentEditorDialog: помещается по высоте ($label)',
        (tester) async {
      await pumpDialog(tester, size, (_) => const DepartmentEditorDialog());
      final dialog = find.byType(Dialog);
      expectOnScreen(tester, dialog, size);
      expectOnScreen(tester, find.text('Структура предприятия'), size);
    });

    testWidgets(
        'DialogScrollContent: длинная форма — кнопки закреплены вне скролла ($label)',
        (tester) async {
      await pumpDialog(
        tester,
        size,
        (_) => AlertDialog(
          title: const Text('Форма'),
          content: DialogScrollContent(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 15; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Поле $i',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Отмена')),
            FilledButton(onPressed: () {}, child: const Text('ОК')),
          ],
        ),
      );

      final ok = find.widgetWithText(FilledButton, 'ОК');
      expectOnScreen(tester, ok, size);

      // Последнее поле прокручивается в зону видимости и не под кнопками.
      final lastField = find.text('Поле 14');
      await tester.ensureVisible(lastField);
      await tester.pumpAndSettle();
      expect(tester.getRect(lastField).bottom,
          lessThanOrEqualTo(tester.getRect(ok).top + 0.01));

      // Floating-подпись верхнего поля не обрезана краем области прокрутки.
      await tester.ensureVisible(find.text('Поле 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'Поле 0'));
      await tester.pumpAndSettle();
      final scrollable = tester.getRect(
          find.ancestor(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(ConstrainedBox)).first);
      expect(tester.getRect(find.text('Поле 0')).top,
          greaterThanOrEqualTo(scrollable.top - 0.01));
    });
  }

  testWidgets('ProfileDialog: клавиатура (viewInsets) не прячет кнопки',
      (tester) async {
    tester.view.physicalSize = shortScreen;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 150);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: TextButton(
                onPressed: () => showDialog(
                    context: ctx, builder: (_) => const ProfileDialog()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Кнопки видны над клавиатурой (250 = 400 - 150).
    final save = find.widgetWithText(FilledButton, 'Сохранить');
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(250.01));
  });
}
