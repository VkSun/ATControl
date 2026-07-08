import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/driver.dart';
import 'package:atcontrol/models/user_role.dart';

// Историческая AuthService._getInitials переехала на сервер
// (SQL _compute_initials в redeem_invitation) и может вернуть пустую строку.
// На клиенте пустые инициалы нормализуются в UserRole.fromJson → 'ПП'.

Map<String, dynamic> roleJson({Object? initials}) => {
      'id': 'r1',
      'user_id': 'u1',
      'full_name': 'Иванов Иван',
      'initials': initials,
    };

Driver driver({String firstName = 'Иван', String? middleName}) => Driver(
      id: 'd1',
      tabNumber: '4501',
      lastName: 'Иванов',
      firstName: firstName,
      middleName: middleName,
      vehicleIds: const [],
    );

void main() {
  group('UserRole.fromJson initials', () {
    test('обычные инициалы сохраняются', () {
      expect(UserRole.fromJson(roleJson(initials: 'ИИ')).initials, 'ИИ');
    });

    test('null → ПП', () {
      expect(UserRole.fromJson(roleJson(initials: null)).initials, 'ПП');
    });

    test('пустая строка → ПП (RangeError-кейс исторической _getInitials)', () {
      expect(UserRole.fromJson(roleJson(initials: '')).initials, 'ПП');
    });

    test('пробелы → ПП', () {
      expect(UserRole.fromJson(roleJson(initials: '  ')).initials, 'ПП');
    });
  });

  group('Driver.shortName', () {
    test('полное ФИО', () {
      expect(driver(middleName: 'Петрович').shortName, 'Иванов И.П.');
    });

    test('без отчества', () {
      expect(driver().shortName, 'Иванов И.');
    });

    test('пустое имя не вызывает RangeError', () {
      expect(driver(firstName: '').shortName, 'Иванов');
      expect(driver(firstName: '', middleName: 'Петрович').shortName,
          'Иванов П.');
    });

    test('пустое отчество не вызывает RangeError', () {
      expect(driver(middleName: '').shortName, 'Иванов И.');
    });
  });
}
