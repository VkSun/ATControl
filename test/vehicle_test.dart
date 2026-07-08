import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/vehicle.dart';

Vehicle vehicle({
  DateTime? toDate,
  int? toPeriodMonths,
  int? toMileage,
  int? toPeriodKm,
  DateTime? equipmentToDate,
  int? equipmentToPeriodMonths,
  int? equipmentHours,
  int? equipmentToPeriodHours,
}) =>
    Vehicle(
      id: 'v1',
      invNumber: '100011',
      brand: 'КАМАЗ',
      model: '43118',
      govNumber: 'А123ВС',
      toDate: toDate,
      toPeriodMonths: toPeriodMonths,
      toMileage: toMileage,
      toPeriodKm: toPeriodKm,
      equipmentToDate: equipmentToDate,
      equipmentToPeriodMonths: equipmentToPeriodMonths,
      equipmentHours: equipmentHours,
      equipmentToPeriodHours: equipmentToPeriodHours,
    );

void main() {
  group('nextToDate', () {
    test('null без даты последнего ТО или периода', () {
      expect(vehicle(toPeriodMonths: 3).nextToDate, null);
      expect(vehicle(toDate: DateTime(2026, 1, 15)).nextToDate, null);
    });

    test('прибавляет период в месяцах', () {
      expect(
        vehicle(toDate: DateTime(2026, 1, 15), toPeriodMonths: 2).nextToDate,
        DateTime(2026, 3, 15),
      );
    });

    test('переход через год', () {
      expect(
        vehicle(toDate: DateTime(2026, 11, 10), toPeriodMonths: 3).nextToDate,
        DateTime(2027, 2, 10),
      );
    });

    test('граница: 31 января + 1 мес. переносится DateTime-нормализацией', () {
      // В феврале 2026 (не високосный) нет 31-го: DateTime(2026, 2, 31)
      // нормализуется в 3 марта. Фиксируем текущее поведение.
      expect(
        vehicle(toDate: DateTime(2026, 1, 31), toPeriodMonths: 1).nextToDate,
        DateTime(2026, 3, 3),
      );
      // Високосный 2028: 31 января + 1 мес. → 2 марта (29 дней в феврале).
      expect(
        vehicle(toDate: DateTime(2028, 1, 31), toPeriodMonths: 1).nextToDate,
        DateTime(2028, 3, 2),
      );
    });
  });

  group('nextEquipmentToDate', () {
    test('null без даты или периода', () {
      expect(vehicle(equipmentToPeriodMonths: 6).nextEquipmentToDate, null);
      expect(
          vehicle(equipmentToDate: DateTime(2026, 5, 1)).nextEquipmentToDate,
          null);
    });

    test('прибавляет период, та же граница конца месяца', () {
      expect(
        vehicle(
          equipmentToDate: DateTime(2026, 5, 1),
          equipmentToPeriodMonths: 6,
        ).nextEquipmentToDate,
        DateTime(2026, 11, 1),
      );
      expect(
        vehicle(
          equipmentToDate: DateTime(2026, 1, 31),
          equipmentToPeriodMonths: 1,
        ).nextEquipmentToDate,
        DateTime(2026, 3, 3),
      );
    });
  });

  group('пробег и моточасы следующего ТО', () {
    test('nextToMileage', () {
      expect(vehicle(toMileage: 150000, toPeriodKm: 10000).nextToMileage,
          160000);
      expect(vehicle(toMileage: 150000).nextToMileage, null);
    });

    test('nextEquipmentToHours', () {
      expect(
          vehicle(equipmentHours: 500, equipmentToPeriodHours: 250)
              .nextEquipmentToHours,
          750);
      expect(vehicle(equipmentToPeriodHours: 250).nextEquipmentToHours, null);
    });
  });

  group('dateStatus (дополнение к date_utils_test)', () {
    // Пороговые значения относительно сегодняшнего дня.
    DateTime inDays(int days) => DateTime.now().add(Duration(days: days));

    test('null → 0 (нет даты)', () {
      expect(Vehicle.dateStatus(null), 0);
    });

    test('просрочено → 4', () {
      expect(Vehicle.dateStatus(inDays(-1)), 4);
    });

    test('границы 7/14/30 дней', () {
      expect(Vehicle.dateStatus(inDays(0)), 3);
      expect(Vehicle.dateStatus(inDays(7)), 3);
      expect(Vehicle.dateStatus(inDays(8)), 2);
      expect(Vehicle.dateStatus(inDays(14)), 2);
      expect(Vehicle.dateStatus(inDays(15)), 1);
      expect(Vehicle.dateStatus(inDays(30)), 1);
      expect(Vehicle.dateStatus(inDays(31)), 0);
    });
  });
}
