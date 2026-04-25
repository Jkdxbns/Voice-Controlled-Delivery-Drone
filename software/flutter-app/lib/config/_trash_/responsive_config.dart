import 'package:flutter/material.dart';

/// Responsive UI Configuration System
/// Automatically adapts to screen size categories: Small Phone, Phone, Tablet, Desktop
class ResponsiveConfig {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  late final DeviceType deviceType;
  late final Orientation orientation;

  ResponsiveConfig(this.context) {
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;
    orientation = MediaQuery.of(context).orientation;
    deviceType = _getDeviceType();
  }

  /// Determine device type based on screen width
  DeviceType _getDeviceType() {
    if (screenWidth < 360) return DeviceType.smallPhone;
    if (screenWidth < 600) return DeviceType.phone;
    if (screenWidth < 1024) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  // ============================================================================
  // RESPONSIVE DIMENSIONS - Based on screen width percentage
  // ============================================================================

  /// Get percentage of screen width
  double widthPercent(double percent) => screenWidth * (percent / 100);

  /// Get percentage of screen height
  double heightPercent(double percent) => screenHeight * (percent / 100);

  // ============================================================================
  // FONT SIZES - Scaled by device type
  // ============================================================================

  double get fontSizeXXS => _scaleFontSize(10);   // Extra Extra Small
  double get fontSizeXS => _scaleFontSize(11);    // Extra Small
  double get fontSizeS => _scaleFontSize(12);     // Small
  double get fontSizeM => _scaleFontSize(14);     // Medium (body text)
  double get fontSizeL => _scaleFontSize(16);     // Large
  double get fontSizeXL => _scaleFontSize(18);    // Extra Large
  double get fontSizeXXL => _scaleFontSize(24);   // Extra Extra Large (headers)
  double get fontSizeXXXL => _scaleFontSize(32);  // Huge

  double _scaleFontSize(double baseSize) {
    switch (deviceType) {
      case DeviceType.smallPhone:
        return baseSize * 0.9;
      case DeviceType.phone:
        return baseSize;
      case DeviceType.tablet:
        return baseSize * 1.2;
      case DeviceType.desktop:
        return baseSize * 1.4;
    }
  }

  // ============================================================================
  // ICON SIZES - Scaled by device type
  // ============================================================================

  double get iconSizeXS => _scaleIconSize(16);    // Extra Small
  double get iconSizeS => _scaleIconSize(18);     // Small
  double get iconSizeM => _scaleIconSize(24);     // Medium
  double get iconSizeL => _scaleIconSize(32);     // Large
  double get iconSizeXL => _scaleIconSize(48);    // Extra Large
  double get iconSizeXXL => _scaleIconSize(64);   // Extra Extra Large

  double _scaleIconSize(double baseSize) {
    switch (deviceType) {
      case DeviceType.smallPhone:
        return baseSize * 0.85;
      case DeviceType.phone:
        return baseSize;
      case DeviceType.tablet:
        return baseSize * 1.3;
      case DeviceType.desktop:
        return baseSize * 1.5;
    }
  }

  // ============================================================================
  // SPACING - Based on screen width percentage
  // ============================================================================

  double get spacingXXS => widthPercent(0.5);   // ~2px on 360px phone
  double get spacingXS => widthPercent(1);      // ~4px on 360px phone
  double get spacingS => widthPercent(2);       // ~8px on 360px phone
  double get spacingM => widthPercent(3);       // ~12px on 360px phone
  double get spacingL => widthPercent(4);       // ~16px on 360px phone
  double get spacingXL => widthPercent(6);      // ~24px on 360px phone
  double get spacingXXL => widthPercent(8);     // ~32px on 360px phone

  // ============================================================================
  // EDGE INSETS - Responsive padding
  // ============================================================================

  EdgeInsets get paddingZero => EdgeInsets.zero;
  EdgeInsets get paddingXS => EdgeInsets.all(spacingXS);
  EdgeInsets get paddingS => EdgeInsets.all(spacingS);
  EdgeInsets get paddingM => EdgeInsets.all(spacingM);
  EdgeInsets get paddingL => EdgeInsets.all(spacingL);
  EdgeInsets get paddingXL => EdgeInsets.all(spacingXL);

  EdgeInsets get paddingHorizontalXS => EdgeInsets.symmetric(horizontal: spacingXS);
  EdgeInsets get paddingHorizontalS => EdgeInsets.symmetric(horizontal: spacingS);
  EdgeInsets get paddingHorizontalM => EdgeInsets.symmetric(horizontal: spacingM);
  EdgeInsets get paddingHorizontalL => EdgeInsets.symmetric(horizontal: spacingL);
  EdgeInsets get paddingHorizontalXL => EdgeInsets.symmetric(horizontal: spacingXL);

  EdgeInsets get paddingVerticalXS => EdgeInsets.symmetric(vertical: spacingXS);
  EdgeInsets get paddingVerticalS => EdgeInsets.symmetric(vertical: spacingS);
  EdgeInsets get paddingVerticalM => EdgeInsets.symmetric(vertical: spacingM);
  EdgeInsets get paddingVerticalL => EdgeInsets.symmetric(vertical: spacingL);
  EdgeInsets get paddingVerticalXL => EdgeInsets.symmetric(vertical: spacingXL);

  // Combined horizontal + vertical
  EdgeInsets paddingSymmetric({double? horizontal, double? vertical}) {
    return EdgeInsets.symmetric(
      horizontal: horizontal ?? spacingM,
      vertical: vertical ?? spacingM,
    );
  }

  // Custom padding with specific sides
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

  // ============================================================================
  // BORDER RADIUS - Based on screen width percentage
  // ============================================================================

  double get radiusXS => widthPercent(1);       // ~4px on 360px phone
  double get radiusS => widthPercent(2);        // ~8px on 360px phone
  double get radiusM => widthPercent(3);        // ~12px on 360px phone
  double get radiusL => widthPercent(4);        // ~16px on 360px phone
  double get radiusXL => widthPercent(6);       // ~24px on 360px phone

  BorderRadius get borderRadiusXS => BorderRadius.circular(radiusXS);
  BorderRadius get borderRadiusS => BorderRadius.circular(radiusS);
  BorderRadius get borderRadiusM => BorderRadius.circular(radiusM);
  BorderRadius get borderRadiusL => BorderRadius.circular(radiusL);
  BorderRadius get borderRadiusXL => BorderRadius.circular(radiusXL);
  BorderRadius get borderRadiusCircular => BorderRadius.circular(screenWidth);

  // ============================================================================
  // BORDER WIDTH - Scaled by device type
  // ============================================================================

  double get borderWidthThin => _scaleBorderWidth(1);
  double get borderWidthMedium => _scaleBorderWidth(2);
  double get borderWidthThick => _scaleBorderWidth(4);

  double _scaleBorderWidth(double baseWidth) {
    switch (deviceType) {
      case DeviceType.smallPhone:
        return baseWidth * 0.8;
      case DeviceType.phone:
        return baseWidth;
      case DeviceType.tablet:
        return baseWidth * 1.2;
      case DeviceType.desktop:
        return baseWidth * 1.5;
    }
  }

  // ============================================================================
  // COMPONENT SPECIFIC SIZES - Based on screen dimensions
  // ============================================================================

  // Button heights
  double get buttonHeightS => heightPercent(4);   // ~32px on 800px height
  double get buttonHeightM => heightPercent(5);   // ~40px on 800px height
  double get buttonHeightL => heightPercent(6);   // ~48px on 800px height
  double get buttonHeightXL => heightPercent(7);  // ~56px on 800px height

  // Card dimensions
  double get cardPaddingS => spacingS;
  double get cardPaddingM => spacingM;
  double get cardPaddingL => spacingL;
  double get cardMarginS => spacingXS;
  double get cardMarginM => spacingS;
  double get cardMarginL => spacingM;

  // Drawer dimensions
  double get drawerWidth => widthPercent(deviceType == DeviceType.tablet ? 30 : 70);
  double get drawerHeaderHeight => heightPercent(20);

  // Chat bubble
  double get chatBubblePadding => spacingM;
  double get chatBubbleMargin => spacingS;
  double get chatBubbleMaxWidth => widthPercent(75);
  double get chatBubbleRadius => radiusM;

  // Recording button
  double get recordingButtonSize => widthPercent(deviceType == DeviceType.tablet ? 10 : 18);
  double get recordingButtonIconSize => iconSizeL;
  double get recordingButtonBorderWidth => borderWidthThick;

  // Model card
  double get modelCardPadding => spacingM;
  double get modelCardBadgePadding => spacingXS;
  double get modelCardBadgeRadius => radiusXS;

  // Divider
  double get dividerThickness => borderWidthThin * 0.5;

  // Elevation
  double get elevationNone => 0;
  double get elevationLow => 2;
  double get elevationMedium => 4;
  double get elevationHigh => 8;

  // ============================================================================
  // TEXT STYLES - Responsive typography
  // ============================================================================

  TextStyle get textStyleHeader => TextStyle(
    fontSize: fontSizeXXL,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  TextStyle get textStyleTitle => TextStyle(
    fontSize: fontSizeL,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  TextStyle get textStyleSubtitle => TextStyle(
    fontSize: fontSizeM,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  TextStyle get textStyleBody => TextStyle(
    fontSize: fontSizeM,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  TextStyle get textStyleBodySmall => TextStyle(
    fontSize: fontSizeS,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  TextStyle get textStyleCaption => TextStyle(
    fontSize: fontSizeXS,
    fontWeight: FontWeight.normal,
    height: 1.3,
  );

  TextStyle get textStyleButton => TextStyle(
    fontSize: fontSizeM,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  TextStyle get textStyleBadge => TextStyle(
    fontSize: fontSizeXS,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  TextStyle get textStyleTimestamp => TextStyle(
    fontSize: fontSizeXXS,
    fontStyle: FontStyle.italic,
    height: 1.2,
  );

  // ============================================================================
  // ANIMATION DURATIONS - Device-dependent timing
  // ============================================================================

  Duration get durationFast => Duration(milliseconds: deviceType == DeviceType.tablet ? 100 : 150);
  Duration get durationNormal => Duration(milliseconds: deviceType == DeviceType.tablet ? 200 : 300);
  Duration get durationSlow => Duration(milliseconds: deviceType == DeviceType.tablet ? 400 : 500);
  Duration get durationSnackbar => const Duration(milliseconds: 2000);

  // ============================================================================
  // OPACITY VALUES - Standard opacity levels
  // ============================================================================

  double get opacityDisabled => 0.38;
  double get opacityMedium => 0.54;
  double get opacityHigh => 0.87;
  double get opacityFull => 1.0;
  double get opacityTransparent => 0.0;
  double get opacityBorder => 0.3;
  double get opacityOverlay => 0.1;
  double get opacityOverlayMedium => 0.2;
  double get opacityOverlayHigh => 0.3;

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if current device is a phone
  bool get isPhone => deviceType == DeviceType.phone || deviceType == DeviceType.smallPhone;

  /// Check if current device is a tablet
  bool get isTablet => deviceType == DeviceType.tablet;

  /// Check if current device is desktop
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// Check if device is in landscape mode
  bool get isLandscape => orientation == Orientation.landscape;

  /// Check if device is in portrait mode
  bool get isPortrait => orientation == Orientation.portrait;

  /// Get adaptive column count for grids
  int get gridColumnCount {
    if (isLandscape) {
      return deviceType == DeviceType.tablet ? 3 : 2;
    }
    return deviceType == DeviceType.tablet ? 2 : 1;
  }

  /// Get safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  /// Get keyboard height
  double get keyboardHeight => MediaQuery.of(context).viewInsets.bottom;

  /// Check if keyboard is visible
  bool get isKeyboardVisible => keyboardHeight > 0;
}

/// Device type enumeration
enum DeviceType {
  smallPhone,  // < 360px width
  phone,       // 360px - 600px width
  tablet,      // 600px - 1024px width
  desktop,     // > 1024px width
}

/// Extension to easily access ResponsiveConfig from context
extension ResponsiveExtension on BuildContext {
  ResponsiveConfig get responsive => ResponsiveConfig(this);
}
