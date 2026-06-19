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

  factory UserRole.fromJson(Map<String, dynamic> json) => UserRole(
    id: json['id'],
    userId: json['user_id'],
    fullName: json['full_name'] ?? '',
    position: json['position'],
    initials: json['initials'] ?? 'ПП',
    avatarColor: json['avatar_color'] ?? '#4361EE',
    isAdmin: json['is_admin'] ?? false,
    permFullAccess: json['perm_full_access'] ?? false,
    permEdit: json['perm_edit'] ?? false,
    permExecute: json['perm_execute'] ?? false,
    permRead: json['perm_read'] ?? true,
    permWrite: json['perm_write'] ?? false,
    permOwnOnly: json['perm_own_only'] ?? false,
    isActive: json['is_active'] ?? true,
    departmentId: json['department_id'],
    sectionId: json['section_id'],
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