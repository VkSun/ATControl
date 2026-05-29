import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import 'vehicle_service.dart';

final profileProvider = FutureProvider<Profile?>((ref) async {
  return ref.read(profileServiceProvider).get();
});

final profileServiceProvider = Provider((ref) => ProfileService());

class ProfileService {
  Future<Profile?> get() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data != null) return Profile.fromJson(data);

    // Профиль ещё не создан — берём данные из user_roles
    try {
      final role = await supabase
          .from('user_roles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (role == null) return null;
      return Profile(
        id: userId,
        fullName: role['full_name'] ?? '',
        position: role['position'] ?? '',
        initials: role['initials'] ?? '',
        avatarColor: role['avatar_color'] ?? '#4361EE',
      );
    } catch (_) {
      return null;
    }
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

    // Синхронизируем имя/должность/инициалы/цвет в user_roles
    await supabase.from('user_roles').update({
      'full_name': p.fullName,
      'position': p.position,
      'initials': p.initials,
      'avatar_color': p.avatarColor,
    }).eq('user_id', userId);

    return Profile.fromJson(data);
  }
}
