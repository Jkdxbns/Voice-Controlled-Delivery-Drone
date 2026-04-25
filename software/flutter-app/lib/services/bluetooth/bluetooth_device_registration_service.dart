import 'dart:async';
import '../../models/unified_bluetooth_device.dart';
import '../../api/models/device_info_data.dart';
import '../../services/api/device_registration_api_service.dart';
import '../../services/server/server_config_service.dart';
import '../../utils/app_logger.dart';
import '../device/device_info_service.dart';

/// Service to register connected Bluetooth devices with the server
/// Broadcasts Bluetooth device info along with parent phone info
class BluetoothDeviceRegistrationService {
  static final BluetoothDeviceRegistrationService _instance = 
      BluetoothDeviceRegistrationService._internal();
  
  static BluetoothDeviceRegistrationService get instance => _instance;
  
  BluetoothDeviceRegistrationService._internal();

  final _registeredDevices = <String>{}; // Track which BT devices we've already registered

  /// Register a Bluetooth device with the server
  /// This broadcasts:
  /// - Bluetooth device MAC address
  /// - Bluetooth device name (original name, not modified)
  /// - Parent phone's info stored in IP address field
  Future<bool> registerBluetoothDevice(UnifiedBluetoothDevice btDevice) async {
    try {
      // Skip if already registered in this session
      if (_registeredDevices.contains(btDevice.id)) {
        AppLogger.info('BT device ${btDevice.displayName} already registered this session');
        return true;
      }

      AppLogger.info('📡 Registering Bluetooth device: ${btDevice.displayName}');

      // Get the parent phone's info (the phone this BT device is connected to)
      final phoneInfo = await DeviceInfoService.instance.getDeviceInfo();

      // Create device info for the Bluetooth device
      // Use BT device's MAC as device_id
      // Store parent phone MAC in IP address field for cross-device routing
      // Server uses this to route commands to the correct phone
      final btDeviceInfo = DeviceInfoData(
        deviceId: btDevice.id, // MAC address of BT device
        deviceName: btDevice.displayName, // Original BT device name
        modelName: btDevice.isClassic ? 'Bluetooth Classic' : 'BLE Device',
        macAddress: btDevice.id, // BT MAC address
        ipAddress: phoneInfo.macAddress ?? '', // Parent phone MAC for cross-device routing
      );

      final service = DeviceRegistrationApiService(
        baseUrl: ServerConfigService.instance.baseUrl,
      );

      final success = await service.registerDevice(btDeviceInfo);

      if (success) {
        _registeredDevices.add(btDevice.id);
        AppLogger.success('✓ Bluetooth device registered: ${btDevice.displayName}');
        AppLogger.success('  └─ Parent Device: ${phoneInfo.deviceName}');
        AppLogger.success('  └─ Parent MAC: ${phoneInfo.macAddress}');
        AppLogger.success('  └─ BT MAC: ${btDevice.id}');
      } else {
        AppLogger.error('Failed to register BT device: ${btDevice.displayName}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Error registering Bluetooth device: $e');
      return false;
    }
  }

  /// Register multiple Bluetooth devices
  Future<void> registerMultipleDevices(List<UnifiedBluetoothDevice> devices) async {
    for (final device in devices) {
      await registerBluetoothDevice(device);
      // Small delay to avoid overwhelming server
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Clear registration cache (force re-registration on next connect)
  void clearCache() {
    _registeredDevices.clear();
    AppLogger.info('Bluetooth device registration cache cleared');
  }

  /// Check if device is registered in this session
  bool isRegistered(String deviceId) {
    return _registeredDevices.contains(deviceId);
  }

  /// Get count of registered BT devices this session
  int get registeredCount => _registeredDevices.length;
}
