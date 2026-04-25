import 'package:flutter/material.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_typography.dart';

/// Professional permission request dialog for Wi-Fi access
class WiFiPermissionDialog extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const WiFiPermissionDialog({
    super.key,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      icon: Icon(
        Icons.wifi,
        size: context.dimensions.iconXLarge,
        color: theme.colorScheme.primary,
      ),
      title: const Text(
        'Network Information Access',
        style: TextStyle(fontSize: FontSize.xlargePlus, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This app needs to access network information to:',
            style: TextStyle(fontSize: FontSize.large, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.device_hub, 'Register device with server'),
          const SizedBox(height: 8),
          _buildFeatureItem(Icons.security, 'Secure connection management'),
          const SizedBox(height: 8),
          _buildFeatureItem(Icons.sync, 'Sync device status'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Network info is used only for device identification',
                    style: TextStyle(fontSize: FontSize.smallPlus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDeny,
          child: Text(
            'Skip',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onAllow,
          icon: const Icon(Icons.check),
          label: const Text('Allow'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: ComponentSize.iconSmall, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: FontSize.medium),
          ),
        ),
      ],
    );
  }
}

/// Show Wi-Fi permission dialog
Future<bool> showWiFiPermissionDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => WiFiPermissionDialog(
      onAllow: () => Navigator.of(context).pop(true),
      onDeny: () => Navigator.of(context).pop(false),
    ),
  );
  
  return result ?? false;
}
