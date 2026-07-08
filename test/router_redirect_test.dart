import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/utils/router.dart';

void main() {
  group('redirectFor', () {
    test('холодный старт без сессии → /login с любого маршрута', () {
      for (final loc in ['/', '/transport', '/drivers', '/planner', '/settings', '/users']) {
        expect(redirectFor(isLoggedIn: false, location: loc), '/login',
            reason: 'из $loc');
      }
    });

    test('без сессии auth-маршруты открываются без редиректа', () {
      for (final loc in ['/login', '/register', '/invite']) {
        expect(redirectFor(isLoggedIn: false, location: loc), null,
            reason: 'на $loc');
      }
    });

    test('логин: сессия появилась на /login → /', () {
      expect(redirectFor(isLoggedIn: true, location: '/login'), '/');
      expect(redirectFor(isLoggedIn: true, location: '/register'), '/');
      expect(redirectFor(isLoggedIn: true, location: '/invite'), '/');
    });

    test('залогинен на обычном маршруте — без редиректа', () {
      for (final loc in ['/', '/transport', '/planner']) {
        expect(redirectFor(isLoggedIn: true, location: loc), null,
            reason: 'на $loc');
      }
    });

    test('логаут (и выход заблокированного): сессии нет → /login отовсюду', () {
      // Заблокированный пользователь: ref.listen(currentUserRoleProvider)
      // вызывает signOut(), сессия исчезает, refreshListenable дёргает
      // redirect — дальше это тот же сценарий «нет сессии».
      for (final loc in ['/', '/settings', '/users']) {
        expect(redirectFor(isLoggedIn: false, location: loc), '/login',
            reason: 'из $loc');
      }
    });
  });
}
