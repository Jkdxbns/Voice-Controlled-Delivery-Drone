import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_logger.dart';

/// Background service to keep WebSocket and BLE connections alive
/// when the app is in the background
class BackgroundServiceManager {
  static final BackgroundServiceManager instance = BackgroundServiceManager._();
  BackgroundServiceManager._();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;
  bool _isRunning = false;

  // Notification channel ID
  static const String _notificationChannelId = 'coffin_background_service';
  static const String _notificationChannelName = 'COFFIN Background Service';
  static const int _notificationId = 888;

  /// Initialize the background service (call once at app startup)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create notification channel for Android 8+
      final FlutterLocalNotificationsPlugin notifications = 
          FlutterLocalNotificationsPlugin();
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: 'Keeps COFFIN connected to receive commands',
        importance: Importance.low, // Low = no sound, but visible
        showBadge: false,
      );

      await notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);
      
      await notifications.initialize(initSettings);

      // Configure the background service
      await _service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          isForegroundMode: true,
          autoStart: false,
          autoStartOnBoot: false,
          notificationChannelId: _notificationChannelId,
          initialNotificationTitle: 'COFFIN',
          initialNotificationContent: 'Ready to receive commands',
          foregroundServiceNotificationId: _notificationId,
          foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
        ),
      );

      _isInitialized = true;
      AppLogger.success('[BACKGROUND] Service manager initialized');
    } catch (e) {
      AppLogger.error('[BACKGROUND] Failed to initialize: $e');
    }
  }

  /// Start the background service (call when app goes to background)
  Future<void> startService() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isRunning) {
      AppLogger.info('[BACKGROUND] Service already running');
      return;
    }

    try {
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        await _service.startService();
        _isRunning = true;
        AppLogger.success('[BACKGROUND] Foreground service started');
      } else {
        _isRunning = true;
      }
    } catch (e) {
      AppLogger.error('[BACKGROUND] Failed to start service: $e');
    }
  }

  /// Stop the background service (call when app comes to foreground)
  Future<void> stopService() async {
    if (!_isRunning) return;

    try {
      final isRunning = await _service.isRunning();
      if (isRunning) {
        _service.invoke('stopService');
        _isRunning = false;
        AppLogger.info('[BACKGROUND] Foreground service stopped');
      }
    } catch (e) {
      AppLogger.error('[BACKGROUND] Failed to stop service: $e');
    }
  }

  /// Update the notification content
  void updateNotification({String? title, String? content}) {
    if (!_isRunning) return;
    
    _service.invoke('updateNotification', {
      'title': title ?? 'COFFIN',
      'content': content ?? 'Connected',
    });
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}

// Top-level function for background service entry point (Android)
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    // Handle stop request
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Handle notification updates
    service.on('updateNotification').listen((event) {
      if (event != null) {
        service.setForegroundNotificationInfo(
          title: event['title'] ?? 'COFFIN',
          content: event['content'] ?? 'Connected',
        );
      }
    });

    // Set as foreground service
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'COFFIN',
      content: 'Maintaining connection...',
    );
  }

  // Keep-alive timer - just keeps the isolate running
  // The actual WebSocket/BLE runs in the main isolate
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Service is still running as foreground
        // This periodic task keeps the isolate alive
      }
    }
  });
}

// iOS background handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}
