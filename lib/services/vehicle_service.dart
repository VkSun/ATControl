import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../services/auth_service.dart';
import 'cache_service.dart';
import 'offline_queue.dart';
import 'offline_state.dart';
import 'supabase_client.dart';
import '../utils/date_utils.dart';
export 'supabase_client.dart';

// Фильтры по подразделению/участку (null = все; только для admin/full_access)
final selectedDepartmentProvider = StateProvider<String?>((ref) => null);
final selectedSectionProvider = StateProvider<String?>((ref) => null);

final vehicleServiceProvider = Provider((ref) => VehicleService());

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final role = await ref.watch(currentUserRoleProvider.future);

  if (role != null && !role.isAdmin && !role.permFullAccess) {
    return ref.read(vehicleServiceProvider).getAll(
          departmentId: role.departmentId,
          sectionId: role.sectionId,
        );
  }

  final deptId = ref.watch(selectedDepartmentProvider);
  final secId = ref.watch(selectedSectionProvider);
  return ref.read(vehicleServiceProvider).getAll(
        departmentId: deptId,
        sectionId: secId,
      );
});

class VehicleService {
  final _table = 'vehicles';

  String _cacheKey({String? departmentId, String? sectionId}) => sectionId != null
      ? 'vehicles_sec_$sectionId'
      : departmentId != null
          ? 'vehicles_dept_$departmentId'
          : 'vehicles_all';

  Future<List<Vehicle>> getAll({String? departmentId, String? sectionId}) async {
    final key = _cacheKey(departmentId: departmentId, sectionId: sectionId);
    try {
      final base = supabase.from(_table).select();
      final q = sectionId != null
          ? base.eq('section_id', sectionId)
          : departmentId != null
              ? base.eq('department_id', departmentId)
              : base;
      final data = (await q.order('inv_number')) as List;
      final maps = data.cast<Map<String, dynamic>>();
      unawaited(CacheService.instance.save(key, maps));
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return maps.map((e) => Vehicle.fromJson(e)).toList();
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached = await CacheService.instance.load(key);
        if (cached != null) return cached.map(Vehicle.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<List<Vehicle>> search(String query) async {
    final tokens = query.toLowerCase().split(RegExp(r'\s+'));
    final all = await getAll();
    return all.where((v) {
      final fields = [
        v.invNumber.toLowerCase(),
        v.brand.toLowerCase(),
        v.model.toLowerCase(),
        v.govNumber.toLowerCase(),
      ];
      return tokens.every((t) => fields.any((f) => f.contains(t)));
    }).toList();
  }

  Future<Vehicle> create(Vehicle v) async {
    try {
      final data =
          await supabase.from(_table).insert(v.toJson()).select().single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return Vehicle.fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final json = {...v.toJson(), 'id': tempId};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: tempId, table: _table, op: 'insert', data: v.toJson(),
          createdAt: DateTime.now(),
        ));
        await _patchAllCaches(id: tempId, json: json, op: 'insert', v: v);
        return Vehicle.fromJson(json);
      }
      rethrow;
    }
  }

  Future<Vehicle> update(String id, Vehicle v) async {
    try {
      final data = await supabase
          .from(_table)
          .update(v.toJson())
          .eq('id', id)
          .select()
          .single();
      isOfflineNotifier.value = false;
      unawaited(OfflineQueue.instance.flush());
      return Vehicle.fromJson(data);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final json = {...v.toJson(), 'id': id};
        await OfflineQueue.instance.enqueue(PendingOp(
          id: 'upd_${id}_${DateTime.now().millisecondsSinceEpoch}',
          table: _table, op: 'update', data: v.toJson(), rowId: id,
          createdAt: DateTime.now(),
        ));
        await _patchAllCaches(id: id, json: json, op: 'update', v: v);
        return Vehicle.fromJson(json);
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
    Vehicle? v,
  }) async {
    final keys = <String>{'vehicles_all'};
    if (v?.departmentId != null) keys.add('vehicles_dept_${v!.departmentId}');
    if (v?.sectionId != null) keys.add('vehicles_sec_${v!.sectionId}');
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

    for (final v in all) {
      void check(DateTime? date, String type) {
        if (date == null) return;
        final diff = daysUntil(date);
        if (diff <= 30) {
          result.add({'vehicle': v, 'type': type, 'date': date, 'diff': diff});
        }
      }
      check(v.inspectionDate, 'Техосмотр');
      check(v.insuranceDate, 'Страховка');
      check(v.specialPermitDate, 'Спец. разрешение');
      check(v.nextToDate, 'ТО автомобиля');
      check(v.nextEquipmentToDate, 'ТО оборудования');
    }

    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return result;
  }
}
