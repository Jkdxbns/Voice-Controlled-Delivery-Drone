import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Background initialization service that runs heavy startup tasks off the main thread
/// 
/// Note: SharedPreferences should NOT be initialized here because:
/// 1. Isolates have separate memory - instances cannot be shared with main thread
/// 2. SharedPreferences is already optimized (async load, memory caching)
/// 3. Any instance created here would be discarded anyway
class BackgroundInitializer {
  /// Initialize app configuration in a background isolate
  /// Only performs CPU-intensive tasks like JSON parsing
  static Future<InitializationResult> initialize() async {
    // Run heavy initialization work off the main thread using compute
    return await compute(_initializeInBackground, null);
  }
}

/// Top-level function for background initialization (required for compute)
Future<InitializationResult> _initializeInBackground(_) async {
  try {
    // Load config from assets (this involves file I/O and JSON parsing)
    final configString = await rootBundle.loadString('assets/config.json');
    
    // NOTE: Do NOT initialize SharedPreferences here!
    // - Isolates have separate memory spaces
    // - Any instance created here cannot be shared with the main thread
    // - PreferencesService.init() handles this correctly on the main thread
    
    return InitializationResult(
      success: true,
      configJson: configString,
    );
  } catch (e) {
    return InitializationResult(
      success: false,
      error: e.toString(),
    );
  }
}

/// Result object for initialization (must be serializable for isolate communication)
class InitializationResult {
  final bool success;
  final String? configJson;
  final String? error;

  InitializationResult({
    required this.success,
    this.configJson,
    this.error,
  });
}
