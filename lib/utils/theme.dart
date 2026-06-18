import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeVariant { light, blue, dark, flame }

extension AppThemeVariantX on AppThemeVariant {
  bool get isDark => this == AppThemeVariant.dark || this == AppThemeVariant.flame;

  String get label => switch (this) {
    AppThemeVariant.light => 'Светлая',
    AppThemeVariant.blue  => 'Синяя',
    AppThemeVariant.dark  => 'Тёмная',
    AppThemeVariant.flame => 'Пламя',
  };

  Color get swatchColor => switch (this) {
    AppThemeVariant.light => const Color(0xFFF0F0F5),
    AppThemeVariant.blue  => const Color(0xFF1A3580),
    AppThemeVariant.dark  => const Color(0xFF242438),
    AppThemeVariant.flame => const Color(0xFFC7500E),
  };

  AppThemeVariant get next {
    final all = AppThemeVariant.values;
    return all[(all.indexOf(this) + 1) % all.length];
  }
}

final themeVariantProvider =
    StateNotifierProvider<_ThemeVariantPref, AppThemeVariant>((_) => _ThemeVariantPref());

class _ThemeVariantPref extends StateNotifier<AppThemeVariant> {
  _ThemeVariantPref() : super(AppThemeVariant.dark) {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString('theme_mode');
      state = switch (v) {
        'light' => AppThemeVariant.light,
        'blue'  => AppThemeVariant.blue,
        'dark'  => AppThemeVariant.dark,
        'flame' => AppThemeVariant.flame,
        _       => AppThemeVariant.dark,
      };
    });
  }

  Future<void> set(AppThemeVariant v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', switch (v) {
      AppThemeVariant.light => 'light',
      AppThemeVariant.blue  => 'blue',
      AppThemeVariant.dark  => 'dark',
      AppThemeVariant.flame => 'flame',
    });
  }
}

final resolvedThemeProvider = Provider<ThemeData>((ref) {
  return switch (ref.watch(themeVariantProvider)) {
    AppThemeVariant.light => AppTheme.lightTheme,
    AppThemeVariant.blue  => AppTheme.blueTheme,
    AppThemeVariant.dark  => AppTheme.darkTheme,
    AppThemeVariant.flame => AppTheme.flameTheme,
  };
});

final fontSizeProvider =
    StateNotifierProvider<_DoublePref, double>((_) => _DoublePref('font_size', 1.0));

final scaleProvider =
    StateNotifierProvider<_DoublePref, double>((_) => _DoublePref('ui_scale', 1.0));

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
  static const _primary = Color(0xFF435EBE);
  static const _danger  = Color(0xFFE24B4A);
  static const _amber   = Color(0xFFEF9F27);
  static const _green   = Color(0xFF639922);

  // ── СВЕТЛАЯ ──────────────────────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFF4F6FA),
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
      bodySmall:  TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: _primary, side: const BorderSide(color: _primary)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _primary)),
    extensions: const [
      AppColors(
        danger: _danger, amber: _amber, success: _green,
        sidebarBg: Colors.white,
        sidebarActive: _primary,
        sidebarText: Color(0xFF1A1A2E),
        sidebarTextSecondary: Color(0xFF888888),
        tableBorder: Color(0xFFE9ECF3),
        badgeRed: Color(0xFFFCEBEB),     badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),   badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),   badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );

  // ── СИНЯЯ ────────────────────────────────────────────────────────────────
  static ThemeData blueTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFEEF2FF),
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
      bodySmall:  TextStyle(fontSize: 11, color: Color(0xFF666888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: _primary, side: const BorderSide(color: _primary)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _primary)),
    extensions: const [
      AppColors(
        danger: _danger, amber: _amber, success: _green,
        sidebarBg: Color(0xFF1A3580),
        sidebarActive: Color(0xFF4895EF),
        sidebarText: Color(0xFFE0EAFF),
        sidebarTextSecondary: Color(0xFF7BA0D8),
        tableBorder: Color(0xFFD8E3F7),
        badgeRed: Color(0xFFFCEBEB),     badgeRedText: Color(0xFFA32D2D),
        badgeAmber: Color(0xFFFAEEDA),   badgeAmberText: Color(0xFF854F0B),
        badgeGreen: Color(0xFFEAF3DE),   badgeGreenText: Color(0xFF3B6D11),
      ),
    ],
  );

  // ── ТЁМНАЯ ───────────────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.dark),
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
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
      bodySmall:  TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFEEEEEE)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(foregroundColor: _primary, side: const BorderSide(color: _primary)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _primary)),
    extensions: const [
      AppColors(
        danger: _danger, amber: _amber, success: _green,
        sidebarBg: Color(0xFF242438),
        sidebarActive: _primary,
        sidebarText: Color(0xFFCCCCCC),
        sidebarTextSecondary: Color(0xFF888888),
        tableBorder: Color(0xFF333355),
        badgeRed: Color(0xFF501313),     badgeRedText: Color(0xFFF7C1C1),
        badgeAmber: Color(0xFF412402),   badgeAmberText: Color(0xFFFAC775),
        badgeGreen: Color(0xFF173404),   badgeGreenText: Color(0xFFC0DD97),
      ),
    ],
  );

  // ── ПЛАМЯ ────────────────────────────────────────────────────────────────
  static ThemeData flameTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFD4560C),
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF1E1008),
    cardColor: const Color(0xFF2C1A0C),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2C1A0C),
      foregroundColor: Color(0xFFF0CCAA),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF2C1A0C),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFF0CCAA)),
      contentTextStyle: TextStyle(fontSize: 13, color: Color(0xFFD4AA88)),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFFD4AA88)),
      bodySmall:  TextStyle(fontSize: 11, color: Color(0xFF9A7050)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFF0CCAA)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFD4560C),
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD4560C),
        side: const BorderSide(color: Color(0xFFD4560C)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFD4560C)),
    ),
    extensions: const [
      AppColors(
        danger: Color(0xFFE24B4A), amber: Color(0xFFEF9F27), success: Color(0xFF639922),
        sidebarBg: Color(0xFF180E04),
        sidebarActive: Color(0xFFD4560C),
        sidebarText: Color(0xFFF0CCB0),
        sidebarTextSecondary: Color(0xFF9A7050),
        tableBorder: Color(0xFF3E2010),
        badgeRed: Color(0xFF4D1010),     badgeRedText: Color(0xFFF7A090),
        badgeAmber: Color(0xFF3D2000),   badgeAmberText: Color(0xFFF5BE60),
        badgeGreen: Color(0xFF162E05),   badgeGreenText: Color(0xFFB5D490),
      ),
    ],
  );
}

class AppColors extends ThemeExtension<AppColors> {
  final Color danger, amber, success;
  final Color sidebarBg, sidebarActive;
  final Color sidebarText, sidebarTextSecondary;
  final Color tableBorder;
  final Color badgeRed, badgeRedText;
  final Color badgeAmber, badgeAmberText;
  final Color badgeGreen, badgeGreenText;

  const AppColors({
    required this.danger, required this.amber, required this.success,
    required this.sidebarBg, required this.sidebarActive,
    required this.sidebarText, required this.sidebarTextSecondary,
    required this.tableBorder,
    required this.badgeRed, required this.badgeRedText,
    required this.badgeAmber, required this.badgeAmberText,
    required this.badgeGreen, required this.badgeGreenText,
  });

  @override
  AppColors copyWith({
    Color? danger, Color? amber, Color? success,
    Color? sidebarBg, Color? sidebarActive,
    Color? sidebarText, Color? sidebarTextSecondary,
    Color? tableBorder,
    Color? badgeRed, Color? badgeRedText,
    Color? badgeAmber, Color? badgeAmberText,
    Color? badgeGreen, Color? badgeGreenText,
  }) => AppColors(
    danger: danger ?? this.danger,
    amber: amber ?? this.amber,
    success: success ?? this.success,
    sidebarBg: sidebarBg ?? this.sidebarBg,
    sidebarActive: sidebarActive ?? this.sidebarActive,
    sidebarText: sidebarText ?? this.sidebarText,
    sidebarTextSecondary: sidebarTextSecondary ?? this.sidebarTextSecondary,
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
