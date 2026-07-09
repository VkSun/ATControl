import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  String describe(Task? item) =>
      item == null ? 'Задача' : 'Задача «${item.title}»';

  // Видимость задач (expiry + собственные) — общая для приложения и
  // расширения логика, живёт в БД: get_my_tasks(p_from, p_to).

  Future<List<Task>> getAll() => fetchList(
        cacheKey: _cacheKey,
        query: () => supabase.rpc('get_my_tasks'),
      );

  Future<List<Task>> getToday() {
    final today = toDateString(DateTime.now());
    return fetchList(
      cacheKey: _todayCacheKey,
      flushQueue: false,
      query: () =>
          supabase.rpc('get_my_tasks', params: {'p_from': today, 'p_to': today}),
    );
  }

  Future<List<Task>> getTodayAndTomorrow() {
    final today = toDateString(DateTime.now());
    final tomorrow = toDateString(DateTime.now().add(const Duration(days: 1)));
    return fetchList(
      cacheKey: 'tasks_2days_${_userId ?? 'anon'}',
      flushQueue: false,
      query: () => supabase
          .rpc('get_my_tasks', params: {'p_from': today, 'p_to': tomorrow}),
    );
  }

  Future<Task> create(Task t) => createRow(t);

  Future<void> toggleComplete(String id, bool value) => mutateRow(
        id: id,
        opPrefix: 'tog',
        data: {'is_completed': value},
        label: value ? 'Задача: выполнена' : 'Задача: снята отметка',
        remote: () =>
            supabase.from(table).update({'is_completed': value}).eq('id', id),
        patch: () => patchCacheField(id, 'is_completed', value),
      );

  Future<void> update(String id, Task t) => mutateRow(
        id: id,
        opPrefix: 'upd',
        data: t.toJson(),
        label: describe(t),
        remote: () => supabase.from(table).update(t.toJson()).eq('id', id),
        patch: () => patchCaches(
            id: id, json: {...t.toJson(), 'id': id}, op: 'update', item: t),
      );

  Future<void> delete(String id) => deleteRow(id, patchOnSuccess: true);

  Future<int> countPending() async {
    final today = toDateString(DateTime.now());
    try {
      // Count-RPC: сервер возвращает число, строки не скачиваются.
      final count = await supabase
          .rpc('count_my_pending_tasks', params: {'p_to': today});
      return count as int;
    } catch (e, s) {
      _log.warning('overdueCount: offline fallback', e, s);
      // Offline: estimate from full cache
      final cached = await CacheService.instance.load(_cacheKey);
      if (cached == null) return 0;
      return cached
          .where((t) =>
              t['is_completed'] == false &&
              t['due_date'] != null &&
              (t['due_date'] as String).compareTo(today) <= 0)
          .length;
    }
  }

  Future<void> syncExpiryTasks() async {
    await supabase.rpc('sync_expiry_tasks');
  }
}
