import 'package:astro_nav/src/design/tokens.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = base.textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
    fontFamily: 'NotoSansSC',
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.voidBlack,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.amber,
      error: AppColors.coral,
      surface: AppColors.panelStrong,
      onSurface: AppColors.text,
    ),
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
    dividerColor: AppColors.line,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panelStrong,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        borderSide: BorderSide(color: AppColors.cyan, width: 1.2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSizes.iconButton),
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.voidBlack,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.panelStrong,
      contentTextStyle: TextStyle(
        color: AppColors.text,
        fontFamily: 'NotoSansSC',
        letterSpacing: 0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
  );
}
