import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_logger.dart';

/// Service for showing local notifications for cross-device commands
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  // Notification channel for routed commands (high priority for heads-up)
  static const String _commandChannelId = 'coffin_routed_commands';
  static const String _commandChannelName = 'Routed Commands';
  static const String _commandChannelDesc = 'Notifications for commands received from other devices';
  
  // Notification IDs (use incrementing to allow multiple notifications)
  int _notificationIdCounter = 1000;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Create high-priority notification channel for command alerts
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _commandChannelId,
        _commandChannelName,
        description: _commandChannelDesc,
        importance: Importance.high,  // High = heads-up popup
        playSound: true,              // Default sound
        enableVibration: true,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Initialize with callback for when notification is tapped
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      AppLogger.success('[NOTIFICATION] Service initialized');
    } catch (e) {
      AppLogger.error('[NOTIFICATION] Failed to initialize: $e');
    }
  }

  /// Handle notification tap - currently just logs (app opens to home by default)
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('[NOTIFICATION] Tapped: ${response.payload}');
    // App will open to home screen by default
    // Future: Could parse payload and navigate to specific screen
  }

  /// Show notification for a routed command from another device
  Future<void> showRoutedCommandNotification({
    required String fromDeviceName,
    required String command,
    required String targetDevice,
  }) async {
    if (!_isInitialized) {
      AppLogger.warning('[NOTIFICATION] Not initialized, skipping notification');
      return;
    }

    try {
      final notificationId = _notificationIdCounter++;
      
      // Keep counter in reasonable range
      if (_notificationIdCounter > 9999) {
        _notificationIdCounter = 1000;
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _commandChannelId,
        _commandChannelName,
        channelDescription: _commandChannelDesc,
        importance: Importance.high,
        priority: Priority.high,      // High priority = heads-up display
        playSound: true,              // Default notification sound
        enableVibration: true,
        showWhen: true,
        autoCancel: true,             // Dismiss when tapped
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        notificationId,
        'Command from $fromDeviceName',
        '$command → $targetDevice',
        notificationDetails,
        payload: 'routed_command:$command:$targetDevice',
      );

      AppLogger.info('[NOTIFICATION] Shown: $command → $targetDevice (from $fromDeviceName)');
    } catch (e) {
      AppLogger.error('[NOTIFICATION] Failed to show notification: $e');
    }
  }

  /// Show notification for a message received from another device
  Future<void> showDeviceMessageNotification({
    required String fromDeviceName,
    required String message,
  }) async {
    if (!_isInitialized) {
      AppLogger.warning('[NOTIFICATION] Not initialized, skipping notification');
      return;
    }

    try {
      final notificationId = _notificationIdCounter++;
      
      // Keep counter in reasonable range
      if (_notificationIdCounter > 9999) {
        _notificationIdCounter = 1000;
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _commandChannelId,
        _commandChannelName,
        channelDescription: _commandChannelDesc,
        importance: Importance.high,
        priority: Priority.high,      // High priority = heads-up display
        playSound: true,              // Default notification sound
        enableVibration: true,
        showWhen: true,
        autoCancel: true,             // Dismiss when tapped
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(message),  // Show full message
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        notificationId,
        '💬 Message from $fromDeviceName',
        message,
        notificationDetails,
        payload: 'device_message:$fromDeviceName:$message',
      );

      AppLogger.info('[NOTIFICATION] Message shown: "$message" (from $fromDeviceName)');
    } catch (e) {
      AppLogger.error('[NOTIFICATION] Failed to show message notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
