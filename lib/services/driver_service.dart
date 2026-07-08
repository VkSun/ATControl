import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart';
import 'offline_crud_service.dart';
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

class DriverService extends OfflineCrudService<Driver> {
  @override
  String get table => 'drivers';

  @override
  Driver fromJson(Map<String, dynamic> json) => Driver.fromJson(json);

  @override
  Map<String, dynamic> toJson(Driver item) => item.toJson();

  @override
  List<String> cacheKeysFor(Driver? item) => [
        'drivers_all',
        if (item?.departmentId != null) 'drivers_dept_${item!.departmentId}',
        if (item?.sectionId != null) 'drivers_sec_${item!.sectionId}',
      ];

  @override
  String describe(Driver? item) =>
      item == null ? 'Водитель' : 'Водитель ${item.shortName}';

  String _cacheKey({String? departmentId, String? sectionId}) => sectionId != null
      ? 'drivers_sec_$sectionId'
      : departmentId != null
          ? 'drivers_dept_$departmentId'
          : 'drivers_all';

  Future<List<Driver>> getAll({String? departmentId, String? sectionId}) =>
      fetchList(
        cacheKey: _cacheKey(departmentId: departmentId, sectionId: sectionId),
        query: () {
          final base = supabase.from(table).select();
          final q = sectionId != null
              ? base.eq('section_id', sectionId)
              : departmentId != null
                  ? base.eq('department_id', departmentId)
                  : base;
          return q.order('last_name');
        },
      );

  Future<List<Driver>> search(String query) async {
    final tokens = query.toLowerCase().split(RegExp(r'\s+'));
    final all = await getAll();
    return all.where((d) {
      final fields = [d.fullName.toLowerCase(), d.tabNumber.toLowerCase()];
      return tokens.every((t) => fields.any((f) => f.contains(t)));
    }).toList();
  }

  Future<Driver> create(Driver d) => createRow(d);

  Future<Driver> update(String id, Driver d) => updateRow(id, d);

  Future<void> delete(String id) => deleteRow(id);

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
