import 'package:sqflite/sqflite.dart';
import '../../models/bluetooth_settings.dart';
import '../../services/database/database_helper.dart';
import '../../utils/app_logger.dart';
import 'bluetooth_settings_database.dart';

/// Service for managing Bluetooth settings
class BluetoothSettingsService {
  static final BluetoothSettingsService instance = BluetoothSettingsService._();
  BluetoothSettingsService._();

  Database? _db;
  bool _isInitialized = false;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the service (safe to call multiple times)
  Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized
    }
    
    _db = await DatabaseHelper.instance.database;
    await BluetoothSettingsDatabase.initializeGlobalSettings(_db!);
    _isInitialized = true;
    AppLogger.info('BluetoothSettingsService initialized');
  }

  /// Get global settings
  Future<BluetoothSettings> getGlobalSettings() async {
    _ensureInitialized();
    return await BluetoothSettingsDatabase.getGlobalSettings(_db!);
  }

  /// Save global settings
  Future<void> saveGlobalSettings(BluetoothSettings settings) async {
    _ensureInitialized();
    await BluetoothSettingsDatabase.saveGlobalSettings(_db!, settings);
  }

  /// Get device-specific settings (returns null if using global)
  Future<BluetoothSettings?> getDeviceSettings(String deviceId) async {
    _ensureInitialized();
    return await BluetoothSettingsDatabase.getDeviceSettings(_db!, deviceId);
  }

  /// Save device-specific settings
  Future<void> saveDeviceSettings(String deviceId, BluetoothSettings settings) async {
    _ensureInitialized();
    await BluetoothSettingsDatabase.saveDeviceSettings(_db!, deviceId, settings);
  }

  /// Get effective settings for a device (merged global + device overrides)
  Future<BluetoothSettings> getEffectiveSettings(String deviceId) async {
    _ensureInitialized();
    return await BluetoothSettingsDatabase.getEffectiveSettings(_db!, deviceId);
  }

  /// Delete device-specific settings (revert to global)
  Future<void> deleteDeviceSettings(String deviceId) async {
    _ensureInitialized();
    await BluetoothSettingsDatabase.deleteDeviceSettings(_db!, deviceId);
  }

  /// Apply global settings to all devices
  Future<void> applyGlobalToAllDevices(BluetoothSettings settings) async {
    _ensureInitialized();
    await BluetoothSettingsDatabase.applyGlobalToAllDevices(_db!, settings);
  }

  /// Reset global settings to defaults
  Future<void> resetGlobalToDefaults() async {
    _ensureInitialized();
    await BluetoothSettingsDatabase.resetGlobalToDefaults(_db!);
  }

  /// Reset device to use global settings
  Future<void> resetDeviceToGlobal(String deviceId) async {
    _ensureInitialized();
    await BluetoothSettingsDatabase.resetDeviceToGlobal(_db!, deviceId);
  }

  /// Check if device has custom settings
  Future<bool> hasCustomSettings(String deviceId) async {
    _ensureInitialized();
    return await BluetoothSettingsDatabase.hasCustomSettings(_db!, deviceId);
  }

  /// Get all devices with custom settings
  Future<List<String>> getDevicesWithCustomSettings() async {
    _ensureInitialized();
    return await BluetoothSettingsDatabase.getDevicesWithCustomSettings(_db!);
  }

  /// Apply preset profile to settings
  BluetoothSettings applyPreset(String presetName, BluetoothSettings currentSettings) {
    switch (presetName.toLowerCase()) {
      case 'hm10':
      case 'hm-10':
        return BluetoothSettings.hm10Preset();
      case 'arduino':
      case 'arduino nano':
        return BluetoothSettings.arduinoNanoPreset();
      default:
        AppLogger.warning('Unknown preset: $presetName');
        return currentSettings;
    }
  }

  void _ensureInitialized() {
    if (_db == null) {
      throw Exception('BluetoothSettingsService not initialized. Call initialize() first.');
    }
  }
}
