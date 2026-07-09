import '../utils/date_utils.dart';

class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? dueTime;
  bool isCompleted;
  final String priority;
  final String type;
  final String? vehicleId;
  final String? driverId;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.priority = 'normal',
    this.type = 'manual',
    this.vehicleId,
    this.driverId,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
    dueTime: json['due_time'] as String?,
    isCompleted: json['is_completed'] as bool? ?? false,
    priority: json['priority'] as String? ?? 'normal',
    type: json['type'] as String? ?? 'manual',
    vehicleId: json['vehicle_id'] as String?,
    driverId: json['driver_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'due_date': dateStr(dueDate),
    'due_time': dueTime,
    'is_completed': isCompleted,
    'priority': priority,
    'type': type,
    'vehicle_id': vehicleId,
    'driver_id': driverId,
  };
}