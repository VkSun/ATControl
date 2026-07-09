import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/profile_service.dart';
import '../../screens/profile/profile_dialog.dart';
import '../../utils/theme.dart';
import '../../utils/responsive.dart';
import 'create_invitation_dialog.dart';
import 'departments_tab.dart';
import 'invitations_tab.dart';
import 'providers.dart';
import 'users_tab.dart';

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
    final mobile = isPhone(context);

    if (mobile) {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Пользователи'),
                  Tab(text: 'Приглашения'),
                  Tab(text: 'Подразделения'),
                ],
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    UsersTab(colors: colors, ref: ref),
                    InvitationsTab(colors: colors, ref: ref),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DepartmentsTab(colors: colors),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openCreateInvitation(context),
            tooltip: 'Создать приглашение',
            child: const Icon(Icons.add),
          ),
        ),
      );
    }

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
              _TabBtn('Пользователи', 0, _tab, (v) => setState(() => _tab = v), colors),
              const SizedBox(width: 8),
              _TabBtn('Коды приглашений', 1, _tab, (v) => setState(() => _tab = v), colors),
              const SizedBox(width: 8),
              _TabBtn('Подразделения', 2, _tab, (v) => setState(() => _tab = v), colors),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: switch (_tab) {
              0 => UsersTab(colors: colors, ref: ref),
              1 => InvitationsTab(colors: colors, ref: ref),
              _ => DepartmentsTab(colors: colors),
            },
          ),
        ),
      ],
    );
  }

  void _openCreateInvitation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CreateInvitationDialog(
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
          color: active ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppTheme.primaryColor : colors.tableBorder,
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
          if (isPhone(context)) ...[
            const Icon(Icons.notifications_outlined, size: 20),
            const SizedBox(width: 12),
            Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(profileProvider);
                final initials = profileAsync.value?.initials ?? 'АИ';
                final color = profileAsync.value?.avatarColor ?? AppTheme.primaryColorHex;
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
        ],
      ),
    );
  }
}
