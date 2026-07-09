import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_client.dart';

final userAdminServiceProvider = Provider((ref) => UserAdminService());

/// Администрирование пользователей (таблица user_roles).
/// Экраны не ходят в Supabase напрямую — сервис переопределяется в тестах.
class UserAdminService {
  Future<void> setActive(String roleId, bool isActive) async {
    await supabase
        .from('user_roles')
        .update({'is_active': isActive}).eq('id', roleId);
  }

  Future<void> updatePermissions(
      String roleId, Map<String, dynamic> data) async {
    await supabase.from('user_roles').update(data).eq('id', roleId);
  }
}
