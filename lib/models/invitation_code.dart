class InvitationCode {
  final String id;
  final String code;
  final String? createdBy;
  final String? usedBy;
  final bool isUsed;
  final String? fullName;
  final String? position;
  final bool permFullAccess;
  final bool permEdit;
  final bool permExecute;
  final bool permRead;
  final bool permWrite;
  final bool permOwnOnly;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String? departmentId;
  final String? sectionId;

  InvitationCode({
    required this.id,
    required this.code,
    this.createdBy,
    this.usedBy,
    required this.isUsed,
    this.fullName,
    this.position,
    required this.permFullAccess,
    required this.permEdit,
    required this.permExecute,
    required this.permRead,
    required this.permWrite,
    required this.permOwnOnly,
    this.expiresAt,
    required this.createdAt,
    this.departmentId,
    this.sectionId,
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isValid => !isUsed && !isExpired;

  /// Колонки для select() — ровно поля, которые читает fromJson.
  static const columns =
      'id, code, created_by, used_by, is_used, full_name, position, '
      'perm_full_access, perm_edit, perm_execute, perm_read, perm_write, '
      'perm_own_only, expires_at, created_at, department_id, section_id';

  factory InvitationCode.fromJson(Map<String, dynamic> json) => InvitationCode(
    id: json['id'] as String,
    code: json['code'] as String,
    createdBy: json['created_by'] as String?,
    usedBy: json['used_by'] as String?,
    isUsed: json['is_used'] as bool? ?? false,
    fullName: json['full_name'] as String?,
    position: json['position'] as String?,
    permFullAccess: json['perm_full_access'] as bool? ?? false,
    permEdit: json['perm_edit'] as bool? ?? false,
    permExecute: json['perm_execute'] as bool? ?? false,
    permRead: json['perm_read'] as bool? ?? true,
    permWrite: json['perm_write'] as bool? ?? false,
    permOwnOnly: json['perm_own_only'] as bool? ?? false,
    expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String) : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    departmentId: json['department_id'] as String?,
    sectionId: json['section_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'full_name': fullName,
    'position': position,
    'perm_full_access': permFullAccess,
    'perm_edit': permEdit,
    'perm_execute': permExecute,
    'perm_read': permRead,
    'perm_write': permWrite,
    'perm_own_only': permOwnOnly,
  };
}