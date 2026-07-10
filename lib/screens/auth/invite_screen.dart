import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/invitation_code.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_error_text.dart';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  InvitationCode? _invitation;
  int _step = 1;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final l10n = AppLocalizations.of(context);
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = l10n.inviteEnterCodeError);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final invitation = await ref.read(authServiceProvider)
          .validateInvitationCode(_codeCtrl.text.trim());
      setState(() { _invitation = invitation; _step = 2; });
    } catch (e) {
      // Экран не различает «не найден»/«истёк» — единое сообщение,
      // как и раньше; тип ошибки нужен лишь другим экранам auth.
      if (mounted) setState(() => _error = l10n.inviteCodeInvalidOrExpiredError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = l10n.fillAllFieldsError);
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _error = l10n.passwordTooShortError(6));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).registerWithInvitation(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        invitation: _invitation!,
      );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.tableBorder, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.appTitle,
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 32),
              if (_step == 1) ...[
                Text(l10n.inviteCodeLabel,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(l10n.inviteCodeSubtitle,
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.inviteCodeLabel,
                    hintText: l10n.inviteCodeHint,
                    prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBox(error: _error!, colors: colors),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _validateCode,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l10n.inviteVerifyButton),
                  ),
                ),
              ] else ...[
                Text(l10n.inviteCreateAccountTitle,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(l10n.inviteWelcomeSubtitle(_invitation!.fullName ?? ''),
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: l10n.confirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBox(error: _error!, colors: colors),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _register,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(l10n.inviteRegisterButton),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.alreadyHaveAccountLink,
                    style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  final AppColors colors;
  const _ErrorBox({required this.error, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.badgeRed,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: colors.badgeRedText),
          const SizedBox(width: 8),
          Expanded(child: Text(error,
            style: TextStyle(fontSize: 12, color: colors.badgeRedText))),
        ],
      ),
    );
  }
}