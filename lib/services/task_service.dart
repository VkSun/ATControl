import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'cache_service.dart';
import 'offline_queue.dart';
import 'offline_state.dart';
import 'vehicle_service.dart';
import '../utils/date_utils.dart';

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

  String get _cacheKey => 'tasks_${_userId ?? 'anon'}';
  String get _todayCacheKey => 'tasks_today_${_userId ?? 'anon'}';

  Future<List<Task>> getAll() async {
    final uid = _userId;
    try {
      final data = uid != null
          ? await supabase
              .from(_table)
              .select()
              .or('type.eq.expiry,user_id.eq.$uid')
              .order('due_date')
              .order('due_time')
          : await supabase
              .from(_table)
              .select()
              .eq('type', 'expiry')
              .order('due_date')
              .order('due_time');
      final maps = (data as List).cast<Map<String, dynamic>>();
      unawaited(CacheService.instance.save(_cacheKey, maps));
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return maps.map((e) => Task.fromJson(e)).toList();
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached = await CacheService.instance.load(_cacheKey);
        if (cached != null) return cached.map(Task.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<Task>> getToday() async {
    final uid = _userId;
    final today = toDateString(DateTime.now());
    try {
      final data = uid != null
          ? await supabase
              .from(_table)
              .select()
              .or('type.eq.expiry,user_id.eq.$uid')
              .eq('due_date', today)
              .order('due_time')
          : await supabase
              .from(_table)
              .select()
              .eq('type', 'expiry')
              .eq('due_date', today)
              .order('due_time');
      final maps = (data as List).cast<Map<String, dynamic>>();
      unawaited(CacheService.instance.save(_todayCacheKey, maps));
      isOfflineNotifier.value = false;
      return maps.map((e) => Task.fromJson(e)).toList();
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached = await CacheService.instance.load(_todayCacheKey);
        if (cached != null) return cached.map(Task.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<Task>> getTodayAndTomorrow() async {
    final uid = _userId;
    final today = toDateString(DateTime.now());
    final tomorrow = toDateString(DateTime.now().add(const Duration(days: 1)));
    try {
      final data = uid != null
          ? await supabase
              .from(_table)
              .select()
              .or('type.eq.expiry,user_id.eq.$uid')
              .inFilter('due_date', [today, tomorrow])
              .order('due_date')
              .order('due_time')
          : await supabase
              .from(_table)
              .select()
              .eq('type', 'expiry')
              .inFilter('due_date', [today, tomorrow])
              .order('due_date')
              .order('due_time');
      final maps = (data as List).cast<Map<String, dynamic>>();
      unawaited(CacheService.instance.save('tasks_2days_${_userId ?? 'anon'}', maps));
      isOfflineNotifier.value = false;
      return maps.map((e) => Task.fromJson(e)).toList();
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached =
            await CacheService.instance.load('tasks_2days_${_userId ?? 'anon'}');
        if (cached != null) return cached.map(Task.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<Task> create(Task t) async {
    final uid = _userId;
    try {
      final json = t.toJson();
      json['user_id'] = uid;
      final data = await supabase.from(_table).insert(json).select().single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      _invalidateCache(Task.fromJson(data));
      return Task.fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final json = {...t.toJson(), 'id': tempId, 'user_id': uid};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: tempId, table: _table, op: 'insert', data: {
            ...t.toJson(), 'user_id': uid,
          },
          createdAt: DateTime.now(),
        ));
        await _patchCache(tempId, json, 'insert');
        return Task.fromJson(json);
      }
      rethrow;
    }
  }

  Future<void> toggleComplete(String id, bool value) async {
    try {
      await supabase.from(_table).update({'is_completed': value}).eq('id', id);
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      await _patchCacheField(id, 'is_completed', value);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'tog_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: _table, op: 'update',
          data: {'is_completed': value}, rowId: id,
          createdAt: DateTime.now(),
        ));
        await _patchCacheField(id, 'is_completed', value);
      } else {
        rethrow;
      }
    }
  }

  Future<void> update(String id, Task t) async {
    try {
      await supabase.from(_table).update(t.toJson()).eq('id', id);
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      await _patchCache(id, {...t.toJson(), 'id': id}, 'update');
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'upd_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: _table, op: 'update', data: t.toJson(), rowId: id,
          createdAt: DateTime.now(),
        ));
        await _patchCache(id, {...t.toJson(), 'id': id}, 'update');
      } else {
        rethrow;
      }
    }
  }

  Future<void> delete(String id) async {
    try {
      await supabase.from(_table).delete().eq('id', id);
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      await _patchCache(id, {}, 'delete');
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'del_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: _table, op: 'delete', data: {}, rowId: id,
          createdAt: DateTime.now(),
        ));
        await _patchCache(id, {}, 'delete');
      } else {
        rethrow;
      }
    }
  }

  Future<int> countPending() async {
    final uid = _userId;
    final today = toDateString(DateTime.now());
    try {
      final data = uid != null
          ? await supabase
              .from(_table)
              .select()
              .or('type.eq.expiry,user_id.eq.$uid')
              .eq('is_completed', false)
              .lte('due_date', today)
          : await supabase
              .from(_table)
              .select()
              .eq('type', 'expiry')
              .eq('is_completed', false)
              .lte('due_date', today);
      return data.length;
    } catch (_) {
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

  Future<void> syncExpiryTasks(List<Map<String, dynamic>> expiringItems) async {
    await supabase.from(_table).delete().eq('type', 'expiry');
    if (expiringItems.isEmpty) return;
    final rows = expiringItems
        .map((item) => {
              'title': item['title'],
              'due_date': toDateString(item['date'] as DateTime),
              'is_completed': false,
              'priority': (item['diff'] as int) <= 7 ? 'high' : 'normal',
              'type': 'expiry',
              'vehicle_id': item['vehicle_id'],
              'driver_id': item['driver_id'],
            })
        .toList();
    await supabase.from(_table).insert(rows);
  }

  Future<void> _patchCache(
      String id, Map<String, dynamic> json, String op) async {
    for (final key in [_cacheKey, _todayCacheKey]) {
      final cached = await CacheService.instance.load(key);
      if (cached == null) continue;
      final updated = switch (op) {
        'insert' => [...cached, json],
        'update' => cached.map((e) => e['id'] == id ? json : e).toList(),
        'delete' => cached.where((e) => e['id'] != id).toList(),
        _ => cached,
      };
      await CacheService.instance.save(key, updated.cast<Map<String, dynamic>>());
    }
  }

  Future<void> _patchCacheField(String id, String field, dynamic value) async {
    for (final key in [_cacheKey, _todayCacheKey]) {
      final cached = await CacheService.instance.load(key);
      if (cached == null) continue;
      final updated = cached.map((e) {
        if (e['id'] == id) return {...e, field: value};
        return e;
      }).toList();
      await CacheService.instance.save(key, updated.cast<Map<String, dynamic>>());
    }
  }

  void _invalidateCache(Task t) {
    // No-op: next getAll() call will refresh the cache.
  }
}
