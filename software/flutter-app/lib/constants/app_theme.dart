import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ============================================================================
/// APP THEME - ThemeData builders for light and dark themes
/// ============================================================================
/// 
/// Usage in MaterialApp:
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: themeMode,
/// )
/// ```
/// ============================================================================

class AppTheme {
  AppTheme._();

  // ============================================================================
  // LIGHT THEME
  // ============================================================================
  
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Color scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: AppColors.background,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Elevated Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
    
    // Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
    
    // List Tiles
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.grey800,
      contentTextStyle: const TextStyle(color: AppColors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    
    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
    ),
    
    // Drawer
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.surface,
    ),
  );

  // ============================================================================
  // DARK THEME
  // ============================================================================
  
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColorsDark.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColorsDark.primary,
      secondary: AppColorsDark.secondary,
      surface: AppColorsDark.surface,
      primaryContainer: AppColorsDark.surfaceContainerHigh,
      secondaryContainer: AppColorsDark.surfaceContainer,
      surfaceContainerHighest: AppColorsDark.surfaceContainerHigh,
      error: AppColorsDark.error,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: AppColorsDark.background,
    
    // Card
    cardColor: AppColorsDark.surface,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsDark.surface,
      foregroundColor: AppColorsDark.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: AppColorsDark.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Elevated Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColorsDark.primary,
        foregroundColor: AppColorsDark.textOnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColorsDark.primaryLight,
      ),
    ),
    
    // Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColorsDark.primaryLight,
        side: const BorderSide(color: AppColorsDark.primaryLight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColorsDark.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColorsDark.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColorsDark.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColorsDark.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColorsDark.error),
      ),
    ),
    
    // List Tiles
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColorsDark.divider,
      thickness: 1,
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColorsDark.surfaceContainerHighest,
      contentTextStyle: const TextStyle(color: AppColorsDark.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    
    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColorsDark.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Bottom Sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColorsDark.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    
    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColorsDark.primary,
      foregroundColor: AppColorsDark.textOnPrimary,
    ),
    
    // Drawer
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColorsDark.surface,
    ),
  );
}
