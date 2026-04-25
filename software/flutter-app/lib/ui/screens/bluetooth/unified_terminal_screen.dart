import 'package:flutter/material.dart';
import 'dart:async';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_typography.dart';
import '../../../models/unified_bluetooth_device.dart';
import '../../../services/bluetooth/unified_bluetooth_service.dart';
import '../../../utils/app_logger.dart';

class UnifiedTerminalScreen extends StatefulWidget {
  const UnifiedTerminalScreen({super.key});

  @override
  State<UnifiedTerminalScreen> createState() => _UnifiedTerminalScreenState();
}

class _UnifiedTerminalScreenState extends State<UnifiedTerminalScreen> {
  final _unifiedService = UnifiedBluetoothService.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<UnifiedBluetoothDevice> _savedDevices = [];
  Map<String, UnifiedConnectionInfo> _connectionStates = {};
  final List<_Message> _messages = [];

  UnifiedBluetoothDevice? _selectedDevice;
  bool _isBroadcastMode = false;

  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _dataSubscription; // Single subscription for all devices

  @override
  void initState() {
    super.initState();
    // Service is already initialized by AppInitializationService
    _loadSavedDevices();
    _listenToConnectionStates();
    _listenToDataStream(); // Single data stream listener
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Note: Devices are loaded in initState
    // Tab switching reloads via the parent TabBar
  }
  
  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _dataSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDevices() async {
    final devices = await _unifiedService.getSavedDevices();
    AppLogger.info('Terminal: Loaded ${devices.length} saved devices');
    if (mounted) {
      setState(() {
        _savedDevices = devices;
        
        // Validate selected device after reloading
        if (_selectedDevice != null && !devices.any((d) => d.id == _selectedDevice!.id)) {
          _selectedDevice = null;
        }
        
        // Auto-select first connected device if none selected
        if (_selectedDevice == null && !_isBroadcastMode) {
          final connectedDevices = devices.where((d) => _connectionStates[d.id]?.isConnected ?? false).toList();
          if (connectedDevices.isNotEmpty) {
            _selectedDevice = connectedDevices.first;
          }
        }
      });
    }
  }

  void _listenToConnectionStates() {
    _connectionStateSubscription = _unifiedService.connectionStates.listen((states) {
      if (mounted) {
        setState(() {
          _connectionStates = states;
          
          // Auto-select first connected device if none selected
          if (_selectedDevice == null || !states.containsKey(_selectedDevice!.id) || !states[_selectedDevice!.id]!.isConnected) {
            final connectedDevices = _savedDevices.where((d) => states[d.id]?.isConnected ?? false).toList();
            if (connectedDevices.isNotEmpty && !_isBroadcastMode) {
              _selectedDevice = connectedDevices.first;
            } else {
              _selectedDevice = null;
            }
          }
        });
      }
    });
  }

  void _listenToDataStream() {
    // Single subscription to the unified data stream for ALL devices
    _dataSubscription = _unifiedService.dataReceivedStream.listen((event) {
      // Find device in saved devices list
      final deviceIndex = _savedDevices.indexWhere((d) => d.id == event.deviceId);
      if (deviceIndex == -1) {
        AppLogger.warning('Received data from unknown device: ${event.deviceId}');
        return;
      }
      
      final device = _savedDevices[deviceIndex];
      
      _addMessage(_Message(
        deviceId: event.deviceId,
        deviceName: device.displayName,
        deviceType: device.type,
        content: event.data,
        timestamp: event.timestamp,
        isOutgoing: false,
      ));
    });
  }

  void _addMessage(_Message message) {
    if (mounted) {
      setState(() => _messages.add(message));
      
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_isBroadcastMode) {
      // Broadcast to all connected devices
      await _unifiedService.broadcastToAll(text);
      
      // Add message for each connected device
      for (final entry in _connectionStates.entries) {
        if (entry.value.isConnected) {
          final device = _savedDevices.firstWhere((d) => d.id == entry.key);
          _addMessage(_Message(
            deviceId: entry.key,
            deviceName: device.displayName,
            deviceType: device.type,
            content: text,
            timestamp: DateTime.now(),
            isOutgoing: true,
          ));
        }
      }
    } else if (_selectedDevice != null) {
      // Send to selected device
      final success = await _unifiedService.sendData(_selectedDevice!.id, text);
      
      if (success) {
        _addMessage(_Message(
          deviceId: _selectedDevice!.id,
          deviceName: _selectedDevice!.displayName,
          deviceType: _selectedDevice!.type,
          content: text,
          timestamp: DateTime.now(),
          isOutgoing: true,
        ));
      } else {
        AppLogger.showToast('Failed to send message', isError: true);
      }
    }

    _messageController.clear();
  }

  void clearMessages() {
    setState(() => _messages.clear());
  }

  void refreshDevices() {
    _loadSavedDevices();
  }

  Future<void> _disconnectDevice(String deviceId) async {
    await _unifiedService.disconnectDevice(deviceId);
    AppLogger.showToast('Disconnected');
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = _savedDevices.where((d) => _connectionStates[d.id]?.isConnected ?? false).toList();

    return Column(
      children: [
        // Connection status bar
        _buildConnectionStatusBar(connectedDevices),
        
        const Divider(height: 1),
        
        // Message history
        Expanded(
          child: _buildMessageList(),
        ),
        
        const Divider(height: 1),
        
        // Input controls
        _buildInputControls(connectedDevices),
      ],
    );
  }

  Widget _buildConnectionStatusBar(List<UnifiedBluetoothDevice> connectedDevices) {
    if (connectedDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.red.withValues(alpha: 0.1),
        child: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.red, size: ComponentSize.iconSmall),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No devices connected',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: FontSize.medium),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.green.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_connected, color: Colors.green, size: ComponentSize.iconSmall),
              const SizedBox(width: 6),
              Text(
                '${connectedDevices.length} device${connectedDevices.length > 1 ? 's' : ''} connected',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: FontSize.smallPlus),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: connectedDevices.map((device) {
              return Chip(
                avatar: Text(device.typeBadge, style: const TextStyle(fontSize: FontSize.medium)),
                label: Text(
                  device.displayName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: FontSize.small),
                ),
                deleteIcon: const Icon(Icons.close, size: ComponentSize.iconXSmall),
                onDeleted: () => _disconnectDevice(device.id),
                backgroundColor: device.isClassic
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message, size: context.dimensions.iconXXLarge, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(fontSize: FontSize.large, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Connect to a device and start messaging',
              style: TextStyle(fontSize: FontSize.medium, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      primary: false, // Don't use PrimaryScrollController - prevents conflicts with keyboard/scrollbar
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildMessageBubble(_Message message) {
    final device = _savedDevices.firstWhere((d) => d.id == message.deviceId);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isOutgoing) ...[
            // Device badge for incoming messages
            Text(device.typeBadge, style: const TextStyle(fontSize: FontSize.xlargePlus)),
            const SizedBox(width: 8),
          ],
          
          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isOutgoing
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: message.isOutgoing ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Device name and type label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          message.deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: FontSize.small,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: device.isClassic
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          device.typeLabel,
                          style: TextStyle(
                            fontSize: FontSize.tiny,
                            fontWeight: FontWeight.bold,
                            color: device.isClassic ? Colors.blue[900] : Colors.green[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Message content
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: FontSize.medium),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Timestamp
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: FontSize.xsmall,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isOutgoing) ...[
            const SizedBox(width: 8),
            // Device badge for outgoing messages
            Text(device.typeBadge, style: const TextStyle(fontSize: FontSize.xlargePlus)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputControls(List<UnifiedBluetoothDevice> connectedDevices) {
    final hasConnectedDevices = connectedDevices.isNotEmpty;
    
    // Validate selected device is still in the connected list
    if (_selectedDevice != null && !connectedDevices.any((d) => d.id == _selectedDevice!.id)) {
      _selectedDevice = null; // Clear invalid selection
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.grey.withValues(alpha: 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target Device and Broadcast Mode in one row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target Device dropdown on the left
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Device',
                      style: TextStyle(fontSize: FontSize.small, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      initialValue: _selectedDevice?.id,
                      hint: const Text('Select device', style: TextStyle(fontSize: FontSize.smallPlus)),
                      items: connectedDevices.map((device) {
                        return DropdownMenuItem(
                          value: device.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(device.typeBadge, style: const TextStyle(fontSize: FontSize.medium)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  device.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: FontSize.smallPlus),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: hasConnectedDevices && !_isBroadcastMode
                          ? (id) {
                              setState(() {
                                _selectedDevice = connectedDevices.firstWhere((d) => d.id == id);
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Broadcast toggle on the right
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Broadcast Mode',
                      style: TextStyle(fontSize: FontSize.small, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _isBroadcastMode ? 'Send to all' : 'Off',
                            style: TextStyle(
                              fontSize: FontSize.xsmallPlus,
                              color: _isBroadcastMode ? Colors.orange : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Switch(
                          value: _isBroadcastMode,
                          onChanged: hasConnectedDevices
                              ? (v) {
                                  setState(() {
                                    _isBroadcastMode = v;
                                    if (v && _selectedDevice == null && connectedDevices.isNotEmpty) {
                                      _selectedDevice = connectedDevices.first;
                                    }
                                  });
                                }
                              : null,
                          activeThumbColor: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Message input and send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: hasConnectedDevices && (_isBroadcastMode || _selectedDevice != null),
                  decoration: InputDecoration(
                    hintText: hasConnectedDevices
                        ? 'Type a message...'
                        : 'Connect a device first',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: ElevatedButton(
                        onPressed: hasConnectedDevices && (_isBroadcastMode || _selectedDevice != null)
                            ? _sendMessage
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBroadcastMode ? Colors.orange : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          disabledBackgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isBroadcastMode ? Icons.broadcast_on_personal : Icons.send,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(_isBroadcastMode ? 'Broadcast' : 'Send'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _Message {
  final String deviceId;
  final String deviceName;
  final BluetoothDeviceType deviceType;
  final String content;
  final DateTime timestamp;
  final bool isOutgoing;

  _Message({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.content,
    required this.timestamp,
    required this.isOutgoing,
  });
}
