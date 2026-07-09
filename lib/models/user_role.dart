import '../utils/brand_colors.dart';

class UserRole {
  final String id;
  final String userId;
  final String fullName;
  final String? position;
  final String initials;
  final String avatarColor;
  final bool isAdmin;
  final bool permFullAccess;
  final bool permEdit;
  final bool permExecute;
  final bool permRead;
  final bool permWrite;
  final bool permOwnOnly;
  final bool isActive;
  final String? departmentId;
  final String? sectionId;

  UserRole({
    required this.id,
    required this.userId,
    required this.fullName,
    this.position,
    required this.initials,
    required this.avatarColor,
    required this.isAdmin,
    required this.permFullAccess,
    required this.permEdit,
    required this.permExecute,
    required this.permRead,
    required this.permWrite,
    required this.permOwnOnly,
    required this.isActive,
    this.departmentId,
    this.sectionId,
  });

  bool get canEdit => permFullAccess || permEdit;
  bool get canExecute => permFullAccess || permExecute;
  bool get canRead => permFullAccess || permRead;
  bool get canWrite => permFullAccess || permWrite;

  /// Колонки для select() — ровно поля, которые читает fromJson.
  static const columns =
      'id, user_id, full_name, position, initials, avatar_color, is_admin, '
      'perm_full_access, perm_edit, perm_execute, perm_read, perm_write, '
      'perm_own_only, is_active, department_id, section_id';

  factory UserRole.fromJson(Map<String, dynamic> json) => UserRole(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    fullName: json['full_name'] as String? ?? '',
    position: json['position'] as String?,
    // Пустая строка тоже → 'ПП' (серверный _compute_initials может вернуть '')
    initials: (json['initials'] as String?)?.trim().isNotEmpty == true
        ? json['initials'] as String
        : 'ПП',
    avatarColor: json['avatar_color'] as String? ?? kPrimaryColorHex,
    isAdmin: json['is_admin'] as bool? ?? false,
    permFullAccess: json['perm_full_access'] as bool? ?? false,
    permEdit: json['perm_edit'] as bool? ?? false,
    permExecute: json['perm_execute'] as bool? ?? false,
    permRead: json['perm_read'] as bool? ?? true,
    permWrite: json['perm_write'] as bool? ?? false,
    permOwnOnly: json['perm_own_only'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    departmentId: json['department_id'] as String?,
    sectionId: json['section_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'full_name': fullName,
    'position': position,
    'initials': initials,
    'avatar_color': avatarColor,
    'is_admin': isAdmin,
    'perm_full_access': permFullAccess,
    'perm_edit': permEdit,
    'perm_execute': permExecute,
    'perm_read': permRead,
    'perm_write': permWrite,
    'perm_own_only': permOwnOnly,
    'is_active': isActive,
    'department_id': departmentId,
    'section_id': sectionId,
  };
}