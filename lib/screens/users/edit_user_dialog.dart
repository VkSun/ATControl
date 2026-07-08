import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_role.dart';
import '../../services/department_service.dart';
import '../../services/supabase_client.dart';
import '../../widgets/dialog_scroll_content.dart';

class EditUserDialog extends ConsumerStatefulWidget {
  final UserRole user;
  final VoidCallback onSaved;
  const EditUserDialog({super.key, required this.user, required this.onSaved});

  @override
  ConsumerState<EditUserDialog> createState() => EditUserDialogState();
}

class EditUserDialogState extends ConsumerState<EditUserDialog> {
  late bool _permFullAccess;
  late bool _permEdit;
  late bool _permExecute;
  late bool _permRead;
  late bool _permWrite;
  late bool _permOwnOnly;
  String? _departmentId;
  String? _sectionId;
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
    _departmentId = widget.user.departmentId;
    _sectionId = widget.user.sectionId;
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Сохранить права?'),
        content: DialogScrollContent(
            child: Text(
                'Права доступа пользователя «${widget.user.fullName}» будут обновлены.')),
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
        'department_id': _departmentId,
        'section_id': _sectionId,
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
    final departmentsAsync = ref.watch(departmentsProvider);
    final sectionsAsync = ref.watch(sectionsProvider);
    final departments = departmentsAsync.value ?? [];
    final deptSections = (sectionsAsync.value ?? [])
        .where((s) => s.departmentId == _departmentId)
        .toList();

    return AlertDialog(
      title: Text('Права: ${widget.user.fullName}'),
      content: DialogScrollContent(
        width: 400,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user.position ?? '',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              const SizedBox(height: 16),
              const Text('ПОДРАЗДЕЛЕНИЕ',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _departmentId,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Подразделение',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Не указано', style: TextStyle(fontSize: 13)),
                        ),
                        ...departments.map((d) => DropdownMenuItem<String?>(
                              value: d.id,
                              child: Text(d.name, style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: (id) => setState(() {
                        _departmentId = id;
                        _sectionId = null;
                      }),
                    ),
                  ),
                  if (deptSections.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _sectionId,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Участок',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Не указан', style: TextStyle(fontSize: 13)),
                          ),
                          ...deptSections.map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name, style: const TextStyle(fontSize: 13)),
                              )),
                        ],
                        onChanged: (id) => setState(() => _sectionId = id),
                      ),
                    ),
                  ],
                ],
              ),
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
