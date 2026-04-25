import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_typography.dart';
import '../../../models/ble_device_config.dart';
import '../../../services/ble/ble_service.dart';
import '../../../services/ble/ble_device_manager.dart';
import '../../../utils/app_logger.dart';

class BleScannerScreen extends StatefulWidget {
  const BleScannerScreen({super.key});

  @override
  State<BleScannerScreen> createState() => _BleScannerScreenState();
}

class _BleScannerScreenState extends State<BleScannerScreen> {
  final BleService _bleService = BleService.instance;
  final BleDeviceManager _deviceManager = BleDeviceManager.instance;
  
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  final List<BleDeviceConfig> _savedDevices = [];
  BleDeviceConfig? _selectedDevice;
  bool _isScanning = false;
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanStateSubscription;
  
  // Configuration controllers
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _serviceUuidController = TextEditingController();
  final TextEditingController _characteristicUuidController = TextEditingController();
  bool _autoReconnect = false;
  int _connectionTimeout = 10;
  int _mtu = 512;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
    _setupListeners();
  }

  void _setupListeners() {
    _scanSubscription = _deviceManager.discoveredDevices.listen((device) {
      setState(() {
        _discoveredDevices[device.id] = device;
      });
    });

    _scanStateSubscription = _deviceManager.scanningState.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _bleService.getSavedDevices();
    setState(() {
      _savedDevices.clear();
      _savedDevices.addAll(devices);
    });
  }

  Future<void> _startScan() async {
    try {
      setState(() {
        _discoveredDevices.clear();
      });
      
      await _deviceManager.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      AppLogger.error('Failed to start scan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start scan: $e')),
        );
      }
    }
  }

  void _stopScan() {
    _deviceManager.stopScan();
  }

  void _selectDevice(DiscoveredDevice device) {
    final config = _deviceManager.deviceToBleConfig(device);
    setState(() {
      _selectedDevice = config;
      _aliasController.text = config.customAlias ?? '';
      _serviceUuidController.text = config.serviceUuid ?? HM10Uuids.serviceUuid;
      _characteristicUuidController.text = config.txCharacteristicUuid ?? HM10Uuids.characteristicUuid;
      _autoReconnect = config.autoReconnect;
      _connectionTimeout = config.connectionTimeout;
      _mtu = config.mtu;
    });
  }

  void _selectSavedDevice(BleDeviceConfig device) {
    setState(() {
      _selectedDevice = device;
      _aliasController.text = device.customAlias ?? '';
      _serviceUuidController.text = device.serviceUuid ?? HM10Uuids.serviceUuid;
      _characteristicUuidController.text = device.txCharacteristicUuid ?? HM10Uuids.characteristicUuid;
      _autoReconnect = device.autoReconnect;
      _connectionTimeout = device.connectionTimeout;
      _mtu = device.mtu;
    });
  }

  Future<void> _connectToDevice() async {
    if (_selectedDevice == null) return;

    try {
      final updatedConfig = _selectedDevice!.copyWith(
        customAlias: _aliasController.text.isNotEmpty ? _aliasController.text : null,
        serviceUuid: _serviceUuidController.text,
        txCharacteristicUuid: _characteristicUuidController.text,
        rxCharacteristicUuid: _characteristicUuidController.text,
        autoReconnect: _autoReconnect,
        connectionTimeout: _connectionTimeout,
        mtu: _mtu,
      );

      await _bleService.connectToDevice(updatedConfig);
      await _loadSavedDevices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected successfully')),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to connect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  Future<void> _disconnectFromDevice() async {
    if (_selectedDevice == null) return;

    try {
      await _bleService.disconnectFromDevice(_selectedDevice!.deviceId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected')),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to disconnect: $e');
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    try {
      await _bleService.deleteSavedDevice(deviceId);
      await _loadSavedDevices();
      
      if (_selectedDevice?.deviceId == deviceId) {
        setState(() {
          _selectedDevice = null;
          _aliasController.clear();
        });
      }
    } catch (e) {
      AppLogger.error('Failed to delete device: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: context.dimensions.appBarHeight,
        title: const Text('BLE Scanner (HM-10)'),
        backgroundColor: Colors.blue,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use stacked layout on narrow screens to avoid horizontal overflow
          if (constraints.maxWidth < 700) {
            return SingleChildScrollView(
              primary: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSavedDevicesSectionCompact(),
                  const Divider(height: 1),
                  _buildDiscoveredDevicesSectionCompact(),
                  const Divider(height: 1),
                  SizedBox(
                    height: 500,
                    child: _buildConfigurationPanel(),
                  ),
                ],
              ),
            );
          }

          // Default wide layout (two-column)
          return Row(
            children: [
              // Left panel - Device lists
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildSavedDevicesSection(),
                    const Divider(height: 1),
                    _buildDiscoveredDevicesSection(),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // Right panel - Configuration
              Expanded(
                flex: 3,
                child: _buildConfigurationPanel(),
              ),
            ],
          );
        },
      ),
    );
  }

  // Compact versions for narrow screens
  Widget _buildSavedDevicesSectionCompact() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: const Row(
              children: [
                Icon(Icons.bookmark, size: ComponentSize.iconSmall),
                SizedBox(width: 8),
                Text('Saved Devices', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              primary: false,
              itemCount: _savedDevices.length,
              itemBuilder: (context, index) {
                final device = _savedDevices[index];
                final isConnected = _bleService.connectedDeviceIds.contains(device.deviceId);
                
                return ListTile(
                  leading: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                  title: Text(device.displayName, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${device.deviceId}\nLast: ${device.lastConnectedAt?.toString().substring(0, 16) ?? "Never"}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  isThreeLine: true,
                  selected: _selectedDevice?.deviceId == device.deviceId,
                  onTap: () => _selectSavedDevice(device),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDevice(device.deviceId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDevicesSectionCompact() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green[50],
            child: Row(
              children: [
                const Icon(Icons.search, size: ComponentSize.iconSmall),
                const SizedBox(width: 8),
                const Text('Discovered Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                  label: Text(_isScanning ? 'Stop' : 'Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: _isScanning && _discoveredDevices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    primary: false,
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = _discoveredDevices.values.elementAt(index);
                      
                      return ListTile(
                        leading: const Icon(Icons.bluetooth_searching, color: Colors.blue),
                        title: Text(
                          device.name.isNotEmpty ? device.name : 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${device.id}\nRSSI: ${device.rssi} dBm',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        isThreeLine: true,
                        selected: _selectedDevice?.deviceId == device.id,
                        onTap: () => _selectDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedDevicesSection() {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: const Row(
              children: [
                Icon(Icons.bookmark, size: ComponentSize.iconSmall),
                SizedBox(width: 8),
                Text('Saved Devices', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _savedDevices.length,
              itemBuilder: (context, index) {
                final device = _savedDevices[index];
                final isConnected = _bleService.connectedDeviceIds.contains(device.deviceId);
                
                return ListTile(
                  leading: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                  title: Text(device.displayName, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${device.deviceId}\nLast: ${device.lastConnectedAt?.toString().substring(0, 16) ?? "Never"}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  isThreeLine: true,
                  selected: _selectedDevice?.deviceId == device.deviceId,
                  onTap: () => _selectSavedDevice(device),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDevice(device.deviceId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDevicesSection() {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green[50],
            child: Row(
              children: [
                const Icon(Icons.search, size: ComponentSize.iconSmall),
                const SizedBox(width: 8),
                const Text('Discovered Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                  label: Text(_isScanning ? 'Stop' : 'Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isScanning && _discoveredDevices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = _discoveredDevices.values.elementAt(index);
                      
                      return ListTile(
                        leading: const Icon(Icons.bluetooth_searching, color: Colors.blue),
                        title: Text(
                          device.name.isNotEmpty ? device.name : 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${device.id}\nRSSI: ${device.rssi} dBm',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        isThreeLine: true,
                        selected: _selectedDevice?.deviceId == device.id,
                        onTap: () => _selectDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    if (_selectedDevice == null) {
      return const Center(
        child: Text(
          'Select a device to configure',
          style: TextStyle(fontSize: FontSize.large, color: Colors.grey),
        ),
      );
    }

    final connectionInfo = _bleService.getConnectionInfo(_selectedDevice!.deviceId);
    final isConnected = connectionInfo?.state == BleConnectionState.connected;

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedDevice!.displayName,
            style: const TextStyle(fontSize: FontSize.xlargePlus, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'ID: ${_selectedDevice!.deviceId}',
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          
          // Status indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.cancel,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Configuration form
          TextField(
            controller: _aliasController,
            decoration: const InputDecoration(
              labelText: 'Custom Alias',
              border: OutlineInputBorder(),
              hintText: 'My HM-10 Module',
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _serviceUuidController,
            decoration: const InputDecoration(
              labelText: 'Service UUID',
              border: OutlineInputBorder(),
              hintText: 'FFE0',
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _characteristicUuidController,
            decoration: const InputDecoration(
              labelText: 'Characteristic UUID',
              border: OutlineInputBorder(),
              hintText: 'FFE1',
            ),
          ),
          const SizedBox(height: 16),

          // Connection timeout
          Row(
            children: [
              const Text('Connection Timeout: '),
              const Spacer(),
              DropdownButton<int>(
                value: _connectionTimeout,
                items: [5, 10, 15, 20, 30].map((sec) {
                  return DropdownMenuItem(value: sec, child: Text('$sec s'));
                }).toList(),
                onChanged: (value) => setState(() => _connectionTimeout = value!),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // MTU
          Row(
            children: [
              const Text('MTU: '),
              const Spacer(),
              DropdownButton<int>(
                value: _mtu,
                items: [23, 185, 247, 512].map((size) {
                  return DropdownMenuItem(value: size, child: Text('$size bytes'));
                }).toList(),
                onChanged: (value) => setState(() => _mtu = value!),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Auto-reconnect
          SwitchListTile(
            title: const Text('Auto Reconnect'),
            value: _autoReconnect,
            onChanged: (value) => setState(() => _autoReconnect = value),
          ),
          const SizedBox(height: 24),

          // Connect/Disconnect button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isConnected ? _disconnectFromDevice : _connectToDevice,
              icon: Icon(isConnected ? Icons.link_off : Icons.link),
              label: Text(isConnected ? 'Disconnect' : 'Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : Colors.blue,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanStateSubscription?.cancel();
    _aliasController.dispose();
    _serviceUuidController.dispose();
    _characteristicUuidController.dispose();
    super.dispose();
  }
}
