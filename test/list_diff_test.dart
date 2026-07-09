import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/utils/list_diff.dart';

void main() {
  group('listsDiffer', () {
    test('одинаковые списки (тот же порядок) — не отличаются', () {
      expect(listsDiffer(['a', 'b'], ['a', 'b']), false);
    });

    test('одинаковые элементы, другой порядок — не отличаются', () {
      expect(listsDiffer(['a', 'b'], ['b', 'a']), false);
    });

    test('оба пустые — не отличаются', () {
      expect(listsDiffer([], []), false);
    });

    test('добавлен элемент — отличаются', () {
      expect(listsDiffer(['a'], ['a', 'b']), true);
    });

    test('удалён элемент — отличаются', () {
      expect(listsDiffer(['a', 'b'], ['a']), true);
    });

    test('элемент заменён на другой — отличаются', () {
      expect(listsDiffer(['a'], ['b']), true);
    });
  });

  group('mergeListDiff', () {
    test('ничего не поменяли — результат равен fresh', () {
      final result = mergeListDiff(
        original: ['v1', 'v2'],
        current: ['v1', 'v2'],
        fresh: ['v1', 'v2', 'v3'], // кто-то добавил v3 параллельно
      );
      expect(result.toSet(), {'v1', 'v2', 'v3'});
    });

    test('добавление применяется поверх fresh, а не поверх original', () {
      // Пользователь открыл форму с [v1], добавил v2. Пока форма была
      // открыта, из другого места добавили v3 (сервер теперь [v1, v3]).
      final result = mergeListDiff(
        original: ['v1'],
        current: ['v1', 'v2'],
        fresh: ['v1', 'v3'],
      );
      // Ожидаем v1 (не трогали), v2 (наше добавление), v3 (чужое, не потеряно).
      expect(result.toSet(), {'v1', 'v2', 'v3'});
    });

    test('удаление применяется поверх fresh, а не поверх original', () {
      // Пользователь открыл форму с [v1, v2], убрал v2. Параллельно
      // добавили v3 (сервер теперь [v1, v2, v3]).
      final result = mergeListDiff(
        original: ['v1', 'v2'],
        current: ['v1'],
        fresh: ['v1', 'v2', 'v3'],
      );
      // v2 — наше удаление, применяется; v3 — чужое добавление, сохраняется.
      expect(result.toSet(), {'v1', 'v3'});
    });

    test('добавление и удаление одновременно', () {
      final result = mergeListDiff(
        original: ['v1', 'v2'],
        current: ['v1', 'v3'], // убрали v2, добавили v3
        fresh: ['v1', 'v2', 'v4'], // параллельно добавили v4
      );
      expect(result.toSet(), {'v1', 'v3', 'v4'});
    });

    test('чужое удаление того же элемента, который добавляем — элемент остаётся', () {
      // Мы добавляем v2; на сервере его уже нет (никогда не было или
      // кто-то убрал) — наше добавление побеждает.
      final result = mergeListDiff(
        original: ['v1'],
        current: ['v1', 'v2'],
        fresh: ['v1'],
      );
      expect(result.toSet(), {'v1', 'v2'});
    });

    test('пустой original и current — fresh остаётся как есть', () {
      final result = mergeListDiff(original: [], current: [], fresh: ['v9']);
      expect(result.toSet(), {'v9'});
    });
  });
}
