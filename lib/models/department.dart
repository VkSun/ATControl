class Department {
  final String id;
  final String name;
  final String? parentId;

  const Department({required this.id, required this.name, this.parentId});

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as String,
        name: json['name'] as String,
        parentId: json['parent_id'] as String?,
      );

  Map<String, dynamic> toJson() => {'name': name};

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Department && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Section {
  final String id;
  final String name;
  final String departmentId;

  const Section({
    required this.id,
    required this.name,
    required this.departmentId,
  });

  factory Section.fromJson(Map<String, dynamic> json) => Section(
        id: json['id'] as String,
        name: json['name'] as String,
        departmentId: json['department_id'] as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'department_id': departmentId};

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Section && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
