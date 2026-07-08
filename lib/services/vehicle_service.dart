import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart';
import '../utils/inv_sort.dart';
import 'offline_crud_service.dart';
import 'supabase_client.dart';
export 'supabase_client.dart';

// Фильтры по подразделению/участку (null = все; только для admin/full_access)
final selectedDepartmentProvider = StateProvider<String?>((ref) => null);
final selectedSectionProvider = StateProvider<String?>((ref) => null);

final vehicleServiceProvider = Provider((ref) => VehicleService());

// Global (no autoDispose): shared across home, transport, and drivers screens simultaneously.
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

class VehicleService extends OfflineCrudService<Vehicle> {
  @override
  String get table => 'vehicles';

  @override
  Vehicle fromJson(Map<String, dynamic> json) => Vehicle.fromJson(json);

  @override
  Map<String, dynamic> toJson(Vehicle item) => item.toJson();

  @override
  List<String> cacheKeysFor(Vehicle? item) => [
        'vehicles_all',
        if (item?.departmentId != null) 'vehicles_dept_${item!.departmentId}',
        if (item?.sectionId != null) 'vehicles_sec_${item!.sectionId}',
      ];

  @override
  String describe(Vehicle? item) =>
      item == null ? 'Автомобиль' : 'Автомобиль ${item.invNumber}';

  // Числовой порядок инвентарных номеров — и для сети, и для кэша/офлайна.
  @override
  List<Vehicle> processList(List<Vehicle> list) =>
      list..sort((a, b) => compareInvNumbers(a.invNumber, b.invNumber));

  String _cacheKey({String? departmentId, String? sectionId}) => sectionId != null
      ? 'vehicles_sec_$sectionId'
      : departmentId != null
          ? 'vehicles_dept_$departmentId'
          : 'vehicles_all';

  Future<List<Vehicle>> getAll({String? departmentId, String? sectionId}) =>
      fetchList(
        cacheKey: _cacheKey(departmentId: departmentId, sectionId: sectionId),
        query: () {
          final base = supabase.from(table).select();
          final q = sectionId != null
              ? base.eq('section_id', sectionId)
              : departmentId != null
                  ? base.eq('department_id', departmentId)
                  : base;
          return q.order('inv_number');
        },
      );

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

  Future<Vehicle> create(Vehicle v) => createRow(v);

  Future<Vehicle> update(String id, Vehicle v) => updateRow(id, v);

  Future<void> delete(String id) => deleteRow(id);

  Future<List<Map<String, dynamic>>> getExpiring({
    String? departmentId,
    String? sectionId,
  }) async {
    final all = await getAll(departmentId: departmentId, sectionId: sectionId);
    final result = <Map<String, dynamic>>[];

    for (final v in all) {
      for (final entry in v.expiryDates()) {
        if (entry.date == null) continue;
        final diff = daysUntil(entry.date!);
        if (diff <= 30) {
          result.add({'vehicle': v, 'type': entry.type, 'date': entry.date, 'diff': diff});
        }
      }
    }

    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return result;
  }
}
