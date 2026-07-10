import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_exceptions.dart';
import '../models/user_role.dart';
import '../models/invitation_code.dart';
import '../utils/logger.dart';
import 'cache_service.dart';
import 'offline_queue.dart' show isNetworkError;
import 'offline_state.dart';
import 'supabase_client.dart';

final _log = Logger('AuthService');

final authServiceProvider = Provider((ref) => AuthService());

final currentUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((event) => event.session?.user);
});

// Ключ кэша содержит user id: раньше был общий на все аккаунты — после
// смены пользователя на этом же устройстве офлайн-фоллбэк мог подсунуть
// данные предыдущего аккаунта.
String _roleCacheKey(String userId) => 'user_role_$userId';

// currentUserRoleProvider раньше не имел офлайн-фоллбэка: при потере сети
// он падал с ошибкой, а от него зависят vehiclesProvider/driversProvider
// (ждут role.departmentId/sectionId для фильтрации до похода в fetchList())
// — их собственный дисковый кэш из-за этого не получал шанса сработать,
// и вместо старых данных пользователь видел пустой экран/ошибку.
final currentUserRoleProvider = FutureProvider<UserRole?>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return null;
  final cacheKey = _roleCacheKey(user.id);
  try {
    // Общая для приложения и расширения логика профиля — в БД (get_my_profile).
    final data = await supabase.rpc('get_my_profile');
    if (data == null) return null; // пользователя нет в user_roles
    final map = Map<String, dynamic>.from(data as Map);
    unawaited(CacheService.instance.save(cacheKey, [map]));
    isOfflineNotifier.value = false;
    return UserRole.fromJson(map);
  } catch (e, s) {
    if (isNetworkError(e)) {
      isOfflineNotifier.value = true;
      final cached = await CacheService.instance.load(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return UserRole.fromJson(cached.first);
      }
    }
    _log.warning('currentUserRoleProvider failed', e, s);
    rethrow;
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
    if (response.user == null) throw const SignUpFailedException();

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
    if (response.user == null) throw const InvalidCredentialsException();

    try {
      final data = await supabase
          .from('user_roles')
          .select(UserRole.columns)
          .eq('user_id', response.user!.id)
          .single();
      final role = UserRole.fromJson(data);
      if (!role.isActive) {
        await supabase.auth.signOut();
        throw AccountBlockedException();
      }
      return role;
    } on AccountBlockedException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        await supabase.auth.signOut();
        throw RoleNotFoundException();
      }
      _log.warning('signIn: role fetch failed', e);
      return null;
    } catch (e, s) {
      _log.warning('signIn: unexpected error', e, s);
      return null;
    }
  }

  // Активация кода приглашения
  Future<InvitationCode> validateInvitationCode(String code) async {
    final List data;
    try {
      data = await supabase
          .from('invitation_codes')
          .select(InvitationCode.columns)
          .eq('code', code.toUpperCase())
          .eq('is_used', false)
          .limit(1);
    } catch (e, s) {
      _log.warning('validateInvitationCode failed', e, s);
      throw const InvitationCodeInvalidException();
    }
    if (data.isEmpty) throw const InvitationCodeInvalidException();
    final invitation = InvitationCode.fromJson(data.first as Map<String, dynamic>);
    if (invitation.isExpired) throw const InvitationCodeExpiredException();
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
    if (response.user == null) throw const SignUpFailedException();

    try {
      // Все три операции (user_roles + profiles + mark used) выполняются
      // атомарно в одной транзакции с FOR UPDATE на строке приглашения.
      await supabase.rpc('redeem_invitation', params: {'p_code': invitation.code});
    } on PostgrestException catch (e) {
      // RPC провалилась — откатываем сессию, чтобы не оставлять auth-пользователя без роли.
      await supabase.auth.signOut();
      throw RedeemInvitationException.fromMessage(e.message);
    }
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