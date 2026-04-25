import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_udid/flutter_udid.dart';
import '../../services/preferences_service.dart';
import '../../api/models/device_info_data.dart';
import '../../utils/app_logger.dart';

/// Service to collect and manage device information
/// 
/// Collects:
/// - Device name (e.g., "Samsung Galaxy S21")
/// - Model name (e.g., "SM-G991B")
/// - MAC address (Hardware identifier - device's unique hardware MAC)
/// - Unique device ID (uses hardware MAC as primary key)
class DeviceInfoService {
  static final DeviceInfoService instance = DeviceInfoService._();
  DeviceInfoService._();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final NetworkInfo _networkInfo = NetworkInfo();

  String? _cachedDeviceId;
  String? _cachedDeviceName;
  String? _cachedModelName;
  String? _cachedMacAddress;
  bool _isInitialized = false;

  /// Initialize the service (pre-fetch all device info to cache)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Pre-fetch ALL device info during initialization
      // This prevents multiple concurrent fetches later
      _cachedDeviceId = await _getOrCreateDeviceId();
      _cachedDeviceName = await _getDeviceName();
      _cachedModelName = await _getModelName();
      _cachedMacAddress = await getMacAddress();
      
      _isInitialized = true;
      AppLogger.info('Device ID initialized: $_cachedDeviceId');
    } catch (e) {
      AppLogger.error('Failed to initialize DeviceInfoService: $e');
    }
  }

  /// Get complete device information (uses cached values after init)
  Future<DeviceInfoData> getDeviceInfo() async {
    // Ensure initialized
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      return DeviceInfoData(
        deviceId: _cachedDeviceId ?? await _getOrCreateDeviceId(),
        deviceName: _cachedDeviceName ?? await _getDeviceName(),
        modelName: _cachedModelName ?? await _getModelName(),
        macAddress: _cachedMacAddress,
      );
    } catch (e) {
      AppLogger.error('Failed to get device info: $e');
      // Return fallback data
      return DeviceInfoData(
        deviceId: _cachedDeviceId ?? 'unknown',
        deviceName: _cachedDeviceName ?? 'Unknown Device',
        modelName: _cachedModelName ?? 'Unknown Model',
        macAddress: _cachedMacAddress,
      );
    }
  }

  /// Get or create persistent device ID (UUID)
  Future<String> _getOrCreateDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Try to load from SharedPreferences
    final prefs = PreferencesService.instance;
    String? savedId = prefs.deviceId;

    if (savedId == null || savedId.isEmpty) {
      // Generate new UUID
      savedId = _generateUuid();
      await prefs.setDeviceId(savedId);
      AppLogger.info('Generated new device ID: $savedId');
    }

    return savedId;
  }

  /// Get device name (human-readable)
  Future<String> _getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use brand + model for readable name
        final brand = androidInfo.brand;
        final model = androidInfo.model;
        return '$brand $model';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.name;
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        return linuxInfo.name;
      } else if (Platform.isMacOS) {
        final macosInfo = await _deviceInfo.macOsInfo;
        return macosInfo.computerName;
      }
    } catch (e) {
      AppLogger.error('Failed to get device name: $e');
    }

    return 'Unknown Device';
  }

  /// Get device model name (technical identifier)
  Future<String> _getModelName() async {
    if (_cachedModelName != null) {
      return _cachedModelName!;
    }

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.productName;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        return linuxInfo.prettyName;
      } else if (Platform.isMacOS) {
        final macosInfo = await _deviceInfo.macOsInfo;
        return macosInfo.model;
      }
    } catch (e) {
      AppLogger.error('Failed to get model name: $e');
    }

    return 'Unknown Model';
  }

  /// Get device hardware MAC address or unique hardware identifier
  /// This is used as the primary device key identifier
  /// Uses flutter_udid to get consistent device identifier
  Future<String?> getMacAddress() async {
    // Only use cache if it's not null (don't cache failures)
    if (_cachedMacAddress != null && _cachedMacAddress!.isNotEmpty) {
      return _cachedMacAddress;
    }

    try {
      // Primary method: Use FlutterUdid to get consistent device identifier
      String udid = await FlutterUdid.consistentUdid;
      
      if (udid.isNotEmpty) {
        AppLogger.info('Got UDID: $udid');
        
        // Format UDID as MAC address (XX:XX:XX:XX:XX:XX)
        // Take first 12 hex characters from UDID
        final cleaned = udid.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
        
        if (cleaned.length >= 12) {
          final macFormatted = cleaned.substring(0, 12)
              .toUpperCase()
              .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)}:')
              .substring(0, 17); // Remove trailing ':'
          
          AppLogger.info('✓ Hardware MAC (UDID): $macFormatted');
          _cachedMacAddress = macFormatted;
          return macFormatted;
        } else {
          AppLogger.error('UDID too short after cleaning: ${cleaned.length} chars');
        }
      } else {
        AppLogger.error('UDID is empty');
      }
      
      // Fallback 1: Try Android ID (for Android devices)
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final androidId = androidInfo.id;
        
        if (androidId.isNotEmpty) {
          AppLogger.info('Fallback to Android ID: $androidId');
          
          final cleaned = androidId.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
          
          if (cleaned.length >= 12) {
            final macFormatted = cleaned.substring(0, 12)
                .toUpperCase()
                .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)}:')
                .substring(0, 17);
            
            AppLogger.info('✓ Hardware MAC (Android ID): $macFormatted');
            _cachedMacAddress = macFormatted;
            return macFormatted;
          }
        }
      }
      
      // Fallback 2: Try WiFi BSSID (validate it's not a router MAC)
      try {
        final wifiBSSID = await _networkInfo.getWifiBSSID();
        
        if (wifiBSSID != null && 
            wifiBSSID.isNotEmpty && 
            wifiBSSID != '02:00:00:00:00:00' && 
            !wifiBSSID.startsWith('192.168.') &&
            !wifiBSSID.startsWith('10.') &&
            !wifiBSSID.startsWith('172.')) {
          AppLogger.info('✓ Wi-Fi BSSID: $wifiBSSID');
          _cachedMacAddress = wifiBSSID;
          return wifiBSSID;
        }
      } catch (e) {
        AppLogger.error('WiFi BSSID failed: $e');
      }
      
      AppLogger.error('❌ All MAC extraction methods failed');
      return null;
      
    } catch (e) {
      AppLogger.error('Failed to get hardware MAC: $e');
      return null;
    }
  }

  /// Generate a simple UUID (without external package)
  String _generateUuid() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString().split('').reversed.join();
    return 'device-$timestamp-$random';
  }

  /// Clear cached values (for testing)
  void clearCache() {
    _cachedDeviceId = null;
    _cachedDeviceName = null;
    _cachedModelName = null;
    _cachedMacAddress = null;
  }

  /// Get cached device ID (if available)
  String? get deviceId => _cachedDeviceId;
}
