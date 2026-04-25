import 'package:flutter/material.dart';
import 'dart:async';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_typography.dart';
import '../../../models/ble_device_config.dart';
import '../../../services/ble/ble_service.dart';
import '../../../utils/app_logger.dart';

class BleTerminalScreen extends StatefulWidget {
  const BleTerminalScreen({super.key});

  @override
  State<BleTerminalScreen> createState() => _BleTerminalScreenState();
}

class _BleTerminalScreenState extends State<BleTerminalScreen> {
  final BleService _bleService = BleService.instance;
  final TextEditingController _messageController = TextEditingController();
  final List<_TerminalMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  String? _selectedDeviceId;
  Map<String, BleConnectionState> _connectionStates = {};
  
  StreamSubscription? _dataSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _loadConnectionStates();
  }

  void _setupListeners() {
    _dataSubscription = _bleService.dataEvents.listen((event) {
      setState(() {
        _messages.add(_TerminalMessage(
          deviceId: event.deviceId,
          data: event.dataAsString,
          timestamp: event.timestamp,
          isIncoming: true,
        ));
      });
      _scrollToBottom();
    });

    _stateSubscription = _bleService.connectionStates.listen((states) {
      setState(() {
        _connectionStates = states;
        
        // Auto-select first connected device if none selected
        if (_selectedDeviceId == null && states.isNotEmpty) {
          final connectedIds = states.entries
              .where((e) => e.value == BleConnectionState.connected)
              .map((e) => e.key)
              .toList();
          
          if (connectedIds.isNotEmpty) {
            _selectedDeviceId = connectedIds.first;
          }
        }
        
        // Deselect if disconnected
        if (_selectedDeviceId != null && 
            states[_selectedDeviceId] != BleConnectionState.connected) {
          _selectedDeviceId = null;
        }
      });
    });
  }

  void _loadConnectionStates() {
    setState(() {
      _connectionStates = _bleService.currentStates;
      
      final connectedIds = _connectionStates.entries
          .where((e) => e.value == BleConnectionState.connected)
          .map((e) => e.key)
          .toList();
      
      if (connectedIds.isNotEmpty) {
        _selectedDeviceId = connectedIds.first;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _selectedDeviceId == null) return;

    try {
      await _bleService.sendStringToDevice(_selectedDeviceId!, text);
      
      setState(() {
        _messages.add(_TerminalMessage(
          deviceId: _selectedDeviceId!,
          data: text,
          timestamp: DateTime.now(),
          isIncoming: false,
        ));
      });
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      AppLogger.error('Failed to send message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _broadcastMessage(String text) async {
    if (text.isEmpty) return;

    try {
      await _bleService.broadcastToAll(text.codeUnits);
      
      setState(() {
        _messages.add(_TerminalMessage(
          deviceId: 'BROADCAST',
          data: text,
          timestamp: DateTime.now(),
          isIncoming: false,
        ));
      });
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      AppLogger.error('Failed to broadcast: $e');
    }
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = _connectionStates.entries
        .where((e) => e.value == BleConnectionState.connected)
        .map((e) => e.key)
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: context.dimensions.appBarHeight,
        title: const Text('BLE Terminal (HM-10)'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearMessages,
            tooltip: 'Clear messages',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          _buildConnectionStatusBar(connectedDevices),
          
          const Divider(height: 1),
          
          // Messages area
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet\nConnect a device and start communicating',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: FontSize.large),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    primary: false, // Don't use PrimaryScrollController
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageItem(_messages[index]);
                    },
                  ),
          ),
          
          const Divider(height: 1),
          
          // Input area
          _buildInputArea(connectedDevices),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBar(List<String> connectedDevices) {
    if (connectedDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.red[50],
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'No devices connected',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.green[50],
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected, color: Colors.green),
          const SizedBox(width: 8),
          const Text('Connected to:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedDeviceId,
              isExpanded: true,
              underline: Container(),
              items: connectedDevices.map((deviceId) {
                return DropdownMenuItem(
                  value: deviceId,
                  child: Text(
                    deviceId,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDeviceId = value;
                });
              },
            ),
          ),
          Text(
            '${connectedDevices.length} device(s)',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_TerminalMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isIncoming ? Colors.blue[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: message.isIncoming ? Colors.blue : Colors.green,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                message.isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                size: 16,
                color: message.isIncoming ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                message.isIncoming ? 'From' : 'To',
                style: TextStyle(
                  fontSize: FontSize.small,
                  color: message.isIncoming ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message.deviceId,
                  style: const TextStyle(fontSize: FontSize.small, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}:${message.timestamp.second.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: FontSize.xsmallPlus, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.data,
            style: const TextStyle(fontSize: FontSize.medium, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(List<String> connectedDevices) {
    final hasDevices = connectedDevices.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: hasDevices,
                  decoration: InputDecoration(
                    hintText: hasDevices 
                        ? 'Type message...' 
                        : 'Connect a device first',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: hasDevices ? _sendMessage : null,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: hasDevices 
                    ? () => _sendMessage(_messageController.text) 
                    : null,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: connectedDevices.length > 1 
                    ? () => _broadcastMessage(_messageController.text) 
                    : null,
                icon: const Icon(Icons.broadcast_on_home),
                label: const Text('Broadcast'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Helper section - Placeholder for custom widgets
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📝 Custom Widget Area',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: FontSize.medium),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your custom buttons and controls here',
                  style: TextStyle(fontSize: FontSize.small, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                
                // Example helper buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickButton('LED ON', hasDevices),
                    _buildQuickButton('LED OFF', hasDevices),
                    _buildQuickButton('STATUS', hasDevices),
                    _buildQuickButton('RESET', hasDevices),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(String label, bool enabled) {
    return ElevatedButton(
      onPressed: enabled ? () => _sendMessage(label) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
      ),
      child: Text(label),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _TerminalMessage {
  final String deviceId;
  final String data;
  final DateTime timestamp;
  final bool isIncoming;

  _TerminalMessage({
    required this.deviceId,
    required this.data,
    required this.timestamp,
    required this.isIncoming,
  });
}
