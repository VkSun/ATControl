import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_role.dart';
import '../../services/supabase_client.dart';
import '../../utils/theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/dialog_scroll_content.dart';
import 'edit_user_dialog.dart';
import 'providers.dart';

class UsersTab extends ConsumerWidget {
  final AppColors colors;
  final WidgetRef ref;

  const UsersTab({super.key, required this.colors, required this.ref});

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
    final mobile = isPhone(context);

    if (mobile) {
      return AsyncValueView(
        value: usersAsync,
        onRetry: usersProvider,
        builder: (users) {
          if (users.isEmpty) return const Center(child: Text('Нет пользователей'));
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final avatarColor = Color(int.parse(u.avatarColor.replaceFirst('#', '0xFF')));
              return InkWell(
                onTap: u.isAdmin ? null : () => showDialog(
                  context: context,
                  builder: (_) => EditUserDialog(
                    user: u,
                    onSaved: () => ref.invalidate(usersProvider),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: avatarColor,
                        child: Text(u.initials,
                            style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text(u.position ?? '—',
                                style: TextStyle(fontSize: 11,
                                    color: Theme.of(context).textTheme.bodySmall!.color)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: u.isActive ? colors.badgeGreen : colors.badgeRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          u.isActive ? 'Активен' : 'Блок.',
                          style: TextStyle(
                              fontSize: 10,
                              color: u.isActive ? colors.badgeGreenText : colors.badgeRedText),
                        ),
                      ),
                      if (!u.isAdmin) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            u.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                            size: 18,
                          ),
                          onPressed: () => _toggleActive(context, ref, u),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          color: u.isActive ? const Color(0xFFE24B4A) : const Color(0xFF639922),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

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
              border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
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
            child: AsyncValueView(
              value: usersAsync,
              onRetry: usersProvider,
              builder: (users) {
                if (users.isEmpty) return const Center(child: Text('Нет пользователей'));
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return GestureDetector(
                      onTap: u.isAdmin ? null : () => showDialog(
                        context: context,
                        builder: (_) => EditUserDialog(
                          user: u,
                          onSaved: () => ref.invalidate(usersProvider),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 200,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(int.parse(
                                        u.avatarColor.replaceFirst('#', '0xFF'))),
                                    child: Text(u.initials,
                                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(u.fullName,
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 160, child: Text(u.position ?? '—', style: const TextStyle(fontSize: 12))),
                            SizedBox(width: 220, child: Text(_permsText(u), style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            SizedBox(
                              width: 100,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: u.isActive ? colors.badgeGreen : colors.badgeRed,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(u.isActive ? 'Активен' : 'Заблокирован',
                                    style: TextStyle(fontSize: 10,
                                        color: u.isActive ? colors.badgeGreenText : colors.badgeRedText)),
                              ),
                            ),
                            const Spacer(),
                            if (!u.isAdmin)
                              IconButton(
                                icon: Icon(u.isActive ? Icons.block_outlined : Icons.check_circle_outline, size: 16),
                                onPressed: () => _toggleActive(context, ref, u),
                                tooltip: u.isActive ? 'Заблокировать' : 'Разблокировать',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                color: u.isActive ? const Color(0xFFE24B4A) : const Color(0xFF639922),
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
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: Text(user.isActive
            ? 'Заблокировать пользователя?'
            : 'Разблокировать пользователя?'),
        content: DialogScrollContent(child: Text(user.fullName)),
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
