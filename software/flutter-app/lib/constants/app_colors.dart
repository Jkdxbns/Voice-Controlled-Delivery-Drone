import 'package:flutter/material.dart';

/// ============================================================================
/// APP COLORS - Centralized color management for the entire application
/// ============================================================================
/// 
/// Structure:
/// - AppColors: Static color values (light theme default)
/// - AppColorsDark: Dark theme color overrides
/// - AppColorScheme: Dynamic color scheme builder for theming
/// 
/// Usage:
/// - Static: AppColors.primary, AppColors.success
/// - Dark mode aware: AppColorScheme.of(context).primary
/// 
/// Future scaling: Add new color themes by creating new classes similar to
/// AppColorsDark (e.g., AppColorsOcean, AppColorsForest, etc.)
/// ============================================================================

/// Primary color palette - Light Theme (Default)
class AppColors {
  AppColors._();

  // ============================================================================
  // BRAND COLORS - Primary palette (Blue theme)
  // ============================================================================
  
  /// Primary brand color - main accent throughout the app
  static const Color primary = Color(0xFF1565C0);       // Blue 800
  static const Color primaryLight = Color(0xFF1976D2); // Blue 700
  static const Color primaryDark = Color(0xFF0D47A1);  // Blue 900
  
  /// Secondary brand color - complementary accent
  static const Color secondary = Color(0xFF0D47A1);     // Darker blue
  static const Color secondaryLight = Color(0xFF1565C0);
  static const Color secondaryDark = Color(0xFF002171);
  
  /// Accent color for highlights and CTAs
  static const Color accent = Color(0xFF448AFF);        // Blue Accent
  static const Color accentLight = Color(0xFF82B1FF);
  static const Color accentDark = Color(0xFF2962FF);

  // ============================================================================
  // SEMANTIC COLORS - Status indicators
  // ============================================================================
  
  /// Success states - confirmations, completed actions
  static const Color success = Color(0xFF4CAF50);       // Green 500
  static const Color successLight = Color(0xFF81C784); // Green 300
  static const Color successDark = Color(0xFF388E3C);  // Green 700
  
  /// Error states - failures, destructive actions
  static const Color error = Color(0xFFF44336);         // Red 500
  static const Color errorLight = Color(0xFFE57373);   // Red 300
  static const Color errorDark = Color(0xFFD32F2F);    // Red 700
  
  /// Warning states - caution, attention needed
  static const Color warning = Color(0xFFFF9800);       // Orange 500
  static const Color warningLight = Color(0xFFFFB74D); // Orange 300
  static const Color warningDark = Color(0xFFF57C00);  // Orange 700
  
  /// Info states - informational, neutral notifications
  static const Color info = Color(0xFF2196F3);          // Blue 500
  static const Color infoLight = Color(0xFF64B5F6);    // Blue 300
  static const Color infoDark = Color(0xFF1976D2);     // Blue 700

  // ============================================================================
  // NEUTRAL COLORS - Grayscale palette
  // ============================================================================
  
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  
  /// Grey scale - from lightest to darkest
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // ============================================================================
  // SURFACE COLORS - Backgrounds and containers (Light theme)
  // ============================================================================
  
  /// Main scaffold/page background
  static const Color background = Color(0xFFFAFAFA);
  
  /// Card and elevated surface background
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Container backgrounds (slightly elevated)
  static const Color surfaceContainer = Color(0xFFF5F5F5);
  static const Color surfaceContainerHigh = Color(0xFFEEEEEE);
  static const Color surfaceContainerHighest = Color(0xFFE0E0E0);

  // ============================================================================
  // TEXT COLORS - Typography (Light theme)
  // ============================================================================
  
  /// Primary text - headings, important content
  static const Color textPrimary = Color(0xDD000000);   // 87% black
  
  /// Secondary text - body, descriptions
  static const Color textSecondary = Color(0x8A000000); // 54% black
  
  /// Tertiary text - hints, placeholders, less important
  static const Color textTertiary = Color(0x66000000);  // 40% black
  
  /// Disabled/hint text
  static const Color textDisabled = Color(0x61000000);  // 38% black
  
  /// Text on colored backgrounds
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);
  static const Color textOnError = Color(0xFFFFFFFF);

  // ============================================================================
  // COMPONENT SPECIFIC COLORS - Chat bubbles
  // ============================================================================
  
  /// User message bubble
  static const Color userBubble = Color(0xFFBBDEFB);      // Blue 100
  static const Color userBubbleBorder = Color(0xFF90CAF9); // Blue 200
  static const Color userText = Color(0xDD000000);
  
  /// AI/Assistant message bubble
  static const Color aiBubble = Color(0xFFEEEEEE);         // Grey 200
  static const Color aiBubbleBorder = Color(0xFFE0E0E0);   // Grey 300
  static const Color aiText = Color(0xDD000000);

  // ============================================================================
  // COMPONENT SPECIFIC COLORS - Recording states
  // ============================================================================
  
  /// Recording active state
  static const Color recording = Color(0xFFFB8C00);       // Orange 600
  static const Color recordingPulse = Color(0xFFFF9800);  // Orange 500
  
  /// Recording idle state
  static const Color recordingIdle = Color(0xFFE0E0E0);   // Grey 300

  // ============================================================================
  // COMPONENT SPECIFIC COLORS - Home screen tiles
  // ============================================================================
  
  static const Color tileAiAssistant = Color(0xFF2196F3); // Blue
  static const Color tileChatHistory = Color(0xFF4CAF50); // Green
  static const Color tileModels = Color(0xFF9C27B0);      // Purple
  static const Color tileSettings = Color(0xFFFF9800);    // Orange

  // ============================================================================
  // COMPONENT SPECIFIC COLORS - Model info bar
  // ============================================================================
  
  static const Color modelInfoBarBackground = Color(0xFF1E3A5F);
  static const Color modelInfoLabel = Color(0xFFB0BEC5);
  static const Color modelInfoSttHighlight = Color(0xFF64B5F6);
  static const Color modelInfoLmHighlight = Color(0xFF81C784);
  
  // ============================================================================
  // ADDITIONAL COLORS
  // ============================================================================
  
  static const Color orange = Color(0xFFFF9800);
  static const Color purple = Color(0xFF9C27B0);

  // ============================================================================
  // BORDER COLORS
  // ============================================================================
  
  static const Color border = Color(0xFFE0E0E0);          // Grey 300
  static const Color borderLight = Color(0xFFEEEEEE);     // Grey 200
  static const Color borderDark = Color(0xFFBDBDBD);      // Grey 400
  static const Color divider = Color(0xFFE0E0E0);

  // ============================================================================
  // OVERLAY COLORS
  // ============================================================================
  
  static const Color overlay = Color(0x1F000000);         // 12% black
  static const Color overlayMedium = Color(0x3D000000);   // 24% black
  static const Color overlayDark = Color(0x61000000);     // 38% black
  static const Color scrim = Color(0x52000000);           // 32% black
}

/// Dark theme color palette
class AppColorsDark {
  AppColorsDark._();

  // ============================================================================
  // BRAND COLORS - Primary palette (Dark theme)
  // ============================================================================
  
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  
  static const Color secondary = Color(0xFF0D47A1);
  static const Color secondaryLight = Color(0xFF1565C0);
  static const Color secondaryDark = Color(0xFF002171);
  
  static const Color accent = Color(0xFF82B1FF);
  static const Color accentLight = Color(0xFFB6D4FF);
  static const Color accentDark = Color(0xFF448AFF);

  // ============================================================================
  // SEMANTIC COLORS - Status indicators (Dark theme - slightly lighter)
  // ============================================================================
  
  static const Color success = Color(0xFF66BB6A);
  static const Color successLight = Color(0xFFA5D6A7);
  static const Color successDark = Color(0xFF43A047);
  
  static const Color error = Color(0xFFEF5350);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorDark = Color(0xFFE53935);
  
  static const Color warning = Color(0xFFFFA726);
  static const Color warningLight = Color(0xFFFFCC80);
  static const Color warningDark = Color(0xFFFB8C00);
  
  static const Color info = Color(0xFF42A5F5);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF2196F3);

  // ============================================================================
  // NEUTRAL COLORS - Dark theme grayscale (inverted)
  // ============================================================================
  
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  
  static const Color grey50 = Color(0xFF303030);
  static const Color grey100 = Color(0xFF424242);
  static const Color grey200 = Color(0xFF616161);
  static const Color grey300 = Color(0xFF757575);
  static const Color grey400 = Color(0xFF9E9E9E);
  static const Color grey500 = Color(0xFFBDBDBD);
  static const Color grey600 = Color(0xFFE0E0E0);
  static const Color grey700 = Color(0xFFEEEEEE);
  static const Color grey800 = Color(0xFFF5F5F5);
  static const Color grey900 = Color(0xFFFAFAFA);

  // ============================================================================
  // SURFACE COLORS - Backgrounds and containers (Dark theme)
  // ============================================================================
  
  /// Main scaffold/page background - deep navy blue
  static const Color background = Color(0xFF0A1929);
  
  /// Card and elevated surface background
  static const Color surface = Color(0xFF1E3A5F);
  
  /// Container backgrounds
  static const Color surfaceContainer = Color(0xFF0D2844);
  static const Color surfaceContainerHigh = Color(0xFF1E3A5F);
  static const Color surfaceContainerHighest = Color(0xFF2A4A6F);

  // ============================================================================
  // TEXT COLORS - Typography (Dark theme)
  // ============================================================================
  
  static const Color textPrimary = Color(0xDEFFFFFF);     // 87% white
  static const Color textSecondary = Color(0x99FFFFFF);   // 60% white
  static const Color textTertiary = Color(0x66FFFFFF);    // 40% white
  static const Color textDisabled = Color(0x61FFFFFF);    // 38% white
  
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);
  static const Color textOnError = Color(0xFFFFFFFF);

  // ============================================================================
  // COMPONENT SPECIFIC COLORS - Chat bubbles (Dark theme)
  // ============================================================================
  
  static const Color userBubble = Color(0xFF2A4A6F);
  static const Color userBubbleBorder = Color(0xFF1565C0);
  static const Color userText = Color(0xDEFFFFFF);
  
  static const Color aiBubble = Color(0xFF0D2844);
  static const Color aiBubbleBorder = Color(0xFF1E3A5F);
  static const Color aiText = Color(0xDEFFFFFF);

  // ============================================================================
  // COMPONENT SPECIFIC COLORS - Recording states (Dark theme)
  // ============================================================================
  
  static const Color recording = Color(0xFFFFA726);
  static const Color recordingPulse = Color(0xFFFFB74D);
  static const Color recordingIdle = Color(0xFF424242);

  // ============================================================================
  // BORDER COLORS (Dark theme)
  // ============================================================================
  
  static const Color border = Color(0xFF1E3A5F);
  static const Color borderLight = Color(0xFF2A4A6F);
  static const Color borderDark = Color(0xFF0D2844);
  static const Color divider = Color(0xFF1E3A5F);

  // ============================================================================
  // OVERLAY COLORS (Dark theme)
  // ============================================================================
  
  static const Color overlay = Color(0x1FFFFFFF);
  static const Color overlayMedium = Color(0x3DFFFFFF);
  static const Color overlayDark = Color(0x61FFFFFF);
  static const Color scrim = Color(0x99000000);
}

/// Dynamic color scheme that provides theme-aware colors
/// Usage: AppColorScheme.of(context).primary
class AppColorScheme {
  final bool isDark;
  
  const AppColorScheme._({required this.isDark});
  
  /// Get color scheme based on current theme
  factory AppColorScheme.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColorScheme._(isDark: isDark);
  }
  
  /// Check if dark mode is active
  factory AppColorScheme.fromBrightness(Brightness brightness) {
    return AppColorScheme._(isDark: brightness == Brightness.dark);
  }

  // Brand colors
  Color get primary => isDark ? AppColorsDark.primary : AppColors.primary;
  Color get primaryLight => isDark ? AppColorsDark.primaryLight : AppColors.primaryLight;
  Color get primaryDark => isDark ? AppColorsDark.primaryDark : AppColors.primaryDark;
  
  Color get secondary => isDark ? AppColorsDark.secondary : AppColors.secondary;
  Color get secondaryLight => isDark ? AppColorsDark.secondaryLight : AppColors.secondaryLight;
  Color get secondaryDark => isDark ? AppColorsDark.secondaryDark : AppColors.secondaryDark;
  
  Color get accent => isDark ? AppColorsDark.accent : AppColors.accent;
  Color get accentLight => isDark ? AppColorsDark.accentLight : AppColors.accentLight;
  Color get accentDark => isDark ? AppColorsDark.accentDark : AppColors.accentDark;

  // Semantic colors
  Color get success => isDark ? AppColorsDark.success : AppColors.success;
  Color get successLight => isDark ? AppColorsDark.successLight : AppColors.successLight;
  Color get successDark => isDark ? AppColorsDark.successDark : AppColors.successDark;
  
  Color get error => isDark ? AppColorsDark.error : AppColors.error;
  Color get errorLight => isDark ? AppColorsDark.errorLight : AppColors.errorLight;
  Color get errorDark => isDark ? AppColorsDark.errorDark : AppColors.errorDark;
  
  Color get warning => isDark ? AppColorsDark.warning : AppColors.warning;
  Color get warningLight => isDark ? AppColorsDark.warningLight : AppColors.warningLight;
  Color get warningDark => isDark ? AppColorsDark.warningDark : AppColors.warningDark;
  
  Color get info => isDark ? AppColorsDark.info : AppColors.info;
  Color get infoLight => isDark ? AppColorsDark.infoLight : AppColors.infoLight;
  Color get infoDark => isDark ? AppColorsDark.infoDark : AppColors.infoDark;

  // Neutral colors
  Color get white => AppColors.white;
  Color get black => AppColors.black;
  Color get transparent => AppColors.transparent;
  
  Color get grey50 => isDark ? AppColorsDark.grey50 : AppColors.grey50;
  Color get grey100 => isDark ? AppColorsDark.grey100 : AppColors.grey100;
  Color get grey200 => isDark ? AppColorsDark.grey200 : AppColors.grey200;
  Color get grey300 => isDark ? AppColorsDark.grey300 : AppColors.grey300;
  Color get grey400 => isDark ? AppColorsDark.grey400 : AppColors.grey400;
  Color get grey500 => isDark ? AppColorsDark.grey500 : AppColors.grey500;
  Color get grey600 => isDark ? AppColorsDark.grey600 : AppColors.grey600;
  Color get grey700 => isDark ? AppColorsDark.grey700 : AppColors.grey700;
  Color get grey800 => isDark ? AppColorsDark.grey800 : AppColors.grey800;
  Color get grey900 => isDark ? AppColorsDark.grey900 : AppColors.grey900;

  // Surface colors
  Color get background => isDark ? AppColorsDark.background : AppColors.background;
  Color get surface => isDark ? AppColorsDark.surface : AppColors.surface;
  Color get surfaceContainer => isDark ? AppColorsDark.surfaceContainer : AppColors.surfaceContainer;
  Color get surfaceContainerHigh => isDark ? AppColorsDark.surfaceContainerHigh : AppColors.surfaceContainerHigh;
  Color get surfaceContainerHighest => isDark ? AppColorsDark.surfaceContainerHighest : AppColors.surfaceContainerHighest;

  // Text colors
  Color get textPrimary => isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get textSecondary => isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get textTertiary => isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
  Color get textDisabled => isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
  Color get textOnPrimary => isDark ? AppColorsDark.textOnPrimary : AppColors.textOnPrimary;

  // Chat bubble colors
  Color get userBubble => isDark ? AppColorsDark.userBubble : AppColors.userBubble;
  Color get userBubbleBorder => isDark ? AppColorsDark.userBubbleBorder : AppColors.userBubbleBorder;
  Color get userText => isDark ? AppColorsDark.userText : AppColors.userText;
  
  Color get aiBubble => isDark ? AppColorsDark.aiBubble : AppColors.aiBubble;
  Color get aiBubbleBorder => isDark ? AppColorsDark.aiBubbleBorder : AppColors.aiBubbleBorder;
  Color get aiText => isDark ? AppColorsDark.aiText : AppColors.aiText;

  // Recording colors
  Color get recording => isDark ? AppColorsDark.recording : AppColors.recording;
  Color get recordingPulse => isDark ? AppColorsDark.recordingPulse : AppColors.recordingPulse;
  Color get recordingIdle => isDark ? AppColorsDark.recordingIdle : AppColors.recordingIdle;

  // Border colors
  Color get border => isDark ? AppColorsDark.border : AppColors.border;
  Color get borderLight => isDark ? AppColorsDark.borderLight : AppColors.borderLight;
  Color get borderDark => isDark ? AppColorsDark.borderDark : AppColors.borderDark;
  Color get divider => isDark ? AppColorsDark.divider : AppColors.divider;

  // Overlay colors
  Color get overlay => isDark ? AppColorsDark.overlay : AppColors.overlay;
  Color get overlayMedium => isDark ? AppColorsDark.overlayMedium : AppColors.overlayMedium;
  Color get overlayDark => isDark ? AppColorsDark.overlayDark : AppColors.overlayDark;
  Color get scrim => isDark ? AppColorsDark.scrim : AppColors.scrim;
}

/// Opacity constants for consistent transparency
class AppOpacity {
  AppOpacity._();
  
  static const double transparent = 0.0;
  static const double subtle = 0.08;
  static const double overlay = 0.12;
  static const double light = 0.24;
  static const double disabled = 0.38;
  static const double medium = 0.54;
  static const double high = 0.87;
  static const double full = 1.0;
  
  /// Border opacity
  static const double border = 0.3;
  
  /// Hover/Focus states
  static const double hover = 0.08;
  static const double focus = 0.12;
  static const double pressed = 0.16;
}
