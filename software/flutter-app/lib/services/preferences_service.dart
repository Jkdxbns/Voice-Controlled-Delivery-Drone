import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service for managing user preferences and settings
/// All app settings are persisted to device storage using SharedPreferences
/// 
/// Note: SharedPreferences is designed to run on the main thread:
/// - First load reads from disk (async, non-blocking)
/// - After that, all reads are from memory cache (instant)
/// - All writes are async and non-blocking
/// - Cannot be shared across isolates (each isolate has separate memory)
class PreferencesService {
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  // ValueNotifiers for reactive model selection
  final ValueNotifier<String> defaultSttModelNotifier = ValueNotifier<String>('small');
  final ValueNotifier<String> defaultLmModelNotifier = ValueNotifier<String>('gemini-2.5-flash');

  // Private constructor
  PreferencesService._();

  /// Get singleton instance
  static PreferencesService get instance {
    _instance ??= PreferencesService._();
    return _instance!;
  }

  /// Initialize the preferences service
  /// Must be called before using any other methods
  /// Returns true if initialization was successful
  static Future<bool> init() async {
    if (_prefs != null) {
      // Already initialized, just reload values
      _loadNotifierValues();
      return true;
    }
    
    try {
      // Initialize SharedPreferences with error handling
      _prefs = await SharedPreferences.getInstance();
      
      // Migrate old model names to new format (awaited to ensure completion)
      await _migrateModelNames();
      
      // Load model preferences into notifiers
      _loadNotifierValues();
      
      AppLogger.success('PreferencesService initialized');
      return true;
    } catch (e) {
      AppLogger.error('Failed to initialize SharedPreferences: $e');
      return false;
    }
  }
  
  /// Load values into ValueNotifiers for reactive updates
  static void _loadNotifierValues() {
    final sttModel = _prefs?.getString(_keyDefaultSttModel) ?? 'small';
    final lmModel = _prefs?.getString(_keyDefaultLmModel) ?? 'gemini-2.5-flash';
    instance.defaultSttModelNotifier.value = sttModel;
    instance.defaultLmModelNotifier.value = lmModel;
  }

  /// Migrate old model names (whisper-small → small)
  static Future<void> _migrateModelNames() async {
    if (_prefs == null) return;
    
    // Migrate STT model name
    final oldSttModel = _prefs!.getString(_keyDefaultSttModel);
    if (oldSttModel != null && oldSttModel.startsWith('whisper-')) {
      // Convert "whisper-small" → "small"
      final newSttModel = oldSttModel.replaceFirst('whisper-', '');
      await _prefs!.setString(_keyDefaultSttModel, newSttModel);  // Now properly awaited
      AppLogger.info('Migrated STT model: $oldSttModel → $newSttModel');
    }
    
    // LM models don't need migration (already use correct format)
  }
  
  /// Ensure preferences are initialized before use
  /// Call this if you need to guarantee initialization
  static void _ensureInitialized() {
    if (_prefs == null) {
      AppLogger.warning('PreferencesService accessed before initialization');
    }
  }

  // Preference Keys
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAllowCellular = 'allow_cellular_download';
  static const String _keyMicPermissionAsked = 'mic_permission_asked';
  static const String _keyWifiPermissionAsked = 'wifi_permission_asked';
  static const String _keyDeviceId = 'device_id';
  static const String _keyTtsEnabled = 'tts_enabled';
  static const String _keyTtsSpeed = 'tts_speed';
  static const String _keyTtsPitch = 'tts_pitch';
  static const String _keyTtsVolume = 'tts_volume';
  static const String _keyServerHost = 'server_host';
  static const String _keyServerPort = 'server_port';
  static const String _keyDefaultSttModel = 'default_stt_model';
  static const String _keyDefaultLmModel = 'default_lm_model';
  static const String _keySharedFolderUri = 'shared_folder_uri';

  // Theme Settings
  bool get isDarkMode {
    _ensureInitialized();
    return _prefs?.getBool(_keyThemeMode) ?? false;
  }
  
  Future<bool> setDarkMode(bool value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save dark mode - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setBool(_keyThemeMode, value);
  }

  // Download Settings
  bool get allowCellularDownload {
    _ensureInitialized();
    return _prefs?.getBool(_keyAllowCellular) ?? false;
  }
  
  Future<bool> setAllowCellularDownload(bool value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save cellular setting - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setBool(_keyAllowCellular, value);
  }

  // Permission Settings
  bool get micPermissionAsked {
    _ensureInitialized();
    return _prefs?.getBool(_keyMicPermissionAsked) ?? false;
  }
  
  Future<bool> setMicPermissionAsked(bool value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save mic permission flag - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setBool(_keyMicPermissionAsked, value);
  }

  bool get wifiPermissionAsked {
    _ensureInitialized();
    return _prefs?.getBool(_keyWifiPermissionAsked) ?? false;
  }
  
  Future<bool> setWifiPermissionAsked(bool value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save wifi permission flag - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setBool(_keyWifiPermissionAsked, value);
  }

  // Device ID
  String? get deviceId {
    _ensureInitialized();
    return _prefs?.getString(_keyDeviceId);
  }
  
  Future<bool> setDeviceId(String value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save device ID - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setString(_keyDeviceId, value);
  }

  // TTS Settings
  bool get ttsEnabled {
    _ensureInitialized();
    return _prefs?.getBool(_keyTtsEnabled) ?? true;
  }
  
  Future<bool> setTtsEnabled(bool value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save TTS enabled - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setBool(_keyTtsEnabled, value);
  }

  double get ttsSpeed {
    _ensureInitialized();
    return _prefs?.getDouble(_keyTtsSpeed) ?? 0.5;
  }
  
  Future<bool> setTtsSpeed(double value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save TTS speed - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setDouble(_keyTtsSpeed, value);
  }

  double get ttsPitch {
    _ensureInitialized();
    return _prefs?.getDouble(_keyTtsPitch) ?? 1.0;
  }
  
  Future<bool> setTtsPitch(double value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save TTS pitch - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setDouble(_keyTtsPitch, value);
  }

  double get ttsVolume {
    _ensureInitialized();
    return _prefs?.getDouble(_keyTtsVolume) ?? 0.8;
  }
  
  Future<bool> setTtsVolume(double value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save TTS volume - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setDouble(_keyTtsVolume, value);
  }

  // Shared Folder (Storage Access Framework)
  String? get sharedFolderUri {
    _ensureInitialized();
    return _prefs?.getString(_keySharedFolderUri);
  }

  Future<bool> setSharedFolderUri(String uri) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save shared folder URI - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setString(_keySharedFolderUri, uri);
  }

  // Server Configuration
  String get serverHost {
    _ensureInitialized();
    return _prefs?.getString(_keyServerHost) ?? '192.168.0.168';
  }
  
  Future<bool> setServerHost(String value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save server host - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setString(_keyServerHost, value);
  }

  int get serverPort {
    _ensureInitialized();
    return _prefs?.getInt(_keyServerPort) ?? 5000;
  }
  
  Future<bool> setServerPort(int value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save server port - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.setInt(_keyServerPort, value);
  }

  // Model Selection - Server Models Only
  String get defaultSttModel => defaultSttModelNotifier.value;
  
  Future<bool> setDefaultSttModel(String value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save STT model - PreferencesService not initialized');
      return false;
    }
    AppLogger.info('Saving STT model: $value');
    final success = await _prefs!.setString(_keyDefaultSttModel, value);
    if (success) {
      defaultSttModelNotifier.value = value;
      AppLogger.success('STT model saved: $value');
    }
    return success;
  }

  String get defaultLmModel => defaultLmModelNotifier.value;
  
  Future<bool> setDefaultLmModel(String value) async {
    if (_prefs == null) {
      AppLogger.error('Cannot save LM model - PreferencesService not initialized');
      return false;
    }
    AppLogger.info('Saving LM model: $value');
    final success = await _prefs!.setString(_keyDefaultLmModel, value);
    if (success) {
      defaultLmModelNotifier.value = value;
      AppLogger.success('LM model saved: $value');
    }
    return success;
  }

  /// Clear all preferences (useful for reset/logout)
  Future<bool> clearAll() async {
    if (_prefs == null) {
      AppLogger.error('Cannot clear preferences - PreferencesService not initialized');
      return false;
    }
    return await _prefs!.clear();
  }

  /// Check if preferences have been initialized
  static bool get isInitialized => _prefs != null;
}
