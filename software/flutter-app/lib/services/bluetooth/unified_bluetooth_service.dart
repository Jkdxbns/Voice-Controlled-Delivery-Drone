import 'dart:async';
import '../../models/unified_bluetooth_device.dart';
import '../../models/bluetooth_device_config.dart';
import '../../models/ble_device_config.dart';
import '../../models/bluetooth_settings.dart';
import 'bluetooth_service.dart';
import 'bluetooth_device_manager.dart';
import '../ble/ble_service.dart';
import 'unified_bluetooth_database.dart';
import 'bluetooth_settings_service.dart';
import 'bluetooth_device_registration_service.dart';
import '../websocket_service.dart';
import '../../utils/app_logger.dart';

class UnifiedBluetoothService {
  static final UnifiedBluetoothService instance = UnifiedBluetoothService._init();

  final BluetoothService _classicService = BluetoothService.instance;
  final BleService _bleService = BleService.instance;
  final UnifiedBluetoothDatabase _database = UnifiedBluetoothDatabase.instance;
  final BluetoothSettingsService _settingsService = BluetoothSettingsService.instance;
  final BluetoothDeviceRegistrationService _btRegistrationService = BluetoothDeviceRegistrationService.instance;

  // Discovered devices stream controller
  final _discoveredDevicesController =
      StreamController<UnifiedBluetoothDevice>.broadcast();

  // Scanning state
  bool _isScanning = false;
  StreamSubscription? _classicScanSubscription;
  StreamSubscription? _bleScanSubscription;

  // Connection states
  final Map<String, UnifiedConnectionInfo> _connectionStates = {};
  final _connectionStatesController =
      StreamController<Map<String, UnifiedConnectionInfo>>.broadcast();

  // Received data stream controller (unified from both Classic and BLE)
  final _dataReceivedController =
      StreamController<UnifiedDataEvent>.broadcast();

  // Subscription tracking for proper cleanup
  StreamSubscription? _classicConnectionSubscription;
  StreamSubscription? _bleConnectionSubscription;
  StreamSubscription? _classicDataSubscription;
  StreamSubscription? _bleDataSubscription;

  UnifiedBluetoothService._init();

  /// Get discovered devices stream
  Stream<UnifiedBluetoothDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  /// Get connection states stream
  Stream<Map<String, UnifiedConnectionInfo>> get connectionStates =>
      _connectionStatesController.stream;

  /// Get received data stream (unified from both Classic and BLE)
  Stream<UnifiedDataEvent> get dataReceivedStream =>
      _dataReceivedController.stream;

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Get current connection states map
  Map<String, UnifiedConnectionInfo> get currentConnectionStates =>
      Map.from(_connectionStates);

  bool _isInitialized = false;
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize service (safe to call multiple times)
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized, skip
    }
    
    await _classicService.initialize();
    await _settingsService.initialize();
    
    // Initialize BLE service and check for existing connections
    await _bleService.initialize();
    
    // Set up listeners
    _listenToConnectionChanges();
    
    _isInitialized = true;
    
    // Immediately sync current connection states from BLE service
    _syncBleConnectionStates();
    
    AppLogger.success('Unified Bluetooth Service initialized');
  }
  
  /// Sync BLE connection states immediately (for already-connected devices)
  void _syncBleConnectionStates() {
    final bleStates = _bleService.currentStates;
    if (bleStates.isNotEmpty) {
      AppLogger.info('Syncing ${bleStates.length} existing BLE connection states');
      for (final entry in bleStates.entries) {
        _connectionStates[entry.key] = UnifiedConnectionInfo(
          deviceId: entry.key,
          deviceType: BluetoothDeviceType.ble,
          state: _convertBleState(entry.value),
          connectedAt: DateTime.now(),
        );
      }
      _connectionStatesController.add(_connectionStates);
    }
  }

  /// Listen to connection state changes from both services
  void _listenToConnectionChanges() {
    // Cancel existing subscriptions to prevent duplicates
    _classicConnectionSubscription?.cancel();
    _bleConnectionSubscription?.cancel();
    _classicDataSubscription?.cancel();
    _bleDataSubscription?.cancel();
    
    // Listen to Classic connections
    _classicConnectionSubscription = _classicService.connectionStateStream.listen((classicStates) {
      for (final entry in classicStates.entries) {
        _connectionStates[entry.key] = UnifiedConnectionInfo(
          deviceId: entry.key,
          deviceType: BluetoothDeviceType.classic,
          state: _convertClassicState(entry.value.state),
          connectedAt: entry.value.connectedAt,
          bytesSent: entry.value.bytesSent,
          bytesReceived: entry.value.bytesReceived,
          errorMessage: entry.value.errorMessage,
        );
      }
      _connectionStatesController.add(_connectionStates);
    });

    // Listen to BLE connections
    _bleConnectionSubscription = _bleService.connectionStates.listen((bleStates) {
      for (final entry in bleStates.entries) {
        _connectionStates[entry.key] = UnifiedConnectionInfo(
          deviceId: entry.key,
          deviceType: BluetoothDeviceType.ble,
          state: _convertBleState(entry.value),
          connectedAt: DateTime.now(), // BLE doesn't provide this
        );
      }
      _connectionStatesController.add(_connectionStates);
    });

    // Listen to Classic data
    _classicDataSubscription = _classicService.dataReceivedStream.listen((event) {
      _dataReceivedController.add(UnifiedDataEvent(
        deviceId: event.deviceAddress,
        deviceType: BluetoothDeviceType.classic,
        data: String.fromCharCodes(event.data),
        timestamp: event.timestamp,
      ));
    });

    // Listen to BLE data
    _bleDataSubscription = _bleService.dataEvents.listen((event) {
      _dataReceivedController.add(UnifiedDataEvent(
        deviceId: event.deviceId,
        deviceType: BluetoothDeviceType.ble,
        data: event.dataAsString,
        timestamp: event.timestamp,
      ));
    });
  }

  /// Convert Classic connection state to unified state
  UnifiedConnectionState _convertClassicState(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        return UnifiedConnectionState.connected;
      case BluetoothConnectionState.connecting:
        return UnifiedConnectionState.connecting;
      case BluetoothConnectionState.disconnecting:
        return UnifiedConnectionState.disconnecting;
      case BluetoothConnectionState.error:
        return UnifiedConnectionState.error;
      case BluetoothConnectionState.disconnected:
        return UnifiedConnectionState.disconnected;
    }
  }

  /// Convert BLE connection state to unified state
  UnifiedConnectionState _convertBleState(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.connected:
        return UnifiedConnectionState.connected;
      case BleConnectionState.connecting:
        return UnifiedConnectionState.connecting;
      case BleConnectionState.disconnecting:
        return UnifiedConnectionState.disconnecting;
      case BleConnectionState.error:
        return UnifiedConnectionState.error;
      case BleConnectionState.disconnected:
        return UnifiedConnectionState.disconnected;
    }
  }

  /// Start unified scan (SIMULTANEOUS Classic + BLE)
  Future<void> startUnifiedScan({Duration? timeout}) async {
    if (_isScanning) {
      AppLogger.warning('Scan already in progress');
      return;
    }

    _isScanning = true;
    AppLogger.info('Starting unified scan (Classic + BLE)...');

    // Start Classic scan with error handling
    try {
      await _startClassicScan();
    } catch (e) {
      AppLogger.error('Failed to start Classic scan: $e');
      // Continue with BLE scan even if Classic fails
    }

    // Start BLE scan with error handling
    try {
      await _startBleScan();
    } catch (e) {
      AppLogger.error('Failed to start BLE scan: $e');
    }

    // Stop after timeout
    if (timeout != null) {
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopUnifiedScan();
        }
      });
    }
  }

  /// Start Classic Bluetooth scan
  Future<void> _startClassicScan() async {
    try {
      final classicManager = BluetoothDeviceManager.instance;

      await classicManager.startDiscovery(
        onDeviceFound: (result) async {
          // Get bonded devices to check pair status
          final bondedDevices = await classicManager.getBondedDevicesWithConfig();
          final isPaired = bondedDevices.any((d) => d.address == result.device.address);

          final device = UnifiedBluetoothDevice(
            id: result.device.address,
            name: result.device.name ?? 'Unknown',
            type: BluetoothDeviceType.classic,
            rssi: result.rssi,
            isPaired: isPaired,
            classicConfig: BluetoothDeviceConfig(
              address: result.device.address,
              name: result.device.name ?? 'Unknown',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          _discoveredDevicesController.add(device);
        },
        onFinished: () {
          AppLogger.info('Classic scan finished');
        },
      );
    } catch (e) {
      AppLogger.error('Classic scan error: $e');
      rethrow;
    }
  }

  /// Start BLE scan
  Future<void> _startBleScan() async {
    try {
      final bleManager = _bleService.deviceManager;

      _bleScanSubscription = bleManager.discoveredDevices.listen((bleDevice) {
        final device = UnifiedBluetoothDevice(
          id: bleDevice.id,
          name: bleDevice.name.isNotEmpty ? bleDevice.name : 'Unknown',
          type: BluetoothDeviceType.ble,
          rssi: bleDevice.rssi,
          isPaired: false,
          bleConfig: BleDeviceConfig(
            deviceId: bleDevice.id,
            deviceName: bleDevice.name,
            rssi: bleDevice.rssi,
            createdAt: DateTime.now(),
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _discoveredDevicesController.add(device);
      });

      await bleManager.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      AppLogger.error('BLE scan error: $e');
      rethrow;
    }
  }

  /// Stop unified scan
  void stopUnifiedScan() {
    if (!_isScanning) return;

    _isScanning = false;
    AppLogger.info('Stopping unified scan...');

    // Stop Classic scan
    BluetoothDeviceManager.instance.stopDiscovery();

    // Stop BLE scan
    _bleService.deviceManager.stopScan();
    _bleScanSubscription?.cancel();

    AppLogger.success('Unified scan stopped');
  }

  /// Connect to device (auto-detects type and uses correct service)
  Future<bool> connectToDevice(UnifiedBluetoothDevice device) async {
    try {
      AppLogger.info('Connecting to ${device.typeLabel} device: ${device.displayName}');

      // CRITICAL: Check if Bluetooth is enabled before connecting
      final classicManager = BluetoothDeviceManager.instance;
      final isEnabled = await classicManager.isBluetoothEnabled();
      
      if (!isEnabled) {
        AppLogger.warning('Bluetooth is disabled - requesting to enable...');
        
        final enabled = await classicManager.requestEnableBluetooth();
        
        if (!enabled) {
          AppLogger.error('Bluetooth not enabled - cannot connect');
          AppLogger.showToast('Please enable Bluetooth to connect');
          return false;
        }
        
        AppLogger.success('Bluetooth enabled successfully');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      bool success;

      if (device.isClassic) {
        // Connect using Classic service
        if (device.classicConfig == null) {
          AppLogger.error('No Classic config for device');
          return false;
        }
        success = await _classicService.connectToDevice(device.classicConfig!);
      } else {
        // Connect using BLE service
        if (device.bleConfig == null) {
          AppLogger.error('No BLE config for device');
          return false;
        }
        success = await _bleService.connectToDevice(device.bleConfig!);
      }

      if (success) {
        // IMMEDIATELY update connection state to reflect successful connection
        // This ensures the UI shows the device as connected right away
        _connectionStates[device.id] = UnifiedConnectionInfo(
          deviceId: device.id,
          deviceType: device.isClassic ? BluetoothDeviceType.classic : BluetoothDeviceType.ble,
          state: UnifiedConnectionState.connected,
          connectedAt: DateTime.now(),
          bytesSent: 0,
          bytesReceived: 0,
        );
        _connectionStatesController.add(_connectionStates);
        
        // Save to database
        await _database.upsertDevice(device);
        await _database.updateLastConnected(device.id);
        
        // Auto-apply preset if first connection (no custom settings)
        await _autoApplyPreset(device);
        
        // Register Bluetooth device with server (broadcasts to device lookup)
        _btRegistrationService.registerBluetoothDevice(device).catchError((e) {
          AppLogger.error('Failed to register BT device with server: $e');
          return false;
        });
        
        // Report connection to server immediately (for real-time status sync)
        _reportConnectionEvent(device.id, isConnected: true);
        
        AppLogger.success('Connected to ${device.displayName}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Connection failed: $e');
      return false;
    }
  }

  /// Auto-apply preset settings based on device name
  Future<void> _autoApplyPreset(UnifiedBluetoothDevice device) async {
    try {
      // Check if device already has custom settings
      final hasCustom = await _settingsService.hasCustomSettings(device.id);
      if (hasCustom) {
        AppLogger.info('Device already has custom settings, skipping preset');
        return;
      }

      // Detect device type from name
      final deviceName = device.name.toLowerCase();
      BluetoothSettings? preset;
      String? presetName;

      if (deviceName.contains('hm-10') || deviceName.contains('hm10') || deviceName.contains('hmsoft')) {
        preset = BluetoothSettings.hm10Preset();
        presetName = 'HM-10';
      } else if (deviceName.contains('arduino') || deviceName.contains('nano')) {
        preset = BluetoothSettings.arduinoNanoPreset();
        presetName = 'Arduino Nano';
      }

      // Apply preset if detected
      if (preset != null && presetName != null) {
        await _settingsService.saveDeviceSettings(device.id, preset);
        AppLogger.success('Applied $presetName preset settings');
        AppLogger.showToast('Applied $presetName preset settings');
      }
    } catch (e) {
      AppLogger.error('Failed to auto-apply preset: $e');
    }
  }

  /// Disconnect from device
  Future<void> disconnectDevice(String deviceId) async {
    try {
      final info = _connectionStates[deviceId];
      if (info == null) {
        AppLogger.warning('Device not connected: $deviceId');
        return;
      }

      if (info.deviceType == BluetoothDeviceType.classic) {
        await _classicService.disconnectDevice(deviceId);
      } else {
        await _bleService.disconnectFromDevice(deviceId);
      }

      // Report disconnection to server immediately
      _reportConnectionEvent(deviceId, isConnected: false);

      AppLogger.success('Disconnected from $deviceId');
    } catch (e) {
      AppLogger.error('Disconnect failed: $e');
    }
  }

  /// Send data to device (auto-detects type and applies settings)
  Future<bool> sendData(String deviceId, dynamic data) async {
    try {
      final info = _connectionStates[deviceId];
      if (info == null || !info.isConnected) {
        AppLogger.error('Device not connected: $deviceId');
        return false;
      }

      // Get effective settings for this device
      final settings = await _settingsService.getEffectiveSettings(deviceId);
      
      // Convert data to string if needed
      String message;
      if (data is String) {
        message = data;
      } else if (data is int) {
        message = data.toString();
      } else if (data is List<int>) {
        message = String.fromCharCodes(data);
      } else {
        message = data.toString();
      }

      // Apply message formatting settings
      message = _applyMessageFormatting(message, settings);

      if (info.deviceType == BluetoothDeviceType.classic) {
        // Send to Classic device
        return await _classicService.sendStringToDevice(deviceId, message);
      } else {
        // Send to BLE device
        // Apply chunking if enabled and message is large
        if (settings.packetChunking && message.length > settings.chunkSize) {
          return await _sendChunkedData(deviceId, message, settings);
        } else {
          await _bleService.sendStringToDevice(deviceId, message);
          return true;
        }
      }
    } catch (e) {
      AppLogger.error('Send data failed: $e');
      return false;
    }
  }

  /// Apply message formatting settings
  String _applyMessageFormatting(String message, BluetoothSettings settings) {
    // Trim whitespace if enabled
    if (settings.trimWhitespace) {
      message = message.trim();
    }

    // Add prefix
    if (settings.autoPrefix.isNotEmpty) {
      message = settings.autoPrefix + message;
    }

    // Add suffix
    if (settings.autoSuffix.isNotEmpty) {
      message = message + settings.autoSuffix;
    }

    // Add line ending
    message = message + settings.lineEnding.value;

    return message;
  }

  /// Send data in chunks (for large messages)
  Future<bool> _sendChunkedData(String deviceId, String message, BluetoothSettings settings) async {
    try {
      final chunks = <String>[];
      for (int i = 0; i < message.length; i += settings.chunkSize) {
        final end = (i + settings.chunkSize < message.length) ? i + settings.chunkSize : message.length;
        chunks.add(message.substring(i, end));
      }

      AppLogger.info('Sending ${chunks.length} chunks to $deviceId');

      for (int i = 0; i < chunks.length; i++) {
        await _bleService.sendStringToDevice(deviceId, chunks[i]);
        
        // Add delay between chunks (except for last chunk)
        if (i < chunks.length - 1 && settings.chunkDelay > 0) {
          await Future.delayed(Duration(milliseconds: settings.chunkDelay));
        }
      }

      AppLogger.success('Sent ${chunks.length} chunks successfully');
      return true;
    } catch (e) {
      AppLogger.error('Chunked send failed: $e');
      return false;
    }
  }

  /// Broadcast to all connected devices (both types)
  Future<Map<String, bool>> broadcastToAll(String message) async {
    final results = <String, bool>{};

    for (final entry in _connectionStates.entries) {
      if (entry.value.isConnected) {
        results[entry.key] = await sendData(entry.key, message);
      }
    }

    AppLogger.info('Broadcast to ${results.length} devices');
    return results;
  }

  /// Get all saved devices from database with current connection state
  Future<List<UnifiedBluetoothDevice>> getSavedDevices() async {
    final devices = await _database.getAllDevices();
    
    // Merge with runtime connection states
    return devices.map((device) {
      final connectionInfo = _connectionStates[device.id];
      if (connectionInfo != null) {
        // Device has runtime connection state - merge it
        return device.copyWith(connectionState: connectionInfo.state);
      }
      // No runtime state - return as-is (disconnected)
      return device;
    }).toList();
  }

  /// Get devices by type
  Future<List<UnifiedBluetoothDevice>> getDevicesByType(
    BluetoothDeviceType type,
  ) async {
    return await _database.getDevicesByType(type);
  }

  /// Delete saved device
  Future<void> deleteSavedDevice(String deviceId) async {
    await _database.deleteDevice(deviceId);
  }

  /// Get all connected devices
  List<UnifiedBluetoothDevice> getConnectedDevices() {
    return _connectionStates.entries
        .where((e) => e.value.isConnected)
        .map((e) => UnifiedBluetoothDevice(
              id: e.key,
              name: e.key,
              type: e.value.deviceType,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              connectionState: e.value.state,
            ))
        .toList();
  }

  /// Report connection event to server (for real-time status sync)
  void _reportConnectionEvent(String deviceId, {required bool isConnected}) {
    try {
      // Send BT device update to server via WebSocket
      // This tells the server which BT devices this phone has connected
      WebSocketService.instance.sendBtUpdate();
    } catch (e) {
      AppLogger.error('Failed to report connection event: $e');
      // Non-critical - continue anyway
    }
  }

  /// Dispose
  void dispose() {
    stopUnifiedScan();
    _discoveredDevicesController.close();
    _connectionStatesController.close();
    _dataReceivedController.close();
    _classicScanSubscription?.cancel();
    _bleScanSubscription?.cancel();
    _classicConnectionSubscription?.cancel();
    _bleConnectionSubscription?.cancel();
    _classicDataSubscription?.cancel();
    _bleDataSubscription?.cancel();
  }
}
