import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../utils/date_utils.dart';
import '../utils/logger.dart';
import 'cache_service.dart';
import 'offline_crud_service.dart';
import 'supabase_client.dart';

final _log = Logger('TaskService');

final taskServiceProvider = Provider((ref) => TaskService());

// Global (no autoDispose): shared across home and planner screens simultaneously.
final tasksProvider = FutureProvider<List<Task>>((ref) async {
  return ref.read(taskServiceProvider).getAll();
});

final todayTasksProvider = FutureProvider<List<Task>>((ref) async {
  return ref.read(taskServiceProvider).getToday();
});

class TaskService extends OfflineCrudService<Task> {
  @override
  String get table => 'tasks';

  String? get _userId => supabase.auth.currentUser?.id;

  String get _cacheKey => 'tasks_${_userId ?? 'anon'}';
  String get _todayCacheKey => 'tasks_today_${_userId ?? 'anon'}';

  @override
  Task fromJson(Map<String, dynamic> json) => Task.fromJson(json);

  @override
  Map<String, dynamic> toJson(Task item) => item.toJson();

  // Кэш «на 2 дня» не патчится (как и раньше): обновится при следующей загрузке.
  @override
  List<String> cacheKeysFor(Task? item) => [_cacheKey, _todayCacheKey];

  @override
  Map<String, dynamic> insertJson(Task item) =>
      {...item.toJson(), 'user_id': _userId};

  /// Задачи, видимые пользователю: expiry-задачи + собственные.
  PostgrestFilterBuilder<PostgrestList> _visible() {
    final uid = _userId;
    final base = supabase.from(table).select();
    return uid != null
        ? base.or('type.eq.expiry,user_id.eq.$uid')
        : base.eq('type', 'expiry');
  }

  Future<List<Task>> getAll() => fetchList(
        cacheKey: _cacheKey,
        query: () => _visible().order('due_date').order('due_time'),
      );

  Future<List<Task>> getToday() {
    final today = toDateString(DateTime.now());
    return fetchList(
      cacheKey: _todayCacheKey,
      flushQueue: false,
      query: () => _visible().eq('due_date', today).order('due_time'),
    );
  }

  Future<List<Task>> getTodayAndTomorrow() {
    final today = toDateString(DateTime.now());
    final tomorrow = toDateString(DateTime.now().add(const Duration(days: 1)));
    return fetchList(
      cacheKey: 'tasks_2days_${_userId ?? 'anon'}',
      flushQueue: false,
      query: () => _visible()
          .inFilter('due_date', [today, tomorrow])
          .order('due_date')
          .order('due_time'),
    );
  }

  Future<Task> create(Task t) => createRow(t);

  Future<void> toggleComplete(String id, bool value) => mutateRow(
        id: id,
        opPrefix: 'tog',
        data: {'is_completed': value},
        remote: () =>
            supabase.from(table).update({'is_completed': value}).eq('id', id),
        patch: () => patchCacheField(id, 'is_completed', value),
      );

  Future<void> update(String id, Task t) => mutateRow(
        id: id,
        opPrefix: 'upd',
        data: t.toJson(),
        remote: () => supabase.from(table).update(t.toJson()).eq('id', id),
        patch: () => patchCaches(
            id: id, json: {...t.toJson(), 'id': id}, op: 'update', item: t),
      );

  Future<void> delete(String id) => deleteRow(id, patchOnSuccess: true);

  Future<int> countPending() async {
    final today = toDateString(DateTime.now());
    try {
      final data =
          await _visible().eq('is_completed', false).lte('due_date', today);
      return data.length;
    } catch (e, s) {
      _log.warning('overdueCount: offline fallback', e, s);
      // Offline: estimate from full cache
      final cached = await CacheService.instance.load(_cacheKey);
      if (cached == null) return 0;
      return cached
          .where((t) =>
              t['is_completed'] == false &&
              t['due_date'] != null &&
              t['due_date'].compareTo(today) <= 0)
          .length;
    }
  }

  Future<void> syncExpiryTasks() async {
    await supabase.rpc('sync_expiry_tasks');
  }
}
