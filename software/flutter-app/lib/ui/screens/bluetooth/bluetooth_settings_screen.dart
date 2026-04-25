import 'package:flutter/material.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_typography.dart';
import '../../../models/bluetooth_settings.dart';
import '../../../models/unified_bluetooth_device.dart';
import '../../../services/bluetooth/unified_bluetooth_service.dart';
import '../../../services/bluetooth/bluetooth_settings_service.dart';
import '../../../utils/app_logger.dart';

class BluetoothSettingsScreen extends StatefulWidget {
  const BluetoothSettingsScreen({super.key});

  @override
  State<BluetoothSettingsScreen> createState() => _BluetoothSettingsScreenState();
}

class _BluetoothSettingsScreenState extends State<BluetoothSettingsScreen> {
  final _unifiedService = UnifiedBluetoothService.instance;
  final _settingsService = BluetoothSettingsService.instance;
  
  BluetoothSettings _globalSettings = const BluetoothSettings();
  BluetoothSettings _currentSettings = const BluetoothSettings();
  List<UnifiedBluetoothDevice> _savedDevices = [];
  String _selectedTarget = 'Global'; // 'Global' or device ID
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Service is already initialized by AppInitializationService
      // (initialize() is idempotent so this is safe)
      await _settingsService.initialize();
      
      // Load saved devices
      _savedDevices = await _unifiedService.getSavedDevices();
      
      // Load global settings from database
      _globalSettings = await _settingsService.getGlobalSettings();
      
      // If device selected, load device-specific settings
      if (_selectedTarget != 'Global') {
        // Load device-specific overrides or use global
        final deviceSettings = await _settingsService.getDeviceSettings(_selectedTarget);
        _currentSettings = deviceSettings ?? _globalSettings;
      } else {
        _currentSettings = _globalSettings;
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('Failed to load settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      if (_selectedTarget == 'Global') {
        // Save global settings to database
        await _settingsService.saveGlobalSettings(_currentSettings);
        _globalSettings = _currentSettings;
        AppLogger.showToast('Global settings saved');
      } else {
        // Save device-specific overrides
        await _settingsService.saveDeviceSettings(_selectedTarget, _currentSettings);
        AppLogger.showToast('Device settings saved');
      }
    } catch (e) {
      AppLogger.error('Failed to save settings: $e');
      AppLogger.showToast('Failed to save settings', isError: true);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: Text(_selectedTarget == 'Global'
            ? 'Reset global settings to defaults?'
            : 'Reset device settings to use global settings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_selectedTarget == 'Global') {
        // Reset to factory defaults
        await _settingsService.resetGlobalToDefaults();
        _globalSettings = const BluetoothSettings();
        _currentSettings = const BluetoothSettings();
        AppLogger.showToast('Reset to default settings');
      } else {
        // Remove device overrides (revert to global)
        await _settingsService.deleteDeviceSettings(_selectedTarget);
        _currentSettings = _globalSettings;
        AppLogger.showToast('Reset to global settings');
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          // Target selector dropdown
          _buildTargetSelector(),
          
          const Divider(height: 1),
          
          // Settings content
          Expanded(
            child: Scrollbar(
              child: ListView(
                primary: false,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildConnectionSettings(),
                  const SizedBox(height: 24),
                  _buildClassicBluetoothSettings(),
                  const SizedBox(height: 24),
                  _buildBleSettings(),
                  const SizedBox(height: 24),
                  _buildMessageFormattingSettings(),
                  const SizedBox(height: 24),
                  _buildDisplaySettings(),
                  const SizedBox(height: 24),
                  _buildAdvancedSettings(),
                  const SizedBox(height: 24),
                  _buildNotificationSettings(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Colors.blue, size: ComponentSize.iconSmall),
          const SizedBox(width: 6),
          const Text(
            'Apply To:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: FontSize.small),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedTarget,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'Global',
                  child: Text('🌐 Global (All Devices)', style: TextStyle(fontSize: FontSize.small)),
                ),
                ..._savedDevices.map((device) {
                  return DropdownMenuItem(
                    value: device.id,
                    child: Text(
                      '${device.typeBadge} ${device.displayName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: FontSize.small),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTarget = value;
                  });
                  _loadData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: ComponentSize.iconSmall, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: FontSize.large,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Connection Settings', Icons.link),
        _buildToggleSetting(
          'Auto-Reconnect',
          _currentSettings.autoReconnect,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(autoReconnect: value);
          }),
        ),
        _buildSliderSetting(
          'Connection Timeout',
          _currentSettings.connectionTimeout.toDouble(),
          5, 60, 'seconds',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(connectionTimeout: value.toInt());
          }),
        ),
        _buildSliderSetting(
          'Reconnect Attempts',
          _currentSettings.reconnectAttempts.toDouble(),
          0, 10, 'attempts',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(reconnectAttempts: value.toInt());
          }),
        ),
        _buildSliderSetting(
          'Reconnect Delay',
          _currentSettings.reconnectDelay.toDouble(),
          1, 10, 'seconds',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(reconnectDelay: value.toInt());
          }),
        ),
        _buildSliderSetting(
          'Keep-Alive Interval',
          _currentSettings.keepAliveInterval.toDouble(),
          0, 60, 'seconds (0=off)',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(keepAliveInterval: value.toInt());
          }),
        ),
      ],
    );
  }

  Widget _buildClassicBluetoothSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Classic Bluetooth (HC-05/HC-06)', Icons.bluetooth),
        _buildDropdownSetting<int>(
          'Baud Rate',
          _currentSettings.baudRate,
          [9600, 19200, 38400, 57600, 115200],
          (value) => value.toString(),
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(baudRate: value);
          }),
        ),
        _buildDropdownSetting<int>(
          'Data Bits',
          _currentSettings.dataBits,
          [7, 8],
          (value) => value.toString(),
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(dataBits: value);
          }),
        ),
        _buildDropdownSetting<int>(
          'Stop Bits',
          _currentSettings.stopBits,
          [1, 2],
          (value) => value.toString(),
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(stopBits: value);
          }),
        ),
        _buildDropdownSetting<ParityType>(
          'Parity',
          _currentSettings.parity,
          ParityType.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(parity: value);
          }),
        ),
        _buildSliderSetting(
          'Buffer Size',
          _currentSettings.bufferSize.toDouble(),
          512, 8192, 'bytes',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(bufferSize: value.toInt());
          }),
          divisions: 15,
        ),
        _buildDropdownSetting<FlowControlType>(
          'Flow Control',
          _currentSettings.flowControl,
          FlowControlType.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(flowControl: value);
          }),
        ),
      ],
    );
  }

  Widget _buildBleSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('BLE Settings (HM-10, Nordic)', Icons.bluetooth_connected),
        _buildSliderSetting(
          'MTU Size',
          _currentSettings.mtuSize.toDouble(),
          23, 517, 'bytes',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(mtuSize: value.toInt());
          }),
          divisions: 49,
        ),
        _buildTextSetting(
          'Service UUID',
          _currentSettings.serviceUuid,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(serviceUuid: value);
          }),
        ),
        _buildTextSetting(
          'RX Characteristic UUID',
          _currentSettings.rxCharacteristicUuid,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(rxCharacteristicUuid: value);
          }),
        ),
        _buildTextSetting(
          'TX Characteristic UUID',
          _currentSettings.txCharacteristicUuid,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(txCharacteristicUuid: value);
          }),
        ),
        _buildDropdownSetting<BleConnectionPriority>(
          'Connection Priority',
          _currentSettings.bleConnectionPriority,
          BleConnectionPriority.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(bleConnectionPriority: value);
          }),
        ),
      ],
    );
  }

  Widget _buildMessageFormattingSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Message Formatting', Icons.edit),
        _buildDropdownSetting<LineEnding>(
          'Line Ending',
          _currentSettings.lineEnding,
          LineEnding.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(lineEnding: value);
          }),
        ),
        _buildTextSetting(
          'Auto-Prefix',
          _currentSettings.autoPrefix,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(autoPrefix: value);
          }),
          hint: 'Text added before every message',
        ),
        _buildTextSetting(
          'Auto-Suffix',
          _currentSettings.autoSuffix,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(autoSuffix: value);
          }),
          hint: 'Text added after every message',
        ),
        _buildDropdownSetting<TextEncoding>(
          'Encoding',
          _currentSettings.encoding,
          TextEncoding.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(encoding: value);
          }),
        ),
        _buildToggleSetting(
          'Trim Whitespace',
          _currentSettings.trimWhitespace,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(trimWhitespace: value);
          }),
        ),
      ],
    );
  }

  Widget _buildDisplaySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Display & Logging', Icons.display_settings),
        _buildDropdownSetting<DisplayFormat>(
          'Display Format',
          _currentSettings.displayFormat,
          DisplayFormat.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(displayFormat: value);
          }),
        ),
        _buildDropdownSetting<TimestampFormat>(
          'Timestamp Format',
          _currentSettings.timestampFormat,
          TimestampFormat.values,
          (value) => value.label,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(timestampFormat: value);
          }),
        ),
        _buildSliderSetting(
          'Max Message History',
          _currentSettings.maxMessageHistory.toDouble(),
          50, 1000, 'messages',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(maxMessageHistory: value.toInt());
          }),
          divisions: 19,
        ),
        _buildToggleSetting(
          'Auto-Scroll',
          _currentSettings.autoScroll,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(autoScroll: value);
          }),
        ),
        _buildToggleSetting(
          'Local Echo',
          _currentSettings.localEcho,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(localEcho: value);
          }),
        ),
        _buildToggleSetting(
          'Enable Logging',
          _currentSettings.enableLogging,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(enableLogging: value);
          }),
        ),
      ],
    );
  }

  Widget _buildAdvancedSettings() {
    return ExpansionTile(
      leading: const Icon(Icons.tune, color: Colors.blue),
      title: const Text(
        'Advanced Settings',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      ),
      children: [
        _buildToggleSetting(
          'Packet Chunking',
          _currentSettings.packetChunking,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(packetChunking: value);
          }),
        ),
        _buildSliderSetting(
          'Chunk Size',
          _currentSettings.chunkSize.toDouble(),
          20, 512, 'bytes',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(chunkSize: value.toInt());
          }),
        ),
        _buildSliderSetting(
          'Chunk Delay',
          _currentSettings.chunkDelay.toDouble(),
          0, 500, 'ms',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(chunkDelay: value.toInt());
          }),
          divisions: 50,
        ),
        _buildToggleSetting(
          'Discard Invalid UTF-8',
          _currentSettings.discardInvalidUtf8,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(discardInvalidUtf8: value);
          }),
        ),
        _buildSliderSetting(
          'Scan Duration',
          _currentSettings.scanDuration.toDouble(),
          5, 60, 'seconds',
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(scanDuration: value.toInt());
          }),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications & Alerts', Icons.notifications),
        _buildToggleSetting(
          'Connection Sound',
          _currentSettings.connectionSound,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(connectionSound: value);
          }),
        ),
        _buildToggleSetting(
          'Message Sound',
          _currentSettings.messageSound,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(messageSound: value);
          }),
        ),
        _buildToggleSetting(
          'Vibrate on Message',
          _currentSettings.vibrateOnMessage,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(vibrateOnMessage: value);
          }),
        ),
        _buildToggleSetting(
          'Show Toast Notifications',
          _currentSettings.showToastNotifications,
          (value) => setState(() {
            _currentSettings = _currentSettings.copyWith(showToastNotifications: value);
          }),
        ),
      ],
    );
  }

  Widget _buildToggleSetting(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildSliderSetting(
    String label,
    double value,
    double min,
    double max,
    String unit,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: FontSize.medium)),
              Text(
                '${value.toInt()} $unit',
                style: const TextStyle(fontSize: FontSize.medium, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).toInt(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting<T>(
    String label,
    T value,
    List<T> options,
    String Function(T) labelBuilder,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: FontSize.medium)),
          ),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<T>(
              initialValue: value,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(labelBuilder(option), style: const TextStyle(fontSize: FontSize.smallPlus)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextSetting(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: FontSize.medium, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: const OutlineInputBorder(),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Apply Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore),
            label: const Text('Reset Defaults'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
