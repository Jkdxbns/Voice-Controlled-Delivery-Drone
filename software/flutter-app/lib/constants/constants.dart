/// ============================================================================
/// CONSTANTS - Barrel export for all app constants
/// ============================================================================
/// 
/// Import this single file to access all constants:
/// ```dart
/// import 'package:mic_record_v2/constants/constants.dart';
/// ```
/// 
/// This gives you access to:
/// - AppColors, AppColorsDark, AppColorScheme, AppOpacity
/// - FontSize, FontWeightStyle, FontFamily, AppTextStyle, AppTypography
/// - AppIcons, IconSize, AppIconSize
/// - Spacing, AppSpacing
/// - AppRadius, BorderSize, AppElevation, ComponentSize, AppDimensions
/// - AppStrings
/// - AppDuration, AppCurves, AppAnimationDuration
/// - AppTheme
/// 
/// Extensions for BuildContext:
/// - context.typography (AppTypography)
/// - context.iconSize (AppIconSize)
/// - context.spacing (AppSpacing)
/// - context.dimensions (AppDimensions)
/// - context.durations (AppAnimationDuration)
/// ============================================================================

// Colors & Theming
export 'app_colors.dart';
export 'app_theme.dart';

// Typography
export 'app_typography.dart';

// Icons
export 'app_icons.dart';

// Spacing & Layout
export 'app_spacing.dart';
export 'app_dimensions.dart';

// Strings & Content
export 'app_strings.dart';

// Animation & Timing
export 'app_durations.dart';
