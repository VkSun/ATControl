import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver.dart';
import 'vehicle_service.dart';

final driverServiceProvider = Provider((ref) => DriverService());

final driversProvider = FutureProvider<List<Driver>>((ref) async {
  return ref.read(driverServiceProvider).getAll();
});

class DriverService {
  final _table = 'drivers';

  Future<List<Driver>> getAll() async {
    final data = await supabase
        .from(_table)
        .select()
        .order('last_name');
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

  Future<List<Map<String, dynamic>>> getExpiring() async {
    final all = await getAll();
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