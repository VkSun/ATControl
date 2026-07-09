import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/invitation_code.dart';
import '../../services/supabase_client.dart';
import '../../utils/responsive.dart';
import '../../utils/theme.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/dialog_scroll_content.dart';
import 'providers.dart';

void _copyCode(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Код скопирован'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      width: 200,
    ),
  );
}

Future<bool> _confirmRevoke(BuildContext context, InvitationCode inv) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(ctx).cardColor,
      surfaceTintColor: Colors.transparent,
      title: const Text('Удалить код?'),
      content:
          DialogScrollContent(child: Text('Код ${inv.code} будет удалён.')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class InvitationsTab extends ConsumerWidget {
  final AppColors colors;
  final WidgetRef ref;

  const InvitationsTab({super.key, required this.colors, required this.ref});

  Future<void> _revoke(WidgetRef ref, InvitationCode inv) async {
    await supabase.from('invitation_codes').delete().eq('id', inv.id);
    ref.invalidate(invitationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(invitationsProvider);
    final fmt = DateFormat('dd.MM.yyyy');

    // Телефон: карточки вместо таблицы с фиксированными колонками.
    if (isPhone(context)) {
      return AsyncValueView(
        value: invitationsAsync,
        onRetry: invitationsProvider,
        builder: (invitations) {
          if (invitations.isEmpty) {
            return const Center(child: Text('Нет кодов приглашений'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(invitationsProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: invitations.length,
              itemBuilder: (context, i) => _InvitationCard(
                invitation: invitations[i],
                colors: colors,
                fmt: fmt,
                onRevoke: () => _revoke(ref, invitations[i]),
              ),
            ),
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
            child: AsyncValueView(
              value: invitationsAsync,
              onRetry: invitationsProvider,
              builder: (invitations) {
                if (invitations.isEmpty) {
                  return const Center(child: Text('Нет кодов приглашений'));
                }
                return ListView.builder(
                  itemCount: invitations.length,
                  itemBuilder: (context, i) => _InvitationRow(
                    invitation: invitations[i],
                    colors: colors,
                    fmt: fmt,
                    onDelete: () => _revoke(ref, invitations[i]),
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
                  onTap: () => _copyCode(context, invitation.code),
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(invitation: invitation, colors: colors),
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
                if (await _confirmRevoke(context, invitation)) onDelete();
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

class _StatusBadge extends StatelessWidget {
  final InvitationCode invitation;
  final AppColors colors;

  const _StatusBadge({required this.invitation, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isUsed = invitation.isUsed;
    final isValid = invitation.isValid;
    return Container(
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
    );
  }
}

/// Карточка приглашения на телефоне: код с копированием, ФИО, должность,
/// статус и действие «Отозвать».
class _InvitationCard extends StatelessWidget {
  final InvitationCode invitation;
  final AppColors colors;
  final DateFormat fmt;
  final VoidCallback onRevoke;

  const _InvitationCard({
    required this.invitation,
    required this.colors,
    required this.fmt,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall!.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.badgeGreenText)),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Копировать код',
                onPressed: () => _copyCode(context, invitation.code),
                color: small,
              ),
              const Spacer(),
              _StatusBadge(invitation: invitation, colors: colors),
            ],
          ),
          const SizedBox(height: 6),
          Text(invitation.fullName ?? '—',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (invitation.position != null && invitation.position!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(invitation.position!,
                  style: TextStyle(fontSize: 12, color: small)),
            ),
          Row(
            children: [
              if (invitation.expiresAt != null)
                Text('Истекает: ${fmt.format(invitation.expiresAt!)}',
                    style: TextStyle(fontSize: 11, color: small)),
              const Spacer(),
              if (!invitation.isUsed)
                TextButton(
                  onPressed: () async {
                    if (await _confirmRevoke(context, invitation)) onRevoke();
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE24B4A)),
                  child: const Text('Отозвать',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
