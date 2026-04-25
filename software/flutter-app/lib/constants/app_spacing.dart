import 'package:flutter/material.dart';

/// ============================================================================
/// APP SPACING - Spacing, padding, margins, and gap constants
/// ============================================================================
/// 
/// Structure:
/// - Spacing: Static spacing values
/// - AppSpacing: Responsive spacing with screen-based calculations
/// 
/// Naming Convention:
/// - Spacing.small, Spacing.medium, Spacing.large, Spacing.xlarge
/// 
/// Usage:
/// - Static: SizedBox(height: Spacing.medium)
/// - Responsive: SizedBox(height: AppSpacing(context).medium)
/// - EdgeInsets: AppSpacing(context).paddingMedium
/// ============================================================================

/// Static spacing constants - Base values in logical pixels
class Spacing {
  Spacing._();

  // ============================================================================
  // SPACING VALUES - 4 Main variants + extras
  // ============================================================================
  
  /// No spacing
  static const double zero = 0.0;
  
  /// Tiny spacing - hairline gaps
  static const double xxsmall = 2.0;
  
  /// Extra small - tight grouping
  static const double xsmall = 4.0;
  
  /// Small - compact layouts
  static const double small = 8.0;
  
  /// Medium - default spacing (base)
  static const double medium = 12.0;
  
  /// Large - comfortable spacing
  static const double large = 16.0;
  
  /// Extra large - section separation
  static const double xlarge = 24.0;
  
  /// 2X large - major sections
  static const double xxlarge = 32.0;
  
  /// 3X large - page-level spacing
  static const double xxxlarge = 48.0;
  
  /// 4X large - maximum spacing
  static const double xxxxlarge = 64.0;

  // ============================================================================
  // MIN/MAX CONSTRAINTS
  // ============================================================================
  
  /// Minimum practical spacing
  static const double min = 2.0;
  
  /// Maximum practical spacing
  static const double max = 96.0;
}

/// Responsive spacing with screen-based calculations
/// Provides spacing that scales appropriately across devices
class AppSpacing {
  final BuildContext context;
  late final double _screenWidth;
  late final double _screenHeight;
  late final _DeviceCategory _device;

  AppSpacing(this.context) {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
    _device = _getDeviceCategory(_screenWidth);
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
        return 1.25;
      case _DeviceCategory.laptop:
        return 1.4;
      case _DeviceCategory.desktop:
        return 1.5;
    }
  }

  /// Scale spacing with constraints
  double _scale(double baseSize, {double? min, double? max}) {
    final scaled = baseSize * _getScaleFactor();
    final minVal = min ?? Spacing.min;
    final maxVal = max ?? (baseSize * 2);
    return scaled.clamp(minVal, maxVal);
  }

  // ============================================================================
  // RESPONSIVE SPACING VALUES
  // ============================================================================
  
  double get zero => 0.0;
  double get xxsmall => _scale(Spacing.xxsmall, max: 4);
  double get xsmall => _scale(Spacing.xsmall, max: 8);
  double get small => _scale(Spacing.small, max: 14);
  double get medium => _scale(Spacing.medium, max: 20);
  double get large => _scale(Spacing.large, max: 28);
  double get xlarge => _scale(Spacing.xlarge, max: 40);
  double get xxlarge => _scale(Spacing.xxlarge, max: 56);
  double get xxxlarge => _scale(Spacing.xxxlarge, max: 80);

  // ============================================================================
  // PERCENTAGE-BASED SPACING (relative to screen dimensions)
  // ============================================================================
  
  /// Horizontal spacing as percentage of screen width
  double widthPercent(double percent, {double min = 4, double max = 64}) {
    return (_screenWidth * percent / 100).clamp(min, max);
  }
  
  /// Vertical spacing as percentage of screen height
  double heightPercent(double percent, {double min = 4, double max = 64}) {
    return (_screenHeight * percent / 100).clamp(min, max);
  }

  // ============================================================================
  // EDGE INSETS - All sides
  // ============================================================================
  
  /// Create EdgeInsets with uniform value on all sides
  EdgeInsets all(double value) => EdgeInsets.all(value);
  
  EdgeInsets get paddingZero => EdgeInsets.zero;
  EdgeInsets get paddingXSmall => EdgeInsets.all(xsmall);
  EdgeInsets get paddingSmall => EdgeInsets.all(small);
  EdgeInsets get paddingMedium => EdgeInsets.all(medium);
  EdgeInsets get paddingLarge => EdgeInsets.all(large);
  EdgeInsets get paddingXLarge => EdgeInsets.all(xlarge);
  EdgeInsets get paddingXXLarge => EdgeInsets.all(xxlarge);

  // ============================================================================
  // EDGE INSETS - Horizontal only
  // ============================================================================
  
  EdgeInsets get paddingHorizontalXSmall => EdgeInsets.symmetric(horizontal: xsmall);
  EdgeInsets get paddingHorizontalSmall => EdgeInsets.symmetric(horizontal: small);
  EdgeInsets get paddingHorizontalMedium => EdgeInsets.symmetric(horizontal: medium);
  EdgeInsets get paddingHorizontalLarge => EdgeInsets.symmetric(horizontal: large);
  EdgeInsets get paddingHorizontalXLarge => EdgeInsets.symmetric(horizontal: xlarge);

  // ============================================================================
  // EDGE INSETS - Vertical only
  // ============================================================================
  
  EdgeInsets get paddingVerticalXSmall => EdgeInsets.symmetric(vertical: xsmall);
  EdgeInsets get paddingVerticalSmall => EdgeInsets.symmetric(vertical: small);
  EdgeInsets get paddingVerticalMedium => EdgeInsets.symmetric(vertical: medium);
  EdgeInsets get paddingVerticalLarge => EdgeInsets.symmetric(vertical: large);
  EdgeInsets get paddingVerticalXLarge => EdgeInsets.symmetric(vertical: xlarge);

  // ============================================================================
  // EDGE INSETS - Custom combinations
  // ============================================================================
  
  /// Symmetric padding with different horizontal/vertical values
  EdgeInsets paddingSymmetric({double? horizontal, double? vertical}) {
    return EdgeInsets.symmetric(
      horizontal: horizontal ?? medium,
      vertical: vertical ?? medium,
    );
  }
  
  /// Padding with specific sides
  EdgeInsets paddingOnly({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return EdgeInsets.only(
      left: left ?? 0,
      top: top ?? 0,
      right: right ?? 0,
      bottom: bottom ?? 0,
    );
  }
  
  /// List tile standard padding
  EdgeInsets get paddingListTile => EdgeInsets.symmetric(
    horizontal: large,
    vertical: small,
  );
  
  /// Card content padding
  EdgeInsets get paddingCard => EdgeInsets.all(large);
  
  /// Dialog content padding
  EdgeInsets get paddingDialog => EdgeInsets.all(xlarge);
  
  /// Screen/page padding
  EdgeInsets get paddingScreen => EdgeInsets.symmetric(
    horizontal: large,
    vertical: medium,
  );

  // ============================================================================
  // SIZED BOX HELPERS - For gaps in Rows/Columns
  // ============================================================================
  
  SizedBox get gapXSmall => SizedBox(width: xsmall, height: xsmall);
  SizedBox get gapSmall => SizedBox(width: small, height: small);
  SizedBox get gapMedium => SizedBox(width: medium, height: medium);
  SizedBox get gapLarge => SizedBox(width: large, height: large);
  SizedBox get gapXLarge => SizedBox(width: xlarge, height: xlarge);
  
  /// Horizontal gap
  SizedBox gapH(double width) => SizedBox(width: width);
  
  /// Vertical gap
  SizedBox gapV(double height) => SizedBox(height: height);
}

enum _DeviceCategory {
  smallPhone,
  phone,
  tablet,
  laptop,
  desktop,
}

/// Extension for easy access to responsive spacing
extension SpacingExtension on BuildContext {
  AppSpacing get spacing => AppSpacing(this);
}
