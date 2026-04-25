import 'package:flutter/material.dart';

/// ============================================================================
/// APP DURATIONS - Animation timings and delay constants
/// ============================================================================
/// 
/// Structure:
/// - AppDuration: Static duration values
/// - AppAnimationDuration: Context-aware durations (for reduced motion)
/// 
/// Naming Convention:
/// - AppDuration.fast, AppDuration.normal, AppDuration.slow
/// 
/// Usage:
/// - AnimatedContainer(duration: AppDuration.normal)
/// - Future.delayed(AppDuration.snackbar)
/// ============================================================================

/// Static duration constants
class AppDuration {
  AppDuration._();

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================
  
  /// Instant - no animation
  static const Duration zero = Duration.zero;
  
  /// Ultra fast - micro interactions (50ms)
  static const Duration ultraFast = Duration(milliseconds: 50);
  
  /// Fast - quick transitions (150ms)
  static const Duration fast = Duration(milliseconds: 150);
  
  /// Normal - standard animations (300ms)
  static const Duration normal = Duration(milliseconds: 300);
  
  /// Slow - deliberate animations (500ms)
  static const Duration slow = Duration(milliseconds: 500);
  
  /// Extra slow - emphasis animations (800ms)
  static const Duration extraSlow = Duration(milliseconds: 800);
  
  /// Very slow - major transitions (1000ms)
  static const Duration verySlow = Duration(milliseconds: 1000);

  // ============================================================================
  // UI FEEDBACK DURATIONS
  // ============================================================================
  
  /// Snackbar display duration
  static const Duration snackbar = Duration(milliseconds: 2000);
  
  /// Snackbar short duration
  static const Duration snackbarShort = Duration(milliseconds: 1500);
  
  /// Snackbar long duration
  static const Duration snackbarLong = Duration(milliseconds: 4000);
  
  /// Toast display duration
  static const Duration toast = Duration(milliseconds: 2000);
  
  /// Tooltip display duration
  static const Duration tooltip = Duration(milliseconds: 1500);

  // ============================================================================
  // INTERACTION DURATIONS
  // ============================================================================
  
  /// Debounce duration for search/input
  static const Duration debounce = Duration(milliseconds: 300);
  
  /// Throttle duration
  static const Duration throttle = Duration(milliseconds: 500);
  
  /// Long press threshold
  static const Duration longPress = Duration(milliseconds: 500);
  
  /// Double tap threshold
  static const Duration doubleTap = Duration(milliseconds: 300);

  // ============================================================================
  // LOADING/PROGRESS DURATIONS
  // ============================================================================
  
  /// Minimum loading spinner display time
  static const Duration minLoading = Duration(milliseconds: 500);
  
  /// Shimmer animation cycle
  static const Duration shimmerCycle = Duration(milliseconds: 1500);
  
  /// Progress indicator update interval
  static const Duration progressUpdate = Duration(milliseconds: 100);

  // ============================================================================
  // NETWORK/ASYNC DURATIONS
  // ============================================================================
  
  /// Connection timeout
  static const Duration connectionTimeout = Duration(seconds: 10);
  
  /// Request timeout
  static const Duration requestTimeout = Duration(seconds: 30);
  
  /// Polling interval
  static const Duration pollingInterval = Duration(seconds: 5);
  
  /// Heartbeat interval
  static const Duration heartbeatInterval = Duration(seconds: 30);

  // ============================================================================
  // MILLISECOND VALUES (for legacy compatibility)
  // ============================================================================
  
  static const int fastMs = 150;
  static const int normalMs = 300;
  static const int slowMs = 500;
  static const int snackbarMs = 2000;
}

/// Animation curves for consistent motion design
class AppCurves {
  AppCurves._();

  // ============================================================================
  // STANDARD CURVES
  // ============================================================================
  
  /// Default easing - general purpose
  static const Curve standard = Curves.easeInOut;
  
  /// Emphasized - for important transitions
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  
  /// Enter/Exit - elements appearing/disappearing
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  
  /// Bounce - playful feedback
  static const Curve bounce = Curves.bounceOut;
  
  /// Elastic - spring-like motion
  static const Curve elastic = Curves.elasticOut;
  
  /// Linear - constant speed
  static const Curve linear = Curves.linear;

  // ============================================================================
  // MOTION-SPECIFIC CURVES
  // ============================================================================
  
  /// Fast out, slow in - deceleration
  static const Curve decelerate = Curves.decelerate;
  
  /// Slow out, fast in - acceleration
  static const Curve accelerate = Curves.fastLinearToSlowEaseIn;
  
  /// Overshoot - slight bounce past target
  static const Curve overshoot = Curves.easeOutBack;
}

/// Context-aware animation durations (respects reduced motion settings)
class AppAnimationDuration {
  final BuildContext context;
  late final bool _reducedMotion;

  AppAnimationDuration(this.context) {
    _reducedMotion = MediaQuery.of(context).disableAnimations;
  }

  /// Apply reduced motion if enabled
  Duration _adjust(Duration duration) {
    if (_reducedMotion) {
      // For reduced motion: use instant or very short durations
      if (duration <= AppDuration.fast) return Duration.zero;
      return const Duration(milliseconds: 50);
    }
    return duration;
  }

  Duration get zero => Duration.zero;
  Duration get ultraFast => _adjust(AppDuration.ultraFast);
  Duration get fast => _adjust(AppDuration.fast);
  Duration get normal => _adjust(AppDuration.normal);
  Duration get slow => _adjust(AppDuration.slow);
  Duration get extraSlow => _adjust(AppDuration.extraSlow);
  
  /// Snackbar and feedback durations are not affected by reduced motion
  Duration get snackbar => AppDuration.snackbar;
  Duration get snackbarShort => AppDuration.snackbarShort;
  Duration get snackbarLong => AppDuration.snackbarLong;
}

/// Extension for easy access to animation durations
extension DurationExtension on BuildContext {
  AppAnimationDuration get durations => AppAnimationDuration(this);
}
