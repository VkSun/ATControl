import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import '../utils/trailing_throttle.dart';
import 'driver_service.dart';
import 'task_service.dart';
import 'vehicle_service.dart';

const _log = Logger('RealtimeInvalidation');

/// Живая подписка на изменения одной таблицы Supabase Realtime.
///
/// Не читает и не применяет payload — только триггерит [onChange] не чаще
/// раза в [debounce] (см. [TrailingThrottle]). Видимость строк
/// (get_my_tasks() с RPC-фильтрами, department/section-фильтры
/// vehicles/drivers) нельзя выразить через .stream()/.eq() — поэтому
/// слушаем все изменения таблицы через postgres_changes и просто
/// перезапрашиваем данные штатным путём.
class TableRealtimeInvalidator {
  final String table;
  final void Function() onChange;
  final Duration debounce;

  RealtimeChannel? _channel;
  late final TrailingThrottle _throttle =
      TrailingThrottle(onFire: onChange, window: debounce);
  bool _disposed = false;

  TableRealtimeInvalidator({
    required this.table,
    required this.onChange,
    this.debounce = const Duration(seconds: 2),
  }) {
    _subscribe();
  }

  void _subscribe() {
    // Суффикс — на случай, если предыдущий канал с тем же именем ещё не
    // успел закрыться (быстрый dispose/recreate, hot restart и т.п.).
    final channel = supabase.channel('invalidate:$table:${identityHashCode(this)}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => _throttle.trigger(),
    );
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        // Не фатально: приложение продолжает работать на ручном invalidate;
        // клиент сам переподключит сокет при восстановлении сети.
        _log.warning('$table realtime channel: $status', error);
      }
    });
    _channel = channel;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _throttle.dispose();
    final channel = _channel;
    if (channel != null) {
      // Future осознанно не ждём — отписка от закрытия виджета не зависит.
      unawaited(supabase.removeChannel(channel));
    }
  }
}

/// autoDispose: подписка живёт, пока активен MainLayout (см. виджет),
/// и закрывается вместе с ним — например, при выходе из системы.
final taskRealtimeProvider = Provider.autoDispose<void>((ref) {
  final invalidator = TableRealtimeInvalidator(
    table: 'tasks',
    onChange: () {
      ref.invalidate(tasksProvider);
      ref.invalidate(todayTasksProvider);
    },
  );
  ref.onDispose(invalidator.dispose);
});

final vehicleRealtimeProvider = Provider.autoDispose<void>((ref) {
  final invalidator = TableRealtimeInvalidator(
    table: 'vehicles',
    onChange: () => ref.invalidate(vehiclesProvider),
  );
  ref.onDispose(invalidator.dispose);
});

final driverRealtimeProvider = Provider.autoDispose<void>((ref) {
  final invalidator = TableRealtimeInvalidator(
    table: 'drivers',
    onChange: () => ref.invalidate(driversProvider),
  );
  ref.onDispose(invalidator.dispose);
});
