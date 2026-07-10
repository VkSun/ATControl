import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/offline_state.dart';
import 'brand_colors.dart';

/// Раздельно от Flutter-овского ThemeMode: помимо светлая/тёмная/системная
/// сюда добавляются именованные цветовые темы (см. AppTheme.purpleTheme) —
/// они переключаются тем же селектором в Настройках, добавляются по одной.
enum AppThemeMode { light, dark, system, purple, orange, mono, beige, emerald, teal }

final themeModeProvider =
    StateNotifierProvider<_ThemePref, AppThemeMode>((_) => _ThemePref());

class _ThemePref extends StateNotifier<AppThemeMode> {
  _ThemePref() : super(AppThemeMode.light) {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString('theme_mode');
      state = AppThemeMode.values.where((m) => m.name == v).firstOrNull ??
          AppThemeMode.light;
    });
  }
  Future<void> set(AppThemeMode v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', v.name);
  }
}

final fontSizeProvider =
    StateNotifierProvider<_DoublePref, double>((_) => _DoublePref('font_size', 1.0));

final scaleProvider =
    StateNotifierProvider<_DoublePref, double>((_) => _DoublePref('ui_scale', 1.0));

final homeSplitProvider =
    StateNotifierProvider<_DoublePref, double>((_) => _DoublePref('home_split', 0.5));

final plannerSplitProvider =
    StateNotifierProvider<_DoublePref, double>((_) => _DoublePref('planner_split', 0.6));

class _DoublePref extends StateNotifier<double> {
  final String _key;
  _DoublePref(this._key, double def) : super(def) {
    SharedPreferences.getInstance().then((p) {
      if (p.containsKey(_key)) state = p.getDouble(_key)!;
    });
  }
  Future<void> set(double v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_key, v);
  }
}

class AppTheme {
  static const Color primaryColor = Color(0xFF4361EE);
  // Та же константа в виде hex-строки — формат хранения avatar_color в БД
  // (см. lib/utils/brand_colors.dart, откуда её берут модели и сервисы).
  // Это дефолт для аватара, а не акцент темы — не путать с AppColors.accent.
  static const String primaryColorHex = kPrimaryColorHex;
  static const _danger = Color(0xFFE24B4A);
  static const _amber = Color(0xFFEF9F27);
  static const _green = Color(0xFF639922);
  static const _purpleAccent = Color(0xFF6C5DD3);
  static const _orangeAccent = Color(0xFFFF7A30);
  static const _monoAccent = Color(0xFF5A5A5A);
  static const _beigeAccent = Color(0xFFC9962F);
  static const _emeraldAccent = Color(0xFF4ECB8D);
  static const _tealAccent = Color(0xFF1F4E4A);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFF333333)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF333333)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryColor),
    ),
    extensions: const [
      AppColors(
        accent: primaryColor,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Colors.white,
        sidebarActive: primaryColor,
        tableBorder: Color(0xFFEEEEEE),
        badgeRed: Color(0xFFFCEBEB),
        badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),
        badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),
        badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    cardColor: const Color(0xFF242438),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF242438),
      foregroundColor: Color(0xFFEEEEEE),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF242438),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFEEEEEE)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryColor),
    ),
    extensions: const [
      AppColors(
        accent: primaryColor,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Color(0xFF242438),
        sidebarActive: primaryColor,
        tableBorder: Color(0xFF333355),
        badgeRed: Color(0xFF501313),
        badgeRedText: Color(0xFFF7C1C1),
        badgeAmber: Color(0xFF412402),
        badgeAmberText: Color(0xFFFAC775),
        badgeGreen: Color(0xFF173404),
        badgeGreenText: Color(0xFFC0DD97),
      ),
    ],
  );

  // Фиолетовая: акцент из мокапа-референса (насыщенный индиго-фиолетовый),
  // светлый лавандовый фон, белые карточки — структура как у lightTheme,
  // отличается только акцентом и фоном.
  static ThemeData purpleTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _purpleAccent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F2FC),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFF333333)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF333333)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _purpleAccent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _purpleAccent,
        side: const BorderSide(color: _purpleAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _purpleAccent),
    ),
    extensions: const [
      AppColors(
        accent: _purpleAccent,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Colors.white,
        sidebarActive: _purpleAccent,
        tableBorder: Color(0xFFE8E4F7),
        badgeRed: Color(0xFFFCEBEB),
        badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),
        badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),
        badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );

  // Оранжевая: акцент из второго мокапа-референса (тёплый оранжевый),
  // светлый персиковый фон — та же структура, что у purpleTheme.
  static ThemeData orangeTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _orangeAccent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFFDF0E4),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFF333333)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF333333)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _orangeAccent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _orangeAccent,
        side: const BorderSide(color: _orangeAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _orangeAccent),
    ),
    extensions: const [
      AppColors(
        accent: _orangeAccent,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Colors.white,
        sidebarActive: _orangeAccent,
        tableBorder: Color(0xFFF6E3D2),
        badgeRed: Color(0xFFFCEBEB),
        badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),
        badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),
        badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );

  // Монохромная: третий референс — почти чёрный фон, серые карточки, без
  // цветного акцента вообще. Строится на структуре darkTheme (тоже тёмная
  // по сути), а не lightTheme-подобных purple/orange — только глубже
  // чёрный фон и нейтрально-серый акцент вместо синего.
  static ThemeData monoTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _monoAccent,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0D0D0D),
    cardColor: const Color(0xFF1C1C1C),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1C1C1C),
      foregroundColor: Color(0xFFEEEEEE),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1C1C1C),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFEEEEEE)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _monoAccent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _monoAccent,
        side: const BorderSide(color: _monoAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _monoAccent),
    ),
    extensions: const [
      AppColors(
        accent: _monoAccent,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Color(0xFF1C1C1C),
        sidebarActive: _monoAccent,
        tableBorder: Color(0xFF2E2E2E),
        badgeRed: Color(0xFF501313),
        badgeRedText: Color(0xFFF7C1C1),
        badgeAmber: Color(0xFF412402),
        badgeAmberText: Color(0xFFFAC775),
        badgeGreen: Color(0xFF173404),
        badgeGreenText: Color(0xFFC0DD97),
      ),
    ],
  );

  // Бежевая: четвёртый референс — тёплый кремовый фон, горчично-золотой
  // акцент. Карточки в референсе чёрные, но здесь оставлены белыми — тёмные
  // карточки плохо подходят под таблицы/списки, которые тут в основном.
  static ThemeData beigeTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _beigeAccent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF3ECE0),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFF333333)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF333333)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _beigeAccent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _beigeAccent,
        side: const BorderSide(color: _beigeAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _beigeAccent),
    ),
    extensions: const [
      AppColors(
        accent: _beigeAccent,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Colors.white,
        sidebarActive: _beigeAccent,
        tableBorder: Color(0xFFEBE1CF),
        badgeRed: Color(0xFFFCEBEB),
        badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),
        badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),
        badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );

  // Изумрудная: пятый референс — тёмная (структура как у monoTheme) с
  // изумрудно-зелёным акцентом вместо серого.
  static ThemeData emeraldTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _emeraldAccent,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Color(0xFFEEEEEE),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFEEEEEE)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _emeraldAccent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _emeraldAccent,
        side: const BorderSide(color: _emeraldAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _emeraldAccent),
    ),
    extensions: const [
      AppColors(
        accent: _emeraldAccent,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Color(0xFF1E1E1E),
        sidebarActive: _emeraldAccent,
        tableBorder: Color(0xFF2E2E2E),
        badgeRed: Color(0xFF501313),
        badgeRedText: Color(0xFFF7C1C1),
        badgeAmber: Color(0xFF412402),
        badgeAmberText: Color(0xFFFAC775),
        badgeGreen: Color(0xFF173404),
        badgeGreenText: Color(0xFFC0DD97),
      ),
    ],
  );

  // Бирюзовая: шестой референс — светлая, холодный серо-голубой фон,
  // тёмно-бирюзовый акцент (как кнопка «Add drug» в референсе).
  static ThemeData tealTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _tealAccent,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFEEF1F2),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFF333333)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF333333)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _tealAccent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _tealAccent,
        side: const BorderSide(color: _tealAccent),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _tealAccent),
    ),
    extensions: const [
      AppColors(
        accent: _tealAccent,
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Colors.white,
        sidebarActive: _tealAccent,
        tableBorder: Color(0xFFE2E8E8),
        badgeRed: Color(0xFFFCEBEB),
        badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),
        badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),
        badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );
}

class AppColors extends ThemeExtension<AppColors> {
  // accent — акцентный цвет текущей темы (кнопки, активные состояния,
  // выделения). Раньше эти места использовали AppTheme.primaryColor
  // напрямую как статическую константу, из-за чего они не могли меняться
  // вместе с темой — теперь берут его отсюда, через Theme.of(context).
  final Color accent;
  final Color danger, amber, success;
  final Color sidebarBg, sidebarActive, tableBorder;
  final Color badgeRed, badgeRedText;
  final Color badgeAmber, badgeAmberText;
  final Color badgeGreen, badgeGreenText;

  const AppColors({
    required this.accent,
    required this.danger, required this.amber, required this.success,
    required this.sidebarBg, required this.sidebarActive, required this.tableBorder,
    required this.badgeRed, required this.badgeRedText,
    required this.badgeAmber, required this.badgeAmberText,
    required this.badgeGreen, required this.badgeGreenText,
  });

  @override
  AppColors copyWith({
    Color? accent,
    Color? danger, Color? amber, Color? success,
    Color? sidebarBg, Color? sidebarActive, Color? tableBorder,
    Color? badgeRed, Color? badgeRedText,
    Color? badgeAmber, Color? badgeAmberText,
    Color? badgeGreen, Color? badgeGreenText,
  }) => AppColors(
    accent: accent ?? this.accent,
    danger: danger ?? this.danger,
    amber: amber ?? this.amber,
    success: success ?? this.success,
    sidebarBg: sidebarBg ?? this.sidebarBg,
    sidebarActive: sidebarActive ?? this.sidebarActive,
    tableBorder: tableBorder ?? this.tableBorder,
    badgeRed: badgeRed ?? this.badgeRed,
    badgeRedText: badgeRedText ?? this.badgeRedText,
    badgeAmber: badgeAmber ?? this.badgeAmber,
    badgeAmberText: badgeAmberText ?? this.badgeAmberText,
    badgeGreen: badgeGreen ?? this.badgeGreen,
    badgeGreenText: badgeGreenText ?? this.badgeGreenText,
  );

  @override
  AppColors lerp(AppColors? other, double t) => this;
}

extension StatusStripColor on AppColors {
  /// Цвет левого индикатора строки списка по шкале Vehicle.dateStatus:
  /// 3–4 — красный, 2 — жёлтый, 1 — зелёный, 0 — прозрачный.
  Color statusStrip(int status) => switch (status) {
        >= 3 => danger,
        2 => amber,
        1 => success,
        _ => Colors.transparent,
      };
}
final resolvedThemeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  return switch (mode) {
    AppThemeMode.dark => AppTheme.darkTheme,
    AppThemeMode.purple => AppTheme.purpleTheme,
    AppThemeMode.orange => AppTheme.orangeTheme,
    AppThemeMode.mono => AppTheme.monoTheme,
    AppThemeMode.beige => AppTheme.beigeTheme,
    AppThemeMode.emerald => AppTheme.emeraldTheme,
    AppThemeMode.teal => AppTheme.tealTheme,
    AppThemeMode.light || AppThemeMode.system => AppTheme.lightTheme,
  };
});

// ─── Offline state providers ──────────────────────────────────────────────────
final isOfflineProvider =
    ChangeNotifierProvider<ValueNotifier<bool>>((ref) => isOfflineNotifier);

final offlineQueueCountProvider =
    ChangeNotifierProvider<ValueNotifier<int>>((ref) => queueCountNotifier);
