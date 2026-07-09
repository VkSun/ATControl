import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/screens/auth/login_screen.dart';
import 'package:atcontrol/services/auth_service.dart';

import 'helpers.dart';

/// Мок: фиксирует вызовы signIn, не ходит в Supabase.
class FakeAuthService extends AuthService {
  int signInCalls = 0;
  String? lastEmail;
  String? lastPassword;
  Object? throwOnSignIn;

  @override
  Future<UserRole?> signIn(
      {required String email, required String password}) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;
    if (throwOnSignIn != null) throw throwOnSignIn!;
    return adminRole();
  }
}

void main() {
  testWidgets('пустые поля: ошибка валидации, сервис не вызывается',
      (tester) async {
    final auth = FakeAuthService();
    await pumpApp(tester, const LoginScreen(), overrides: [
      authServiceProvider.overrideWithValue(auth),
    ]);

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Заполните все поля'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('заполненные поля: сабмит вызывает AuthService.signIn',
      (tester) async {
    final auth = FakeAuthService();
    await pumpApp(tester, const LoginScreen(), overrides: [
      authServiceProvider.overrideWithValue(auth),
    ]);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), ' user@test.ru ');
    await tester.enterText(
        find.widgetWithText(TextField, 'Пароль'), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(auth.lastEmail, 'user@test.ru'); // email обрезается
    expect(auth.lastPassword, 'secret1'); // пароль — как введён
    expect(find.text('Заполните все поля'), findsNothing);
  });

  testWidgets('ошибка сервиса показывается на форме', (tester) async {
    final auth = FakeAuthService()
      ..throwOnSignIn = Exception('Неверный логин или пароль');
    await pumpApp(tester, const LoginScreen(), overrides: [
      authServiceProvider.overrideWithValue(auth),
    ]);

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'user@test.ru');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'x');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный логин или пароль'), findsOneWidget);
  });
}
