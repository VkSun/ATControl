import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';

class Permissions {
  final UserRole? role;

  Permissions(this.role);

  bool get isAdmin => role?.isAdmin ?? false;
  bool get canFullAccess => isAdmin || (role?.permFullAccess ?? false);
  bool get canEdit => canFullAccess || (role?.permEdit ?? false);
  bool get canExecute => canFullAccess || (role?.permExecute ?? false);
  bool get canRead => canFullAccess || (role?.permRead ?? false);
  bool get canWrite => canFullAccess || (role?.permWrite ?? false);
  bool get ownOnly => !isAdmin && !canFullAccess && (role?.permOwnOnly ?? false);

  // Транспорт
  bool get canAddVehicle => canFullAccess || canWrite;
  bool get canEditVehicle => canFullAccess || canEdit;
  bool get canDeleteVehicle => canFullAccess || isAdmin;

  // Водители
  bool get canAddDriver => canFullAccess || canWrite;
  bool get canEditDriver => canFullAccess || canEdit;
  bool get canDeleteDriver => canFullAccess || isAdmin;

  // Планировщик
  bool get canAddTask => canFullAccess || canWrite;
  bool get canCompleteTask => canFullAccess || canExecute;
  bool get canDeleteTask => canFullAccess || canEdit;
  bool get canEditNotes => canFullAccess || canRead;
}

final permissionsProvider = Provider<Permissions>((ref) {
  final role = ref.watch(currentUserRoleProvider).value;
  return Permissions(role);
});