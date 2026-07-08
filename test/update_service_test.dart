import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions', () {
    test('равные версии → 0', () {
      expect(UpdateService.compareVersions('1.2.3', '1.2.3'), 0);
      expect(UpdateService.compareVersions('0.0.0', '0.0.0'), 0);
    });

    test('больше по патчу/минору/мажору → >0', () {
      expect(UpdateService.compareVersions('1.2.4', '1.2.3'), greaterThan(0));
      expect(UpdateService.compareVersions('1.3.0', '1.2.9'), greaterThan(0));
      expect(UpdateService.compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('меньше → <0', () {
      expect(UpdateService.compareVersions('1.2.3', '1.2.4'), lessThan(0));
    });

    test('числовое сравнение компонентов, не лексикографическое', () {
      expect(UpdateService.compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    });

    test('недостающие компоненты считаются нулями', () {
      expect(UpdateService.compareVersions('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('нечисловые компоненты считаются нулями', () {
      expect(UpdateService.compareVersions('1.2.beta', '1.2.0'), 0);
    });
  });
}
