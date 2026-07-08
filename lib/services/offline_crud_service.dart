import 'dart:async';

import 'cache_service.dart';
import 'offline_queue.dart';
import 'offline_state.dart';
import 'supabase_client.dart';

/// Общий CRUD-паттерн с офлайн-поддержкой: запрос → кэш → при сетевой ошибке
/// постановка в OfflineQueue + патч кэша. Наследники задают таблицу,
/// (де)сериализацию и набор ключей кэша; специфичные запросы собирают из
/// защищённых хелперов (fetchList/createRow/updateRow/deleteRow/mutateRow).
abstract class OfflineCrudService<T> {
  String get table;

  T fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson(T item);

  /// Ключи кэша, которые патчатся при офлайн-изменении.
  /// [item] == null — операция без данных строки (delete, патч поля).
  List<String> cacheKeysFor(T? item);

  /// JSON для вставки (TaskService добавляет user_id).
  Map<String, dynamic> insertJson(T item) => toJson(item);

  /// Пост-обработка списков (VehicleService сортирует по инв. номеру).
  List<T> processList(List<T> list) => list;

  /// Общий getAll-паттерн: запрос → кэш; офлайн — чтение из кэша.
  Future<List<T>> fetchList({
    required String cacheKey,
    required Future<dynamic> Function() query,
    bool flushQueue = true,
  }) async {
    try {
      final data = (await query()) as List;
      final maps = data.cast<Map<String, dynamic>>();
      unawaited(CacheService.instance.save(cacheKey, maps));
      isOfflineNotifier.value = false;
      if (flushQueue) unawaited(OfflineQueue.instance.flush());
      return processList(maps.map(fromJson).toList());
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached = await CacheService.instance.load(cacheKey);
        if (cached != null) return processList(cached.map(fromJson).toList());
      }
      rethrow;
    }
  }

  /// Вставка; офлайн — временный id + очередь + патч кэша.
  Future<T> createRow(T item) async {
    try {
      final data = await supabase
          .from(table)
          .insert(insertJson(item))
          .select()
          .single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final json = {...insertJson(item), 'id': tempId};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: tempId, table: table, op: 'insert', data: insertJson(item),
          createdAt: DateTime.now(),
        ));
        await patchCaches(id: tempId, json: json, op: 'insert', item: item);
        return fromJson(json);
      }
      rethrow;
    }
  }

  /// Обновление с возвратом свежей строки; офлайн — очередь + патч кэша.
  Future<T> updateRow(String id, T item) async {
    try {
      final data = await supabase
          .from(table)
          .update(toJson(item))
          .eq('id', id)
          .select()
          .single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final json = {...toJson(item), 'id': id};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'upd_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: table, op: 'update', data: toJson(item), rowId: id,
          createdAt: DateTime.now(),
        ));
        await patchCaches(id: id, json: json, op: 'update', item: item);
        return fromJson(json);
      }
      rethrow;
    }
  }

  /// Точечное update-изменение без возврата строки (TaskService.update,
  /// toggleComplete): онлайн и офлайн применяют один и тот же патч кэша.
  Future<void> mutateRow({
    required String id,
    required String opPrefix,
    required Map<String, dynamic> data,
    required Future<void> Function() remote,
    required Future<void> Function() patch,
  }) async {
    try {
      await remote();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      await patch();
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        await OfflineQueue.instance.enqueue(PendingOp(
          id: '${opPrefix}_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: table, op: 'update', data: data, rowId: id,
          createdAt: DateTime.now(),
        ));
        await patch();
      } else {
        rethrow;
      }
    }
  }

  /// Удаление; офлайн — очередь + патч кэша.
  /// [patchOnSuccess] — TaskService патчит кэш и в онлайн-ветке.
  Future<void> deleteRow(String id, {bool patchOnSuccess = false}) async {
    try {
      await supabase.from(table).delete().eq('id', id);
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      if (patchOnSuccess) {
        await patchCaches(id: id, json: const {}, op: 'delete');
      }
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'del_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: table, op: 'delete', data: {}, rowId: id,
          createdAt: DateTime.now(),
        ));
        await patchCaches(id: id, json: const {}, op: 'delete');
      } else {
        rethrow;
      }
    }
  }

  /// Применяет insert/update/delete к каждому существующему ключу кэша.
  Future<void> patchCaches({
    required String id,
    required Map<String, dynamic> json,
    required String op,
    T? item,
  }) async {
    for (final key in cacheKeysFor(item).toSet()) {
      final cached = await CacheService.instance.load(key);
      if (cached == null) continue;
      final updated = switch (op) {
        'insert' => [...cached, json],
        'update' => cached.map((e) => e['id'] == id ? json : e).toList(),
        'delete' => cached.where((e) => e['id'] != id).toList(),
        _ => cached,
      };
      await CacheService.instance
          .save(key, updated.cast<Map<String, dynamic>>());
    }
  }

  /// Точечно меняет одно поле строки во всех кэшах.
  Future<void> patchCacheField(String id, String field, dynamic value) async {
    for (final key in cacheKeysFor(null).toSet()) {
      final cached = await CacheService.instance.load(key);
      if (cached == null) continue;
      final updated = cached.map((e) {
        if (e['id'] == id) return {...e, field: value};
        return e;
      }).toList();
      await CacheService.instance
          .save(key, updated.cast<Map<String, dynamic>>());
    }
  }
}
