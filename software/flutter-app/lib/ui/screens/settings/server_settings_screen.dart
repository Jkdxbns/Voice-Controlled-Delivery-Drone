import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api/server_api_service.dart';
import '../../../services/server/server_config_service.dart';
import '../../../utils/app_logger.dart';
import '../../../constants/constants.dart';

/// Server settings screen
/// Allows users to configure server host and port
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  
  bool _isTesting = false;
  bool? _connectionStatus; // null = not tested, true = success, false = failed
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = ServerConfigService.instance;
    _hostController.text = config.host.value;
    _portController.text = config.port.value.toString();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = null;
      _statusMessage = 'Testing connection...';
    });

    try {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim());

      if (host.isEmpty) {
        setState(() {
          _isTesting = false;
          _connectionStatus = false;
          _statusMessage = 'Host cannot be empty';
        });
        return;
      }

      if (port == null || port <= 0 || port > 65535) {
        setState(() {
          _isTesting = false;
          _connectionStatus = false;
          _statusMessage = 'Invalid port number (1-65535)';
        });
        return;
      }

      final testUrl = 'http://$host:$port';
      final apiService = ServerApiService(baseUrl: testUrl);
      
      final isHealthy = await apiService.checkHealth();

      setState(() {
        _isTesting = false;
        _connectionStatus = isHealthy;
        _statusMessage = isHealthy
            ? 'Connection successful!'
            : 'Server is reachable but not healthy';
      });

      AppLogger.info('Connection test: ${_connectionStatus! ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      setState(() {
        _isTesting = false;
        _connectionStatus = false;
        _statusMessage = 'Connection failed: ${e.toString()}';
      });
      AppLogger.error('Connection test error: $e');
    }
  }

  Future<void> _saveConfiguration() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty) {
      _showSnackBar(AppStrings.errorHostEmpty, AppColors.error);
      return;
    }

    if (port == null || port <= 0 || port > 65535) {
      _showSnackBar(AppStrings.errorInvalidPort, AppColors.error);
      return;
    }

    final success = await ServerConfigService.instance.updateServer(host, port);

    if (success) {
      _showSnackBar(AppStrings.statusServerConfigSaved, AppColors.success);
      AppLogger.success('Server config updated: $host:$port');
    } else {
      _showSnackBar(AppStrings.errorSaveFailed, AppColors.error);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset the server configuration to default values:\n\n'
          'Host: 192.168.0.168\n'
          'Port: 5000',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ServerConfigService.instance.resetToDefaults();
      _loadCurrentConfig();
      _showSnackBar(AppStrings.statusResetToDefault, AppColors.info);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    final iconSize = context.iconSize;
    final typography = context.typography;
    final colors = AppColorScheme.of(context);
    
    return Scaffold(
      body: ListView(
        primary: false,
        padding: spacing.all(Spacing.large),
        children: [
          // Configuration Card
          Card(
            elevation: AppElevation.small,
            child: Padding(
              padding: spacing.all(Spacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host field
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Server Host',
                      hintText: 'e.g., 192.168.0.168 or localhost',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.server),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  SizedBox(height: spacing.large),

                  // Port field
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Server Port',
                      hintText: 'e.g., 5000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(AppIcons.wifi),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  SizedBox(height: spacing.large),

                  // Current URL display
                  Container(
                    padding: spacing.all(Spacing.medium),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: dimensions.borderRadiusMedium,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.link,
                          size: iconSize.small,
                          color: colors.textSecondary,
                        ),
                        SizedBox(width: spacing.small),
                        Expanded(
                          child: Text(
                            'http://${_hostController.text.isEmpty ? "host" : _hostController.text}'
                            ':${_portController.text.isEmpty ? "port" : _portController.text}',
                            style: typography.bodySmall.copyWith(
                              fontFamily: FontFamily.monospace,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.large),

                  // Test Connection Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? SizedBox(
                              width: iconSize.small,
                              height: iconSize.small,
                              child: const CircularProgressIndicator(strokeWidth: BorderSize.medium),
                            )
                          : const Icon(AppIcons.wifi),
                      label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                      style: ElevatedButton.styleFrom(
                        padding: spacing.all(Spacing.medium),
                      ),
                    ),
                  ),

                  // Connection status
                  if (_statusMessage != null) ...[
                    SizedBox(height: spacing.medium),
                    Container(
                      padding: spacing.all(Spacing.medium),
                      decoration: BoxDecoration(
                        color: _connectionStatus == null
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : _connectionStatus!
                                ? AppColors.success.withValues(alpha: AppOpacity.subtle)
                                : AppColors.error.withValues(alpha: AppOpacity.subtle),
                        borderRadius: dimensions.borderRadiusMedium,
                        border: Border.all(
                          color: _connectionStatus == null
                              ? Theme.of(context).colorScheme.outline
                              : _connectionStatus!
                                  ? AppColors.success
                                  : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _connectionStatus == null
                                ? AppIcons.infoOutlined
                                : _connectionStatus!
                                    ? AppIcons.checkCircleOutlined
                                    : AppIcons.errorOutlined,
                            color: _connectionStatus == null
                                ? colors.textSecondary
                                : _connectionStatus!
                                    ? AppColors.success
                                    : AppColors.error,
                          ),
                          SizedBox(width: spacing.small),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: typography.bodyMedium.copyWith(
                                color: _connectionStatus == null
                                    ? colors.textSecondary
                                    : _connectionStatus!
                                        ? AppColors.success
                                        : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: spacing.large),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(AppIcons.restore),
                  label: const Text(AppStrings.settingsReset),
                  style: OutlinedButton.styleFrom(
                    padding: spacing.all(Spacing.medium),
                  ),
                ),
              ),
              SizedBox(width: spacing.medium),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saveConfiguration,
                  icon: const Icon(AppIcons.save),
                  label: const Text('Save Configuration'),
                  style: ElevatedButton.styleFrom(
                    padding: spacing.all(Spacing.medium),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: spacing.xlarge),

          // Info section
          Card(
            child: Padding(
              padding: spacing.all(Spacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.infoOutlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: spacing.small),
                      Text(
                        'Connection Tips',
                        style: typography.titleMedium.copyWith(
                          fontWeight: FontWeightStyle.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.medium),
                  Text(
                    '• Make sure your Flask server is running\n'
                    '• Use localhost or 127.0.0.1 if server is on the same device\n'
                    '• Use your computer\'s local IP (e.g., 192.168.x.x) for same network\n'
                    '• Default Flask port is 5000\n'
                    '• Test connection before saving',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
