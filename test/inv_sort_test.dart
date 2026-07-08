import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/utils/inv_sort.dart';

void main() {
  test('числовые инвентарные номера сортируются по значению', () {
    final nums = ['1000', '100011', '1059', '109002', '1097']
      ..sort(compareInvNumbers);
    expect(nums, ['1000', '1059', '1097', '100011', '109002']);
  });

  test('нечисловые номера уходят в конец по алфавиту', () {
    final nums = ['Б-2', '1000', 'А-1', '25']..sort(compareInvNumbers);
    expect(nums, ['25', '1000', 'А-1', 'Б-2']);
  });

  test('равные значения дают 0', () {
    expect(compareInvNumbers('0042', '42'), 0);
    expect(compareInvNumbers('А-1', 'А-1'), 0);
  });
}
