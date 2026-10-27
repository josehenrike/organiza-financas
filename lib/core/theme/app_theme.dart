import 'package:flutter/material.dart';

/// Cores semânticas do app, com variações para tema claro e escuro.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.business,
    required this.family,
    required this.businessFill,
    required this.familyFill,
    required this.businessTint,
    required this.familyTint,
    required this.danger,
    required this.warning,
    required this.panel,
    required this.border,
    required this.track,
    required this.warningSurface,
    required this.onWarningSurface,
    required this.muted,
  });

  /// Destaques e textos de cada bolso.
  final Color business, family;

  /// Fundos sólidos com texto branco por cima.
  final Color businessFill, familyFill;

  /// Fundos suaves.
  final Color businessTint, familyTint;
  final Color danger, warning;
  final Color panel, border, track;
  final Color warningSurface, onWarningSurface;
  final Color muted;

  static const light = FinanceColors(
    business: Color(0xFF286747),
    family: Color(0xFF285E99),
    businessFill: Color(0xFF286747),
    familyFill: Color(0xFF285E99),
    businessTint: Color(0xFFEAF1E6),
    familyTint: Color(0xFFE7EEF7),
    danger: Color(0xFFB74636),
    warning: Color(0xFF8F6000),
    panel: Colors.white,
    border: Color(0xFFE0E6DD),
    track: Color(0xFFE9EDE6),
    warningSurface: Color(0xFFFFECCD),
    onWarningSurface: Color(0xFF5A3D00),
    muted: Color(0xFF5D6B62),
  );

  static const dark = FinanceColors(
    business: Color(0xFF8FD3A8),
    family: Color(0xFF9CC3EE),
    businessFill: Color(0xFF1E5A3D),
    familyFill: Color(0xFF22507F),
    businessTint: Color(0xFF1C2A22),
    familyTint: Color(0xFF1A2431),
    danger: Color(0xFFFF9A8A),
    warning: Color(0xFFE5B85C),
    panel: Color(0xFF1A211D),
    border: Color(0xFF2E3832),
    track: Color(0xFF2A332D),
    warningSurface: Color(0xFF45361A),
    onWarningSurface: Color(0xFFFFE2B0),
    muted: Color(0xFFA5B3AA),
  );

  @override
  FinanceColors copyWith() => this;

  @override
  FinanceColors lerp(FinanceColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FinanceColors(
      business: l(business, other.business),
      family: l(family, other.family),
      businessFill: l(businessFill, other.businessFill),
      familyFill: l(familyFill, other.familyFill),
      businessTint: l(businessTint, other.businessTint),
      familyTint: l(familyTint, other.familyTint),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
      panel: l(panel, other.panel),
      border: l(border, other.border),
      track: l(track, other.track),
      warningSurface: l(warningSurface, other.warningSurface),
      onWarningSurface: l(onWarningSurface, other.onWarningSurface),
      muted: l(muted, other.muted),
    );
  }
}

abstract final class AppTheme {
  static const _tabular = [FontFeature.tabularFigures()];

  static ThemeData get light => _build(
    Brightness.light,
    FinanceColors.light,
    background: const Color(0xFFF5F5EE),
    ink: const Color(0xFF202E26),
  );

  static ThemeData get dark => _build(
    Brightness.dark,
    FinanceColors.dark,
    background: const Color(0xFF111613),
    ink: const Color(0xFFE3EAE5),
  );

  static ThemeData _build(
    Brightness brightness,
    FinanceColors colors, {
    required Color background,
    required Color ink,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF286747),
      brightness: brightness,
      surface: background,
      error: colors.danger,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      extensions: [colors],
      scaffoldBackgroundColor: background,
      // Algarismos de largura fixa alinham os valores em colunas.
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.2,
          letterSpacing: -.3,
          color: ink,
          fontFeatures: _tabular,
        ),
        titleLarge: TextStyle(fontSize: 20, color: ink, fontFeatures: _tabular),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.45,
          color: ink,
          fontFeatures: _tabular,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          height: 1.45,
          color: ink,
          fontFeatures: _tabular,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.panel,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? const Color(0xFFF8F9F5)
            : const Color(0xFF151B18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colors.border, width: 1.4),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: shape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.businessFill,
        foregroundColor: Colors.white,
        extendedTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colors.border),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.panel,
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: colors.panel,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.panel,
      ),
    );
  }
}
