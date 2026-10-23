import 'package:app_do_fut/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Tema escuro do app (docs/design/01-cores-e-tipografia.md).
/// Inter para UI e Oswald para números (placar, OVR, notas), ambas empacotadas
/// como assets para funcionar offline.
class AppTheme {
  static const uiFont = 'Inter';
  static const numberFont = 'Oswald';

  /// Algarismos tabulares: placar e notas não "pulam".
  static const tabularFigures = [FontFeature.tabularFigures()];

  /// Estilo para números (placar, OVR, notas). Nunca abaixo de 10sp.
  static TextStyle number({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.textPrimary,
  }) {
    assert(fontSize >= 10, 'Nenhum texto abaixo de 10sp');
    return TextStyle(
      fontFamily: numberFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: tabularFigures,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accentBlue,
      secondary: AppColors.highlightBlue,
      surface: AppColors.headerBlue,
      surfaceContainerHighest: AppColors.surfaceSubtle,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.borderSubtle,
      outlineVariant: AppColors.borderSubtle,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: uiFont,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.deepBlue,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: uiFont,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.headerBlue,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSubtle,
        side: const BorderSide(color: AppColors.borderSubtle),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderFocused),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.highlightBlue),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
