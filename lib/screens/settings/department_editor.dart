import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/department.dart';
import '../../services/department_service.dart';
import '../../utils/theme.dart';
import '../../widgets/dialog_scroll_content.dart';

class DepartmentEditorDialog extends ConsumerStatefulWidget {
  const DepartmentEditorDialog({super.key});

  @override
  ConsumerState<DepartmentEditorDialog> createState() => _DepartmentEditorDialogState();
}

class _DepartmentEditorDialogState extends ConsumerState<DepartmentEditorDialog> {
  List<Department> _depts = [];
  List<Section> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = ref.read(departmentServiceProvider);
    final depts = await svc.getDepartments();
    final sections = await svc.getSections();
    if (mounted) {
      setState(() {
        _depts = depts;
        _sections = sections;
        _loading = false;
      });
    }
  }

  DepartmentService get _svc => ref.read(departmentServiceProvider);

  Future<String?> _nameDialog(String title, {String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        content: DialogScrollContent(
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            content: DialogScrollContent(
              child: Text(
                '«$name» будет удалён.\nЕсли к нему привязаны водители или транспорт — удаление не выполнится.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE24B4A)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(Object e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ошибка', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        content: DialogScrollContent(
            child: Text(e.toString(), style: const TextStyle(fontSize: 12))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _addTopDept() async {
    final name = await _nameDialog('Новый цех / отдел');
    if (name == null || name.isEmpty) return;
    try {
      await _svc.createDepartment(name);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addChildDept(String parentId) async {
    final name = await _nameDialog('Новый участок');
    if (name == null || name.isEmpty) return;
    try {
      await _svc.createDepartment(name, parentId: parentId);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameDept(Department dept) async {
    final name = await _nameDialog('Переименовать', initial: dept.name);
    if (name == null || name.isEmpty || name == dept.name) return;
    try {
      await _svc.updateDepartment(dept.id, name);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteDept(Department dept) async {
    if (!await _confirmDelete(dept.name)) return;
    try {
      await _svc.deleteDepartment(dept.id);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addSection(Department dept) async {
    final name = await _nameDialog('Новая секция');
    if (name == null || name.isEmpty) return;
    try {
      await _svc.createSection(name, dept.id);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameSection(Section sec) async {
    final name = await _nameDialog('Переименовать', initial: sec.name);
    if (name == null || name.isEmpty || name == sec.name) return;
    try {
      await _svc.updateSection(sec.id, name);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteSection(Section sec) async {
    if (!await _confirmDelete(sec.name)) return;
    try {
      await _svc.deleteSection(sec.id);
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 660,
        // Список прокручивается внутри; высота лишь ограничивается экраном.
        height: math.min(700, dialogMaxHeight(context)),
        child: Column(
          children: [
            _Header(colors: colors, onAdd: _addTopDept),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _depts.isEmpty
                      ? const Center(
                          child: Text('Нет данных', style: TextStyle(color: Color(0xFF888888))))
                      : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: _buildTree(colors),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTree(AppColors colors) {
    final topLevel = _depts.where((d) => d.parentId == null).toList();
    final result = <Widget>[];

    for (final dept in topLevel) {
      result.add(_Divider(colors: colors));
      result.add(_DeptRow(
        name: dept.name,
        indent: 0,
        isChild: false,
        colors: colors,
        onAddChild: () => _addChildDept(dept.id),
        onAddSection: () => _addSection(dept),
        onRename: () => _renameDept(dept),
        onDelete: () => _deleteDept(dept),
      ));

      for (final sec in _sections.where((s) => s.departmentId == dept.id)) {
        result.add(_SectionRow(
          name: sec.name,
          indent: 1,
          colors: colors,
          onRename: () => _renameSection(sec),
          onDelete: () => _deleteSection(sec),
        ));
      }

      for (final child in _depts.where((d) => d.parentId == dept.id)) {
        result.add(_DeptRow(
          name: child.name,
          indent: 1,
          isChild: true,
          colors: colors,
          onAddChild: null,
          onAddSection: () => _addSection(child),
          onRename: () => _renameDept(child),
          onDelete: () => _deleteDept(child),
        ));

        for (final sec in _sections.where((s) => s.departmentId == child.id)) {
          result.add(_SectionRow(
            name: sec.name,
            indent: 2,
            colors: colors,
            onRename: () => _renameSection(sec),
            onDelete: () => _deleteSection(sec),
          ));
        }
      }
    }

    return result;
  }
}

class _Header extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onAdd;
  const _Header({required this.colors, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          const Text('Структура предприятия',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Добавить цех', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppColors colors;
  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 0.5, color: colors.tableBorder,
        indent: 16, endIndent: 16);
  }
}

class _DeptRow extends StatelessWidget {
  final String name;
  final int indent;
  final bool isChild;
  final AppColors colors;
  final VoidCallback? onAddChild;
  final VoidCallback onAddSection;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _DeptRow({
    required this.name,
    required this.indent,
    required this.isChild,
    required this.colors,
    required this.onAddChild,
    required this.onAddSection,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16.0 + indent * 20, right: 8, top: 3, bottom: 3),
      child: Row(
        children: [
          Icon(
            isChild ? Icons.subdirectory_arrow_right : Icons.corporate_fare,
            size: isChild ? 14 : 16,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name,
                style: TextStyle(
                  fontSize: isChild ? 12 : 13,
                  fontWeight: isChild ? FontWeight.w400 : FontWeight.w600,
                )),
          ),
          if (onAddChild != null)
            _Btn(
                icon: Icons.account_tree_outlined,
                tooltip: 'Добавить участок',
                onTap: onAddChild!),
          _Btn(
              icon: Icons.playlist_add,
              tooltip: 'Добавить секцию',
              onTap: onAddSection),
          _Btn(icon: Icons.edit_outlined, tooltip: 'Переименовать', onTap: onRename),
          _Btn(
              icon: Icons.delete_outline,
              tooltip: 'Удалить',
              onTap: onDelete,
              danger: true),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String name;
  final int indent;
  final AppColors colors;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SectionRow({
    required this.name,
    required this.indent,
    required this.colors,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 + indent * 20, right: 8, top: 2, bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFAAAAAA),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
          ),
          _Btn(icon: Icons.edit_outlined, tooltip: 'Переименовать', onTap: onRename),
          _Btn(
              icon: Icons.delete_outline,
              tooltip: 'Удалить',
              onTap: onDelete,
              danger: true),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _Btn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon,
              size: 15,
              color: danger ? const Color(0xFFE24B4A) : const Color(0xFF999999)),
        ),
      ),
    );
  }
}
