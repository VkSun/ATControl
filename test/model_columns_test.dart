import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/driver.dart';
import 'package:atcontrol/models/invitation_code.dart';
import 'package:atcontrol/models/task.dart';
import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/models/vehicle.dart';

/// Кэш и офлайн-ветки теперь хранят суженные выборки: fromJson каждой
/// модели должен парситься из map, где есть ТОЛЬКО явно выбранные колонки.
Map<String, dynamic> rowWith(String columns, Map<String, dynamic> values) {
  final keys = columns.split(',').map((c) => c.trim()).toList();
  return {for (final k in keys) k: values[k]};
}

void main() {
  test('Vehicle.fromJson парсится из строки с явными колонками', () {
    final v = Vehicle.fromJson(rowWith(Vehicle.columns, {
      'id': 'v1',
      'inv_number': '100011',
      'brand': 'КАМАЗ',
      'model': '43118',
      'gov_number': 'А123ВС',
      'inspection_date': '2026-08-01',
      'to_period_months': 3,
    }));
    expect(v.invNumber, '100011');
    expect(v.inspectionDate, DateTime(2026, 8, 1));
    expect(v.toPeriodMonths, 3);
    expect(v.year, null);
  });

  test('Driver.fromJson парсится из строки с явными колонками', () {
    final d = Driver.fromJson(rowWith(Driver.columns, {
      'id': 'd1',
      'tab_number': '4501',
      'last_name': 'Иванов',
      'first_name': 'Иван',
      'vehicle_ids': ['v1', 'v2'],
    }));
    expect(d.tabNumber, '4501');
    expect(d.vehicleIds, ['v1', 'v2']);
    expect(d.medicalExpiry, null);
  });

  test('Task.fromJson парсится из колонок get_my_tasks', () {
    // Ровно то, что возвращает RPC get_my_tasks (RETURNS TABLE).
    const rpcColumns =
        'id, title, description, due_date, due_time, is_completed, '
        'priority, type, vehicle_id, driver_id';
    final t = Task.fromJson(rowWith(rpcColumns, {
      'id': 't1',
      'title': 'Заменить масло',
      'due_date': '2026-07-08',
      'due_time': '10:30:00',
      'is_completed': false,
    }));
    expect(t.title, 'Заменить масло');
    expect(t.dueDate, DateTime(2026, 7, 8));
    expect(t.priority, 'normal');
    expect(t.type, 'manual');
  });

  test('UserRole.fromJson парсится из строки с явными колонками', () {
    final r = UserRole.fromJson(rowWith(UserRole.columns, {
      'id': 'r1',
      'user_id': 'u1',
      'full_name': 'Иванов Иван',
      'is_admin': true,
    }));
    expect(r.isAdmin, true);
    expect(r.initials, 'ПП'); // null → нормализация
    expect(r.isActive, true);
  });

  test('InvitationCode.fromJson парсится из строки с явными колонками', () {
    final c = InvitationCode.fromJson(rowWith(InvitationCode.columns, {
      'id': 'i1',
      'code': 'AAAA-BBBB-CCCC',
      'created_at': '2026-07-08T10:00:00Z',
      'expires_at': '2026-07-15T10:00:00Z',
    }));
    expect(c.code, 'AAAA-BBBB-CCCC');
    expect(c.isUsed, false);
    expect(c.expiresAt, DateTime.utc(2026, 7, 15, 10));
  });
}
