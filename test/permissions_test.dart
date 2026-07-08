import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/models/user_role.dart';
import 'package:atcontrol/utils/permissions.dart';

UserRole role({
  bool isAdmin = false,
  bool fullAccess = false,
  bool edit = false,
  bool execute = false,
  bool read = false,
  bool write = false,
  bool ownOnly = false,
}) =>
    UserRole(
      id: 'r1',
      userId: 'u1',
      fullName: 'Тестовый Пользователь',
      initials: 'ТП',
      avatarColor: '#4361EE',
      isAdmin: isAdmin,
      permFullAccess: fullAccess,
      permEdit: edit,
      permExecute: execute,
      permRead: read,
      permWrite: write,
      permOwnOnly: ownOnly,
      isActive: true,
    );

void main() {
  group('роль ещё не загружена', () {
    test('null-роль: всё запрещено', () {
      const p = Permissions(null);
      expect(p.isAdmin, false);
      expect(p.canFullAccess, false);
      expect(p.canEdit, false);
      expect(p.canExecute, false);
      expect(p.canRead, false);
      expect(p.canWrite, false);
      expect(p.ownOnly, false);
      expect(p.canAddVehicle, false);
      expect(p.canDeleteVehicle, false);
      expect(p.canAddTask, false);
      expect(p.isLoading, false);
    });

    test('isLoading пробрасывается', () {
      const p = Permissions(null, isLoading: true);
      expect(p.isLoading, true);
      expect(p.canAddVehicle, false);
    });
  });

  group('матрица ролей', () {
    test('админ: всё разрешено, включая удаление', () {
      final p = Permissions(role(isAdmin: true));
      expect(p.isAdmin, true);
      expect(p.canFullAccess, true);
      expect(p.canEdit, true);
      expect(p.canExecute, true);
      expect(p.canRead, true);
      expect(p.canWrite, true);
      expect(p.ownOnly, false);
      expect(p.canAddVehicle, true);
      expect(p.canEditVehicle, true);
      expect(p.canDeleteVehicle, true);
      expect(p.canAddDriver, true);
      expect(p.canDeleteDriver, true);
      expect(p.canAddTask, true);
      expect(p.canCompleteTask, true);
      expect(p.canDeleteTask, true);
      expect(p.canEditNotes, true);
    });

    test('полный доступ: как админ, но удаление тоже разрешено', () {
      final p = Permissions(role(fullAccess: true));
      expect(p.isAdmin, false);
      expect(p.canFullAccess, true);
      expect(p.canDeleteVehicle, true);
      expect(p.canDeleteDriver, true);
      expect(p.canDeleteTask, true);
      expect(p.ownOnly, false);
    });

    test('только чтение: заметки — да, добавление/изменение — нет', () {
      final p = Permissions(role(read: true));
      expect(p.canRead, true);
      expect(p.canEditNotes, true);
      expect(p.canAddVehicle, false);
      expect(p.canEditVehicle, false);
      expect(p.canDeleteVehicle, false);
      expect(p.canCompleteTask, false);
    });

    test('запись: добавление — да, изменение/удаление — нет', () {
      final p = Permissions(role(write: true));
      expect(p.canAddVehicle, true);
      expect(p.canAddDriver, true);
      expect(p.canAddTask, true);
      expect(p.canEditVehicle, false);
      expect(p.canDeleteVehicle, false);
      expect(p.canDeleteTask, false);
    });

    test('изменение: правка и удаление задач — да, удаление ТС — нет', () {
      final p = Permissions(role(edit: true));
      expect(p.canEditVehicle, true);
      expect(p.canEditDriver, true);
      expect(p.canDeleteTask, true);
      expect(p.canDeleteVehicle, false);
      expect(p.canDeleteDriver, false);
      expect(p.canAddVehicle, false);
    });

    test('выполнение: завершение задач — да, остальное — нет', () {
      final p = Permissions(role(execute: true));
      expect(p.canCompleteTask, true);
      expect(p.canAddTask, false);
      expect(p.canDeleteTask, false);
    });

    test('ownOnly действует только без admin/full access', () {
      expect(Permissions(role(ownOnly: true, read: true)).ownOnly, true);
      expect(Permissions(role(ownOnly: true, isAdmin: true)).ownOnly, false);
      expect(
          Permissions(role(ownOnly: true, fullAccess: true)).ownOnly, false);
    });
  });
}
