import 'dart:async' show Future, TimeoutException;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gotrue/gotrue.dart' show AuthRetryableFetchException;
import 'package:http/http.dart' show ClientException;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import 'offline_state.dart';
import 'supabase_client.dart';

final _log = Logger('OfflineQueue');

/// Maximum consecutive non-network failures before an op is dead-lettered.
const int maxQueueAttempts = 5;

// ─── PendingOp ────────────────────────────────────────────────────────────────

class PendingOp {
  final String id;
  final String table;
  final String op; // insert | update | delete
  final Map<String, dynamic> data;
  final String? rowId;
  final DateTime createdAt;
  final int attempts;

  /// Человекочитаемая подпись для шторки синхронизации
  /// («Автомобиль 100011», «Задача «Заменить масло»»). Заполняется
  /// сервисами при enqueue; в старом JSON поля нет — читается как null.
  final String? label;

  PendingOp({
    required this.id,
    required this.table,
    required this.op,
    required this.data,
    this.rowId,
    required this.createdAt,
    this.attempts = 0,
    this.label,
  });

  PendingOp copyWith({int? attempts}) => PendingOp(
        id: id,
        table: table,
        op: op,
        data: data,
        rowId: rowId,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        label: label,
      );

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        id: j['id'] as String,
        table: j['table'] as String,
        op: j['op'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map),
        rowId: j['row_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        attempts: (j['attempts'] as int?) ?? 0,
        label: j['label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'op': op,
        'data': data,
        'row_id': rowId,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        if (label != null) 'label': label,
      };
}

/// Операция, окончательно не прошедшая синхронизацию (dead-letter).
class DeadLetterEntry {
  final PendingOp op;
  final String reason;
  final DateTime killedAt;

  DeadLetterEntry({required this.op, required this.reason, required this.killedAt});

  factory DeadLetterEntry.fromJson(Map<String, dynamic> j) => DeadLetterEntry(
        op: PendingOp.fromJson(Map<String, dynamic>.from(j['op'] as Map)),
        reason: (j['reason'] as String?) ?? '',
        killedAt: DateTime.tryParse(j['killed_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'op': op.toJson(),
        'reason': reason,
        'killed_at': killedAt.toIso8601String(),
      };
}

// ─── Executor interface ───────────────────────────────────────────────────────

/// Abstracts the actual DB calls so flush() can be unit-tested without Supabase.
abstract class QueueExecutor {
  /// Inserts [data] into [table] and returns the server-assigned real id.
  Future<String> insert(String table, Map<String, dynamic> data);
  Future<void> update(String table, String rowId, Map<String, dynamic> data);
  Future<void> delete(String table, String rowId);
}

// ─── Persistence interface ────────────────────────────────────────────────────

/// Abstracts queue persistence so flush() can be unit-tested without the filesystem.
abstract class QueueStore {
  Future<List<PendingOp>> getAll();
  Future<void> persist(List<PendingOp> ops);
  Future<void> appendDeadLetter(PendingOp op, String reason);
  Future<List<DeadLetterEntry>> getDeadLetters();
  Future<void> persistDeadLetters(List<DeadLetterEntry> entries);
}

// ─── Production implementations ──────────────────────────────────────────────

class _SupabaseExecutor implements QueueExecutor {
  const _SupabaseExecutor();

  @override
  Future<String> insert(String table, Map<String, dynamic> data) async {
    final result = await supabase.from(table).insert(data).select().single();
    return result['id'] as String;
  }

  @override
  Future<void> update(String table, String rowId, Map<String, dynamic> data) =>
      supabase.from(table).update(data).eq('id', rowId);

  @override
  Future<void> delete(String table, String rowId) =>
      supabase.from(table).delete().eq('id', rowId);
}

class _FileQueueStore implements QueueStore {
  Future<Directory> get _dir => getApplicationSupportDirectory();

  Future<File> get _pendingFile async =>
      File('${(await _dir).path}/atc_pending.json');

  Future<File> get _deadLetterFile async =>
      File('${(await _dir).path}/atc_dead_letter.json');

  @override
  Future<List<PendingOp>> getAll() async {
    try {
      final f = await _pendingFile;
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) => PendingOp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, s) {
      _log.warning('getAll: failed to read pending queue', e, s);
      return [];
    }
  }

  @override
  Future<void> persist(List<PendingOp> ops) async {
    try {
      final f = await _pendingFile;
      await f.writeAsString(
        jsonEncode(ops.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (e, s) {
      _log.error('persist: failed to write pending queue', e, s);
    }
  }

  @override
  Future<List<DeadLetterEntry>> getDeadLetters() async {
    try {
      final f = await _deadLetterFile;
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) =>
              DeadLetterEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, s) {
      _log.warning('getDeadLetters: failed to read dead-letter file', e, s);
      return [];
    }
  }

  @override
  Future<void> persistDeadLetters(List<DeadLetterEntry> entries) async {
    try {
      final f = await _deadLetterFile;
      await f.writeAsString(
        jsonEncode(entries.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (e, s) {
      _log.error('persistDeadLetters: failed to write dead-letter file', e, s);
    }
  }

  @override
  Future<void> appendDeadLetter(PendingOp op, String reason) async {
    try {
      final f = await _deadLetterFile;
      List<dynamic> existing = [];
      if (await f.exists()) {
        try {
          existing = jsonDecode(await f.readAsString()) as List;
        } catch (e, s) {
          _log.warning('appendDeadLetter: failed to parse existing dead-letter file', e, s);
        }
      }
      existing.add({
        'op': op.toJson(),
        'reason': reason,
        'killed_at': DateTime.now().toIso8601String(),
      });
      await f.writeAsString(jsonEncode(existing), flush: true);
    } catch (e, s) {
      _log.error('appendDeadLetter: failed to write dead-letter file', e, s);
    }
  }
}

// ─── OfflineQueue ─────────────────────────────────────────────────────────────

class OfflineQueue {
  final QueueExecutor _executor;
  final QueueStore _store;

  OfflineQueue._(this._executor, this._store);

  static final OfflineQueue instance = OfflineQueue._(
    const _SupabaseExecutor(),
    _FileQueueStore(),
  );

  @visibleForTesting
  factory OfflineQueue.forTesting({
    required QueueExecutor executor,
    required QueueStore store,
  }) =>
      OfflineQueue._(executor, store);

  // Concurrency guard: second flush() while one is running returns the
  // same Future instead of starting a second pass.
  bool _flushing = false;
  Future<bool>? _flushFuture;

  Future<List<PendingOp>> getAll() => _store.getAll();

  Future<int> get count async => (await getAll()).length;

  /// Актуализирует queueCountNotifier (например, при холодном старте,
  /// когда очередь уже лежит на диске).
  Future<void> refreshCount() async {
    queueCountNotifier.value = await count;
  }

  Future<List<DeadLetterEntry>> deadLetters() => _store.getDeadLetters();

  /// Возвращает операцию из dead-letter в очередь, сбросив attempts.
  Future<void> retryDeadLetter(String opId) async {
    final entries = await _store.getDeadLetters();
    final entry = entries.where((e) => e.op.id == opId).firstOrNull;
    if (entry == null) return;
    await _store
        .persistDeadLetters(entries.where((e) => e.op.id != opId).toList());
    await enqueue(entry.op.copyWith(attempts: 0));
  }

  /// Окончательно удаляет операцию из dead-letter.
  Future<void> deleteDeadLetter(String opId) async {
    final entries = await _store.getDeadLetters();
    await _store
        .persistDeadLetters(entries.where((e) => e.op.id != opId).toList());
  }

  Future<void> enqueue(PendingOp op) async {
    final all = await getAll();
    all.add(op);
    await _store.persist(all);
    queueCountNotifier.value = all.length;
  }

  /// Replays pending operations in chronological order.
  ///
  /// Temp-id mapping: a successful insert returns the real server id;
  /// all subsequent ops whose rowId or data values reference that tempId
  /// are patched automatically before execution.
  ///
  /// Concurrency: if flush() is called while a flush is already in progress,
  /// the caller joins the running pass — no second pass is started.
  ///
  /// Poison ops: a non-network failure increments [PendingOp.attempts].
  /// After [maxQueueAttempts] failures the op (and any ops that became
  /// orphaned because their parent insert died) is moved to atc_dead_letter.json.
  ///
  /// Returns true when the queue is empty after this pass.
  Future<bool> flush() {
    if (_flushing) return _flushFuture!;
    _flushing = true;
    _flushFuture = _doFlush().whenComplete(() {
      _flushing = false;
      _flushFuture = null;
    });
    return _flushFuture!;
  }

  Future<bool> _doFlush() async {
    var ops = await _store.getAll();
    if (ops.isEmpty) return true;

    // Process inserts before their dependent updates/deletes.
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // tempId (= PendingOp.id for insert ops) → real server id, populated
    // as each insert succeeds.
    final idMap = <String, String>{};
    final toRemove = <String>{};
    final updatedOps = <String, PendingOp>{};

    for (final op in ops) {
      try {
        switch (op.op) {
          case 'insert':
            final data = Map<String, dynamic>.from(op.data);
            // Strip any stale temp id that leaked into the data map.
            if ((data['id'] as String? ?? '').startsWith('offline_')) {
              data.remove('id');
            }
            final realId = await _executor.insert(
                op.table, _applyIdMap(data, idMap));
            idMap[op.id] = realId;
            toRemove.add(op.id);

          case 'update':
            final resolvedId = idMap[op.rowId] ?? op.rowId;
            if (resolvedId == null || resolvedId.startsWith('offline_')) {
              // Parent insert hasn't succeeded yet — defer to next flush.
              continue;
            }
            await _executor.update(
              op.table,
              resolvedId,
              _applyIdMap(Map<String, dynamic>.from(op.data), idMap),
            );
            toRemove.add(op.id);

          case 'delete':
            final resolvedId = idMap[op.rowId] ?? op.rowId;
            if (resolvedId == null || resolvedId.startsWith('offline_')) {
              continue;
            }
            await _executor.delete(op.table, resolvedId);
            toRemove.add(op.id);
        }
      } catch (e) {
        if (isNetworkError(e)) break; // still offline — stop, don't touch attempts

        // Business/constraint error: track attempts.
        final updated = op.copyWith(attempts: op.attempts + 1);
        if (updated.attempts >= maxQueueAttempts) {
          toRemove.add(op.id);
          await _store.appendDeadLetter(op, e.toString());
        } else {
          updatedOps[op.id] = updated;
        }
        // Don't break — the network is working, only this specific op is bad.
      }
    }

    // Dead-letter update/delete ops whose parent insert was just dead-lettered.
    final liveInsertIds = ops
        .where((o) => o.op == 'insert' && !toRemove.contains(o.id))
        .map((o) => o.id)
        .toSet();

    for (final op in ops) {
      if (toRemove.contains(op.id) || op.op == 'insert') continue;
      final rowId = op.rowId;
      if (rowId == null || !rowId.startsWith('offline_')) continue;
      // rowId is still a temp id: parent succeeded this pass → already handled above;
      // parent still alive → defer; parent was just dead-lettered → orphan.
      if (!liveInsertIds.contains(rowId) && !idMap.containsKey(rowId)) {
        toRemove.add(op.id);
        await _store.appendDeadLetter(
            op, 'orphaned: parent insert $rowId was dead-lettered');
      }
    }

    if (toRemove.isNotEmpty || updatedOps.isNotEmpty) {
      final remaining = ops
          .where((o) => !toRemove.contains(o.id))
          .map((o) => updatedOps[o.id] ?? o)
          .toList();
      await _store.persist(remaining);
      queueCountNotifier.value = remaining.length;
    }

    final remaining = await count;
    if (remaining == 0) isOfflineNotifier.value = false;
    return remaining == 0;
  }

  /// Replaces any string value in [data] that appears as a key in [idMap]
  /// with its mapped real id (handles vehicle_id, driver_id references).
  static Map<String, dynamic> _applyIdMap(
      Map<String, dynamic> data, Map<String, String> idMap) {
    if (idMap.isEmpty) return data;
    return data.map((k, v) {
      if (v is String) {
        final mapped = idMap[v];
        if (mapped != null) return MapEntry(k, mapped);
      }
      return MapEntry(k, v);
    });
  }
}

// ─── Network error detection ──────────────────────────────────────────────────

bool isNetworkError(Object e) {
  if (e is SocketException) return true;
  if (e is TimeoutException) return true;
  if (e is ClientException) return true;
  if (e is AuthRetryableFetchException) return true;
  final s = e.toString().toLowerCase();
  return s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection refused') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('no address associated') ||
      s.contains('connection timed out') ||
      s.contains('handshakeexception') ||
      s.contains('timeoutexception');
}
