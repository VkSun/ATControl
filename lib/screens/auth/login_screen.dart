import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
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
                      color: const Color(0xFF4361EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_car,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('ATControl',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Вход в систему',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Введите ваши данные для входа',
                style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
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
                onSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Пароль',
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
                      Text(_error!,
                        style: TextStyle(fontSize: 12,
                            color: colors.badgeRedText)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _signIn,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Войти',
                          style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Первый запуск? Зарегистрировать админа',
                    style: TextStyle(fontSize: 12)),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/invite'),
                  child: const Text('Есть код приглашения? Активировать',
                    style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}