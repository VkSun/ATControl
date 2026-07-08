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
    id: json['id'],
    title: json['title'],
    description: json['description'],
    dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
    dueTime: json['due_time'],
    isCompleted: json['is_completed'] ?? false,
    priority: json['priority'] ?? 'normal',
    type: json['type'] ?? 'manual',
    vehicleId: json['vehicle_id'],
    driverId: json['driver_id'],
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