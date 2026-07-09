/// Custom exceptions for better error handling and type safety

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

/// Thrown by [AuthService.registerAdmin] when registration fails
class RegistrationFailedException implements Exception {
  final String message;
  const RegistrationFailedException(this.message);
  @override
  String toString() => message;
}

/// Thrown by [AuthService.signIn] when credentials are invalid
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
  @override
  String toString() => 'Неверный логин или пароль';
}

/// Thrown by [AuthService.validateInvitationCode] when code is invalid
class InvalidInvitationCodeException implements Exception {
  final String message;
  const InvalidInvitationCodeException(this.message);
  @override
  String toString() => message;
}

/// Thrown by [AuthService.registerWithInvitation] when redemption fails
class InvitationRedemptionException implements Exception {
  final String message;
  const InvitationRedemptionException(this.message);
  @override
  String toString() => message;
}
