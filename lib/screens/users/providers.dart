import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invitation_code.dart';
import '../../models/user_role.dart';
import '../../services/supabase_client.dart';

final invitationsProvider = FutureProvider.autoDispose<List<InvitationCode>>((ref) async {
  final data = await supabase
      .from('invitation_codes')
      .select(InvitationCode.columns)
      .order('created_at', ascending: false);
  return (data as List).map((e) => InvitationCode.fromJson(e)).toList();
});

final usersProvider = FutureProvider.autoDispose<List<UserRole>>((ref) async {
  final data = await supabase
      .from('user_roles')
      .select(UserRole.columns)
      .order('created_at');
  return (data as List).map((e) => UserRole.fromJson(e)).toList();
});
