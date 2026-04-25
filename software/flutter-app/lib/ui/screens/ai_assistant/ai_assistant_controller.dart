import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../../../models/conversation.dart';
import '../../../services/preferences_service.dart';
import '../../../services/audio_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/database/database_helper.dart';
import '../../../services/permissions/permission_service.dart';
import '../../../services/api/server_api_service.dart';
import '../../../services/command_router_service.dart';
import '../../../models/assistant_response.dart';
import '../../../api/models/server_event.dart';
import '../../../utils/app_logger.dart';
import '../../../core/utils/formatters/formatters.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/database_constants.dart';
import '../../../constants/constants.dart';
import '../../widgets/ai_assistant/recording_button.dart';

/// Business logic for AI Assistant screen
/// Handles all state management, API calls, and data operations
class AIAssistantController {
  // Callbacks
  final void Function(VoidCallback fn) setState;
  final void Function()? onConversationUpdated;
  final Function(String title)? onCreateConversation;
  final BuildContext context;

  // Services
  late ServerApiService _serverApi;
  late CommandRouterService _commandRouter;
  StreamSubscription? _serverStreamSubscription;

  // State
  Conversation? currentConversation;
  List<ChatMessage> messages = [];
  int? streamingMessageIndex;

  // Notifiers
  final ValueNotifier<ProcessingState> processingStateNotifier =
      ValueNotifier<ProcessingState>(ProcessingState.idle);
  final ValueNotifier<String> streamingMessageContentNotifier =
      ValueNotifier<String>('');

  // Timers
  Timer? _recordingTimer;
  Stopwatch? _recordingStopwatch;

  AIAssistantController({
    required this.setState,
    required this.context,
    required String baseUrl,
    this.onConversationUpdated,
    this.onCreateConversation,
  }) {
    _serverApi = ServerApiService(baseUrl: baseUrl);
    _commandRouter = CommandRouterService();
  }

  ProcessingState get processingState => processingStateNotifier.value;
  set processingState(ProcessingState value) =>
      processingStateNotifier.value = value;

  /// Initialize or load conversation
  Future<void> initialize({int? conversationId}) async {
    if (conversationId != null) {
      await _loadConversation(conversationId);
    } else {
      await _createNewConversation();
    }
  }

  /// Update server API configuration
  void updateServerConfig(String baseUrl) {
    _serverApi = ServerApiService(baseUrl: baseUrl);
  }

  /// Create a new conversation
  Future<void> _createNewConversation() async {
    final now = DateTime.now();
    final conversation = Conversation(
      title: AppStrings.aiNewChat,
      createdAt: now,
      lastModified: now,
    );

    final id = await DatabaseHelper.instance.createConversation(conversation);
    currentConversation = conversation.copyWith(id: id);

    setState(() {
      messages = [];
    });

    AppLogger.info('Created new conversation with ID: $id');
  }

  /// Load existing conversation from database
  Future<void> _loadConversation(int conversationId) async {
    final conversation =
        await DatabaseHelper.instance.getConversation(conversationId);

    if (conversation == null) {
      AppLogger.error('Conversation not found: $conversationId');
      await _createNewConversation();
      return;
    }

    currentConversation = conversation;
    final loadedMessages =
        await DatabaseHelper.instance.getMessagesForConversation(conversationId);

    setState(() {
      messages = loadedMessages;
    });

    AppLogger.info(
        'Loaded conversation $conversationId with ${loadedMessages.length} messages');
  }

  /// Start recording audio
  Future<void> startRecording() async {
    if (processingState != ProcessingState.idle) return;

    if (!PermissionService.instance.hasMicrophonePermission.value) {
      final granted = await PermissionService.instance.requestPermission();

      if (!granted) {
        final isPermanentlyDenied =
            await PermissionService.instance.isPermanentlyDenied();

        if (isPermanentlyDenied) {
          await _showPermissionDialog();
        } else {
          _showSnackBar('Microphone permission is required to record audio');
        }
      }
      // Always return after permission dialog - user must press button again
      // This maintains push-to-talk behavior
      return;
    }

    final success = await AudioService.instance.startRecording();

    if (!success) {
      _showSnackBar(AppStrings.errorMicPermission);
      return;
    }

    processingState = ProcessingState.recording;
    _startRecordingTimer();
  }

  /// Stop recording and process audio
  Future<void> stopRecording() async {
    if (processingState != ProcessingState.recording) return;

    final duration = _recordingStopwatch?.elapsedMilliseconds ?? 0;
    _stopRecordingTimer();

    if (duration < AppConstants.minRecordingDurationMs) {
      processingState = ProcessingState.idle;
      _showSnackBar(AppStrings.statusRecordingTooShort);
      await AudioService.instance.cancelRecording();
      return;
    }

    final filePath = await AudioService.instance.stopRecording();

    if (filePath == null) {
      processingState = ProcessingState.idle;
      _showSnackBar('Recording failed');
      return;
    }

    AppLogger.success('Recording saved: $filePath');
    await _uploadAndProcess(filePath);
  }

  /// Send text message
  Future<void> sendTextMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    await _addUserMessage(trimmedText);
    await _processText(trimmedText);
  }

  /// Stop all processing
  Future<void> stopProcessing() async {
    AppLogger.info('Stop button pressed - cancelling processing and TTS');

    if (streamingMessageIndex != null &&
        streamingMessageIndex! < messages.length &&
        streamingMessageContentNotifier.value.isNotEmpty) {
      final streamingMessage = messages[streamingMessageIndex!];
      final messageId = await DatabaseHelper.instance.createMessage(
        streamingMessage.copyWith(
            content: streamingMessageContentNotifier.value),
      );

      setState(() {
        messages[streamingMessageIndex!] = streamingMessage.copyWith(
          id: messageId,
          content: streamingMessageContentNotifier.value,
        );
        streamingMessageIndex = null;
      });

      if (currentConversation != null) {
        await DatabaseHelper.instance.updateConversation(
          currentConversation!.copyWith(lastModified: DateTime.now()),
        );
      }
    }

    _serverStreamSubscription?.cancel();
    _serverStreamSubscription = null;

    TtsService.instance.stopStreaming();
    TtsService.instance.stop();

    if (processingState == ProcessingState.recording) {
      AudioService.instance.cancelRecording();
      _stopRecordingTimer();
    }

    processingState = ProcessingState.idle;
    _showSnackBar('Processing stopped', duration: AppConstants.shortSnackbarDuration);
  }

  /// Add user message to conversation
  Future<void> _addUserMessage(String content) async {
    if (currentConversation == null) return;

    if (messages.isEmpty && onCreateConversation != null) {
      final title = TextFormatters.generateChatTitle(content);
      currentConversation = currentConversation!.copyWith(
        title: title,
        lastModified: DateTime.now(),
      );

      await DatabaseHelper.instance.updateConversation(currentConversation!);
      onCreateConversation!(title);
    }

    final userMessage = ChatMessage(
      conversationId: currentConversation!.id!,
      role: DatabaseConstants.roleUser,
      content: content,
      timestamp: DateTime.now(),
    );

    final messageId =
        await DatabaseHelper.instance.createMessage(userMessage);
    final savedMessage = userMessage.copyWith(id: messageId);

    setState(() {
      messages.add(savedMessage);
    });
  }

  /// Process uploaded audio file
  Future<void> _uploadAndProcess(String audioFilePath) async {
    processingState = ProcessingState.uploading;

    try {
      final prefs = PreferencesService.instance;
      final sttModel = prefs.defaultSttModel;

      AppLogger.info('Uploading audio for transcription: STT=$sttModel');

      // Step 1: Get transcription from audio (transcribe-only endpoint)
      processingState = ProcessingState.transcribing;
      final transcription = await _serverApi.transcribeAudio(
        audioFilePath: audioFilePath,
        sttModel: sttModel,
      );

      if (transcription.isEmpty) {
        throw Exception('Empty transcription received');
      }

      AppLogger.success('Transcription: $transcription');

      // Step 2: Add user message with transcription
      await _addUserMessage(transcription);

      // Step 3: Process through assistant pipeline (two-pass: categorization → routing)
      AppLogger.info('Routing through assistant pipeline...');
      await _processText(transcription);
      
    } catch (e) {
      AppLogger.error('Upload and process error: $e');
      processingState = ProcessingState.idle;
      TtsService.instance.stopStreaming();
      await TtsService.instance.stop();
      _showSnackBar('Transcription failed: $e');
      _serverStreamSubscription = null;
    }
  }

  /// Process text input
  Future<void> _processText(String text) async {
    processingState = ProcessingState.processing;

    try {
      AppLogger.info('Processing text through assistant API');

      // Call the new assistant API with user's selected LM model
      final lmModel = PreferencesService.instance.defaultLmModel;
      final result = await _serverApi.handleAssistantRequest(
        userQuery: text,
        lmModel: lmModel,
      );

      // Route based on result type
      await _handleAssistantResult(result);
    } catch (e) {
      AppLogger.error('Process text error: $e');
      processingState = ProcessingState.idle;
      TtsService.instance.stopStreaming();
      await TtsService.instance.stop();
      _showSnackBar(AppStrings.errorServerUnavailable);
      _serverStreamSubscription = null;
    }
  }

  /// Handle assistant API result
  Future<void> _handleAssistantResult(AssistantApiResult result) async {
    if (result.isStreaming && result.streamingEvents != null) {
      // Text generation - stream to chat bubble
      AppLogger.info('Handling streaming text-generation response');
      await _handleStreamResponse(result.streamingEvents!, useStt: false);
    } else if (result.isJson && result.jsonResponse != null) {
      // BT control - route command to device
      AppLogger.info('Handling bt-control JSON response');
      await _handleBtControlResponse(result.jsonResponse!);
    } else if (result.isRouted) {
      // Command was routed to another device via WebSocket
      AppLogger.success('Command routed: ${result.routedMessage}');
      processingState = ProcessingState.idle;
      _showSnackBar(
        result.routedMessage ?? 'Command sent',
        duration: AppConstants.shortSnackbarDuration,
      );
      // Speak confirmation
      final deviceName = result.targetDevice ?? 'device';
      await TtsService.instance.speak('Command sent to $deviceName');
    } else if (result.isError) {
      // Error occurred
      AppLogger.error('Assistant API error: ${result.error}');
      processingState = ProcessingState.idle;
      _showSnackBar(result.error ?? AppStrings.errorServerUnavailable);
    } else {
      // Unexpected state
      AppLogger.warning('Unexpected assistant result state');
      processingState = ProcessingState.idle;
      _showSnackBar('Unexpected response from server');
    }
  }

  /// Handle Bluetooth control response
  Future<void> _handleBtControlResponse(AssistantResponse response) async {
    try {
      // Check for errors in the response
      if (response.hasError && response.error != null) {
        final errorMsg = response.error!.message;
        AppLogger.error('BT control error: $errorMsg');
        processingState = ProcessingState.idle;
        _showSnackBar(errorMsg, duration: AppConstants.snackbarDisplayDuration);
        await TtsService.instance.speak('Command failed: $errorMsg');
        return;
      }

      // Route command to Bluetooth device
      final success = await _commandRouter.routeCommand(response);
      
      processingState = ProcessingState.idle;

      // Extract clean device name for TTS
      final deviceName = _extractDeviceName(response.targetDevice);

      // Provide feedback based on success
      if (success) {
        final command = response.output.generatedOutput;
        _showSnackBar(
          'Sent to $deviceName: $command',
          duration: AppConstants.shortSnackbarDuration,
        );
        AppLogger.info('BT control command sent successfully');
        // Speak confirmation via TTS
        await TtsService.instance.speak('Sent command to $deviceName');
      } else {
        _showSnackBar(
          'Failed to send command',
          duration: AppConstants.shortSnackbarDuration,
        );
        AppLogger.warning('BT control command failed');
        // Speak failure via TTS
        await TtsService.instance.speak('Failed to send command to $deviceName');
      }
    } catch (e) {
      AppLogger.error('Error handling BT control: $e');
      processingState = ProcessingState.idle;
      _showSnackBar('Failed to process command: $e');
    }
  }

  /// Extract device name from device string (e.g., "drone (MAC: XX:XX:XX)" -> "drone")
  String _extractDeviceName(String deviceString) {
    final match = RegExp(r'^([^(]+)').firstMatch(deviceString);
    return match?.group(1)?.trim() ?? deviceString;
  }

  /// Handle server stream response
  Future<void> _handleStreamResponse(
    Stream<ServerEvent> stream, {
    required bool useStt,
  }) async {
    String assistantResponse = '';
    ChatMessage? assistantMessage;

    await _serverStreamSubscription?.cancel();

    _serverStreamSubscription = stream.listen(
      (event) async {
        await _processServerEvent(
          event,
          assistantMessage: assistantMessage,
          assistantResponse: assistantResponse,
          useStt: useStt,
          onMessageCreated: (message) => assistantMessage = message,
          onResponseUpdated: (response) => assistantResponse = response,
        );
      },
      onError: (error) => _handleStreamError(error, assistantMessage),
      onDone: () {
        AppLogger.info('Stream closed');
        // If stream closes without any response, reset state
        if (assistantMessage == null && processingState != ProcessingState.idle) {
          AppLogger.warning('Stream closed without creating assistant message - resetting state');
          processingState = ProcessingState.idle;
          TtsService.instance.stopStreaming();
        }
      },
      cancelOnError: true,
    );
  }

  /// Process individual server event
  Future<void> _processServerEvent(
    ServerEvent event, {
    required ChatMessage? assistantMessage,
    required String assistantResponse,
    required bool useStt,
    required Function(ChatMessage) onMessageCreated,
    required Function(String) onResponseUpdated,
  }) async {
    switch (event.type) {
      case ServerEventType.status:
        await _handleStatusEvent(event, useStt, onMessageCreated);
        break;

      case ServerEventType.data:
        if (assistantMessage != null) {
          // Parse JSON to extract the chunk text
          try {
            final jsonData = jsonDecode(event.data) as Map<String, dynamic>;
            final chunkText = jsonData['chunk'] as String? ?? event.data;
            
            assistantResponse += chunkText;
            streamingMessageContentNotifier.value = assistantResponse;
            onResponseUpdated(assistantResponse);
            await TtsService.instance.speakChunk(chunkText);
          } catch (e) {
            // Fallback to raw data if not JSON
            AppLogger.warning('Could not parse chunk JSON, using raw data: $e');
            assistantResponse += event.data;
            streamingMessageContentNotifier.value = assistantResponse;
            onResponseUpdated(assistantResponse);
            await TtsService.instance.speakChunk(event.data);
          }
        }
        break;

      case ServerEventType.done:
        await _handleDoneEvent(assistantMessage, assistantResponse);
        break;

      case ServerEventType.error:
        _handleErrorEvent(event, assistantMessage);
        break;

      case ServerEventType.unknown:
        AppLogger.info('Unknown event: ${event.data}');
        break;
    }
  }

  Future<void> _handleStatusEvent(
    ServerEvent event,
    bool useStt,
    Function(ChatMessage) onMessageCreated,
  ) async {
    AppLogger.info('📊 Status event: ${event.data}');

    // Try to parse as JSON first (new format)
    try {
      final jsonData = jsonDecode(event.data) as Map<String, dynamic>;
      final status = jsonData['status'] as String?;
      
      AppLogger.info('📊 Parsed status JSON: $status');
      
      if (status == 'transcribing') {
        AppLogger.info('🎤 Transcribing...');
        processingState = ProcessingState.transcribing;
      } else if (status == 'generating') {
        final transcript = jsonData['transcription'] as String?;
        
        // If transcription provided, add user message (from /process endpoint)
        if (transcript != null && transcript.isNotEmpty) {
          AppLogger.info('📝 Transcription complete: ${transcript.substring(0, transcript.length.clamp(0, 50))}...');
          await _addUserMessage(transcript);
        } else {
          // No transcription - just starting generation (from assistant API)
          AppLogger.info('🤖 Starting generation (no transcription)');
        }

        processingState = ProcessingState.processing;
        TtsService.instance.startStreamMode();

        final currentSttModel = PreferencesService.instance.defaultSttModel;
        final currentLmModel = PreferencesService.instance.defaultLmModel;

        final assistantMessage = ChatMessage(
          conversationId: currentConversation!.id!,
          role: DatabaseConstants.roleAssistant,
          content: '',
          timestamp: DateTime.now(),
          sttModel: currentSttModel,
          lmModel: currentLmModel,
        );

        setState(() {
          messages.add(assistantMessage);
          streamingMessageIndex = messages.length - 1;
        });

        streamingMessageContentNotifier.value = '';
        onMessageCreated(assistantMessage);
        AppLogger.success('✅ Created assistant message, ready for streaming');
      }
    } catch (e) {
      // Fallback to old text format
      AppLogger.info('📊 Using old text format: ${event.data}');
      
      if (event.data.contains('Transcribing')) {
        processingState = ProcessingState.transcribing;
      } else if (event.data.startsWith('Transcription complete:')) {
        final transcript =
            event.data.substring('Transcription complete:'.length).trim();

        if (transcript.isNotEmpty) {
          await _addUserMessage(transcript);
        }

        processingState = ProcessingState.processing;
        TtsService.instance.startStreamMode();

        final currentSttModel = PreferencesService.instance.defaultSttModel;
        final currentLmModel = PreferencesService.instance.defaultLmModel;

        final assistantMessage = ChatMessage(
          conversationId: currentConversation!.id!,
          role: DatabaseConstants.roleAssistant,
          content: '',
          timestamp: DateTime.now(),
          sttModel: currentSttModel,
          lmModel: currentLmModel,
        );

        setState(() {
          messages.add(assistantMessage);
          streamingMessageIndex = messages.length - 1;
        });

        streamingMessageContentNotifier.value = '';
        onMessageCreated(assistantMessage);
      } else if (event.data.contains('generating')) {
        processingState = ProcessingState.processing;
      }
    }
  }

  Future<void> _handleDoneEvent(
    ChatMessage? assistantMessage,
    String assistantResponse,
  ) async {
    AppLogger.success('Processing complete');

    TtsService.instance.endStreamMode();

    if (assistantMessage != null && assistantResponse.isNotEmpty) {
      final messageId = await DatabaseHelper.instance.createMessage(
        assistantMessage.copyWith(content: assistantResponse),
      );

      setState(() {
        if (streamingMessageIndex != null &&
            streamingMessageIndex! < messages.length) {
          messages[streamingMessageIndex!] = assistantMessage.copyWith(
            id: messageId,
            content: assistantResponse,
          );
        }
        streamingMessageIndex = null;
      });

      if (currentConversation != null) {
        await DatabaseHelper.instance.updateConversation(
          currentConversation!.copyWith(lastModified: DateTime.now()),
        );
      }

      onConversationUpdated?.call();
      processingState = ProcessingState.idle;
    } else {
      processingState = ProcessingState.idle;
    }

    _serverStreamSubscription = null;
  }

  void _handleErrorEvent(ServerEvent event, ChatMessage? assistantMessage) {
    AppLogger.error('Server error: ${event.data}');
    processingState = ProcessingState.idle;

    TtsService.instance.stopStreaming();
    TtsService.instance.stop();

    _showSnackBar('Error: ${event.data}');

    if (assistantMessage?.content.isEmpty ?? false) {
      setState(() {
        messages.removeLast();
      });
    }

    _serverStreamSubscription = null;
  }

  void _handleStreamError(dynamic error, ChatMessage? assistantMessage) {
    AppLogger.error('Stream error: $error');
    processingState = ProcessingState.idle;

    TtsService.instance.stopStreaming();
    TtsService.instance.stop();

    _showSnackBar(AppStrings.errorServerUnavailable);
    _serverStreamSubscription = null;
  }

  // Helper methods
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingStopwatch = Stopwatch()..start();

    _recordingTimer =
        Timer.periodic(AppConstants.recordingTimerInterval, (_) {
      // Timer runs for UI updates if needed
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingStopwatch?.stop();
  }

  Future<void> _showPermissionDialog() async {
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Microphone access is required to record audio. '
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      await PermissionService.instance.openSettings();
    }
  }

  void _showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? AppConstants.snackbarDisplayDuration,
      ),
    );
  }

  /// Cleanup resources
  void dispose() {
    _recordingTimer?.cancel();
    _serverStreamSubscription?.cancel();
    processingStateNotifier.dispose();
    streamingMessageContentNotifier.dispose();
    _recordingStopwatch?.stop();
  }
}
