import 'dart:async';
import 'dart:io' show SocketException;
import 'package:flutter_test/flutter_test.dart';
import 'package:atcontrol/services/offline_queue.dart';

// ─── Test doubles ─────────────────────────────────────────────────────────────

class MemoryQueueStore implements QueueStore {
  final List<PendingOp> _pending = [];
  final List<Map<String, dynamic>> deadLetter = [];

  @override
  Future<List<PendingOp>> getAll() async => List.of(_pending);

  @override
  Future<void> persist(List<PendingOp> ops) async {
    _pending
      ..clear()
      ..addAll(ops);
  }

  @override
  Future<void> appendDeadLetter(PendingOp op, String reason) async {
    deadLetter.add({'op': op.toJson(), 'reason': reason});
  }
}

class RecordingExecutor implements QueueExecutor {
  Exception? _insertError;
  int insertCallCount = 0;
  int updateCallCount = 0;
  int deleteCallCount = 0;

  final List<(String table, Map<String, dynamic> data)> inserts = [];
  final List<(String table, String rowId, Map<String, dynamic> data)> updates = [];
  final List<(String table, String rowId)> deletes = [];
  final List<String> _nextInsertIds = [];

  void queueInsertId(String id) => _nextInsertIds.add(id);
  void alwaysFailWith(Exception e) => _insertError = e;

  @override
  Future<String> insert(String table, Map<String, dynamic> data) async {
    insertCallCount++;
    if (_insertError != null) throw _insertError!;
    inserts.add((table, Map.of(data)));
    return _nextInsertIds.isNotEmpty
        ? _nextInsertIds.removeAt(0)
        : 'real-${insertCallCount - 1}';
  }

  @override
  Future<void> update(String table, String rowId, Map<String, dynamic> data) async {
    updateCallCount++;
    updates.add((table, rowId, Map.of(data)));
  }

  @override
  Future<void> delete(String table, String rowId) async {
    deleteCallCount++;
    deletes.add((table, rowId));
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

PendingOp _insertOp(
  String id,
  Map<String, dynamic> data, {
  DateTime? at,
  String table = 'tasks',
}) =>
    PendingOp(
      id: id,
      table: table,
      op: 'insert',
      data: data,
      createdAt: at ?? DateTime(2026, 1, 1, 10, 0),
    );

PendingOp _updateOp(
  String id,
  String rowId,
  Map<String, dynamic> data, {
  DateTime? at,
  String table = 'tasks',
}) =>
    PendingOp(
      id: id,
      table: table,
      op: 'update',
      data: data,
      rowId: rowId,
      createdAt: at ?? DateTime(2026, 1, 1, 10, 1),
    );

PendingOp _deleteOp(
  String id,
  String rowId, {
  DateTime? at,
  String table = 'tasks',
}) =>
    PendingOp(
      id: id,
      table: table,
      op: 'delete',
      data: {},
      rowId: rowId,
      createdAt: at ?? DateTime(2026, 1, 1, 10, 2),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('PendingOp', () {
    test('fromJson is backward-compatible: missing attempts defaults to 0', () {
      final json = {
        'id': 'x',
        'table': 'tasks',
        'op': 'insert',
        'data': <String, dynamic>{},
        'row_id': null,
        'created_at': '2026-01-01T00:00:00.000',
        // 'attempts' field absent — old format
      };
      expect(PendingOp.fromJson(json).attempts, 0);
    });

    test('toJson / fromJson round-trip preserves attempts', () {
      final op = PendingOp(
        id: 'x',
        table: 'tasks',
        op: 'update',
        data: {'title': 'hi'},
        rowId: 'r1',
        createdAt: DateTime(2026, 1, 1),
        attempts: 3,
      );
      expect(PendingOp.fromJson(op.toJson()).attempts, 3);
    });
  });

  group('OfflineQueue.flush()', () {
    // ── Test 1: temp-id chain ────────────────────────────────────────────────

    test('offline-created then offline-updated: update uses real id after flush',
        () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor()..queueInsertId('server-uuid-abc');
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      // Enqueue: create a record offline, then edit it offline.
      await queue.enqueue(_insertOp(
        'offline_t1',
        {'title': 'Draft'},
        at: DateTime(2026, 1, 1, 10, 0),
      ));
      await queue.enqueue(_updateOp(
        'upd_offline_t1_1',
        'offline_t1',
        {'title': 'Final'},
        at: DateTime(2026, 1, 1, 10, 1),
      ));

      final ok = await queue.flush();

      expect(ok, isTrue);
      // Insert was executed once with the original data (no 'id' field).
      expect(ex.inserts, hasLength(1));
      expect(ex.inserts.first.$2, equals({'title': 'Draft'}));
      // Update was executed against the real server id, not the temp id.
      expect(ex.updates, hasLength(1));
      expect(ex.updates.first.$2, 'server-uuid-abc');
      expect(ex.updates.first.$3, equals({'title': 'Final'}));
      // Queue is drained.
      expect(await store.getAll(), isEmpty);
      expect(store.deadLetter, isEmpty);
    });

    test('offline-created, offline-updated, offline-deleted: all use real id',
        () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor()..queueInsertId('server-uuid-xyz');
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_insertOp('offline_v1', {'name': 'Truck'},
          at: DateTime(2026, 1, 1, 9, 0)));
      await queue.enqueue(_updateOp('upd_v1_1', 'offline_v1', {'name': 'Big Truck'},
          at: DateTime(2026, 1, 1, 9, 1)));
      await queue.enqueue(_deleteOp('del_v1_1', 'offline_v1',
          at: DateTime(2026, 1, 1, 9, 2)));

      await queue.flush();

      expect(ex.inserts, hasLength(1));
      expect(ex.updates.first.$2, 'server-uuid-xyz');
      expect(ex.deletes.first.$2, 'server-uuid-xyz');
      expect(await store.getAll(), isEmpty);
    });

    test('foreign key in data is rewritten when parent insert succeeds', () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor()..queueInsertId('real-vehicle-id');
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      // Insert a vehicle offline, then insert a task that references it.
      await queue.enqueue(PendingOp(
        id: 'offline_vehicle1',
        table: 'vehicles',
        op: 'insert',
        data: {'brand': 'KamAZ'},
        createdAt: DateTime(2026, 1, 1, 10, 0),
      ));
      await queue.enqueue(PendingOp(
        id: 'offline_task1',
        table: 'tasks',
        op: 'insert',
        data: {'title': 'Check', 'vehicle_id': 'offline_vehicle1'},
        createdAt: DateTime(2026, 1, 1, 10, 1),
      ));

      await queue.flush();

      // The task insert must have its vehicle_id rewritten to the real id.
      final taskData = ex.inserts
          .firstWhere((e) => e.$1 == 'tasks')
          .$2;
      expect(taskData['vehicle_id'], 'real-vehicle-id');
    });

    // ── Test 2: concurrency ──────────────────────────────────────────────────

    test('concurrent flush() calls share one pass — op executed exactly once',
        () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor();
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_insertOp('offline_c1', {'title': 'X'}));

      // Both calls happen synchronously before any await yields control.
      final f1 = queue.flush();
      final f2 = queue.flush();
      final results = await Future.wait([f1, f2]);

      // One insert, not two.
      expect(ex.insertCallCount, 1);
      // Both futures resolved to the same result.
      expect(results[0], results[1]);
    });

    test('sequential flush() calls each start a fresh pass', () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor();
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_insertOp('offline_s1', {'a': '1'},
          at: DateTime(2026, 1, 1, 10, 0)));
      await queue.enqueue(_insertOp('offline_s2', {'a': '2'},
          at: DateTime(2026, 1, 1, 10, 1)));

      // First flush processes both.
      await queue.flush();
      expect(ex.insertCallCount, 2);
      expect(await store.getAll(), isEmpty);

      // Second flush on an empty queue.
      final ok = await queue.flush();
      expect(ok, isTrue);
      expect(ex.insertCallCount, 2); // no extra calls
    });

    // ── Test 3: poison / dead-letter ─────────────────────────────────────────

    test('permanent error dead-letters op after $maxQueueAttempts attempts', () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor()
        ..alwaysFailWith(Exception('constraint violation'));
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_insertOp('offline_p1', {'title': 'Bad'}));

      // First maxQueueAttempts-1 flushes: op stays in queue, not dead-lettered.
      for (var i = 0; i < maxQueueAttempts - 1; i++) {
        await queue.flush();
        final remaining = await store.getAll();
        expect(remaining, hasLength(1),
            reason: 'should still be queued after ${i + 1} attempt(s)');
        expect(remaining.first.attempts, i + 1);
        expect(store.deadLetter, isEmpty,
            reason: 'should not be dead-lettered yet');
      }

      // Final (maxQueueAttempts-th) flush: op reaches the limit → dead-lettered.
      await queue.flush();
      expect(await store.getAll(), isEmpty);
      expect(store.deadLetter, hasLength(1));
      expect(store.deadLetter.first['reason'] as String,
          contains('constraint violation'));
    });

    test('orphaned update is dead-lettered when its parent insert is dead-lettered',
        () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor()
        ..alwaysFailWith(Exception('rls violation'));
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_insertOp('offline_i1', {'title': 'Item'},
          at: DateTime(2026, 1, 1, 10, 0)));
      await queue.enqueue(_updateOp('upd_i1_1', 'offline_i1', {'title': 'Edited'},
          at: DateTime(2026, 1, 1, 10, 1)));

      // Drive insert to dead-letter threshold.
      for (var i = 0; i < maxQueueAttempts; i++) {
        await queue.flush();
      }

      // Both insert and its orphaned update must be in dead letter.
      expect(await store.getAll(), isEmpty);
      expect(store.deadLetter, hasLength(2));
      final reasons = store.deadLetter.map((e) => e['reason'] as String).toList();
      expect(reasons.any((r) => r.contains('rls violation')), isTrue);
      expect(reasons.any((r) => r.contains('orphaned')), isTrue);
    });

    test('network error stops flush without incrementing attempts', () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor()
        ..alwaysFailWith(SocketException('network is unreachable'));
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_insertOp('offline_n1', {'title': 'X'}));
      await queue.flush();

      final remaining = await store.getAll();
      expect(remaining, hasLength(1));
      expect(remaining.first.attempts, 0); // NOT incremented
    });

    test('real-rowId update/delete go through without temp-id mapping', () async {
      final store = MemoryQueueStore();
      final ex = RecordingExecutor();
      final queue = OfflineQueue.forTesting(executor: ex, store: store);

      await queue.enqueue(_updateOp('upd_r1_1', 'real-server-id',
          {'title': 'Online edit'}));

      await queue.flush();

      expect(ex.updates, hasLength(1));
      expect(ex.updates.first.$2, 'real-server-id');
      expect(await store.getAll(), isEmpty);
    });
  });
}
