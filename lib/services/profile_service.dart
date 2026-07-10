import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../utils/brand_colors.dart';
import 'auth_service.dart' show currentUserProvider;
import 'cache_service.dart';
import 'offline_queue.dart' show isNetworkError;
import 'offline_state.dart';
import 'vehicle_service.dart';

// Следит за currentUserProvider, а не только вычисляется один раз: раньше
// profileProvider не пересчитывался ни на логин, ни на логаут, и в меню
// висел профиль предыдущего аккаунта до перезапуска приложения.
final profileProvider = FutureProvider<Profile?>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  if (userAsync.valueOrNull == null) return null;
  return ref.read(profileServiceProvider).get();
});

final profileServiceProvider = Provider((ref) => ProfileService());

// Ключ кэша содержит user id — общий ключ на все аккаунты мог после смены
// пользователя на этом же устройстве подсунуть офлайн-фоллбэком данные
// предыдущего аккаунта.
String _profileCacheKey(String userId) => 'profile_$userId';

class ProfileService {
  // Как currentUserRoleProvider: без офлайн-фоллбэка падение этого RPC
  // роняет profileProvider целиком — а он на экране почти всегда (аватар
  // в сайдбаре/топбаре), так что вместе с ним пропадал бы весь блок.
  Future<Profile?> get() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final cacheKey = _profileCacheKey(userId);

    try {
      // Логика «profiles, а если профиля нет — user_roles» едина для
      // приложения и расширения и живёт в БД: get_my_profile().
      final data = await supabase.rpc('get_my_profile');
      if (data == null) return null;
      final json = Map<String, dynamic>.from(data as Map);
      unawaited(CacheService.instance.save(cacheKey, [json]));
      isOfflineNotifier.value = false;
      return _fromRpcJson(userId, json);
    } catch (e) {
      if (isNetworkError(e)) {
        isOfflineNotifier.value = true;
        final cached = await CacheService.instance.load(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          return _fromRpcJson(userId, cached.first);
        }
      }
      rethrow;
    }
  }

  Profile _fromRpcJson(String userId, Map<String, dynamic> json) => Profile(
    id: userId,
    fullName: json['full_name'] as String? ?? '',
    position: json['position'] as String? ?? '',
    initials: json['initials'] as String? ?? '',
    avatarColor: json['avatar_color'] as String? ?? kPrimaryColorHex,
  );

  Future<Profile> save(Profile p) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Пользователь не авторизован');

    final json = p.toJson();
    json['id'] = userId;
    final data = await supabase
        .from('profiles')
        .upsert(json)
        .select()
        .single();

    // Синхронизируем имя/должность/инициалы/цвет в user_roles (через RPC — только display-поля)
    await supabase.rpc('sync_profile_display', params: {
      'p_full_name': p.fullName,
      'p_position': p.position,
      'p_initials': p.initials,
      'p_avatar_color': p.avatarColor,
    });

    return Profile.fromJson(data);
  }
}
