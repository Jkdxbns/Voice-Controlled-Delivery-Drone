import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

/// Helper class for requesting battery optimization exemption
class BatteryOptimizationHelper {
  static const MethodChannel _channel = MethodChannel('coffin/battery_optimization');

  /// Check if battery optimization is disabled for this app
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e) {
      AppLogger.error('[BATTERY] Failed to check optimization status: $e');
      return false;
    }
  }

  /// Request battery optimization exemption
  /// Returns true if the request was shown (not necessarily granted)
  static Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod<bool>('requestDisableBatteryOptimization');
      return result ?? false;
    } catch (e) {
      AppLogger.error('[BATTERY] Failed to request exemption: $e');
      return false;
    }
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      AppLogger.error('[BATTERY] Failed to open settings: $e');
    }
  }
}
