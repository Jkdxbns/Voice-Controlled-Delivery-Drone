import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../models/ble_device_config.dart';
import 'ble_connection.dart';
import 'ble_device_manager.dart';
import 'ble_database_helper.dart';
import '../../utils/app_logger.dart';

class BleService {
  static final BleService instance = BleService._init();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Map<String, BleDeviceConnection> _connections = {};
  final Map<String, int> _connectionHistoryIds = {};
  
  final _dataEventsController = StreamController<BleDeviceDataEvent>.broadcast();
  final _connectionStatesController = StreamController<Map<String, BleConnectionState>>.broadcast();

  bool _isInitialized = false;

  BleService._init();

  // Getters
  bool get isInitialized => _isInitialized;
  Stream<BleDeviceDataEvent> get dataEvents => _dataEventsController.stream;
  Stream<Map<String, BleConnectionState>> get connectionStates => _connectionStatesController.stream;
  Map<String, BleConnectionState> get currentStates => 
      _connections.map((key, conn) => MapEntry(key, conn.currentState));
  List<String> get connectedDeviceIds => 
      _connections.entries
          .where((entry) => entry.value.currentState == BleConnectionState.connected)
          .map((entry) => entry.key)
          .toList();
  BleDeviceManager get deviceManager => BleDeviceManager.instance;

  /// Initialize and check for already connected devices (safe to call multiple times)
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized
    }
    
    AppLogger.info('Initializing BLE service and checking for existing connections');
    
    try {
      // Get all saved devices
      final savedDevices = await getSavedDevices();
      
      if (savedDevices.isEmpty) {
        AppLogger.info('No saved BLE devices found');
        _isInitialized = true;
        return;
      }
      
      AppLogger.info('Found ${savedDevices.length} saved BLE devices, checking connections');
      
      // Check each saved device to see if it's already connected
      for (final config in savedDevices) {
        try {
          // Try to establish connection stream (will detect if already connected)
          // This is non-blocking and will handle already-connected devices gracefully
          await _checkAndRestoreConnection(config);
        } catch (e) {
          AppLogger.debug('Device ${config.deviceId} not currently connected: $e');
        }
      }
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('Failed to initialize BLE service: $e');
    }
  }

  /// Check if device is already connected and restore the connection
  Future<void> _checkAndRestoreConnection(BleDeviceConfig config) async {
    final deviceId = config.deviceId;
    
    // Skip if we already have this connection tracked
    if (_connections.containsKey(deviceId)) {
      AppLogger.debug('Connection already tracked for $deviceId');
      return;
    }
    
    AppLogger.debug('Checking connection status for $deviceId');
    
    // Create connection object
    final connection = BleDeviceConnection(
      ble: _ble,
      config: config,
    );

    // Store connection reference for proper cleanup
    _connections[deviceId] = connection;
    
    // Set up listeners before attempting connection
    StreamSubscription? stateSubscription;
    StreamSubscription? dataSubscription;
    
    stateSubscription = connection.stateStream.listen((state) {
      _handleConnectionStateChange(deviceId, state);
    });

    dataSubscription = connection.dataStream.listen((data) {
      _handleIncomingData(deviceId, data);
    });
    
    // Try to connect - if already connected, this will be detected immediately
    // Set a short timeout since we're just checking
    try {
      final connected = await connection.connect().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          AppLogger.debug('Connection check timeout for $deviceId (not connected)');
          return false;
        },
      );
      
      if (connected) {
        AppLogger.success('✓ Restored connection to $deviceId');
        
        final historyId = await BleDatabaseHelper.instance.insertConnectionHistory(
          deviceId: deviceId,
          connectedAt: DateTime.now(),
        );
        _connectionHistoryIds[deviceId] = historyId;
        
        _broadcastConnectionStates();
      } else {
        // Not connected, clean up properly
        await stateSubscription.cancel();
        await dataSubscription.cancel();
        await connection.dispose();
        _connections.remove(deviceId);
      }
    } catch (e) {
      AppLogger.debug('Device $deviceId not currently connected: $e');
      // Clean up on error
      await stateSubscription.cancel();
      await dataSubscription.cancel();
      await connection.dispose();
      _connections.remove(deviceId);
    }
  }

  /// Connect to a BLE device
  Future<bool> connectToDevice(BleDeviceConfig config) async {
    final deviceId = config.deviceId;
    
    // Check if already connected or connecting
    if (_connections.containsKey(deviceId)) {
      final existingConn = _connections[deviceId]!;
      final state = existingConn.currentState;
      
      if (state == BleConnectionState.connected) {
        AppLogger.info('Already connected to $deviceId');
        return true;
      } else if (state == BleConnectionState.connecting) {
        AppLogger.info('Connection already in progress to $deviceId, waiting...');
        // Wait for existing connection attempt to complete
        try {
          // Listen for state changes
          await for (final connState in existingConn.stateStream) {
            if (connState == BleConnectionState.connected) {
              return true;
            } else if (connState == BleConnectionState.disconnected || 
                       connState == BleConnectionState.error) {
              return false;
            }
          }
        } catch (e) {
          AppLogger.error('Error waiting for connection: $e');
          return false;
        }
      }
      // If disconnected or error state, clean up and reconnect below
      else {
        AppLogger.info('Cleaning up previous connection to $deviceId');
        await existingConn.dispose();
        _connections.remove(deviceId);
      }
    }

    AppLogger.info('Connecting to BLE device: $deviceId');

    // Save config to database first
    await BleDatabaseHelper.instance.insertDevice(config);

    // Create new connection
    final connection = BleDeviceConnection(
      ble: _ble,
      config: config,
    );

    // Set up listeners
    connection.stateStream.listen((state) {
      _handleConnectionStateChange(deviceId, state);
    });

    connection.dataStream.listen((data) {
      _handleIncomingData(deviceId, data);
    });

    // Store connection before attempting to connect
    _connections[deviceId] = connection;

    // Start connection
    final success = await connection.connect();

    // Record connection start if successful
    if (success && connection.currentState == BleConnectionState.connected) {
      final historyId = await BleDatabaseHelper.instance.insertConnectionHistory(
        deviceId: deviceId,
        connectedAt: DateTime.now(),
      );
      _connectionHistoryIds[deviceId] = historyId;
      
      await BleDatabaseHelper.instance.updateLastConnected(deviceId);
      
      _broadcastConnectionStates();
    } else {
      // Connection failed, clean up
      await connection.dispose();
      _connections.remove(deviceId);
    }
    
    return success;
  }

  /// Disconnect from a BLE device
  Future<void> disconnectFromDevice(String deviceId) async {
    if (!_connections.containsKey(deviceId)) {
      AppLogger.warning('Device $deviceId is not in connections map');
      return;
    }

    AppLogger.info('Disconnecting from BLE device: $deviceId');

    final connection = _connections[deviceId]!;
    final info = connection.getConnectionInfo();

    // Disconnect (this will trigger the disconnected state)
    await connection.disconnect();
    
    // Update connection history
    if (_connectionHistoryIds.containsKey(deviceId)) {
      await BleDatabaseHelper.instance.updateConnectionHistory(
        historyId: _connectionHistoryIds[deviceId]!,
        disconnectedAt: DateTime.now(),
        bytesSent: info.bytesSent,
        bytesReceived: info.bytesReceived,
      );
      _connectionHistoryIds.remove(deviceId);
    }

    // Clean up and remove connection
    await connection.dispose();
    _connections.remove(deviceId);
    
    _broadcastConnectionStates();
  }

  /// Send data to a specific device
  Future<void> sendToDevice(String deviceId, List<int> data) async {
    if (!_connections.containsKey(deviceId)) {
      throw Exception('Device $deviceId is not connected');
    }

    final connection = _connections[deviceId]!;
    
    if (connection.currentState != BleConnectionState.connected) {
      // Queue message for later if auto-reconnect is enabled
      if (connection.config.autoReconnect) {
        AppLogger.info('Device disconnected, queueing message');
        await BleDatabaseHelper.instance.queueMessage(deviceId, data);
        return;
      }
      throw Exception('Device $deviceId is not connected');
    }

    await connection.writeData(data);
  }

  /// Send string to a specific device
  Future<void> sendStringToDevice(String deviceId, String text) async {
    await sendToDevice(deviceId, text.codeUnits);
  }

  /// Send data to all connected devices
  Future<void> broadcastToAll(List<int> data) async {
    final connectedIds = connectedDeviceIds;
    
    if (connectedIds.isEmpty) {
      AppLogger.warning('No connected devices to broadcast to');
      return;
    }

    AppLogger.info('Broadcasting to ${connectedIds.length} devices');
    
    for (final deviceId in connectedIds) {
      try {
        await sendToDevice(deviceId, data);
      } catch (e) {
        AppLogger.error('Failed to broadcast to $deviceId: $e');
      }
    }
  }

  /// Send data to multiple specific devices
  Future<void> sendToMultiple(List<String> deviceIds, List<int> data) async {
    for (final deviceId in deviceIds) {
      try {
        await sendToDevice(deviceId, data);
      } catch (e) {
        AppLogger.error('Failed to send to $deviceId: $e');
      }
    }
  }

  /// Get connection info for a device
  BleConnectionInfo? getConnectionInfo(String deviceId) {
    return _connections[deviceId]?.getConnectionInfo();
  }

  /// Get all connection infos
  Map<String, BleConnectionInfo> getAllConnectionInfos() {
    return _connections.map((key, conn) => MapEntry(key, conn.getConnectionInfo()));
  }

  /// Process pending messages for a device (after reconnection)
  Future<void> processPendingMessages(String deviceId) async {
    final messages = await BleDatabaseHelper.instance.getPendingMessages(deviceId);
    
    if (messages.isEmpty) return;

    AppLogger.info('Processing ${messages.length} pending messages for $deviceId');

    for (final message in messages) {
      try {
        final data = message['message_data'] as List<int>;
        await sendToDevice(deviceId, data);
        await BleDatabaseHelper.instance.markMessageSent(message['id'] as int);
      } catch (e) {
        AppLogger.error('Failed to send pending message: $e');
      }
    }
  }

  /// Disconnect all devices
  Future<void> disconnectAll() async {
    AppLogger.info('Disconnecting all BLE devices');
    
    final deviceIds = _connections.keys.toList();
    for (final deviceId in deviceIds) {
      await disconnectFromDevice(deviceId);
    }
  }

  void _handleConnectionStateChange(String deviceId, BleConnectionState state) {
    AppLogger.info('BLE device $deviceId state changed to: $state');
    
    // Handle auto-reconnect and pending messages
    if (state == BleConnectionState.connected) {
      processPendingMessages(deviceId);
    }
    
    _broadcastConnectionStates();
  }

  void _handleIncomingData(String deviceId, List<int> data) {
    final event = BleDeviceDataEvent(
      deviceId: deviceId,
      data: data,
      timestamp: DateTime.now(),
    );
    
    _dataEventsController.add(event);
  }

  void _broadcastConnectionStates() {
    _connectionStatesController.add(currentStates);
  }

  /// Get saved devices from database
  Future<List<BleDeviceConfig>> getSavedDevices() async {
    return await BleDatabaseHelper.instance.getAllDevices();
  }

  /// Delete a saved device
  Future<void> deleteSavedDevice(String deviceId) async {
    // Disconnect if connected
    if (_connections.containsKey(deviceId)) {
      await disconnectFromDevice(deviceId);
    }
    
    await BleDatabaseHelper.instance.deleteDevice(deviceId);
  }

  /// Update device configuration
  Future<void> updateDeviceConfig(BleDeviceConfig config) async {
    await BleDatabaseHelper.instance.updateDevice(config);
    
    // If device is connected, apply changes by reconnecting
    if (_connections.containsKey(config.deviceId)) {
      await disconnectFromDevice(config.deviceId);
      await Future.delayed(const Duration(milliseconds: 500));
      await connectToDevice(config);
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await disconnectAll();
    deviceManager.dispose();
    await _dataEventsController.close();
    await _connectionStatesController.close();
  }
}
