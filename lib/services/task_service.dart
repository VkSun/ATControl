import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'vehicle_service.dart';

final taskServiceProvider = Provider((ref) => TaskService());

final tasksProvider = FutureProvider<List<Task>>((ref) async {
  return ref.read(taskServiceProvider).getAll();
});

final todayTasksProvider = FutureProvider<List<Task>>((ref) async {
  return ref.read(taskServiceProvider).getToday();
});

class TaskService {
  final _table = 'tasks';
  String? get _userId => supabase.auth.currentUser?.id;

  Future<List<Task>> getAll() async {
    final data = await supabase
        .from(_table)
        .select()
        .or('type.eq.expiry,user_id.eq.$_userId')
        .order('due_date')
        .order('due_time');
    return (data as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<List<Task>> getToday() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await supabase
        .from(_table)
        .select()
        .or('type.eq.expiry,user_id.eq.$_userId')
        .eq('due_date', today)
        .order('due_time');
    return (data as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<List<Task>> getTodayAndTomorrow() async {
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];
    final tomorrow = now.add(const Duration(days: 1)).toIso8601String().split('T')[0];
    final data = await supabase
        .from(_table)
        .select()
        .or('type.eq.expiry,user_id.eq.$_userId')
        .inFilter('due_date', [today, tomorrow])
        .order('due_date')
        .order('due_time');
    return (data as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<Task> create(Task t) async {
    final json = t.toJson();
    json['user_id'] = _userId;
    final data = await supabase.from(_table).insert(json).select().single();
    return Task.fromJson(data);
  }

  Future<void> toggleComplete(String id, bool value) async {
    await supabase.from(_table).update({'is_completed': value}).eq('id', id);
  }

  Future<void> update(String id, Task t) async {
    await supabase.from(_table).update(t.toJson()).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }

  Future<int> countPending() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final data = await supabase
        .from(_table)
        .select()
        .or('type.eq.expiry,user_id.eq.$_userId')
        .eq('is_completed', false)
        .lte('due_date', today);
    return (data as List).length;
  }

  Future<void> syncExpiryTasks(List<Map<String, dynamic>> expiringItems) async {
    await supabase.from(_table).delete().eq('type', 'expiry');
    if (expiringItems.isEmpty) return;
    final rows = expiringItems.map((item) => {
      'title': item['title'],
      'due_date': (item['date'] as DateTime).toIso8601String().split('T')[0],
      'is_completed': false,
      'priority': (item['diff'] as int) <= 7 ? 'high' : 'normal',
      'type': 'expiry',
      'vehicle_id': item['vehicle_id'],
      'driver_id': item['driver_id'],
    }).toList();
    await supabase.from(_table).insert(rows);
  }
}