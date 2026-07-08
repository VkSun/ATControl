/// Thrown by [AuthService.signIn] when the user's account is marked inactive.
class AccountBlockedException implements Exception {
  const AccountBlockedException();
  @override
  String toString() => 'Ваш аккаунт заблокирован. Обратитесь к администратору.';
}

/// Thrown by [AuthService.signIn] when auth succeeded but no user_roles row
/// was found for the authenticated user (PGRST116 from .single()).
class RoleNotFoundException implements Exception {
  const RoleNotFoundException();
  @override
  String toString() => 'Учётная запись не найдена. Обратитесь к администратору.';
}
