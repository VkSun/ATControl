import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/department.dart';
import '../../services/department_service.dart';
import '../../utils/responsive.dart';
import '../../utils/theme.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/dialog_scroll_content.dart';

// ─── ВКЛАДКА ПОДРАЗДЕЛЕНИЯ ────────────────────────────────────────────────────

class DepartmentsTab extends ConsumerStatefulWidget {
  final AppColors colors;
  const DepartmentsTab({super.key, required this.colors});

  @override
  ConsumerState<DepartmentsTab> createState() => DepartmentsTabState();
}

class DepartmentsTabState extends ConsumerState<DepartmentsTab> {
  String? _selectedDeptId;

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentsProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final colors = widget.colors;

    final departments = departmentsAsync.value ?? [];
    final allSections = sectionsAsync.value ?? [];
    final deptSections = allSections
        .where((s) => s.departmentId == _selectedDeptId)
        .toList();

    // Список цехов
    final deptPanel = Container(
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
                      const Expanded(
                        child: Text('Подразделения (цеха)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => _showAddDept(context),
                        tooltip: 'Добавить подразделение',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AsyncValueView(
                    value: departmentsAsync,
                    onRetry: departmentsProvider,
                    builder: (depts) {
                      if (depts.isEmpty) {
                        return const Center(
                            child: Text('Нет подразделений',
                                style: TextStyle(fontSize: 12)));
                      }
                      return ListView.builder(
                        itemCount: depts.length,
                        itemBuilder: (context, i) {
                          final d = depts[i];
                          final isSelected = d.id == _selectedDeptId;
                          final secCount = allSections
                              .where((s) => s.departmentId == d.id)
                              .length;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedDeptId = d.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.08)
                                    : Colors.transparent,
                                border: Border(
                                    bottom: BorderSide(
                                        color: colors.tableBorder,
                                        width: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(d.name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w500
                                                : FontWeight.normal)),
                                  ),
                                  if (secCount > 0)
                                    Text('$secCount уч.',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF888888))),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 14),
                                    onPressed: () =>
                                        _showEditDept(context, d),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 24, minHeight: 24),
                                    color: const Color(0xFF888888),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 14),
                                    onPressed: () =>
                                        _deleteDept(context, d),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 24, minHeight: 24),
                                    color: const Color(0xFFE24B4A),
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

    // Список участков выбранного цеха
    final sectionPanel = Container(
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
                      Expanded(
                        child: Text(
                          _selectedDeptId == null
                              ? 'Выберите подразделение'
                              : 'Участки: ${departments.firstWhere((d) => d.id == _selectedDeptId, orElse: () => const Department(id: '', name: '')).name}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (_selectedDeptId != null)
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => _showAddSection(context),
                          tooltip: 'Добавить участок',
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _selectedDeptId == null
                      ? const Center(
                          child: Text('Выберите подразделение слева',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF888888))))
                      : AsyncValueView(
                          value: sectionsAsync,
                          onRetry: sectionsProvider,
                          builder: (_) {
                            if (deptSections.isEmpty) {
                              return const Center(
                                  child: Text('Нет участков',
                                      style: TextStyle(fontSize: 12)));
                            }
                            return ListView.builder(
                              itemCount: deptSections.length,
                              itemBuilder: (context, i) {
                                final s = deptSections[i];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: colors.tableBorder,
                                            width: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(s.name,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 14),
                                        onPressed: () =>
                                            _showEditSection(context, s),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 24, minHeight: 24),
                                        color: const Color(0xFF888888),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 14),
                                        onPressed: () =>
                                            _deleteSection(context, s),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 24, minHeight: 24),
                                        color: const Color(0xFFE24B4A),
                                      ),
                                    ],
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

    // На телефоне узкие панели бок о бок нечитаемы — цеха сверху,
    // участки снизу; на планшете/десктопе — как раньше, в два столбца.
    if (isPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: deptPanel),
          const SizedBox(height: 16),
          Expanded(flex: 3, child: sectionPanel),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: deptPanel),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: sectionPanel),
      ],
    );
  }

  Future<void> _showAddDept(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Добавить подразделение'),
        content: DialogScrollContent(
          child: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
                isDense: true,
              ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(departmentServiceProvider).createDepartment(ctrl.text.trim());
      ref.invalidate(departmentsProvider);
    }
    ctrl.dispose();
  }

  Future<void> _showEditDept(BuildContext context, Department dept) async {
    final ctrl = TextEditingController(text: dept.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Переименовать подразделение'),
        content: DialogScrollContent(
          child: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
                isDense: true,
              ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(departmentServiceProvider).updateDepartment(dept.id, ctrl.text.trim());
      ref.invalidate(departmentsProvider);
    }
    ctrl.dispose();
  }

  Future<void> _deleteDept(BuildContext context, Department dept) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Удалить подразделение?'),
        content: DialogScrollContent(
            child: Text(
                '«${dept.name}» и все его участки будут удалены.\n\nЭто действие нельзя отменить.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(departmentServiceProvider).deleteDepartment(dept.id);
      if (_selectedDeptId == dept.id) setState(() => _selectedDeptId = null);
      ref.invalidate(departmentsProvider);
      ref.invalidate(sectionsProvider);
    }
  }

  Future<void> _showAddSection(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Добавить участок'),
        content: DialogScrollContent(
          child: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название участка',
                border: OutlineInputBorder(),
                isDense: true,
              ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ref
          .read(departmentServiceProvider)
          .createSection(ctrl.text.trim(), _selectedDeptId!);
      ref.invalidate(sectionsProvider);
    }
    ctrl.dispose();
  }

  Future<void> _showEditSection(BuildContext context, Section section) async {
    final ctrl = TextEditingController(text: section.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Переименовать участок'),
        content: DialogScrollContent(
          child: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
                isDense: true,
              ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ref
          .read(departmentServiceProvider)
          .updateSection(section.id, ctrl.text.trim());
      ref.invalidate(sectionsProvider);
    }
    ctrl.dispose();
  }

  Future<void> _deleteSection(BuildContext context, Section section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Удалить участок?'),
        content: DialogScrollContent(
            child: Text(
                '«${section.name}» будет удалён.\n\nЭто действие нельзя отменить.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  FilledButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(departmentServiceProvider).deleteSection(section.id);
      ref.invalidate(sectionsProvider);
    }
  }
}
