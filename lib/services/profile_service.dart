import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import 'vehicle_service.dart';

final profileProvider = FutureProvider<Profile>((ref) async {
  final data = await supabase.from('profiles').select().limit(1).single();
  return Profile.fromJson(data);
});

final profileServiceProvider = Provider((ref) => ProfileService());

class ProfileService {
  Future<Profile> get() async {
    final data = await supabase.from('profiles').select().limit(1).single();
    return Profile.fromJson(data);
  }

  Future<Profile> update(String id, Profile p) async {
    final data = await supabase
        .from('profiles').update(p.toJson()).eq('id', id).select().single();
    return Profile.fromJson(data);
  }
}