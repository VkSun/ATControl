import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/department.dart';
import 'supabase_client.dart';

final departmentServiceProvider = Provider((ref) => DepartmentService());

final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  return ref.read(departmentServiceProvider).getDepartments();
});

final sectionsProvider = FutureProvider<List<Section>>((ref) async {
  return ref.read(departmentServiceProvider).getSections();
});

class DepartmentService {
  Future<List<Department>> getDepartments() async {
    final data = await supabase.from('departments').select().order('name');
    return (data as List).map((e) => Department.fromJson(e)).toList();
  }

  Future<List<Section>> getSections({String? departmentId}) async {
    final q = supabase.from('sections').select().order('name');
    final data = departmentId != null
        ? await q.eq('department_id', departmentId)
        : await q;
    return (data as List).map((e) => Section.fromJson(e)).toList();
  }

  Future<Department> createDepartment(String name) async {
    final data = await supabase
        .from('departments')
        .insert({'name': name})
        .select()
        .single();
    return Department.fromJson(data);
  }

  Future<void> updateDepartment(String id, String name) async {
    await supabase.from('departments').update({'name': name}).eq('id', id);
  }

  Future<void> deleteDepartment(String id) async {
    await supabase.from('departments').delete().eq('id', id);
  }

  Future<Section> createSection(String name, String departmentId) async {
    final data = await supabase
        .from('sections')
        .insert({'name': name, 'department_id': departmentId})
        .select()
        .single();
    return Section.fromJson(data);
  }

  Future<void> updateSection(String id, String name) async {
    await supabase.from('sections').update({'name': name}).eq('id', id);
  }

  Future<void> deleteSection(String id) async {
    await supabase.from('sections').delete().eq('id', id);
  }
}
