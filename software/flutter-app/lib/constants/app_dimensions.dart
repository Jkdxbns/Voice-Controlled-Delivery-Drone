import 'package:flutter/material.dart';

/// ============================================================================
/// APP DIMENSIONS - Component sizes, borders, radius, and layout dimensions
/// ============================================================================
/// 
/// Structure:
/// - BorderRadius: Static border radius values
/// - BorderWidth: Border thickness constants
/// - AppDimensions: Responsive component dimensions
/// - Elevation: Shadow elevation constants
/// 
/// Naming Convention:
/// - BorderRadius.small, BorderRadius.medium, BorderRadius.large
/// - ComponentSize.buttonSmall, ComponentSize.buttonLarge
/// 
/// Usage:
/// - Static: BorderRadius.circular(AppRadius.medium)
/// - Responsive: AppDimensions(context).buttonHeight
/// ============================================================================

/// Border radius constants
class AppRadius {
  AppRadius._();

  // ============================================================================
  // BORDER RADIUS VALUES
  // ============================================================================
  
  /// No radius - sharp corners
  static const double zero = 0.0;
  
  /// Extra small - subtle rounding
  static const double xsmall = 2.0;
  
  /// Small - light rounding
  static const double small = 4.0;
  
  /// Medium - standard rounding (default)
  static const double medium = 8.0;
  
  /// Large - prominent rounding
  static const double large = 12.0;
  
  /// Extra large - pill-like shapes
  static const double xlarge = 16.0;
  
  /// 2X large - very rounded
  static const double xxlarge = 24.0;
  
  /// Full/Circular - completely round
  static const double full = 9999.0;

  // ============================================================================
  // MIN/MAX CONSTRAINTS
  // ============================================================================
  
  static const double min = 0.0;
  static const double max = 32.0;

  // ============================================================================
  // CONVENIENCE GETTERS - Pre-built BorderRadius objects
  // ============================================================================
  
  static BorderRadius get none => BorderRadius.zero;
  static BorderRadius get xs => BorderRadius.circular(xsmall);
  static BorderRadius get sm => BorderRadius.circular(small);
  static BorderRadius get md => BorderRadius.circular(medium);
  static BorderRadius get lg => BorderRadius.circular(large);
  static BorderRadius get xl => BorderRadius.circular(xlarge);
  static BorderRadius get xxl => BorderRadius.circular(xxlarge);
  static BorderRadius get circular => BorderRadius.circular(full);
}

/// Border width constants
class BorderSize {
  BorderSize._();

  // ============================================================================
  // BORDER WIDTH VALUES
  // ============================================================================
  
  /// No border
  static const double zero = 0.0;
  
  /// Hairline - thinnest border
  static const double hairline = 0.5;
  
  /// Thin - subtle border
  static const double thin = 1.0;
  
  /// Medium - standard border
  static const double medium = 2.0;
  
  /// Thick - prominent border
  static const double thick = 3.0;
  
  /// Extra thick - very prominent
  static const double extraThick = 4.0;

  // ============================================================================
  // MIN/MAX CONSTRAINTS
  // ============================================================================
  
  static const double min = 0.5;
  static const double max = 8.0;
}

/// Elevation/Shadow constants
class AppElevation {
  AppElevation._();

  // ============================================================================
  // ELEVATION VALUES
  // ============================================================================
  
  /// No elevation - flat
  static const double zero = 0.0;
  
  /// Extra small - barely visible shadow
  static const double xsmall = 1.0;
  
  /// Small - subtle shadow
  static const double small = 2.0;
  
  /// Medium - standard card shadow
  static const double medium = 4.0;
  
  /// Large - prominent shadow
  static const double large = 8.0;
  
  /// Extra large - floating elements
  static const double xlarge = 12.0;
  
  /// 2X large - dialogs, modals
  static const double xxlarge = 16.0;
  
  /// Maximum elevation
  static const double max = 24.0;
}

/// Static component size constants
class ComponentSize {
  ComponentSize._();

  // ============================================================================
  // BUTTON HEIGHTS
  // ============================================================================
  
  static const double buttonXSmall = 28.0;
  static const double buttonSmall = 32.0;
  static const double buttonMedium = 40.0;
  static const double buttonLarge = 48.0;
  static const double buttonXLarge = 56.0;

  // ============================================================================
  // INPUT FIELD HEIGHTS
  // ============================================================================
  
  static const double inputSmall = 36.0;
  static const double inputMedium = 44.0;
  static const double inputLarge = 52.0;

  // ============================================================================
  // APP BAR HEIGHTS
  // ============================================================================
  
  static const double appBarSmall = 48.0;
  static const double appBarMedium = 56.0;
  static const double appBarLarge = 64.0;

  // ============================================================================
  // AVATAR SIZES
  // ============================================================================
  
  static const double avatarXSmall = 24.0;
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 40.0;
  static const double avatarLarge = 56.0;
  static const double avatarXLarge = 72.0;

  // ============================================================================
  // ICON SIZES
  // ============================================================================
  
  static const double iconXSmall = 16.0;
  static const double iconSmall = 20.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;
  static const double iconXXLarge = 64.0;

  // ============================================================================
  // CARD DIMENSIONS
  // ============================================================================
  
  static const double cardMinHeight = 80.0;
  static const double cardMaxHeight = 400.0;

  // ============================================================================
  // MINIMUM TAP TARGETS (Accessibility)
  // ============================================================================
  
  static const double minTapTarget = 44.0;  // iOS guideline
  static const double minTapTargetMaterial = 48.0;  // Material guideline

  // ============================================================================
  // BOTTOM SHEET
  // ============================================================================
  
  static const double bottomSheetHandleHeight = 4.0;
  static const double bottomSheetHandleWidth = 32.0;
  static const double bottomSheetPadding = 16.0;
}

/// Responsive dimensions with screen-based calculations
class AppDimensions {
  final BuildContext context;
  late final double _screenWidth;
  late final double _screenHeight;
  late final _DeviceCategory _device;

  AppDimensions(this.context) {
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
        return 0.9;
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

  /// Scale dimension with constraints
  double _scale(double baseSize, {required double min, required double max}) {
    final scaled = baseSize * _getScaleFactor();
    return scaled.clamp(min, max);
  }

  /// Get percentage of screen width with constraints
  double widthPercent(double percent, {double min = 0, double max = double.infinity}) {
    return (_screenWidth * percent / 100).clamp(min, max);
  }

  /// Get percentage of screen height with constraints
  double heightPercent(double percent, {double min = 0, double max = double.infinity}) {
    return (_screenHeight * percent / 100).clamp(min, max);
  }

  // ============================================================================
  // DEVICE INFO
  // ============================================================================
  
  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;
  bool get isSmallPhone => _device == _DeviceCategory.smallPhone;
  bool get isPhone => _device == _DeviceCategory.phone || _device == _DeviceCategory.smallPhone;
  bool get isTablet => _device == _DeviceCategory.tablet;
  bool get isLaptop => _device == _DeviceCategory.laptop;
  bool get isDesktop => _device == _DeviceCategory.desktop;
  bool get isLargeScreen => _device == _DeviceCategory.laptop || _device == _DeviceCategory.desktop;

  // ============================================================================
  // RESPONSIVE BUTTON HEIGHTS
  // ============================================================================
  
  double get buttonHeightSmall => _scale(ComponentSize.buttonSmall, min: 28, max: 40);
  double get buttonHeightMedium => _scale(ComponentSize.buttonMedium, min: 36, max: 52);
  double get buttonHeightLarge => _scale(ComponentSize.buttonLarge, min: 44, max: 64);
  double get buttonHeightXLarge => _scale(ComponentSize.buttonXLarge, min: 52, max: 72);

  // ============================================================================
  // RESPONSIVE INPUT FIELD HEIGHTS
  // ============================================================================
  
  double get inputHeightSmall => _scale(ComponentSize.inputSmall, min: 32, max: 44);
  double get inputHeightMedium => _scale(ComponentSize.inputMedium, min: 40, max: 56);
  double get inputHeightLarge => _scale(ComponentSize.inputLarge, min: 48, max: 68);

  // ============================================================================
  // RESPONSIVE APP BAR
  // ============================================================================
  
  /// AppBar height as percentage of screen height (10% for debugging, change max to 100 later)
  double get appBarHeight => heightPercent(6, min: 40, max: 500);
  
  /// TabBar height for tabs with icon + text
  double get tabBarHeight => _scale(56, min: 48, max: 64);

  // ============================================================================
  // RESPONSIVE ICON SIZES
  // ============================================================================
  
  double get iconXSmall => _scale(ComponentSize.iconXSmall, min: 14, max: 18);
  double get iconSmall => _scale(ComponentSize.iconSmall, min: 18, max: 24);
  double get iconMedium => _scale(ComponentSize.iconMedium, min: 22, max: 28);
  double get iconLarge => _scale(ComponentSize.iconLarge, min: 28, max: 40);
  double get iconXLarge => _scale(ComponentSize.iconXLarge, min: 40, max: 56);
  double get iconXXLarge => _scale(ComponentSize.iconXXLarge, min: 56, max: 80);

  // ============================================================================
  // RESPONSIVE AVATAR SIZES
  // ============================================================================
  
  double get avatarSmall => _scale(ComponentSize.avatarSmall, min: 28, max: 40);
  double get avatarMedium => _scale(ComponentSize.avatarMedium, min: 36, max: 52);
  double get avatarLarge => _scale(ComponentSize.avatarLarge, min: 48, max: 72);

  // ============================================================================
  // RESPONSIVE BORDER RADIUS
  // ============================================================================
  
  double get radiusSmall => _scale(AppRadius.small, min: 3, max: 6);
  double get radiusMedium => _scale(AppRadius.medium, min: 6, max: 12);
  double get radiusLarge => _scale(AppRadius.large, min: 10, max: 18);
  double get radiusXLarge => _scale(AppRadius.xlarge, min: 14, max: 24);

  BorderRadius get borderRadiusSmall => BorderRadius.circular(radiusSmall);
  BorderRadius get borderRadiusMedium => BorderRadius.circular(radiusMedium);
  BorderRadius get borderRadiusLarge => BorderRadius.circular(radiusLarge);
  BorderRadius get borderRadiusXLarge => BorderRadius.circular(radiusXLarge);

  // ============================================================================
  // RESPONSIVE BORDER WIDTH
  // ============================================================================
  
  double get borderThin => _scale(BorderSize.thin, min: 0.5, max: 1.5);
  double get borderMedium => _scale(BorderSize.medium, min: 1.5, max: 3);
  double get borderThick => _scale(BorderSize.thick, min: 2.5, max: 5);

  // ============================================================================
  // DRAWER DIMENSIONS
  // ============================================================================
  
  double get drawerWidth {
    switch (_device) {
      case _DeviceCategory.smallPhone:
        return widthPercent(80, min: 240, max: 300);
      case _DeviceCategory.phone:
        return widthPercent(75, min: 260, max: 320);
      case _DeviceCategory.tablet:
        return widthPercent(40, min: 300, max: 400);
      case _DeviceCategory.laptop:
      case _DeviceCategory.desktop:
        return widthPercent(25, min: 280, max: 360);
    }
  }

  double get drawerHeaderHeight => heightPercent(20, min: 140, max: 200);

  // ============================================================================
  // CHAT BUBBLE DIMENSIONS
  // ============================================================================
  
  double get chatBubbleMaxWidth => widthPercent(75, min: 200, max: 600);
  double get chatBubblePadding => _scale(12, min: 10, max: 18);
  double get chatBubbleMargin => _scale(8, min: 6, max: 14);
  double get chatBubbleRadius => _scale(12, min: 10, max: 18);

  // ============================================================================
  // RECORDING BUTTON DIMENSIONS
  // ============================================================================
  
  double get recordingButtonSize => widthPercent(18, min: 56, max: 96);
  double get recordingButtonIconSize => recordingButtonSize * 0.5;
  double get recordingButtonBorderWidth => _scale(4, min: 3, max: 6);

  // ============================================================================
  // CARD DIMENSIONS
  // ============================================================================
  
  double get cardPaddingSmall => _scale(8, min: 6, max: 12);
  double get cardPaddingMedium => _scale(12, min: 10, max: 18);
  double get cardPaddingLarge => _scale(16, min: 14, max: 24);
  double get cardMarginSmall => _scale(4, min: 3, max: 6);
  double get cardMarginMedium => _scale(8, min: 6, max: 12);
  double get cardMarginLarge => _scale(16, min: 12, max: 24);

  // ============================================================================
  // MODEL CARD DIMENSIONS
  // ============================================================================
  
  double get modelCardPadding => _scale(12, min: 10, max: 18);
  double get modelCardBadgePadding => _scale(4, min: 3, max: 6);
  double get modelCardBadgeRadius => _scale(4, min: 3, max: 6);

  // ============================================================================
  // SCROLLBAR CONFIGURATION
  // ============================================================================
  
  double get scrollbarThickness => _scale(6, min: 4, max: 10);
  double get scrollbarRadius => scrollbarThickness / 2;
  bool get scrollbarThumbVisibility => true;

  // ============================================================================
  // GRID CONFIGURATION
  // ============================================================================
  
  int get gridColumnCount {
    switch (_device) {
      case _DeviceCategory.smallPhone:
        return 1;
      case _DeviceCategory.phone:
        return 2;
      case _DeviceCategory.tablet:
        return 3;
      case _DeviceCategory.laptop:
        return 4;
      case _DeviceCategory.desktop:
        return 5;
    }
  }

  double get gridSpacing => _scale(16, min: 12, max: 24);
}

enum _DeviceCategory {
  smallPhone,
  phone,
  tablet,
  laptop,
  desktop,
}

/// Extension for easy access to responsive dimensions
extension DimensionsExtension on BuildContext {
  AppDimensions get dimensions => AppDimensions(this);
}
