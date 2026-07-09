import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../utils/brand_colors.dart';
import 'vehicle_service.dart';

final profileProvider = FutureProvider<Profile?>((ref) async {
  return ref.read(profileServiceProvider).get();
});

final profileServiceProvider = Provider((ref) => ProfileService());

class ProfileService {
  Future<Profile?> get() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    // Логика «profiles, а если профиля нет — user_roles» едина для
    // приложения и расширения и живёт в БД: get_my_profile().
    final data = await supabase.rpc('get_my_profile');
    if (data == null) return null;
    final json = Map<String, dynamic>.from(data as Map);
    return Profile(
      id: userId,
      fullName: json['full_name'] as String? ?? '',
      position: json['position'] as String? ?? '',
      initials: json['initials'] as String? ?? '',
      avatarColor: json['avatar_color'] as String? ?? kPrimaryColorHex,
    );
  }

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
