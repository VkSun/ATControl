import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';

const _log = Logger('ProfileDialog');

class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key});

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  late TextEditingController _fullName, _position, _initials;
  String _avatarColor = '#4361EE';
  bool _loading = false;

  final _colors = [
    '#4361EE', '#E24B4A', '#1D9E75', '#EF9F27',
    '#534AB7', '#D85A30', '#0F6E56', '#854F0B',
  ];

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _position = TextEditingController();
    _initials = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ref.read(profileServiceProvider).get();
      if (mounted) {
        setState(() {
          _fullName.text = p?.fullName ?? '';
          _position.text = p?.position ?? '';
          _initials.text = p?.initials ?? '';
          _avatarColor = p?.avatarColor ?? '#4361EE';
        });
      }
    } catch (e, s) {
      _log.warning('_loadProfile failed', e, s);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _position.dispose();
    _initials.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Сохранить профиль?'),
        content: const Text('Данные профиля будут обновлены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final updated = Profile(
        id: '',
        fullName: _fullName.text.trim(),
        position: _position.text.trim(),
        initials: _initials.text.trim().toUpperCase(),
        avatarColor: _avatarColor,
      );
      await ref.read(profileServiceProvider).save(updated);
      ref.invalidate(profileProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      title: const Text('Профиль'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: _hexToColor(_avatarColor),
                child: Text(
                  _initials.text.isEmpty ? 'АИ' : _initials.text,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _avatarColor = c),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _hexToColor(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _avatarColor == c ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: _avatarColor == c ? [
                      BoxShadow(color: _hexToColor(c).withOpacity(0.5),
                          blurRadius: 4, spreadRadius: 1)
                    ] : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Полное имя',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _position,
              decoration: const InputDecoration(
                labelText: 'Должность',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _initials,
              maxLength: 3,
              decoration: const InputDecoration(
                labelText: 'Инициалы (2–3 символа)',
                border: OutlineInputBorder(),
                isDense: true,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authServiceProvider).signOut();
              },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE24B4A)),
              child: const Text('Выйти из системы'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ],
    );
  }
}
