import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_error_text.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_emailCtrl, _passwordCtrl, _confirmCtrl,
      _fullNameCtrl, _positionCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final hasAdmin = await ref.read(authServiceProvider).hasAdmin();
      if (hasAdmin) {
        if (mounted) {
          setState(() => _error = AppLocalizations.of(context).registerAdminAlreadyExistsError);
        }
        return;
      }
      await ref.read(authServiceProvider).registerAdmin(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _fullNameCtrl.text.trim(),
        position: _positionCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
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
          width: 440,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.tableBorder, width: 0.5),
          ),
          child: Form(
            key: _formKey,
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
                Text(l10n.registerTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(l10n.registerSubtitle,
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.fullNameLabel,
                    prefixIcon: const Icon(Icons.person_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? l10n.requiredFieldError : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _positionCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.positionLabel,
                    prefixIcon: const Icon(Icons.work_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: const Icon(Icons.email_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? l10n.invalidEmailError : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
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
                  validator: (v) => v == null || v.length < 6
                      ? l10n.passwordTooShortError(6) : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: l10n.confirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  validator: (v) => v != _passwordCtrl.text
                      ? l10n.passwordMismatchError : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.badgeRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 14,
                            color: colors.badgeRedText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                            style: TextStyle(fontSize: 12,
                                color: colors.badgeRedText)),
                        ),
                      ],
                    ),
                  ),
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
                        : Text(l10n.registerButton,
                            style: const TextStyle(fontSize: 14)),
                  ),
                ),
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
      ),
    );
  }
}