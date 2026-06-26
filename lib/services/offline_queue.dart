import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'offline_state.dart';
import 'supabase_client.dart';

class PendingOp {
  final String id;
  final String table;
  final String op; // insert | update | delete
  final Map<String, dynamic> data;
  final String? rowId;
  final DateTime createdAt;

  PendingOp({
    required this.id,
    required this.table,
    required this.op,
    required this.data,
    this.rowId,
    required this.createdAt,
  });

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        id: j['id'] as String,
        table: j['table'] as String,
        op: j['op'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map),
        rowId: j['row_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'op': op,
        'data': data,
        'row_id': rowId,
        'created_at': createdAt.toIso8601String(),
      };
}

class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/atc_pending.json');
  }

  Future<List<PendingOp>> getAll() async {
    try {
      final f = await _file;
      if (!await f.exists()) return [];
      final list = jsonDecode(await f.readAsString()) as List;
      return list
          .map((e) => PendingOp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> get count async => (await getAll()).length;

  Future<void> enqueue(PendingOp op) async {
    final all = await getAll();
    all.add(op);
    await _persist(all);
    queueCountNotifier.value = all.length;
  }

  // Returns true when all ops were successfully sent.
  Future<bool> flush() async {
    final all = await getAll();
    if (all.isEmpty) return true;
    final done = <String>[];
    for (final op in all) {
      try {
        switch (op.op) {
          case 'insert':
            final json = Map<String, dynamic>.from(op.data);
            // Remove temp offline ID so server assigns a real UUID.
            if ((json['id'] as String? ?? '').startsWith('offline_')) {
              json.remove('id');
            }
            await supabase.from(op.table).insert(json);
          case 'update':
            if (op.rowId != null && !op.rowId!.startsWith('offline_')) {
              await supabase.from(op.table).update(op.data).eq('id', op.rowId!);
            }
          case 'delete':
            if (op.rowId != null && !op.rowId!.startsWith('offline_')) {
              await supabase.from(op.table).delete().eq('id', op.rowId!);
            }
        }
        done.add(op.id);
      } catch (e) {
        if (isNetworkError(e)) break; // still offline — stop replaying
      }
    }
    if (done.isNotEmpty) {
      final remaining = all.where((o) => !done.contains(o.id)).toList();
      await _persist(remaining);
      queueCountNotifier.value = remaining.length;
    }
    final remaining = await count;
    if (remaining == 0) isOfflineNotifier.value = false;
    return remaining == 0;
  }

  Future<void> _persist(List<PendingOp> ops) async {
    try {
      final f = await _file;
      await f.writeAsString(
          jsonEncode(ops.map((e) => e.toJson()).toList()),
          flush: true);
    } catch (_) {}
  }
}

bool isNetworkError(Object e) {
  if (e is SocketException) return true;
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
