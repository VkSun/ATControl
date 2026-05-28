import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

class AppTheme {
  static const _primary = Color(0xFF4361EE);
  static const _danger = Color(0xFFE24B4A);
  static const _amber = Color(0xFFEF9F27);
  static const _green = Color(0xFF639922);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primary,
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
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF333333)),
      bodySmall: TextStyle(fontSize: 11, color: Color(0xFF888888)),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    extensions: const [
      AppColors(
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Colors.white,
        sidebarActive: _primary,
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
      seedColor: _primary,
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
    extensions: const [
      AppColors(
        danger: _danger,
        amber: _amber,
        success: _green,
        sidebarBg: Color(0xFF242438),
        sidebarActive: _primary,
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
}

class AppColors extends ThemeExtension<AppColors> {
  final Color danger, amber, success;
  final Color sidebarBg, sidebarActive, tableBorder;
  final Color badgeRed, badgeRedText;
  final Color badgeAmber, badgeAmberText;
  final Color badgeGreen, badgeGreenText;

  const AppColors({
    required this.danger, required this.amber, required this.success,
    required this.sidebarBg, required this.sidebarActive, required this.tableBorder,
    required this.badgeRed, required this.badgeRedText,
    required this.badgeAmber, required this.badgeAmberText,
    required this.badgeGreen, required this.badgeGreenText,
  });

  @override
  AppColors copyWith({
    Color? danger, Color? amber, Color? success,
    Color? sidebarBg, Color? sidebarActive, Color? tableBorder,
    Color? badgeRed, Color? badgeRedText,
    Color? badgeAmber, Color? badgeAmberText,
    Color? badgeGreen, Color? badgeGreenText,
  }) => AppColors(
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