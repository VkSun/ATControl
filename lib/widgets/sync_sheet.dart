import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/driver_service.dart';
import '../services/offline_queue.dart';
import '../services/task_service.dart';
import '../services/vehicle_service.dart';
import '../utils/theme.dart';
import '../widgets/sidebar.dart' show pendingCountProvider;

/// Шторка «Синхронизация»: ожидающие операции офлайн-очереди и dead-letter.
Future<void> showSyncSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const SyncSheet(),
  );
}

String _opText(String op) => switch (op) {
      'insert' => 'создание',
      'update' => 'изменение',
      'delete' => 'удаление',
      _ => op,
    };

String _tableText(String table) => switch (table) {
      'vehicles' => 'Автомобиль',
      'drivers' => 'Водитель',
      'tasks' => 'Задача',
      _ => table,
    };

class SyncSheet extends ConsumerStatefulWidget {
  const SyncSheet({super.key});

  @override
  ConsumerState<SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<SyncSheet> {
  List<PendingOp> _pending = [];
  List<DeadLetterEntry> _dead = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await OfflineQueue.instance.getAll();
    final dead = await OfflineQueue.instance.deadLetters();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _dead = dead;
      _loading = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await OfflineQueue.instance.flush();
      // Данные могли измениться на сервере — перечитываем экраны.
      ref.invalidate(vehiclesProvider);
      ref.invalidate(driversProvider);
      ref.invalidate(tasksProvider);
      ref.invalidate(todayTasksProvider);
      ref.invalidate(pendingCountProvider);
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        await _load();
      }
    }
  }

  Future<void> _retryDead(DeadLetterEntry e) async {
    await OfflineQueue.instance.retryDeadLetter(e.op.id);
    await _load();
  }

  Future<void> _deleteDead(DeadLetterEntry e) async {
    await OfflineQueue.instance.deleteDeadLetter(e.op.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final fmt = DateFormat('dd.MM HH:mm');
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Text('Синхронизация',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        (_syncing || _pending.isEmpty) ? null : _syncNow,
                    icon: _syncing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5))
                        : const Icon(Icons.sync, size: 14),
                    label: const Text('Синхронизировать сейчас',
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    if (_pending.isEmpty && _dead.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: Text('Все изменения синхронизированы',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF888888)))),
                      ),
                    if (_pending.isNotEmpty) ...[
                      Text('ОЖИДАЮТ СИНХРОНИЗАЦИИ (${_pending.length})',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF888888),
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      ..._pending.map((op) => _OpRow(
                            title:
                                '${op.label ?? _tableText(op.table)}: ${_opText(op.op)}',
                            subtitle: fmt.format(op.createdAt),
                            colors: colors,
                          )),
                    ],
                    if (_dead.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('НЕ УДАЛОСЬ СИНХРОНИЗИРОВАТЬ (${_dead.length})',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: colors.badgeRedText,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      ..._dead.map((e) => _OpRow(
                            title:
                                '${e.op.label ?? _tableText(e.op.table)}: ${_opText(e.op.op)}',
                            subtitle:
                                '${fmt.format(e.op.createdAt)} · ${e.reason}',
                            colors: colors,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay, size: 16),
                                  tooltip: 'Повторить',
                                  onPressed: () => _retryDead(e),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16),
                                  tooltip: 'Удалить',
                                  onPressed: () => _deleteDead(e),
                                  color: const Color(0xFFE24B4A),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 28, minHeight: 28),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OpRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppColors colors;
  final Widget? trailing;

  const _OpRow({
    required this.title,
    required this.subtitle,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
