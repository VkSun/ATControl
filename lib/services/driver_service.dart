import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver.dart';
import '../services/auth_service.dart';
import 'vehicle_service.dart';

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

  Future<List<Driver>> getAll({String? departmentId, String? sectionId}) async {
    var q = supabase.from(_table).select().order('last_name');
    if (sectionId != null) {
      q = q.eq('section_id', sectionId);
    } else if (departmentId != null) {
      q = q.eq('department_id', departmentId);
    }
    final data = await q;
    return (data as List).map((e) => Driver.fromJson(e)).toList();
  }

  Future<List<Driver>> search(String query) async {
    final q = query.toLowerCase();
    final all = await getAll();
    return all.where((d) => d.fullName.toLowerCase().contains(q)).toList();
  }

  Future<Driver> create(Driver d) async {
    final data = await supabase.from(_table).insert(d.toJson()).select().single();
    return Driver.fromJson(data);
  }

  Future<Driver> update(String id, Driver d) async {
    final data = await supabase.from(_table).update(d.toJson()).eq('id', id).select().single();
    return Driver.fromJson(data);
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

    for (final d in all) {
      void check(DateTime? date, String type) {
        if (date == null) return;
        final diff = date.difference(now).inDays;
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
