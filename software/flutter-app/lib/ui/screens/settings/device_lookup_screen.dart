import 'package:flutter/material.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_typography.dart';
import '../../../services/api/device_registration_api_service.dart';
import '../../../services/server/server_config_service.dart';
import '../../../utils/app_logger.dart';
import '../../../core/utils/formatters/datetime_formatters.dart';

/// Device Lookup Screen
/// Displays all registered devices from the server in a tabulated format
class DeviceLookupScreen extends StatefulWidget {
  const DeviceLookupScreen({super.key});

  @override
  State<DeviceLookupScreen> createState() => _DeviceLookupScreenState();
}

class _DeviceLookupScreenState extends State<DeviceLookupScreen> {
  List<Map<String, dynamic>>? _devices;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadDevices();
  }

  // Public method so it can be called from main.dart via GlobalKey
  Future<void> loadDevices() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = DeviceRegistrationApiService(
        baseUrl: ServerConfigService.instance.baseUrl,
      );

      final devices = await service.getDeviceList();

      if (!mounted) return;

      if (devices != null) {
        // Parse stats from first device's metadata if available
        // Or make a separate stats call
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
        AppLogger.success('Loaded ${devices.length} devices');
      } else {
        setState(() {
          _errorMessage = 'Failed to load devices from server';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      AppLogger.error('Failed to load devices: $e');
    }
  }

  Future<void> _showEditNameDialog(Map<String, dynamic> device) async {
    // Use MAC address as identifier (server uses MAC as primary key)
    final macAddress = device['mac_address'] as String?;
    final deviceId = device['device_id'] as String?;
    
    // Need either MAC or device_id to identify device
    if (macAddress == null && deviceId == null) {
      AppLogger.error('Cannot edit device: missing mac_address and device_id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot identify device'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Prefer MAC address, fallback to device_id
    final identifier = macAddress ?? deviceId!;

    final currentName = device['custom_name'] as String? ?? 
                        device['device_name'] as String? ?? 
                        '';

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _EditDeviceNameDialog(
          deviceName: currentName,
          modelName: device['model_name'] as String? ?? 'Unknown',
          hasCustomName: device['has_custom_name'] == true,
        );
      },
    );

    // Handle result
    if (result != null && mounted) {
      if (result == '__CLEAR__') {
        await _clearDeviceName(identifier);
      } else if (result.isNotEmpty) {
        await _updateDeviceName(identifier, result);
      }
    }
  }

  Future<void> _updateDeviceName(String identifier, String customName) async {
    try {
      AppLogger.info('=== UPDATE DEVICE NAME START ===');
      AppLogger.info('Identifier: $identifier');
      AppLogger.info('Custom name: $customName');
      
      final service = DeviceRegistrationApiService(
        baseUrl: ServerConfigService.instance.baseUrl,
      );

      final success = await service.updateDeviceName(identifier, customName);

      if (success) {
        AppLogger.success('=== UPDATE SUCCESS ===');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Updated to: $customName'),
              backgroundColor: Colors.green,
            ),
          );
          // Small delay to let UI settle before refreshing
          await Future.delayed(const Duration(milliseconds: 300));
          // Refresh device list only if still mounted
          if (mounted) {
            await loadDevices();
          }
        }
      } else {
        AppLogger.error('=== UPDATE FAILED ===');
        throw Exception('Server rejected the update. Check server logs for details.');
      }
    } catch (e) {
      AppLogger.error('=== UPDATE EXCEPTION ===');
      AppLogger.error('Error: $e');
      if (mounted) {
        // More user-friendly error message
        String errorMsg = 'Failed to update device name';
        if (e.toString().contains('not found')) {
          errorMsg = 'Device not found on server. Try refreshing the device list.';
        } else if (e.toString().contains('rejected')) {
          errorMsg = 'Server rejected the update. Please check server logs.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: loadDevices,
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearDeviceName(String identifier) async {
    try {
      AppLogger.info('Clearing device name: identifier=$identifier');
      
      final service = DeviceRegistrationApiService(
        baseUrl: ServerConfigService.instance.baseUrl,
      );

      final success = await service.clearDeviceName(identifier);

      if (success) {
        AppLogger.success('Device name reset to auto-detected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device name reset to auto-detected'),
              backgroundColor: Colors.green,
            ),
          );
          // Small delay to let UI settle before refreshing
          await Future.delayed(const Duration(milliseconds: 300));
          // Refresh device list only if still mounted
          if (mounted) {
            await loadDevices();
          }
        }
      } else {
        throw Exception('Server returned false - clear failed');
      }
    } catch (e) {
      AppLogger.error('Failed to reset device name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _buildBody(theme);
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading devices...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loadDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_devices == null || _devices!.isEmpty) {
      // Show empty table with headers instead of "no devices" message
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatsCard(theme),
          Expanded(
            child: SingleChildScrollView(
              primary: false, // Don't use PrimaryScrollController
              child: _buildEmptyDeviceTable(theme),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Stats Card
        _buildStatsCard(theme),
        const SizedBox(height: 8),
        // Device Table
        Expanded(
          child: _buildDeviceTable(theme),
        ),
      ],
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final onlineCount = _devices?.where((d) => d['status'] == 'online').length ?? 0;
    final offlineCount = _devices?.where((d) => d['status'] == 'offline').length ?? 0;
    final totalCount = _devices?.length ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.devices,
              label: 'Total',
              value: totalCount.toString(),
              color: theme.colorScheme.primary,
            ),
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Online',
              value: onlineCount.toString(),
              color: Colors.green,
            ),
            _buildStatItem(
              icon: Icons.cancel,
              label: 'Offline',
              value: offlineCount.toString(),
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: ComponentSize.iconLarge),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: FontSize.xxlarge,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: FontSize.small, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDeviceTable(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      primary: false, // Don't use PrimaryScrollController
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(
          primary: false, // Don't use PrimaryScrollController
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            columnSpacing: 24,
            horizontalMargin: 16,
            columns: const [
              DataColumn(
                label: Text(
                  'Device Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Model',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'IP / Parent Device',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'MAC Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Last Seen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: _devices!.map((device) {
              final status = device['status'] as String? ?? 'unknown';
              final isOnline = status == 'online';
              final lastSeen = device['last_seen'] as String?;
              final ipAddress = device['ip_address'] as String? ?? 'N/A';
              final modelName = device['model_name'] as String? ?? 'N/A';
              
              // Detect if this is a Bluetooth device
              // Bluetooth devices have parent phone model in IP field (e.g., "SM-A356E")
              final isBluetoothDevice = modelName.contains('Bluetooth') || 
                                        modelName.contains('BLE');

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            device['custom_name'] as String? ?? 
                            device['device_name'] as String? ?? 
                            'Unknown',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Show small badge if custom name is set
                        if (device['has_custom_name'] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.label,
                              size: 12,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      modelName,
                      style: const TextStyle(fontSize: FontSize.small),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          isBluetoothDevice ? Icons.smartphone : Icons.router,
                          size: 14,
                          color: isBluetoothDevice ? Colors.purple : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: isBluetoothDevice 
                            ? 'Parent phone model' 
                            : 'IP Address',
                          child: Text(
                            ipAddress,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: FontSize.small,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      device['mac_address'] as String? ?? 'N/A',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: FontSize.xsmallPlus,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: FontSize.xsmallPlus,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      lastSeen != null
                          ? DateTimeFormatters.formatMessageTime(
                              DateTime.parse(lastSeen),
                            )
                          : 'N/A',
                      style: const TextStyle(fontSize: FontSize.small),
                    ),
                  ),
                  // Actions column - edit button
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit, size: ComponentSize.iconSmall),
                      tooltip: 'Edit device name',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditNameDialog(device),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDeviceTable(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              columns: const [
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Device Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Model',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'IP / Parent Device',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'MAC Address',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Last Seen',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: const [],
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.devices_other,
              size: ComponentSize.iconXLarge,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No devices registered yet',
              style: TextStyle(fontSize: FontSize.large, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Make any API request from your device\nand it will appear here automatically',
              style: TextStyle(fontSize: FontSize.medium, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Separate stateful dialog for editing device names
/// Isolated to prevent context/lifecycle issues with parent screen
class _EditDeviceNameDialog extends StatefulWidget {
  final String deviceName;
  final String modelName;
  final bool hasCustomName;

  const _EditDeviceNameDialog({
    required this.deviceName,
    required this.modelName,
    required this.hasCustomName,
  });

  @override
  State<_EditDeviceNameDialog> createState() => _EditDeviceNameDialogState();
}

class _EditDeviceNameDialogState extends State<_EditDeviceNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.deviceName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Device Name'),
      content: SingleChildScrollView(
        primary: false, // Don't use PrimaryScrollController
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device: ${widget.modelName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'Enter custom name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (mounted) {
                  Navigator.of(context).pop(value);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty to use auto-detected name',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) {
              Navigator.of(context).pop(null);
            }
          },
          child: const Text('Cancel'),
        ),
        if (widget.hasCustomName)
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop('__CLEAR__');
              }
            },
            child: const Text('Reset to Auto'),
          ),
        FilledButton(
          onPressed: () {
            if (mounted) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
