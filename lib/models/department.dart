class Department {
  final String id;
  final String name;
  final String? parentId;

  const Department({required this.id, required this.name, this.parentId});

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'],
        name: json['name'],
        parentId: json['parent_id'],
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
        id: json['id'],
        name: json['name'],
        departmentId: json['department_id'],
      );

  Map<String, dynamic> toJson() => {'name': name, 'department_id': departmentId};

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Section && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
