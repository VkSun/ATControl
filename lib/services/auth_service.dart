import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../models/invitation_code.dart';
import 'supabase_client.dart';

final authServiceProvider = Provider((ref) => AuthService());

final currentUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.value;
  if (user == null) return null;
  try {
    final data = await supabase
        .from('user_roles')
        .select()
        .eq('user_id', user.id)
        .single();
    return UserRole.fromJson(data);
  } catch (_) {
    return null;
  }
});

class AuthService {
  // Регистрация первого админа
  Future<UserRole> registerAdmin({
    required String email,
    required String password,
    required String fullName,
    required String position,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Ошибка регистрации');

    final data = await supabase.rpc('register_first_admin', params: {
      'p_full_name': fullName,
      'p_position': position,
    });
    return UserRole.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // Вход по email/пароль
  Future<UserRole?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Неверный логин или пароль');

    try {
      final data = await supabase
          .from('user_roles')
          .select()
          .eq('user_id', response.user!.id)
          .single();
      final role = UserRole.fromJson(data);
      if (!role.isActive) {
        await supabase.auth.signOut();
        throw Exception('Ваш аккаунт заблокирован. Обратитесь к администратору.');
      }
      return role;
    } catch (e) {
      if (e.toString().contains('заблокирован')) rethrow;
      return null;
    }
  }

  // Активация кода приглашения
  Future<InvitationCode> validateInvitationCode(String code) async {
    final List data;
    try {
      data = await supabase
          .from('invitation_codes')
          .select()
          .eq('code', code.toUpperCase())
          .eq('is_used', false);
    } catch (_) {
      throw Exception('Код приглашения недействителен');
    }
    if (data.isEmpty) throw Exception('Код приглашения недействителен');
    final invitation = InvitationCode.fromJson(data.first as Map<String, dynamic>);
    if (invitation.isExpired) throw Exception('Код приглашения истёк');
    return invitation;
  }

  // Регистрация пользователя по коду приглашения
  Future<void> registerWithInvitation({
    required String email,
    required String password,
    required InvitationCode invitation,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Ошибка регистрации');

    // Permissions are set server-side from the invitation code — client cannot escalate.
    await supabase.rpc('register_with_invitation', params: {
      'p_code': invitation.code,
    });
  }

  // Выход
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Генерация кода приглашения
  Future<InvitationCode> generateInvitationCode({
    required String fullName,
    required String? position,
    required bool permFullAccess,
    required bool permEdit,
    required bool permExecute,
    required bool permRead,
    required bool permWrite,
    required bool permOwnOnly,
    String? departmentId,
    String? sectionId,
  }) async {
    final code = _generateCode();
    final data = await supabase.from('invitation_codes').insert({
      'code': code,
      'created_by': supabase.auth.currentUser!.id,
      'full_name': fullName,
      'position': position,
      'perm_full_access': permFullAccess,
      'perm_edit': permEdit,
      'perm_execute': permExecute,
      'perm_read': permRead,
      'perm_write': permWrite,
      'perm_own_only': permOwnOnly,
      'department_id': departmentId,
      'section_id': sectionId,
    }).select().single();
    return InvitationCode.fromJson(data);
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    final random = List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${random.substring(0, 4)}-${random.substring(4, 8)}-${random.substring(8, 12)}';
  }

  // Проверка существует ли уже админ
  Future<bool> hasAdmin() async {
    final result = await supabase.rpc('has_admin');
    return result as bool;
  }
}