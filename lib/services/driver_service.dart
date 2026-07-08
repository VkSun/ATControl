import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver.dart';
import '../services/auth_service.dart';
import 'cache_service.dart';
import 'offline_queue.dart';
import 'offline_state.dart';
import 'vehicle_service.dart';
import '../utils/date_utils.dart';

final driverServiceProvider = Provider((ref) => DriverService());

final driversProvider = FutureProvider<List<Driver>>((ref) async {
  final role = await ref.watch(currentUserRoleProvider.future);

  if (role != null && !role.isAdmin && !role.permFullAccess) {
    return ref.read(driverServiceProvider).getAll(
          departmentId: role.departmentId,
          sectionId: role.sectionId,
        );
  }

  final deptId = ref.watch(selectedDepartmentProvider);
  final secId = ref.watch(selectedSectionProvider);
  return ref.read(driverServiceProvider).getAll(
        departmentId: deptId,
        sectionId: secId,
      );
});

class DriverService {
  final _table = 'drivers';

  String _cacheKey({String? departmentId, String? sectionId}) => sectionId != null
      ? 'drivers_sec_$sectionId'
      : departmentId != null
          ? 'drivers_dept_$departmentId'
          : 'drivers_all';

  Future<List<Driver>> getAll({String? departmentId, String? sectionId}) async {
    final key = _cacheKey(departmentId: departmentId, sectionId: sectionId);
    try {
      final base = supabase.from(_table).select();
      final q = sectionId != null
          ? base.eq('section_id', sectionId)
          : departmentId != null
              ? base.eq('department_id', departmentId)
              : base;
      final data = (await q.order('last_name')) as List;
      final maps = data.cast<Map<String, dynamic>>();
      unawaited(CacheService.instance.save(key, maps));
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return maps.map((e) => Driver.fromJson(e)).toList();
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached = await CacheService.instance.load(key);
        if (cached != null) return cached.map(Driver.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<Driver>> search(String query) async {
    final tokens = query.toLowerCase().split(RegExp(r'\s+'));
    final all = await getAll();
    return all.where((d) {
      final fields = [d.fullName.toLowerCase(), d.tabNumber.toLowerCase()];
      return tokens.every((t) => fields.any((f) => f.contains(t)));
    }).toList();
  }

  Future<Driver> create(Driver d) async {
    try {
      final data =
          await supabase.from(_table).insert(d.toJson()).select().single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return Driver.fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final json = {...d.toJson(), 'id': tempId};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: tempId, table: _table, op: 'insert', data: d.toJson(),
          createdAt: DateTime.now(),
        ));
        await _patchAllCaches(id: tempId, json: json, op: 'insert', d: d);
        return Driver.fromJson(json);
      }
      rethrow;
    }
  }

  Future<Driver> update(String id, Driver d) async {
    try {
      final data = await supabase
          .from(_table)
          .update(d.toJson())
          .eq('id', id)
          .select()
          .single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return Driver.fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final json = {...d.toJson(), 'id': id};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'upd_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: _table, op: 'update', data: d.toJson(), rowId: id,
          createdAt: DateTime.now(),
        ));
        await _patchAllCaches(id: id, json: json, op: 'update', d: d);
        return Driver.fromJson(json);
      }
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await supabase.from(_table).delete().eq('id', id);
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'del_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: _table, op: 'delete', data: {}, rowId: id,
          createdAt: DateTime.now(),
        ));
        await _patchAllCaches(id: id, json: {}, op: 'delete');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _patchAllCaches({
    required String id,
    required Map<String, dynamic> json,
    required String op,
    Driver? d,
  }) async {
    final keys = <String>{'drivers_all'};
    if (d?.departmentId != null) keys.add('drivers_dept_${d!.departmentId}');
    if (d?.sectionId != null) keys.add('drivers_sec_${d!.sectionId}');
    for (final key in keys) {
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

  Future<List<Map<String, dynamic>>> getExpiring({
    String? departmentId,
    String? sectionId,
  }) async {
    final all = await getAll(departmentId: departmentId, sectionId: sectionId);
    final result = <Map<String, dynamic>>[];

    for (final d in all) {
      void check(DateTime? date, String type) {
        if (date == null) return;
        final diff = daysUntil(date);
        if (diff <= 30) {
          result.add({'driver': d, 'type': type, 'date': date, 'diff': diff});
        }
      }
      check(d.licenseExpiry, 'Вод. удостоверение');
      check(d.medicalExpiry, 'Мед. справка');
    }

    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return result;
  }
}
