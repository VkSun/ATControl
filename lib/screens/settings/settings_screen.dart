import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/responsive.dart';
import '../../services/profile_service.dart';
import '../../services/autostart_service.dart';
import '../../screens/profile/profile_dialog.dart';
import 'import_dialog.dart';

// Провайдеры уведомлений с сохранением в SharedPreferences
final notifyDay30Provider = StateNotifierProvider<_BoolPref, bool>(
    (_) => _BoolPref('notify_30', true));
final notifyDay14Provider = StateNotifierProvider<_BoolPref, bool>(
    (_) => _BoolPref('notify_14', true));
final notifyDay7Provider = StateNotifierProvider<_BoolPref, bool>(
    (_) => _BoolPref('notify_7', true));

class _BoolPref extends StateNotifier<bool> {
  final String _key;
  _BoolPref(this._key, bool def) : super(def) {
    SharedPreferences.getInstance().then((p) {
      if (p.containsKey(_key)) state = p.getBool(_key)!;
    });
  }
  Future<void> set(bool v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, v);
  }
}

// Провайдер автозагрузки (только Windows)
final autostartProvider = StateNotifierProvider<_AutostartNotifier, AsyncValue<bool>>(
    (_) => _AutostartNotifier());

class _AutostartNotifier extends StateNotifier<AsyncValue<bool>> {
  _AutostartNotifier() : super(const AsyncValue.loading()) {
    _load();
  }
  Future<void> _load() async {
    final v = await AutostartService.isEnabled();
    state = AsyncValue.data(v);
  }
  Future<void> set(bool v) async {
    await AutostartService.setEnabled(v);
    state = AsyncValue.data(v);
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        _TopBar(colors: colors),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                const _SectionLabel('Уведомления'),
                _ToggleSetting(
                  label: 'Уведомления за 30 дней',
                  desc: 'Предупреждения за 30 дней до истечения срока',
                  value: ref.watch(notifyDay30Provider),
                  onChanged: (v) => ref.read(notifyDay30Provider.notifier).set(v),
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _ToggleSetting(
                  label: 'Уведомления за 14 дней',
                  desc: 'Предупреждения за 14 дней до истечения срока',
                  value: ref.watch(notifyDay14Provider),
                  onChanged: (v) => ref.read(notifyDay14Provider.notifier).set(v),
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _ToggleSetting(
                  label: 'Уведомления за 7 дней',
                  desc: 'Срочные предупреждения за 7 дней до истечения',
                  value: ref.watch(notifyDay7Provider),
                  onChanged: (v) => ref.read(notifyDay7Provider.notifier).set(v),
                  colors: colors,
                ),
                const _SectionLabel('Внешний вид'),
                _SelectSetting(
                  label: 'Тема оформления',
                  value: ref.watch(themeVariantProvider).label,
                  options: AppThemeVariant.values.map((v) => v.label).toList(),
                  onChanged: (v) {
                    final variant = AppThemeVariant.values
                        .firstWhere((e) => e.label == v);
                    ref.read(themeVariantProvider.notifier).set(variant);
                  },
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _SelectSetting(
                  label: 'Размер шрифта',
                  value: ref.watch(fontSizeProvider) == 0.9 ? 'Маленький'
                      : ref.watch(fontSizeProvider) == 1.1 ? 'Большой' : 'Средний',
                  options: const ['Маленький', 'Средний', 'Большой'],
                  onChanged: (v) {
                    ref.read(fontSizeProvider.notifier).set(
                        v == 'Маленький' ? 0.9 : v == 'Большой' ? 1.1 : 1.0);
                  },
                  colors: colors,
                ),
                const SizedBox(height: 8),
                _SelectSetting(
                  label: 'Масштаб интерфейса',
                  value: ref.watch(scaleProvider) == 0.9 ? '90%'
                      : ref.watch(scaleProvider) == 1.1 ? '110%'
                      : ref.watch(scaleProvider) == 1.25 ? '125%' : '100%',
                  options: const ['90%', '100%', '110%', '125%'],
                  onChanged: (v) {
                    ref.read(scaleProvider.notifier).set(
                        v == '90%' ? 0.9 : v == '110%' ? 1.1 : v == '125%' ? 1.25 : 1.0);
                  },
                  colors: colors,
                ),
                if (Platform.isWindows) ...[
                  const _SectionLabel('Система'),
                  _AutostartCard(colors: colors),
                ],
                const _SectionLabel('Импорт и экспорт'),
                _ImportExportCard(colors: colors),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppColors colors;
  const _TopBar({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: colors.tableBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Настройки', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (isMobile(context)) ...[
            const Icon(Icons.notifications_outlined, size: 20),
            const SizedBox(width: 12),
            Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(profileProvider);
                final initials = profileAsync.value?.initials ?? 'АИ';
                final color = profileAsync.value?.avatarColor ?? '#4361EE';
                final avatarColor = Color(int.parse(color.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const ProfileDialog(),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: avatarColor,
                    child: Text(initials,
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: Color(0xFF888888), letterSpacing: 0.5)),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  final AppColors colors;

  const _SettingCard({required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.tableBorder, width: 0.5),
      ),
      child: child,
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  final String label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColors colors;

  const _ToggleSetting({
    required this.label, required this.desc,
    required this.value, required this.onChanged, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      colors: colors,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFF4361EE)),
        ],
      ),
    );
  }
}

class _SelectSetting extends StatelessWidget {
  final String label, value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final AppColors colors;

  const _SelectSetting({
    required this.label, required this.value,
    required this.options, required this.onChanged, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      colors: colors,
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          DropdownButton<String>(
            value: value,
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => v != null ? onChanged(v) : null,
            underline: const SizedBox(),
            isDense: true,
          ),
        ],
      ),
    );
  }
}

class _ImportExportCard extends StatelessWidget {
  final AppColors colors;
  const _ImportExportCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      colors: colors,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Импорт данных из Excel', style: TextStyle(fontSize: 13)),
                SizedBox(height: 2),
                Text('Загрузка транспорта и водителей из xlsx-файлов',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const ImportDialog(),
            ),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Импортировать', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutostartCard extends ConsumerWidget {
  final AppColors colors;
  const _AutostartCard({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(autostartProvider);
    return _SettingCard(
      colors: colors,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Автозагрузка при старте Windows',
                    style: TextStyle(fontSize: 13)),
                SizedBox(height: 2),
                Text('Запускать ATControl автоматически при входе в систему',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
          state.when(
            loading: () => const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Icon(Icons.error_outline,
                color: Color(0xFFE24B4A), size: 20),
            data: (enabled) => Switch(
              value: enabled,
              onChanged: (v) => ref.read(autostartProvider.notifier).set(v),
              activeThumbColor: const Color(0xFF4361EE),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathSetting extends StatefulWidget {
  final String label, desc, value;
  final ValueChanged<String> onChanged;
  final AppColors colors;

  const _PathSetting({
    required this.label, required this.desc,
    required this.value, required this.onChanged, required this.colors,
  });

  @override
  State<_PathSetting> createState() => _PathSettingState();
}

class _PathSettingState extends State<_PathSetting> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_PathSetting old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return _SettingCard(
      colors: widget.colors,
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(widget.desc,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        onChanged: widget.onChanged,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      child: const Text('Обзор...'),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(widget.desc,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _ctrl,
                    onChanged: widget.onChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('Обзор...'),
                ),
              ],
            ),
    );
  }
}