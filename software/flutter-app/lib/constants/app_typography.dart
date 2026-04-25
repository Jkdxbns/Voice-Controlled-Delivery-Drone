import 'package:flutter/material.dart';

/// ============================================================================
/// APP TYPOGRAPHY - Font sizes, weights, families, and text styles
/// ============================================================================
/// 
/// Structure:
/// - FontSize: Static font size values (use with constraints in responsive context)
/// - FontWeight: Font weight definitions
/// - FontFamily: Font family constants
/// - AppTextStyle: Pre-built text styles for common use cases
/// 
/// Naming Convention:
/// - FontSize.small, FontSize.medium, FontSize.large, FontSize.xlarge
/// - AppTextStyle.headingLarge, AppTextStyle.bodyMedium
/// 
/// Usage:
/// - Static: FontSize.medium (returns 14.0)
/// - Responsive: AppTypography(context).bodyMedium
/// ============================================================================

/// Font size constants - Base values in logical pixels
/// Use these with responsive scaling for different device sizes
class FontSize {
  FontSize._();

  // ============================================================================
  // FONT SIZES - Full scale for flexibility
  // ============================================================================
  
  /// Micro - very small labels on widgets (e.g., joystick buttons)
  static const double xxsmall = 8.0;
  
  /// Tiny - smallest readable text (rarely used)
  static const double tiny = 9.0;
  
  /// Extra small - captions, timestamps, badges
  static const double xsmall = 10.0;
  
  /// Extra small+ - slightly larger captions
  static const double xsmallPlus = 11.0;
  
  /// Small - secondary text, hints, labels
  static const double small = 12.0;
  
  /// Small+ - between small and medium
  static const double smallPlus = 13.0;
  
  /// Medium - body text, default size (base)
  static const double medium = 14.0;
  
  /// Large - subtitles, emphasized text
  static const double large = 16.0;
  
  /// Extra large - section headers, titles
  static const double xlarge = 18.0;
  
  /// Extra large+ - slightly larger titles
  static const double xlargePlus = 20.0;
  
  /// 2X large - page titles, major headings
  static const double xxlarge = 24.0;
  
  /// 3X large - display text, hero sections
  static const double xxxlarge = 32.0;
  
  /// 4X large - splash screens, large displays
  static const double xxxxlarge = 40.0;

  // ============================================================================
  // MIN/MAX CONSTRAINTS - For responsive scaling
  // ============================================================================
  
  /// Minimum readable font size (accessibility)
  static const double minReadable = 10.0;
  
  /// Maximum practical font size for body text
  static const double maxBody = 20.0;
  
  /// Maximum practical font size for headings
  static const double maxHeading = 48.0;
}

/// Font weight constants
class FontWeightStyle {
  FontWeightStyle._();

  // ============================================================================
  // FONT WEIGHTS - Standard weight scale
  // ============================================================================
  
  /// Thin - w100 (rarely used)
  static const FontWeight thin = FontWeight.w100;
  
  /// Extra light - w200
  static const FontWeight extraLight = FontWeight.w200;
  
  /// Light - w300
  static const FontWeight light = FontWeight.w300;
  
  /// Regular/Normal - w400 (default)
  static const FontWeight regular = FontWeight.w400;
  
  /// Medium - w500
  static const FontWeight medium = FontWeight.w500;
  
  /// Semi-bold - w600
  static const FontWeight semiBold = FontWeight.w600;
  
  /// Bold - w700
  static const FontWeight bold = FontWeight.w700;
  
  /// Extra bold - w800
  static const FontWeight extraBold = FontWeight.w800;
  
  /// Black - w900 (heaviest)
  static const FontWeight black = FontWeight.w900;
}

/// Font family constants
/// Note: Using system default for now (Roboto on Android, SF Pro on iOS)
/// Update this when custom fonts are added
class FontFamily {
  FontFamily._();

  // ============================================================================
  // FONT FAMILIES
  // ============================================================================
  
  /// Primary font - used for most text
  /// null = system default (Roboto/SF Pro)
  static const String? primary = null;
  
  /// Secondary font - used for headings (if different)
  static const String? secondary = null;
  
  /// Monospace font - used for code, technical content
  static const String monospace = 'monospace';
}

/// Line height multipliers
class LineHeight {
  LineHeight._();

  /// Tight - for headings, dense text
  static const double tight = 1.1;
  
  /// Normal - default line height
  static const double normal = 1.2;
  
  /// Relaxed - for body text, better readability
  static const double relaxed = 1.4;
  
  /// Loose - for large text blocks
  static const double loose = 1.6;
}

/// Letter spacing constants
class LetterSpacing {
  LetterSpacing._();

  /// Tight - for headings
  static const double tight = -0.5;
  
  /// Normal - default
  static const double normal = 0.0;
  
  /// Wide - for uppercase text, labels
  static const double wide = 0.5;
  
  /// Extra wide - for small caps, emphasis
  static const double extraWide = 1.0;
}

/// Pre-built text styles for common use cases
/// These use fixed sizes - for responsive sizes, use AppTypography
class AppTextStyle {
  AppTextStyle._();

  // ============================================================================
  // DISPLAY STYLES - Large prominent text
  // ============================================================================
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: FontSize.xxxxlarge,
    fontWeight: FontWeightStyle.bold,
    height: LineHeight.tight,
    letterSpacing: LetterSpacing.tight,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: FontSize.xxxlarge,
    fontWeight: FontWeightStyle.bold,
    height: LineHeight.tight,
    letterSpacing: LetterSpacing.tight,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontSize: FontSize.xxlarge,
    fontWeight: FontWeightStyle.bold,
    height: LineHeight.normal,
    letterSpacing: LetterSpacing.normal,
  );

  // ============================================================================
  // HEADING STYLES - Section headers
  // ============================================================================
  
  static const TextStyle headingLarge = TextStyle(
    fontSize: FontSize.xxlarge,
    fontWeight: FontWeightStyle.bold,
    height: LineHeight.normal,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: FontSize.xlarge,
    fontWeight: FontWeightStyle.bold,
    height: LineHeight.normal,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: FontSize.large,
    fontWeight: FontWeightStyle.semiBold,
    height: LineHeight.normal,
  );

  // ============================================================================
  // TITLE STYLES - Card titles, list item titles
  // ============================================================================
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: FontSize.large,
    fontWeight: FontWeightStyle.semiBold,
    height: LineHeight.relaxed,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: FontSize.medium,
    fontWeight: FontWeightStyle.semiBold,
    height: LineHeight.relaxed,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: FontSize.small,
    fontWeight: FontWeightStyle.semiBold,
    height: LineHeight.relaxed,
  );

  // ============================================================================
  // BODY STYLES - Main content text
  // ============================================================================
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: FontSize.large,
    fontWeight: FontWeightStyle.regular,
    height: LineHeight.relaxed,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: FontSize.medium,
    fontWeight: FontWeightStyle.regular,
    height: LineHeight.relaxed,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: FontSize.small,
    fontWeight: FontWeightStyle.regular,
    height: LineHeight.relaxed,
  );

  // ============================================================================
  // LABEL STYLES - Form labels, button text
  // ============================================================================
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: FontSize.medium,
    fontWeight: FontWeightStyle.medium,
    height: LineHeight.normal,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: FontSize.small,
    fontWeight: FontWeightStyle.medium,
    height: LineHeight.normal,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: FontSize.xsmall,
    fontWeight: FontWeightStyle.medium,
    height: LineHeight.normal,
    letterSpacing: LetterSpacing.wide,
  );

  // ============================================================================
  // SPECIAL STYLES - Specific use cases
  // ============================================================================
  
  /// Caption style - timestamps, secondary info
  static const TextStyle caption = TextStyle(
    fontSize: FontSize.xsmall,
    fontWeight: FontWeightStyle.regular,
    height: LineHeight.normal,
    fontStyle: FontStyle.italic,
  );
  
  /// Button text style
  static const TextStyle button = TextStyle(
    fontSize: FontSize.medium,
    fontWeight: FontWeightStyle.semiBold,
    height: LineHeight.normal,
  );
  
  /// Badge/Chip text style
  static const TextStyle badge = TextStyle(
    fontSize: FontSize.xsmall,
    fontWeight: FontWeightStyle.bold,
    height: LineHeight.tight,
  );
  
  /// Overline style - category labels, section markers
  static const TextStyle overline = TextStyle(
    fontSize: FontSize.xsmall,
    fontWeight: FontWeightStyle.medium,
    height: LineHeight.normal,
    letterSpacing: LetterSpacing.extraWide,
  );
}

/// Responsive typography that scales based on screen size
/// Usage: AppTypography(context).headingLarge
class AppTypography {
  final BuildContext context;
  late final double _scaleFactor;
  late final _DeviceCategory _device;

  AppTypography(this.context) {
    final width = MediaQuery.of(context).size.width;
    _device = _getDeviceCategory(width);
    _scaleFactor = _getScaleFactor();
  }

  _DeviceCategory _getDeviceCategory(double width) {
    if (width < 360) return _DeviceCategory.smallPhone;
    if (width < 600) return _DeviceCategory.phone;
    if (width < 900) return _DeviceCategory.tablet;
    if (width < 1200) return _DeviceCategory.laptop;
    return _DeviceCategory.desktop;
  }

  double _getScaleFactor() {
    switch (_device) {
      case _DeviceCategory.smallPhone:
        return 0.85;
      case _DeviceCategory.phone:
        return 1.0;
      case _DeviceCategory.tablet:
        return 1.15;
      case _DeviceCategory.laptop:
        return 1.25;
      case _DeviceCategory.desktop:
        return 1.35;
    }
  }

  /// Scale a font size with min/max constraints
  double _scale(double baseSize, {double? min, double? max}) {
    final scaled = baseSize * _scaleFactor;
    final minVal = min ?? FontSize.minReadable;
    final maxVal = max ?? (baseSize * 1.5);
    return scaled.clamp(minVal, maxVal);
  }

  // ============================================================================
  // RESPONSIVE FONT SIZES
  // ============================================================================
  
  double get fontSizeXSmall => _scale(FontSize.xsmall);
  double get fontSizeSmall => _scale(FontSize.small);
  double get fontSizeMedium => _scale(FontSize.medium);
  double get fontSizeLarge => _scale(FontSize.large);
  double get fontSizeXLarge => _scale(FontSize.xlarge);
  double get fontSizeXXLarge => _scale(FontSize.xxlarge, max: FontSize.maxHeading);
  double get fontSizeXXXLarge => _scale(FontSize.xxxlarge, max: FontSize.maxHeading);

  // ============================================================================
  // RESPONSIVE TEXT STYLES
  // ============================================================================
  
  TextStyle get displayLarge => AppTextStyle.displayLarge.copyWith(
    fontSize: _scale(FontSize.xxxxlarge, max: 56),
  );
  
  TextStyle get displayMedium => AppTextStyle.displayMedium.copyWith(
    fontSize: _scale(FontSize.xxxlarge, max: 48),
  );
  
  TextStyle get displaySmall => AppTextStyle.displaySmall.copyWith(
    fontSize: _scale(FontSize.xxlarge, max: 36),
  );

  TextStyle get headingLarge => AppTextStyle.headingLarge.copyWith(
    fontSize: _scale(FontSize.xxlarge, max: 32),
  );
  
  TextStyle get headingMedium => AppTextStyle.headingMedium.copyWith(
    fontSize: _scale(FontSize.xlarge, max: 24),
  );
  
  TextStyle get headingSmall => AppTextStyle.headingSmall.copyWith(
    fontSize: _scale(FontSize.large, max: 20),
  );

  TextStyle get titleLarge => AppTextStyle.titleLarge.copyWith(
    fontSize: _scale(FontSize.large, max: 20),
  );
  
  TextStyle get titleMedium => AppTextStyle.titleMedium.copyWith(
    fontSize: _scale(FontSize.medium, max: 18),
  );
  
  TextStyle get titleSmall => AppTextStyle.titleSmall.copyWith(
    fontSize: _scale(FontSize.small, max: 16),
  );

  TextStyle get bodyLarge => AppTextStyle.bodyLarge.copyWith(
    fontSize: _scale(FontSize.large, max: FontSize.maxBody),
  );
  
  TextStyle get bodyMedium => AppTextStyle.bodyMedium.copyWith(
    fontSize: _scale(FontSize.medium, max: FontSize.maxBody),
  );
  
  TextStyle get bodySmall => AppTextStyle.bodySmall.copyWith(
    fontSize: _scale(FontSize.small, max: 16),
  );

  TextStyle get labelLarge => AppTextStyle.labelLarge.copyWith(
    fontSize: _scale(FontSize.medium, max: 18),
  );
  
  TextStyle get labelMedium => AppTextStyle.labelMedium.copyWith(
    fontSize: _scale(FontSize.small, max: 16),
  );
  
  TextStyle get labelSmall => AppTextStyle.labelSmall.copyWith(
    fontSize: _scale(FontSize.xsmall, max: 14),
  );

  TextStyle get caption => AppTextStyle.caption.copyWith(
    fontSize: _scale(FontSize.xsmall, max: 14),
  );
  
  TextStyle get button => AppTextStyle.button.copyWith(
    fontSize: _scale(FontSize.medium, max: 18),
  );
  
  TextStyle get badge => AppTextStyle.badge.copyWith(
    fontSize: _scale(FontSize.xsmall, max: 14),
  );
}

enum _DeviceCategory {
  smallPhone,  // < 360px
  phone,       // 360-600px
  tablet,      // 600-900px
  laptop,      // 900-1200px
  desktop,     // > 1200px
}

/// Extension for easy access to responsive typography
extension TypographyExtension on BuildContext {
  AppTypography get typography => AppTypography(this);
}
