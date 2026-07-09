import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/utils/trailing_throttle.dart';

void main() {
  test('первый trigger вызывает onFire немедленно', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger();

      expect(calls, 1);
      t.dispose();
    });
  });

  test('повторные trigger в течение окна не вызывают onFire сразу — не чаще '
      'раза в window', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger();
      async.elapse(const Duration(milliseconds: 500));
      t.trigger(); // в окне — отложится
      async.elapse(const Duration(milliseconds: 500));
      t.trigger(); // тоже в окне — не добавляет новый вызов

      expect(calls, 1);
      t.dispose();
    });
  });

  test('изменение внутри окна не теряется — финальный вызов на границе '
      'окна', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger(); // немедленный вызов, calls = 1
      async.elapse(const Duration(milliseconds: 500));
      t.trigger(); // в окне — запланирован финальный вызов
      async.elapse(const Duration(milliseconds: 1500)); // граница окна (2с от старта)

      expect(calls, 2);
      t.dispose();
    });
  });

  test('без повторных trigger внутри окна финальный вызов не происходит',
      () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger();
      async.elapse(const Duration(seconds: 3)); // окно истекло, новых событий не было

      expect(calls, 1);
      t.dispose();
    });
  });

  test('trigger сразу после окончания окна снова вызывает onFire '
      'немедленно', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger();
      async.elapse(const Duration(seconds: 2, milliseconds: 1));
      t.trigger();

      expect(calls, 2);
      t.dispose();
    });
  });

  test('dispose останавливает отложенный финальный вызов', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger();
      async.elapse(const Duration(milliseconds: 500));
      t.trigger(); // отложен на границу окна
      t.dispose();
      async.elapse(const Duration(seconds: 5));

      expect(calls, 1); // финальный вызов не состоялся
    });
  });

  test('dispose после dispose безопасен (idempotent)', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.trigger();
      t.dispose();
      expect(() => t.dispose(), returnsNormally);
      expect(calls, 1);
    });
  });

  test('trigger после dispose не вызывает onFire', () {
    fakeAsync((async) {
      var calls = 0;
      final t = TrailingThrottle(
          onFire: () => calls++, window: const Duration(seconds: 2));

      t.dispose();
      t.trigger();
      async.elapse(const Duration(seconds: 5));

      expect(calls, 0);
    });
  });
}
