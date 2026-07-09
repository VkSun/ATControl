// Типизированные ошибки аутентификации. Сервис не знает про BuildContext —
// текст для пользователя выбирает экран (см. lib/screens/auth/auth_error_text.dart).
// toString() ниже — техническое сообщение для логов, не для показа в UI.

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

/// Thrown by [AuthService.signIn] on wrong email/password.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
  @override
  String toString() => 'Неверный логин или пароль';
}

/// Thrown by [AuthService.registerAdmin] / [AuthService.registerWithInvitation]
/// when Supabase returns no user for a sign-up call.
class SignUpFailedException implements Exception {
  const SignUpFailedException();
  @override
  String toString() => 'Ошибка регистрации';
}

/// Thrown by [AuthService.validateInvitationCode] when the code doesn't
/// exist, was already used, or the lookup itself failed.
class InvitationCodeInvalidException implements Exception {
  const InvitationCodeInvalidException();
  @override
  String toString() => 'Код приглашения недействителен';
}

/// Thrown by [AuthService.validateInvitationCode] when the code is expired.
class InvitationCodeExpiredException implements Exception {
  const InvitationCodeExpiredException();
  @override
  String toString() => 'Код приглашения истёк';
}

/// Reasons redeem_invitation() (Postgres RPC) can reject a code — mirrors
/// its error markers, checked by [AuthService.registerWithInvitation].
enum RedeemInvitationFailure { notFound, alreadyUsed, expired, unknown }

class RedeemInvitationException implements Exception {
  final RedeemInvitationFailure reason;
  const RedeemInvitationException(this.reason);

  factory RedeemInvitationException.fromMessage(String? msg) {
    if (msg == null) {
      return const RedeemInvitationException(RedeemInvitationFailure.unknown);
    }
    if (msg.contains('invitation_not_found')) {
      return const RedeemInvitationException(RedeemInvitationFailure.notFound);
    }
    if (msg.contains('invitation_used')) {
      return const RedeemInvitationException(RedeemInvitationFailure.alreadyUsed);
    }
    if (msg.contains('invitation_expired')) {
      return const RedeemInvitationException(RedeemInvitationFailure.expired);
    }
    return const RedeemInvitationException(RedeemInvitationFailure.unknown);
  }

  @override
  String toString() => switch (reason) {
        RedeemInvitationFailure.notFound => 'Код приглашения не найден',
        RedeemInvitationFailure.alreadyUsed => 'Код приглашения уже использован',
        RedeemInvitationFailure.expired => 'Срок действия кода истёк',
        RedeemInvitationFailure.unknown => 'Ошибка активации кода приглашения',
      };
}
