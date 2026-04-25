import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';
import '../../services/tts_service.dart';
import '../../services/permissions/permission_service.dart';
import '../../services/server/server_config_service.dart';
import '../widgets/ai_assistant/widgets.dart';
import '../../constants/constants.dart';
import '../../core/constants/app_constants.dart';
import 'ai_assistant/ai_assistant_controller.dart';

/// AI Assistant Screen - Main chat interface with voice recording
/// Refactored to use controller pattern for better separation of concerns
class AIAssistantScreen extends StatefulWidget {
  final int? conversationId;
  final Function(String title)? onCreateConversation;

  const AIAssistantScreen({
    super.key,
    this.conversationId,
    this.onCreateConversation,
  });

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
    with WidgetsBindingObserver {
  // UI Controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  
  // Value Notifiers for efficient UI updates
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);

  // Business Logic Controller
  late AIAssistantController _controller;

  // Text input debouncer
  Timer? _textListenerDebouncer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
    _initializeTextListener();
    _initialize();
  }

  void _initializeController() {
    final serverConfig = ServerConfigService.instance;
    _controller = AIAssistantController(
      setState: setState,
      context: context,
      baseUrl: serverConfig.baseUrl,
      onConversationUpdated: _scrollToBottom,
      onCreateConversation: widget.onCreateConversation,
    );

    // Listen to server config changes
    serverConfig.host.addListener(_updateServerConfig);
    serverConfig.port.addListener(_updateServerConfig);
  }

  void _updateServerConfig() {
    final serverConfig = ServerConfigService.instance;
    _controller.updateServerConfig(serverConfig.baseUrl);
  }

  void _initializeTextListener() {
    _textController.addListener(_onTextChanged);
  }

  Future<void> _initialize() async {
    await _controller.initialize(conversationId: widget.conversationId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      PermissionService.instance.recheckPermission();
    }
  }

  void _onTextChanged() {
    _textListenerDebouncer?.cancel();
    _textListenerDebouncer = Timer(AppConstants.textInputDebounce, () {
      final text = _textController.text;
      _hasTextNotifier.value = text.isNotEmpty && text.trim().isNotEmpty;
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll > AppConstants.autoScrollThreshold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: AppConstants.scrollAnimationDuration,
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _hasTextNotifier.value = false;

    await _controller.sendTextMessage(text);
    _scrollToBottom();
  }

  Future<void> _onMicPressed() async {
    await _controller.startRecording();
    _isRecordingNotifier.value = true;
  }

  Future<void> _onMicReleased() async {
    _isRecordingNotifier.value = false;
    await _controller.stopRecording();
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textListenerDebouncer?.cancel();
    _isRecordingNotifier.dispose();
    _hasTextNotifier.dispose();
    _scrollController.dispose();
    _textController.dispose();

    final serverConfig = ServerConfigService.instance;
    serverConfig.host.removeListener(_updateServerConfig);
    serverConfig.port.removeListener(_updateServerConfig);

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final dimensions = context.dimensions;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Model information bar - listens to model changes
            ValueListenableBuilder<String>(
              valueListenable: PreferencesService.instance.defaultSttModelNotifier,
              builder: (context, sttModel, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: PreferencesService.instance.defaultLmModelNotifier,
                  builder: (context, lmModel, _) {
                    return ModelInfoBar(
                      sttModel: sttModel,
                      lmModel: lmModel,
                    );
                  },
                );
              },
            ),

            // Chat messages
            Expanded(
              child: Container(
                margin: spacing.all(Spacing.small),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: AppOpacity.border),
                    width: BorderSize.thin,
                  ),
                  borderRadius: dimensions.borderRadiusLarge,
                ),
                child: ChatMessageList(
                  messages: _controller.messages,
                  scrollController: _scrollController,
                  streamingMessageIndex: _controller.streamingMessageIndex,
                  streamingContentNotifier:
                      _controller.streamingMessageContentNotifier,
                ),
              ),
            ),

            // Input area
            ValueListenableBuilder<bool>(
              valueListenable: _hasTextNotifier,
              builder: (context, hasText, _) {
                return MessageInputField(
                  controller: _textController,
                  hasText: hasText,
                  onSend: _sendTextMessage,
                  trailingWidget: _buildRecordingButton(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isRecordingNotifier,
      builder: (context, isRecording, _) {
        return ValueListenableBuilder<ProcessingState>(
          valueListenable: _controller.processingStateNotifier,
          builder: (context, state, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: TtsService.instance.isSpeakingNotifier,
              builder: (context, isTtsSpeaking, _) {
                return RecordingButton(
                  processingState: state,
                  isRecording: isRecording,
                  isTtsSpeaking: isTtsSpeaking,
                  onMicPressed: _onMicPressed,
                  onMicReleased: _onMicReleased,
                  onStop: _controller.stopProcessing,
                );
              },
            );
          },
        );
      },
    );
  }
}
