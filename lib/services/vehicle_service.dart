import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../services/auth_service.dart';
import 'supabase_client.dart';
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

  Future<List<Vehicle>> getAll({String? departmentId, String? sectionId}) async {
    var q = supabase.from(_table).select().order('inv_number');
    if (sectionId != null) {
      q = q.eq('section_id', sectionId);
    } else if (departmentId != null) {
      q = q.eq('department_id', departmentId);
    }
    final data = await q;
    return (data as List).map((e) => Vehicle.fromJson(e)).toList();
  }

  Future<List<Vehicle>> search(String query) async {
    final q = query.toLowerCase();
    final all = await getAll();
    return all
        .where((v) =>
            v.invNumber.toLowerCase().contains(q) ||
            v.brand.toLowerCase().contains(q) ||
            v.model.toLowerCase().contains(q) ||
            v.govNumber.toLowerCase().contains(q))
        .toList();
  }

  Future<Vehicle> create(Vehicle v) async {
    final data = await supabase.from(_table).insert(v.toJson()).select().single();
    return Vehicle.fromJson(data);
  }

  Future<Vehicle> update(String id, Vehicle v) async {
    final data =
        await supabase.from(_table).update(v.toJson()).eq('id', id).select().single();
    return Vehicle.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getExpiring({
    String? departmentId,
    String? sectionId,
  }) async {
    final all = await getAll(departmentId: departmentId, sectionId: sectionId);
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (final v in all) {
      void check(DateTime? date, String type) {
        if (date == null) return;
        final diff = date.difference(now).inDays;
        if (diff <= 30) {
          result.add({'vehicle': v, 'type': type, 'date': date, 'diff': diff});
        }
      }
      check(v.inspectionDate, 'Техосмотр');
      check(v.insuranceDate, 'Страховка');
      check(v.specialPermitDate, 'Спец. разрешение');
    }

    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return result;
  }
}
