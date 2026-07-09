import 'package:flutter/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/auth_exceptions.dart';

/// Подбирает локализованный текст для типизированных ошибок AuthService.
/// Сервис не знает про BuildContext — весь выбор текста происходит здесь,
/// на стороне экрана.
String authErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  return switch (error) {
    InvalidCredentialsException() => l10n.authInvalidCredentialsError,
    AccountBlockedException() => l10n.authAccountBlockedError,
    RoleNotFoundException() => l10n.authRoleNotFoundError,
    SignUpFailedException() => l10n.authSignUpFailedError,
    RedeemInvitationException(:final reason) => switch (reason) {
        RedeemInvitationFailure.notFound => l10n.authRedeemNotFoundError,
        RedeemInvitationFailure.alreadyUsed => l10n.authRedeemAlreadyUsedError,
        RedeemInvitationFailure.expired => l10n.authRedeemExpiredError,
        RedeemInvitationFailure.unknown => l10n.authRedeemUnknownError,
      },
    _ => l10n.authGenericError,
  };
}
