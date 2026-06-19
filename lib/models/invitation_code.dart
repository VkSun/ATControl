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

  factory InvitationCode.fromJson(Map<String, dynamic> json) => InvitationCode(
    id: json['id'],
    code: json['code'],
    createdBy: json['created_by'],
    usedBy: json['used_by'],
    isUsed: json['is_used'] ?? false,
    fullName: json['full_name'],
    position: json['position'],
    permFullAccess: json['perm_full_access'] ?? false,
    permEdit: json['perm_edit'] ?? false,
    permExecute: json['perm_execute'] ?? false,
    permRead: json['perm_read'] ?? true,
    permWrite: json['perm_write'] ?? false,
    permOwnOnly: json['perm_own_only'] ?? false,
    expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at']) : null,
    createdAt: DateTime.parse(json['created_at']),
    departmentId: json['department_id'],
    sectionId: json['section_id'],
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