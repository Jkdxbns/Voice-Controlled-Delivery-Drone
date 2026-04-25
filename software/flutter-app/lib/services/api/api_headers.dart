import '../device/device_info_service.dart';
import '../../utils/app_logger.dart';

/// Helper to create HTTP headers with device information for auto-registration
class ApiHeaders {
  static bool _hasLoggedHeaders = false;
  
  /// Get standard headers including device information for automatic tracking
  /// 
  /// Includes:
  /// - X-Device-Id: Unique device identifier (UUID)
  /// - X-Device-Name: Human-readable device name
  /// - X-Device-Model: Device model identifier
  /// - X-Device-MAC: Wi-Fi MAC address (if available)
  static Future<Map<String, String>> getHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = <String, String>{
      ...?additionalHeaders,
    };

    // Get device information
    final deviceInfo = await DeviceInfoService.instance.getDeviceInfo();
    
    // Add device headers for auto-registration
    headers['X-Device-Id'] = deviceInfo.deviceId;
    headers['X-Device-Name'] = deviceInfo.deviceName;
    headers['X-Device-Model'] = deviceInfo.modelName;
    
    // Add MAC address if available
    if (deviceInfo.macAddress != null && deviceInfo.macAddress!.isNotEmpty) {
      headers['X-Device-MAC'] = deviceInfo.macAddress!;
      
      // Only log once to reduce noise
      if (!_hasLoggedHeaders) {
        _hasLoggedHeaders = true;
        AppLogger.info('✅ API Headers with MAC:');
        AppLogger.info('  X-Device-Id: ${deviceInfo.deviceId}');
        AppLogger.info('  X-Device-Name: ${deviceInfo.deviceName}');
        AppLogger.info('  X-Device-Model: ${deviceInfo.modelName}');
        AppLogger.info('  X-Device-MAC: ${deviceInfo.macAddress}');
      }
    } else if (!_hasLoggedHeaders) {
      _hasLoggedHeaders = true;
      AppLogger.error('⚠️ NO MAC ADDRESS - Device will use device_id fallback');
      AppLogger.info('API Headers WITHOUT MAC:');
      AppLogger.info('  X-Device-Id: ${deviceInfo.deviceId}');
      AppLogger.info('  X-Device-Name: ${deviceInfo.deviceName}');
      AppLogger.info('  X-Device-Model: ${deviceInfo.modelName}');
    }

    return headers;
  }

  /// Get headers with Content-Type: application/json
  static Future<Map<String, String>> getJsonHeaders() async {
    return getHeaders(additionalHeaders: {
      'Content-Type': 'application/json',
    });
  }
}
