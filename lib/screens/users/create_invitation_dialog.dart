import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/department_service.dart';
import '../../widgets/dialog_scroll_content.dart';
import 'show_code_dialog.dart';

class CreateInvitationDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const CreateInvitationDialog({super.key, required this.onSaved});

  @override
  ConsumerState<CreateInvitationDialog> createState() =>
      CreateInvitationDialogState();
}

class CreateInvitationDialogState
    extends ConsumerState<CreateInvitationDialog> {
  final _fullNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  bool _permFullAccess = false;
  bool _permEdit = false;
  bool _permExecute = false;
  bool _permRead = true;
  bool _permWrite = false;
  bool _permOwnOnly = false;
  String? _departmentId;
  String? _sectionId;
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
                departmentId: _departmentId,
                sectionId: _sectionId,
              );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        // Диалог с кодом открывается поверх — дожидаться его закрытия здесь не нужно.
        unawaited(showDialog(
          context: context,
          builder: (_) => ShowCodeDialog(code: invitation.code),
        ));
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
    final departments = ref.watch(departmentsProvider).value ?? [];
    final deptSections = (ref.watch(sectionsProvider).value ?? [])
        .where((s) => s.departmentId == _departmentId)
        .toList();

    return AlertDialog(
      title: const Text('Создать приглашение'),
      content: DialogScrollContent(
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
            if (departments.isNotEmpty) ...[
              const SizedBox(height: 10),
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
            ],
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
