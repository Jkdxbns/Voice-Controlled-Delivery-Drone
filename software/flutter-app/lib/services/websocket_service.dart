import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/app_logger.dart';
import 'server/server_config_service.dart';
import 'device/device_info_service.dart';
import 'bluetooth/unified_bluetooth_service.dart';
import 'command_router_service.dart';
import 'tts_service.dart';
import 'notification_service.dart';
import 'system_control_service.dart';
import 'file_transfer_service.dart';
import '../models/assistant_response.dart';

/// Connection state for WebSocket
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Service for managing WebSocket connection to server
/// Replaces heartbeat service with persistent real-time connection
class WebSocketService {
  static final WebSocketService instance = WebSocketService._();
  WebSocketService._();

  IO.Socket? _socket;
  WebSocketState _state = WebSocketState.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _btUpdateDebounceTimer;  // Debounce BT updates
  
  // Reconnection settings
  static const int _maxReconnectAttempts = 50;  // Increased for better persistence
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _pingInterval = Duration(seconds: 15);  // More frequent pings
  static const Duration _btUpdateDebounce = Duration(milliseconds: 500);  // Debounce BT updates
  
  int _reconnectAttempts = 0;
  Duration _currentReconnectDelay = _initialReconnectDelay;
  List<Map<String, dynamic>>? _lastBtDeviceList;  // Track last sent list to avoid duplicates
  final Set<String> _spokenArmFeedbackKeys = <String>{};
  
  // Callbacks for UI updates
  Function(WebSocketState)? onStateChanged;
  Function(Map<String, dynamic>)? onTaskReceived;
  
  // Services
  final CommandRouterService _commandRouter = CommandRouterService();
  
  // Initialization guard
  bool _isInitialized = false;

  /// Get current connection state
  WebSocketState get state => _state;
  
  /// Check if connected
  bool get isConnected => _state == WebSocketState.connected;
  
  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Initialize and connect to server (safe to call multiple times)
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized
    }
    
    AppLogger.info('[WEBSOCKET] Initializing WebSocket service...');
    _isInitialized = true;
    await connect();
  }

  /// Connect to server WebSocket
  Future<void> connect() async {
    if (_state == WebSocketState.connecting || _state == WebSocketState.connected) {
      AppLogger.info('[WEBSOCKET] Already connecting or connected');
      return;
    }

    _setState(WebSocketState.connecting);
    
    try {
      final serverUrl = ServerConfigService.instance.baseUrl;
      AppLogger.info('[WEBSOCKET] Connecting to $serverUrl');

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(_maxReconnectAttempts)
            .setReconnectionDelay(2000)
            .build(),
      );

      _setupEventHandlers();
      _socket!.connect();
    } catch (e) {
      AppLogger.error('[WEBSOCKET] Connection error: $e');
      _setState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  /// Setup socket event handlers
  void _setupEventHandlers() {
    if (_socket == null) return;

    // Clear any existing listeners to prevent duplicates on reconnect
    _socket!.clearListeners();

    _socket!.onConnect((_) {
      AppLogger.success('[WEBSOCKET] Connected to server');
      _setState(WebSocketState.connected);
      _resetReconnectState();
      _startPingTimer();
      _registerDevice();
    });

    _socket!.onDisconnect((_) {
      AppLogger.warning('[WEBSOCKET] Disconnected from server');
      _setState(WebSocketState.disconnected);
      _stopPingTimer();
      _scheduleReconnect();
    });

    _socket!.onConnectError((error) {
      AppLogger.error('[WEBSOCKET] Connection error: $error');
      _setState(WebSocketState.error);
    });

    _socket!.onError((error) {
      AppLogger.error('[WEBSOCKET] Socket error: $error');
    });

    // Handle server events
    _socket!.on('connected', (data) {
      AppLogger.info('[WEBSOCKET] Server acknowledged connection: $data');
    });

    _socket!.on('registered', (data) {
      AppLogger.success('[WEBSOCKET] Device registered: $data');
      // Send initial BT device list
      _sendBtUpdate();
    });

    _socket!.on('bt_update_ack', (data) {
      AppLogger.info('[WEBSOCKET] BT update acknowledged: $data');
    });

    _socket!.on('task', (data) {
      AppLogger.info('[WEBSOCKET] Task received: $data');
      _handleTask(data);
    });

    _socket!.on('command_routed', (data) {
      AppLogger.info('[WEBSOCKET] Command was routed: $data');
    });

    _socket!.on('arm_status', (data) {
      AppLogger.info('[WEBSOCKET] Arm status received: $data');
      _handleArmStatus(data);
    });

    _socket!.on('error', (data) {
      AppLogger.error('[WEBSOCKET] Server error: $data');
      _handleServerError(data);
    });

    _socket!.on('pong', (data) {
      // Server responded to ping
    });
  }

  /// Register this device with the server
  Future<void> _registerDevice() async {
    try {
      final deviceInfo = await DeviceInfoService.instance.getDeviceInfo();
      
      final registrationData = {
        'mac_address': deviceInfo.macAddress ?? '',
        'device_id': deviceInfo.deviceId,
        'device_name': deviceInfo.deviceName,
        'model_name': deviceInfo.modelName,
      };
      
      AppLogger.info('[WEBSOCKET] Registering device: $registrationData');
      _socket?.emit('register', registrationData);
    } catch (e) {
      AppLogger.error('[WEBSOCKET] Failed to register device: $e');
    }
  }

  /// Send Bluetooth device update to server (debounced)
  Future<void> sendBtUpdate() async {
    // Cancel any pending debounce timer
    _btUpdateDebounceTimer?.cancel();
    
    // Debounce: wait 500ms before actually sending to batch rapid changes
    _btUpdateDebounceTimer = Timer(_btUpdateDebounce, () {
      _sendBtUpdateImmediate();
    });
  }

  /// Internal method to send BT update immediately (no debounce)
  Future<void> _sendBtUpdateImmediate() async {
    if (!isConnected) {
      return;  // Silently skip if not connected
    }

    try {
      final connectedDevices = UnifiedBluetoothService.instance.getConnectedDevices();
      
      // Send device info with name and type (not just MACs)
      final deviceList = connectedDevices.map((d) => {
        'mac': d.id,
        'name': d.displayName,
        'type': d.isClassic ? 'classic' : 'ble',
      }).toList();
      
      // Skip if device list hasn't changed (avoid duplicate sends)
      if (_lastBtDeviceList != null && _areDeviceListsEqual(_lastBtDeviceList!, deviceList)) {
        return;  // No change, skip sending
      }
      
      _lastBtDeviceList = List.from(deviceList);
      
      final updateData = {
        'connected_devices': deviceList,
      };
      
      AppLogger.info('[WEBSOCKET] Sending BT update: ${deviceList.map((d) => d['name']).toList()}');
      _socket?.emit('bt_update', updateData);
    } catch (e) {
      AppLogger.error('[WEBSOCKET] Failed to send BT update: $e');
    }
  }
  
  /// Compare two device lists for equality
  bool _areDeviceListsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    final aMacs = a.map((d) => d['mac'] as String).toSet();
    final bMacs = b.map((d) => d['mac'] as String).toSet();
    return aMacs.length == bMacs.length && aMacs.containsAll(bMacs);
  }

  /// Force send BT update immediately (bypasses debounce, for registration)
  Future<void> _sendBtUpdate() async {
    _btUpdateDebounceTimer?.cancel();
    await _sendBtUpdateImmediate();
  }

  /// Handle incoming task from server
  void _handleTask(dynamic data) async {
    try {
      if (data == null) return;
      
      final taskData = Map<String, dynamic>.from(data);
      final taskType = taskData['task'] as String?;
      
      AppLogger.info('[WEBSOCKET] Processing task: $taskType');
      
      // Get source device info for TTS feedback
      final routedFrom = taskData['_routed_from'] as String?;
      final routedFromName = taskData['_routed_from_name'] as String? ?? 'another device';
      
      // Skip if this task originated from THIS device (prevents double execution)
      // This happens when HTTP response already handled the command locally
      if (routedFrom == null) {
        AppLogger.warning('[WEBSOCKET] Task has no _routed_from - skipping to prevent duplicate');
        return;
      }
      
      // Check if this task was routed from ourselves (shouldn't happen, but safety check)
      final deviceInfo = await DeviceInfoService.instance.getDeviceInfo();
      if (routedFrom.toUpperCase() == deviceInfo.macAddress?.toUpperCase()) {
        AppLogger.warning('[WEBSOCKET] Task routed from self - skipping to prevent duplicate');
        return;
      }
      
      AppLogger.info('[WEBSOCKET] Task routed from: $routedFromName ($routedFrom)');
      
      if (taskType == 'bt-control') {
        // Parse as AssistantResponse and route to Bluetooth device
        final response = AssistantResponse.fromJson(taskData);
        
        if (response.hasError) {
          AppLogger.error('[WEBSOCKET] Task has error: ${response.error?.message}');
          await TtsService.instance.speak('Command failed: ${response.error?.message}');
          return;
        }
        
        // Route to Bluetooth device
        final success = await _commandRouter.routeCommand(response);
        
        // Extract device name and command for feedback
        final targetDevice = _extractDeviceName(response.targetDevice);
        final command = response.output.generatedOutput;
        
        if (success) {
          AppLogger.success('[WEBSOCKET] BT command executed successfully');
          
          // Show heads-up notification for routed command
          await NotificationService.instance.showRoutedCommandNotification(
            fromDeviceName: routedFromName,
            command: command,
            targetDevice: targetDevice,
          );
          
          // Speak confirmation via TTS
          await TtsService.instance.speak('Sent command to $targetDevice');
        } else {
          AppLogger.error('[WEBSOCKET] BT command failed');
          await TtsService.instance.speak('Failed to send command to $targetDevice');
        }
      } else if (taskType == 'device-message') {
        // Handle incoming message from another device
        final message = taskData['output']?['message'] as String? ?? '';
        final fromDevice = taskData['output']?['from_device'] as String? ?? routedFromName;
        
        if (message.isNotEmpty) {
          AppLogger.info('[WEBSOCKET] Received message from $fromDevice: $message');
          
          // Show notification with the message
          await NotificationService.instance.showDeviceMessageNotification(
            fromDeviceName: fromDevice,
            message: message,
          );
          
          // Also speak the message
          await TtsService.instance.speak('Message from $fromDevice: $message');
        }
      } else if (taskType == 'system-alarm') {
        final output = Map<String, dynamic>.from(taskData['output'] ?? {});
        final hour = output['hour'] as int?;
        final minute = output['minute'] as int?;
        final label = output['label'] as String?;

        if (hour == null || minute == null) {
          await TtsService.instance.speak('Alarm time is missing.');
          return;
        }

        final ok = await SystemControlService.instance.setAlarm(
          hour: hour,
          minute: minute,
          label: label,
        );

        await TtsService.instance.speak(
          ok ? "Alarm set for $hour ${minute.toString().padLeft(2, '0')}" : 'Failed to set alarm',
        );
      } else if (taskType == 'system-calendar') {
        final output = Map<String, dynamic>.from(taskData['output'] ?? {});
        final title = output['title'] as String? ?? 'Event';
        final startTimeRaw = output['start_time'] as String?;
        final duration = (output['duration_min'] as num?)?.toInt() ?? 60;
        final location = output['location'] as String?;
        final notes = output['notes'] as String?;

        if (startTimeRaw == null || startTimeRaw.isEmpty) {
          await TtsService.instance.speak('Event time is missing.');
          return;
        }

        DateTime? startTime;
        try {
          startTime = DateTime.parse(startTimeRaw);
        } catch (_) {
          await TtsService.instance.speak('Invalid event time.');
          return;
        }

        final ok = await SystemControlService.instance.addCalendarEvent(
          startTime: startTime,
          durationMinutes: duration,
          title: title,
          location: location,
          notes: notes,
        );

        await TtsService.instance.speak(
          ok ? 'Opening calendar for $title' : 'Failed to add calendar event',
        );
      } else if (taskType == 'system-call') {
        final output = Map<String, dynamic>.from(taskData['output'] ?? {});
        final phoneNumber = output['phone_number'] as String? ?? '';

        if (phoneNumber.trim().isEmpty) {
          await TtsService.instance.speak('Please provide a phone number to call.');
          return;
        }

        final ok = await SystemControlService.instance.placeCall(
          phoneNumber: phoneNumber.trim(),
        );

        await TtsService.instance.speak(
          ok ? 'Opening dialer' : 'Failed to open dialer',
        );
      } else if (taskType == 'file-transfer') {
        await FileTransferService.instance.handleSourceTransfer(taskData);
      } else if (taskType == 'file-transfer-ready') {
        await FileTransferService.instance.handleTargetDownload(taskData);
      } else if (taskType == 'text-generation') {
        // Handle text response - speak it
        final content = taskData['output']?['generated_output'] as String? ?? '';
        if (content.isNotEmpty) {
          await TtsService.instance.speak(content);
        }
      }
      
      // Notify listeners
      onTaskReceived?.call(taskData);
    } catch (e) {
      AppLogger.error('[WEBSOCKET] Error handling task: $e');
    }
  }

  /// Handle server error
  void _handleServerError(dynamic data) {
    try {
      final errorData = Map<String, dynamic>.from(data);
      final code = errorData['code'] as String? ?? 'UNKNOWN';
      final message = errorData['message'] as String? ?? 'Unknown error';
      
      AppLogger.error('[WEBSOCKET] Server error [$code]: $message');
      
      // Speak error for important cases
      if (code == 'BT_DEVICE_NOT_CONNECTED') {
        TtsService.instance.speak('Target device is not connected');
      }
    } catch (e) {
      AppLogger.error('[WEBSOCKET] Error parsing server error: $e');
    }
  }

  Future<void> _handleArmStatus(dynamic data) async {
    try {
      final statusData = Map<String, dynamic>.from(data);
      final fromName = statusData['from_name'] as String? ?? 'Jetson';
      final status = statusData['status'] as String? ?? 'unknown';
      final message = statusData['message'] as String? ?? '';
      final command = statusData['command'] as String? ?? '';
      final planId = (statusData['plan_id'] as String? ?? '').trim();
      final stepId = (statusData['step_id'] as String? ?? '').trim();
      final commandId = (statusData['command_id'] as String? ?? '').trim();

      final text = command.isNotEmpty
          ? '$status: $message [$command]'
          : '$status: $message';

      await NotificationService.instance.showRoutedCommandNotification(
        fromDeviceName: fromName,
        command: text,
        targetDevice: 'Robotic Arm',
      );

      // Spoken feedback milestones for arm tasks (deduped per plan/command).
      final dedupeScope = commandId.isNotEmpty ? commandId : (planId.isNotEmpty ? planId : 'global');
      Future<void> speakOnce(String marker, String phrase) async {
        final key = '$dedupeScope|$marker';
        if (_spokenArmFeedbackKeys.contains(key)) {
          return;
        }
        _spokenArmFeedbackKeys.add(key);
        await TtsService.instance.speak(phrase);
      }

      if (message == 'object_detected' || message == 'tracking_started') {
        await speakOnce('object_found', 'Object found');
      }

      if (message == 'prepick_locked' || message == 'grabbing') {
        await speakOnce('arm_picking', 'Arm picking');
      }

      if (message == 'picked') {
        await speakOnce('object_picked', 'Object picked');
      }

      final isFinalDone =
          status == 'done' &&
          (stepId == 's3' || stepId == 's5' || stepId == 's6') &&
          (message == 'picked' || command.toLowerCase() == 'home');
      if (isFinalDone) {
        await speakOnce('task_completed', 'Task completed');
      }

      // Prevent unbounded growth after task completion.
      if (isFinalDone && dedupeScope.isNotEmpty) {
        _spokenArmFeedbackKeys.removeWhere((item) => item.startsWith('$dedupeScope|'));
      }
    } catch (e) {
      AppLogger.error('[WEBSOCKET] Error handling arm_status: $e');
    }
  }

  /// Extract device name from device string (e.g., "drone (MAC: XX:XX:XX)" -> "drone")
  String _extractDeviceName(String deviceString) {
    final match = RegExp(r'^([^(]+)').firstMatch(deviceString);
    return match?.group(1)?.trim() ?? deviceString;
  }

  /// Send assistant request via WebSocket
  Future<void> sendAssistantRequest(String query, {String? lmModel}) async {
    if (!isConnected) {
      AppLogger.warning('[WEBSOCKET] Cannot send request - not connected');
      return;
    }

    final requestData = {
      'query': query,
      if (lmModel != null) 'lm_model': lmModel,
    };
    
    AppLogger.info('[WEBSOCKET] Sending assistant request: $query');
    _socket?.emit('assistant_request', requestData);
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (isConnected) {
        _socket?.emit('ping_server', {});
      }
    });
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      AppLogger.error('[WEBSOCKET] Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_currentReconnectDelay, () {
      _reconnectAttempts++;
      AppLogger.info('[WEBSOCKET] Reconnect attempt $_reconnectAttempts');
      
      // Exponential backoff
      _currentReconnectDelay = Duration(
        milliseconds: (_currentReconnectDelay.inMilliseconds * 1.5).toInt(),
      );
      if (_currentReconnectDelay > _maxReconnectDelay) {
        _currentReconnectDelay = _maxReconnectDelay;
      }
      
      connect();
    });
  }

  /// Reset reconnection state
  void _resetReconnectState() {
    _reconnectAttempts = 0;
    _currentReconnectDelay = _initialReconnectDelay;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Update state and notify listeners
  void _setState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      AppLogger.info('[WEBSOCKET] State changed: $newState');
      onStateChanged?.call(newState);
    }
  }

  /// Disconnect from server
  void disconnect() {
    AppLogger.info('[WEBSOCKET] Disconnecting...');
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _btUpdateDebounceTimer?.cancel();  // Clean up debounce timer
    _lastBtDeviceList = null;  // Reset last sent list
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setState(WebSocketState.disconnected);
  }

  /// Reconnect to server (force reconnect)
  Future<void> reconnect() async {
    disconnect();
    _resetReconnectState();
    await connect();
  }

  /// Called when app comes back to foreground - ensure connection is alive
  Future<void> ensureConnected() async {
    AppLogger.info('[WEBSOCKET] Ensuring connection (app resumed)...');
    
    if (_state == WebSocketState.connected && _socket?.connected == true) {
      // Connection seems alive, send a ping to verify
      _socket?.emit('ping_server', {});
      AppLogger.info('[WEBSOCKET] Connection alive, sent ping');
      
      // Also resend BT device list in case it changed
      await _sendBtUpdate();
    } else {
      // Not connected, reconnect
      AppLogger.warning('[WEBSOCKET] Not connected, reconnecting...');
      _resetReconnectState();
      await connect();
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    onStateChanged = null;
    onTaskReceived = null;
  }
}
