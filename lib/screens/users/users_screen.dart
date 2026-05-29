import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/invitation_code.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';
import '../../utils/theme.dart';

final invitationsProvider = FutureProvider<List<InvitationCode>>((ref) async {
  final data = await supabase
      .from('invitation_codes')
      .select()
      .order('created_at', ascending: false);
  return (data as List).map((e) => InvitationCode.fromJson(e)).toList();
});

final usersProvider = FutureProvider<List<UserRole>>((ref) async {
  final data = await supabase.from('user_roles').select().order('created_at');
  return (data as List).map((e) => UserRole.fromJson(e)).toList();
});

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        _TopBar(
            colors: colors,
            ref: ref,
            onAddInvitation: () => _openCreateInvitation(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _TabBtn('Пользователи', 0, _tab, (v) => setState(() => _tab = v),
                  colors),
              const SizedBox(width: 8),
              _TabBtn('Коды приглашений', 1, _tab,
                  (v) => setState(() => _tab = v), colors),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _tab == 0
                ? _UsersTab(colors: colors, ref: ref)
                : _InvitationsTab(colors: colors, ref: ref),
          ),
        ),
      ],
    );
  }

  void _openCreateInvitation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateInvitationDialog(
        onSaved: () => ref.invalidate(invitationsProvider),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final int value, current;
  final ValueChanged<int> onTap;
  final AppColors colors;

  const _TabBtn(this.label, this.value, this.current, this.onTap, this.colors);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4361EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF4361EE) : colors.tableBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active
                ? Colors.white
                : Theme.of(context).textTheme.bodySmall!.color,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppColors colors;
  final WidgetRef ref;
  final VoidCallback onAddInvitation;

  const _TopBar({
    required this.colors,
    required this.ref,
    required this.onAddInvitation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border:
            Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Пользователи', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAddInvitation,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Создать приглашение',
                style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: Size.zero,
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_outlined, size: 20),
          const SizedBox(width: 12),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(profileProvider);
              final initials = profileAsync.value?.initials ?? 'АИ';
              final color = profileAsync.value?.avatarColor ?? '#4361EE';
              final avatarColor =
                  Color(int.parse(color.replaceFirst('#', '0xFF')));
              return GestureDetector(
                onTap: () => showDialog(
                    context: context, builder: (_) => const ProfileDialog()),
                child: CircleAvatar(
                    radius: 16,
                    backgroundColor: avatarColor,
                    child: Text(initials,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white))),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  final AppColors colors;
  final WidgetRef ref;

  const _UsersTab({required this.colors, required this.ref});

  String _permsText(UserRole role) {
    if (role.isAdmin) return 'Администратор';
    final perms = <String>[];
    if (role.permFullAccess) perms.add('Полный доступ');
    if (role.permEdit) perms.add('Изменение');
    if (role.permExecute) perms.add('Выполнение');
    if (role.permRead) perms.add('Чтение');
    if (role.permWrite) perms.add('Запись');
    if (role.permOwnOnly) perms.add('Только своё');
    return perms.isEmpty ? '—' : perms.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
            ),
            child: Row(
              children: [
                _th('Имя', 200),
                _th('Должность', 160),
                _th('Права', 220),
                _th('Статус', 100),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('Нет пользователей'));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return GestureDetector(
                      onTap: u.isAdmin
                          ? null
                          : () => showDialog(
                                context: context,
                                builder: (_) => _EditUserDialog(
                                  user: u,
                                  onSaved: () => ref.invalidate(usersProvider),
                                ),
                              ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: colors.tableBorder, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 200,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(int.parse(u
                                        .avatarColor
                                        .replaceFirst('#', '0xFF'))),
                                    child: Text(u.initials,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(u.fullName,
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                                width: 160,
                                child: Text(u.position ?? '—',
                                    style: const TextStyle(fontSize: 12))),
                            SizedBox(
                                width: 220,
                                child: Text(_permsText(u),
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis)),
                            SizedBox(
                              width: 100,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: u.isActive
                                      ? colors.badgeGreen
                                      : colors.badgeRed,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                    u.isActive ? 'Активен' : 'Заблокирован',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: u.isActive
                                            ? colors.badgeGreenText
                                            : colors.badgeRedText)),
                              ),
                            ),
                            const Spacer(),
                            if (!u.isAdmin)
                              IconButton(
                                icon: Icon(
                                  u.isActive
                                      ? Icons.block_outlined
                                      : Icons.check_circle_outline,
                                  size: 16,
                                ),
                                onPressed: () => _toggleActive(context, ref, u),
                                tooltip: u.isActive
                                    ? 'Заблокировать'
                                    : 'Разблокировать',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                color: u.isActive
                                    ? const Color(0xFFE24B4A)
                                    : const Color(0xFF639922),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String label, double width) => SizedBox(
        width: width,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888))),
      );

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, UserRole user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.isActive
            ? 'Заблокировать пользователя?'
            : 'Разблокировать пользователя?'),
        content: Text(user.fullName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive
                  ? const Color(0xFFE24B4A)
                  : const Color(0xFF4361EE),
            ),
            child: Text(user.isActive ? 'Заблокировать' : 'Разблокировать'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await supabase
          .from('user_roles')
          .update({'is_active': !user.isActive}).eq('id', user.id);
      ref.invalidate(usersProvider);
    }
  }
}

class _InvitationsTab extends ConsumerWidget {
  final AppColors colors;
  final WidgetRef ref;

  const _InvitationsTab({required this.colors, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(invitationsProvider);
    final fmt = DateFormat('dd.MM.yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
            ),
            child: Row(
              children: [
                _th('Код', 160),
                _th('Имя пользователя', 200),
                _th('Должность', 150),
                _th('Права', 200),
                _th('Статус', 110),
                _th('Истекает', 120),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: invitationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
              data: (invitations) {
                if (invitations.isEmpty) {
                  return const Center(child: Text('Нет кодов приглашений'));
                }
                return ListView.builder(
                  itemCount: invitations.length,
                  itemBuilder: (context, i) => _InvitationRow(
                    invitation: invitations[i],
                    colors: colors,
                    fmt: fmt,
                    onDelete: () async {
                      await supabase
                          .from('invitation_codes')
                          .delete()
                          .eq('id', invitations[i].id);
                      ref.invalidate(invitationsProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String label, double width) => SizedBox(
        width: width,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888888))),
      );
}

class _InvitationRow extends StatelessWidget {
  final InvitationCode invitation;
  final AppColors colors;
  final DateFormat fmt;
  final VoidCallback onDelete;

  const _InvitationRow({
    required this.invitation,
    required this.colors,
    required this.fmt,
    required this.onDelete,
  });

  String _permsText() {
    final perms = <String>[];
    if (invitation.permFullAccess) perms.add('Полный доступ');
    if (invitation.permEdit) perms.add('Изменение');
    if (invitation.permExecute) perms.add('Выполнение');
    if (invitation.permRead) perms.add('Чтение');
    if (invitation.permWrite) perms.add('Запись');
    if (invitation.permOwnOnly) perms.add('Только своё');
    return perms.isEmpty ? '—' : perms.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isValid = invitation.isValid;
    final isUsed = invitation.isUsed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.badgeGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(invitation.code,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.badgeGreenText)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: invitation.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Код скопирован'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 200,
                      ),
                    );
                  },
                  child: Icon(Icons.copy,
                      size: 14,
                      color: Theme.of(context).textTheme.bodySmall!.color),
                ),
              ],
            ),
          ),
          SizedBox(
              width: 200,
              child: Text(invitation.fullName ?? '—',
                  style: const TextStyle(fontSize: 12))),
          SizedBox(
              width: 150,
              child: Text(invitation.position ?? '—',
                  style: const TextStyle(fontSize: 12))),
          SizedBox(
              width: 200,
              child: Text(_permsText(),
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 110,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isUsed
                    ? colors.badgeAmber
                    : isValid
                        ? colors.badgeGreen
                        : colors.badgeRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isUsed
                    ? 'Использован'
                    : isValid
                        ? 'Активен'
                        : 'Истёк',
                style: TextStyle(
                    fontSize: 10,
                    color: isUsed
                        ? colors.badgeAmberText
                        : isValid
                            ? colors.badgeGreenText
                            : colors.badgeRedText),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              invitation.expiresAt != null
                  ? fmt.format(invitation.expiresAt!)
                  : '—',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const Spacer(),
          if (!isUsed)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить код?'),
                    content: Text('Код ${invitation.code} будет удалён.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE24B4A)),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onDelete();
              },
              color: const Color(0xFFE24B4A),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

class _CreateInvitationDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _CreateInvitationDialog({required this.onSaved});

  @override
  ConsumerState<_CreateInvitationDialog> createState() =>
      _CreateInvitationDialogState();
}

class _CreateInvitationDialogState
    extends ConsumerState<_CreateInvitationDialog> {
  final _fullNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  bool _permFullAccess = false;
  bool _permEdit = false;
  bool _permExecute = false;
  bool _permRead = true;
  bool _permWrite = false;
  bool _permOwnOnly = false;
  bool _loading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_fullNameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final invitation =
          await ref.read(authServiceProvider).generateInvitationCode(
                fullName: _fullNameCtrl.text.trim(),
                position: _positionCtrl.text.trim().isEmpty
                    ? null
                    : _positionCtrl.text.trim(),
                permFullAccess: _permFullAccess,
                permEdit: _permEdit,
                permExecute: _permExecute,
                permRead: _permRead,
                permWrite: _permWrite,
                permOwnOnly: _permOwnOnly,
              );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => _ShowCodeDialog(code: invitation.code),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создать приглашение'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fullNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Полное имя пользователя',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _positionCtrl,
              decoration: const InputDecoration(
                labelText: 'Должность',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('ПРАВА ДОСТУПА',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5)),
            ),
            const SizedBox(height: 8),
            _PermCheckbox(
                'Полный доступ',
                _permFullAccess,
                (v) => setState(() {
                      _permFullAccess = v;
                      if (v) {
                        _permEdit =
                            _permExecute = _permRead = _permWrite = true;
                        _permOwnOnly = false;
                      }
                    })),
            _PermCheckbox(
                'Изменение', _permEdit, (v) => setState(() => _permEdit = v)),
            _PermCheckbox('Выполнение', _permExecute,
                (v) => setState(() => _permExecute = v)),
            _PermCheckbox(
                'Чтение', _permRead, (v) => setState(() => _permRead = v)),
            _PermCheckbox(
                'Запись', _permWrite, (v) => setState(() => _permWrite = v)),
            _PermCheckbox('Только свой транспорт и водители', _permOwnOnly,
                (v) => setState(() => _permOwnOnly = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Создать'),
        ),
      ],
    );
  }

  Widget _PermCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _ShowCodeDialog extends StatelessWidget {
  final String code;
  const _ShowCodeDialog({required this.code});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Код приглашения создан'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Передайте этот код пользователю:',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3DE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(code,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                    color: Color(0xFF27500A))),
          ),
          const SizedBox(height: 12),
          const Text(
              'Код действителен 7 дней и может быть использован только один раз.',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              textAlign: TextAlign.center),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Код скопирован'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  width: 200),
            );
          },
          tooltip: 'Копировать',
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _EditUserDialog extends ConsumerStatefulWidget {
  final UserRole user;
  final VoidCallback onSaved;
  const _EditUserDialog({required this.user, required this.onSaved});

  @override
  ConsumerState<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<_EditUserDialog> {
  late bool _permFullAccess;
  late bool _permEdit;
  late bool _permExecute;
  late bool _permRead;
  late bool _permWrite;
  late bool _permOwnOnly;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _permFullAccess = widget.user.permFullAccess;
    _permEdit = widget.user.permEdit;
    _permExecute = widget.user.permExecute;
    _permRead = widget.user.permRead;
    _permWrite = widget.user.permWrite;
    _permOwnOnly = widget.user.permOwnOnly;
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сохранить права?'),
        content: Text('Права доступа пользователя «${widget.user.fullName}» будут обновлены.'),
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
      await supabase.from('user_roles').update({
        'perm_full_access': _permFullAccess,
        'perm_edit': _permEdit,
        'perm_execute': _permExecute,
        'perm_read': _permRead,
        'perm_write': _permWrite,
        'perm_own_only': _permOwnOnly,
      }).eq('id', widget.user.id);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Права: ${widget.user.fullName}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.position ?? '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            const SizedBox(height: 16),
            const Text('ПРАВА ДОСТУПА',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888888),
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            _PermRow(
                'Полный доступ',
                _permFullAccess,
                (v) => setState(() {
                      _permFullAccess = v;
                      if (v) {
                        _permEdit =
                            _permExecute = _permRead = _permWrite = true;
                        _permOwnOnly = false;
                      }
                    })),
            _PermRow(
                'Изменение', _permEdit, (v) => setState(() => _permEdit = v)),
            _PermRow('Выполнение', _permExecute,
                (v) => setState(() => _permExecute = v)),
            _PermRow('Чтение', _permRead, (v) => setState(() => _permRead = v)),
            _PermRow(
                'Запись', _permWrite, (v) => setState(() => _permWrite = v)),
            _PermRow('Только свой транспорт и водители', _permOwnOnly,
                (v) => setState(() => _permOwnOnly = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _PermRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
