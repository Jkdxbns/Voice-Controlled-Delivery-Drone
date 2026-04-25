import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'preferences_service.dart';
import 'tts_service.dart';
import 'notification_service.dart';
import 'server/server_config_service.dart';
import 'device/device_info_service.dart';
import 'ble/ble_service.dart';
import 'bluetooth/unified_bluetooth_service.dart';
import 'websocket_service.dart';
import 'database/database_helper.dart';

/// Centralized app initialization service
/// Handles all service initialization in the correct order, once only
/// Heavy operations are moved off the main thread where possible
class AppInitializationService {
  static final AppInitializationService instance = AppInitializationService._();
  AppInitializationService._();

  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Check if app is fully initialized
  bool get isInitialized => _isInitialized;

  /// Wait for initialization to complete
  Future<void> get initialized => _initCompleter.future;

  /// Initialize all app services
  /// This should be called once from main.dart
  /// Services are initialized in dependency order
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('[APP_INIT] Already initialized, skipping');
      return;
    }

    if (_isInitializing) {
      AppLogger.info('[APP_INIT] Already initializing, waiting...');
      await _initCompleter.future;
      return;
    }

    _isInitializing = true;
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info('═══════════════════════════════════════════════════════');
      AppLogger.info('[APP_INIT] Starting centralized initialization');
      AppLogger.info('═══════════════════════════════════════════════════════');

      // Phase 1: Core services (must be on main thread)
      await _initializeCoreServices();

      // Phase 2: Database initialization (can be parallelized)
      await _initializeDatabases();

      // Phase 3: Hardware services (Bluetooth, etc.) - before WebSocket so MAC is ready
      await _initializeHardwareServices();

      // Phase 4: Communication services (WebSocket registers device with MAC)
      await _initializeCommunicationServices();

      stopwatch.stop();
      _isInitialized = true;
      _initCompleter.complete();

      AppLogger.info('═══════════════════════════════════════════════════════');
      AppLogger.success('[APP_INIT] All services initialized in ${stopwatch.elapsedMilliseconds}ms');
      AppLogger.info('═══════════════════════════════════════════════════════');
    } catch (e) {
      AppLogger.error('[APP_INIT] Initialization failed: $e');
      _initCompleter.completeError(e);
      rethrow;
    }
  }

  /// Phase 1: Core services that other services depend on
  Future<void> _initializeCoreServices() async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info('[APP_INIT] Phase 1: Core services...');

    // Preferences must be first - many services depend on it
    await PreferencesService.init();
    AppLogger.info('  ✓ PreferencesService');

    // Server config - needed for API calls
    await ServerConfigService.instance.init();
    AppLogger.info('  ✓ ServerConfigService');

    // Device info - pre-fetch all device info including MAC (for WebSocket registration)
    await DeviceInfoService.instance.initialize();
    final macAddress = DeviceInfoService.instance.deviceId != null 
        ? (await DeviceInfoService.instance.getDeviceInfo()).macAddress 
        : null;
    AppLogger.info('  ✓ DeviceInfoService (MAC: ${macAddress ?? "pending"})');

    // TTS service
    await TtsService.instance.initialize();
    AppLogger.info('  ✓ TtsService');

    // Notification service for cross-device command alerts
    await NotificationService.instance.initialize();
    AppLogger.info('  ✓ NotificationService');

    AppLogger.info('[APP_INIT] Phase 1 complete (${stopwatch.elapsedMilliseconds}ms)');
  }

  /// Phase 2: Database initialization (parallelized)
  Future<void> _initializeDatabases() async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info('[APP_INIT] Phase 2: Databases...');

    // Run database initializations in parallel
    await Future.wait([
      DatabaseHelper.instance.database.then((_) {
        AppLogger.info('  ✓ AI Assistant database');
      }),
      // Bluetooth databases are initialized by their services
    ]);

    AppLogger.info('[APP_INIT] Phase 2 complete (${stopwatch.elapsedMilliseconds}ms)');
  }

  /// Phase 4: Communication services (WebSocket - after hardware so MAC is ready)
  Future<void> _initializeCommunicationServices() async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info('[APP_INIT] Phase 4: Communication services...');

    // WebSocket service for real-time communication
    await WebSocketService.instance.initialize();
    AppLogger.info('  ✓ WebSocketService');

    AppLogger.info('[APP_INIT] Phase 4 complete (${stopwatch.elapsedMilliseconds}ms)');
  }

  /// Phase 3: Hardware services (Bluetooth) - runs before WebSocket
  Future<void> _initializeHardwareServices() async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info('[APP_INIT] Phase 3: Hardware services...');

    // Unified Bluetooth service (includes Classic + BLE)
    // This internally initializes BluetoothService and BleService
    await UnifiedBluetoothService.instance.initialize();
    AppLogger.info('  ✓ UnifiedBluetoothService (Classic + BLE)');

    AppLogger.info('[APP_INIT] Phase 3 complete (${stopwatch.elapsedMilliseconds}ms)');
  }

  /// Reinitialize services after a config change
  Future<void> reinitialize() async {
    AppLogger.info('[APP_INIT] Reinitializing services...');
    _isInitialized = false;
    _isInitializing = false;
    await initialize();
  }
}
