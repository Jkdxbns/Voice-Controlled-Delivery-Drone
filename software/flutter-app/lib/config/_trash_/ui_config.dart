import 'package:flutter/material.dart';

/// Centralized UI configuration for the entire app
/// 
/// NOTE: For responsive sizing (fonts, spacing, icons, borders), use ResponsiveConfig
/// This class now contains only NON-RESPONSIVE values like colors, text, icons, etc.
/// 
/// MIGRATION: All hardcoded pixel sizes have been moved to ResponsiveConfig
/// Use context.responsive to access responsive sizing throughout the app.
/// Import: import 'package:coffin_v6/config/responsive_config.dart';
class UIConfig {
  UIConfig._();

  // ============================================================================
  // DEPRECATED - Use ResponsiveConfig for all sizing values
  // These are kept for backwards compatibility during migration
  // ============================================================================
  
  @Deprecated('Use ResponsiveConfig.fontSizeXXL instead')
  static const double fontSizeXXL = 24.0;
  @Deprecated('Use ResponsiveConfig.fontSizeM instead')
  static const double fontSizeMedium = 14.0;
  @Deprecated('Use ResponsiveConfig.fontSizeS instead')
  static const double fontSizeSmall = 12.0;

  // FONT WEIGHTS (These are semantic, not size-dependent)
  static const FontWeight fontWeightBold = FontWeight.bold;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightRegular = FontWeight.w400;

  @Deprecated('Use ResponsiveConfig.iconSizeXL instead')
  static const double iconSizeLarge = 48.0;
  @Deprecated('Use ResponsiveConfig.iconSizeM instead')
  static const double iconSizeMedium = 24.0;
  @Deprecated('Use ResponsiveConfig.iconSizeS instead')
  static const double iconSizeSmall = 18.0;
  @Deprecated('Use ResponsiveConfig.recordingButtonIconSize instead')
  static const double iconSizeRecording = 32.0;

  @Deprecated('Use ResponsiveConfig.spacingXXS/spacingXS/spacingS/spacingM/spacingL/spacingXL instead')
  static const double spacingNone = 0.0;
  @Deprecated('Use ResponsiveConfig.spacingS instead')
  static const double spacingSmall = 8.0;
  @Deprecated('Use ResponsiveConfig.spacingM instead')
  static const double spacingMedium = 12.0;
  @Deprecated('Use ResponsiveConfig.spacingL instead')
  static const double spacingLarge = 16.0;
  @Deprecated('Use ResponsiveConfig.spacingXL instead')
  static const double spacingXLarge = 24.0;

  @Deprecated('Use ResponsiveConfig.radiusXS/radiusS/radiusM instead')
  static const double borderRadiusSmall = 4.0;
  @Deprecated('Use ResponsiveConfig.radiusS instead')
  static const double borderRadiusMedium = 8.0;
  @Deprecated('Use ResponsiveConfig.radiusM instead')
  static const double borderRadiusLarge = 12.0;

  @Deprecated('Use ResponsiveConfig.borderWidthThin/Medium/Thick instead')
  static const double borderWidthThin = 1.0;
  @Deprecated('Use ResponsiveConfig.borderWidthMedium instead')
  static const double borderWidthMedium = 2.0;
  @Deprecated('Use ResponsiveConfig.borderWidthThick instead')
  static const double borderWidthThick = 4.0;

  // ELEVATION & SHADOWS (These are platform standard values, not size-dependent)
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;

  // OPACITY (These are semantic values, not size-dependent)
  static const double opacityDisabled = 0.38;
  static const double opacityMedium = 0.54;
  static const double opacityHigh = 0.87;
  static const double opacityFull = 1.0;
  static const double opacityTransparent = 0.0;
  static const double opacityBorder = 0.3;

  @Deprecated('Use ResponsiveConfig.drawerWidth instead')
  static const double drawerWidth = 243.0;
  @Deprecated('Use ResponsiveConfig.drawerHeaderHeight instead')
  static const double drawerHeaderHeight = 160.0;
  @Deprecated('Use ResponsiveConfig for responsive spacing')
  static const double drawerNestedIndent = 48.0;
  static const VisualDensity drawerNestedDensity = VisualDensity(vertical: -1);

  @Deprecated('Use ResponsiveConfig.buttonHeightS/M/L/XL instead')
  static const double buttonHeightSmall = 32.0;
  @Deprecated('Use ResponsiveConfig.buttonHeightM instead')
  static const double buttonHeightMedium = 40.0;
  @Deprecated('Use ResponsiveConfig.buttonHeightL instead')
  static const double buttonHeightLarge = 48.0;
  @Deprecated('Use ResponsiveConfig.buttonHeightXL instead')
  static const double buttonHeightXL = 56.0;
  @Deprecated('Use ResponsiveConfig.spacingS instead')
  static const double buttonPaddingSmall = 8.0;
  @Deprecated('Use ResponsiveConfig.spacingM instead')
  static const double buttonPaddingMedium = 12.0;
  @Deprecated('Use ResponsiveConfig.spacingL instead')
  static const double buttonPaddingLarge = 16.0;

  @Deprecated('Use ResponsiveConfig.cardPaddingS/M/L instead')
  static const double cardPaddingSmall = 8.0;
  @Deprecated('Use ResponsiveConfig.cardPaddingM instead')
  static const double cardPaddingMedium = 12.0;
  @Deprecated('Use ResponsiveConfig.cardPaddingL instead')
  static const double cardPaddingLarge = 16.0;
  @Deprecated('Use ResponsiveConfig.cardMarginS/M/L instead')
  static const double cardMarginSmall = 4.0;
  @Deprecated('Use ResponsiveConfig.cardMarginM instead')
  static const double cardMarginMedium = 8.0;
  @Deprecated('Use ResponsiveConfig.cardMarginL instead')
  static const double cardMarginLarge = 16.0;

  @Deprecated('Use ResponsiveConfig.chatBubblePadding/Margin/MaxWidth/Radius instead')
  static const double chatBubblePadding = 12.0;
  @Deprecated('Use ResponsiveConfig.chatBubbleMargin instead')
  static const double chatBubbleMargin = 8.0;
  static const double chatBubbleMaxWidth = 0.75; // This is a percentage, can stay
  @Deprecated('Use ResponsiveConfig.chatBubbleRadius instead')
  static const double chatBubbleRadius = 12.0;

  @Deprecated('Use ResponsiveConfig.recordingButtonSize/IconSize/BorderWidth instead')
  static const double recordingButtonSize = 64.0;
  @Deprecated('Use ResponsiveConfig.recordingButtonIconSize instead')
  static const double recordingButtonIconSize = 32.0;
  @Deprecated('Use ResponsiveConfig.recordingButtonBorderWidth instead')
  static const double recordingButtonBorderWidth = 4.0;

  @Deprecated('Use ResponsiveConfig.modelCardPadding/BadgePadding/BadgeRadius instead')
  static const double modelCardPadding = 12.0;
  @Deprecated('Use ResponsiveConfig for padding')
  static const double modelCardBadgePadding = 4.0;
  @Deprecated('Use ResponsiveConfig for border radius')
  static const double modelCardBadgeRadius = 4.0;

  // SCROLLBAR CONFIGURATION (Platform-specific, can stay as constants)
  static const double scrollbarThickness = 6.0;
  static const double scrollbarRadius = 3.0;
  static const bool scrollbarThumbVisibility = true;

  @Deprecated('Use ResponsiveConfig.durationFast/Normal/Snackbar instead')
  static const int animationDurationFast = 150;
  @Deprecated('Use ResponsiveConfig.durationNormal instead')
  static const int animationDurationNormal = 300;
  @Deprecated('Use ResponsiveConfig.durationSnackbar instead')
  static const int snackbarDuration = 2000;

  // COLORS - PRIMARY PALETTE
  static const Color colorWhite = Colors.white;
  static const Color colorBlack = Colors.black;
  static const Color colorTransparent = Colors.transparent;
  static Color get colorPrimary => Colors.blue[700]!;
  static Color get colorSecondary => Colors.blue[500]!;
  static Color get colorAccent => Colors.blueAccent;

  // COLORS - SEMANTIC
  static const Color colorSuccess = Colors.green;
  static Color get colorSuccessDark => Colors.green[700]!;
  static const Color colorError = Colors.red;
  static Color get colorErrorDark => Colors.red[700]!;
  static const Color colorWarning = Colors.orange;
  static Color get colorWarningDark => Colors.orange[700]!;
  static const Color colorInfo = Colors.blue;
  static Color get colorInfoDark => Colors.blue[700]!;
  static const Color colorInfoLight = Color(0xFF64B5F6); // Light blue for dark mode

  // COLORS - GREY SCALE
  static Color get colorGrey50 => Colors.grey[50]!;
  static Color get colorGrey100 => Colors.grey[100]!;
  static Color get colorGrey200 => Colors.grey[200]!;
  static Color get colorGrey300 => Colors.grey[300]!;
  static Color get colorGrey400 => Colors.grey[400]!;
  static Color get colorGrey500 => Colors.grey[500]!;
  static Color get colorGrey600 => Colors.grey[600]!;
  static Color get colorGrey700 => Colors.grey[700]!;
  static Color get colorGrey800 => Colors.grey[800]!;
  static Color get colorGrey900 => Colors.grey[900]!;

  // COLORS - DARK MODE SPECIFIC
  static const Color colorDarkSurface = Color(0xFF1E3A5F); // Dark mode surface/container
  static const Color colorDarkBorder = Color(0xFF0D2844); // Dark mode border
  static const Color colorDarkPrimary = Color(0xFF1565C0); // Dark mode primary (blue)

  // COLORS - CHAT BUBBLES
  static Color get colorUserBubble => Colors.blue[100]!;
  static Color get colorUserBubbleDark => const Color(0xFF2A4A6F);
  static Color get colorUserBubbleBorder => Colors.blue[300]!;
  static Color get colorAiBubble => Colors.grey[200]!;
  static Color get colorAiBubbleDark => const Color(0xFF0D2844);
  static const Color colorUserText = Colors.black87;
  static const Color colorAiText = Colors.black87;

  // COLORS - RECORDING STATES
  static Color get colorRecording => Colors.orange[600]!;
  static Color get colorRecordingIdle => Colors.grey[300]!;
  static const Color colorRecordingPulse = Colors.orange;

  // COLORS - HOME SCREEN TILES
  static const Color colorTileAiAssistant = Colors.blue;
  static const Color colorTileChatHistory = Colors.green;
  static const Color colorTileModels = Colors.purple;
  static const Color colorTileSettings = Colors.orange;

  // TEXT - UI LABELS & MESSAGES
  static const String textHome = 'Home';
  static const String textTools = 'Tools';
  static const String textAiAssistant = 'AI Assistant';
  static const String textChatHistory = 'Chat History';
  static const String textModelSelection = 'Model Selection';
  static const String textSettings = 'Settings';
  static const String textChatWithAi = 'Chat with AI';
  static const String textViewPastChats = 'View past chats';
  static const String textManageModels = 'Manage models';
  static const String textAppSettings = 'App settings';
  static const String textVoiceAssistant = 'Voice Assistant';
  static const String textModels = 'Models';
  
  // TEXT - AI ASSISTANT SCREEN
  static const String textStt = 'STT:';
  static const String textLocal = 'Local';
  static const String textServer = 'Server';
  static const String textLocalInference = 'Local Inference';
  static const String textStartConversation = 'Start a conversation';
  static const String textTypeOrRecord = 'Type a message or record audio';
  static const String textTypeMessage = 'Type a message...';
  static const String textRecordingTooShort = 'Recording too short';
  static const String textTranscriptionCancelled = 'Transcription cancelled';
  static const String textGenerationStopped = 'Generation stopped';
  static const String textSttNoInternet = 'STT (No Internet)';
  static const String textLmNoInternet = 'LM (No Internet)';
  static const String textWhisperBaseLocal = 'whisper-base (local)';
  static const String textWhisperSmallServer = 'whisper-small (server)';
  static const String textGeminiFlashServer = 'Gemini 2.5 Flash (server)';
  static const String textNewChat = 'New Chat';
  static const String textGeminiFlash = 'Gemini 2.5 Flash';
  static const String textRoleUser = 'user';
  static const String textRoleAssistant = 'assistant';
  
  // TEXT - SETTINGS SCREEN
  static const String textTheme = 'Theme';
  static const String textUseDarkMode = 'Use Dark Mode';
  static const String textEnableDarkTheme = 'Enable dark theme for the app';
  static const String textDownloadSettings = 'Download Settings';
  static const String textAllowCellular = 'Allow Cellular Download';
  static const String textDownloadOverMobile = 'Download models over mobile data';
  static const String textTtsSettings = 'Text-to-Speech Settings';
  static const String textSpeechSpeed = 'Speech Speed';
  static const String textSpeechPitch = 'Speech Pitch';
  static const String textSpeechVolume = 'Speech Volume';
  static const String textServerConfiguration = 'Server Configuration';
  static const String textServerAddress = 'Server Address';
  static const String textServerIpAddress = 'Server IP Address';
  static const String textServerPort = 'Server Port';
  static const String textAbout = 'About';
  static const String textAppVersion = 'App Version';
  static const String textBuild = 'Build';
  static const String textCancel = 'CANCEL';
  static const String textSave = 'SAVE';
  static const String textSettingsSaved = 'Settings saved (UI only - not persisted)';
  
  // TEXT - MODEL SELECTION SCREEN
  static const String textDownloadInProgress = 'Download(s) already in progress';
  static const String textNoChanges = 'No changes to apply';
  static const String textDeleteModel = 'Delete Model?';
  static const String textDeleteModelMessage = 'Delete %s model from device?';
  static const String textDelete = 'DELETE';
  static const String textDownloadModel = 'Download Model?';
  static const String textDownloadModelMessage = 'Download %s (%s MB)?';
  static const String textDownload = 'DOWNLOAD';
  static const String textDownloadsStarted = '%s download(s) started';
  static const String textErrorApplyingChanges = 'Error applying changes: %s';
  static const String textClearAllChats = 'Clear All Chats';
  static const String textApply = 'Apply';
  static const String textNewChatButton = 'New Chat';
  
  // TEXT - CHAT HISTORY SCREEN
  static const String textNoChatHistory = 'No chat history';
  static const String textStartChatting = 'Start chatting to see your conversations here';
  static const String textRenameChat = 'Rename Chat';
  static const String textEnterNewTitle = 'Enter new title';
  static const String textRename = 'RENAME';
  static const String textDeleteChat = 'Delete Chat?';
  static const String textDeleteChatMessage = 'Delete this chat permanently?';
  static const String textClearAllChatsConfirm = 'Clear All Chats?';
  static const String textClearAllChatsMessage = 'Delete all chat history permanently?';
  static const String textClear = 'CLEAR';
  
  // ERROR MESSAGES
  static const String errorServerUnavailable = 'Cannot connect to server';
  static const String errorNoModels = 'No models available';
  static const String errorNoModelsDownload = 'No models available. Please download a model first.';
  static const String errorMicPermission = 'Microphone permission denied';
  static const String errorRecordingFailed = 'Failed to start recording';
  static const String errorTranscriptionFailed = 'Transcription failed';
  static const String errorChatFailed = 'Failed to get AI response';
  static const String errorDownloadFailed = 'Download failed';
  static const String errorUploadFailed = 'Upload failed';
  
  // DEFAULT VALUES
  static const String mockServerHost = '192.168.0.168';
  static const int mockServerPort = 8000;
  
  // APP METADATA
  static const String appVersion = '2.1.0';
  static const String appBuild = '1';
  
  // MODEL NAMES (These are actual model identifiers)
  static const String modelWhisperTiny = 'whisper-tiny';
  static const String modelWhisperBase = 'whisper-base';
  static const String modelWhisperSmall = 'whisper-small';
  static const String modelSizeTiny = 'tiny';
  static const String modelSizeBase = 'base';
  static const String modelSizeSmall = 'small';
  static const String modelFileEncoder = 'encoder.onnx';
  static const String modelFileDecoder = 'decoder.onnx';

  // ICONS - APP
  static const IconData iconApp = Icons.mic;
  static const IconData iconHome = Icons.home;
  static const IconData iconChat = Icons.chat;
  static const IconData iconChatHistory = Icons.history;
  static const IconData iconAI = Icons.psychology;
  static const IconData iconModel = Icons.model_training;
  static const IconData iconSettings = Icons.settings;
  static const IconData iconMenu = Icons.menu;
  static const IconData iconMore = Icons.more_vert;

  // ICONS - ACTIONS
  static const IconData iconDelete = Icons.delete;
  static const IconData iconDeleteAll = Icons.delete_sweep;
  static const IconData iconEdit = Icons.edit;
  static const IconData iconSave = Icons.save;
  static const IconData iconCancel = Icons.cancel;
  static const IconData iconClose = Icons.close;
  static const IconData iconAdd = Icons.add;
  static const IconData iconRemove = Icons.remove;
  static const IconData iconDownload = Icons.download;
  static const IconData iconUpload = Icons.upload;
  static const IconData iconRefresh = Icons.refresh;
  static const IconData iconSearch = Icons.search;
  static const IconData iconFilter = Icons.filter_list;

  // ICONS - MEDIA & RECORDING
  static const IconData iconMicrophone = Icons.mic;
  static const IconData iconMicrophoneOff = Icons.mic_off;
  static const IconData iconSend = Icons.send;
  static const IconData iconStop = Icons.stop;
  static const IconData iconPlay = Icons.play_arrow;
  static const IconData iconPause = Icons.pause;
  static const IconData iconVolumeUp = Icons.volume_up;
  static const IconData iconVolumeMute = Icons.volume_off;

  // ICONS - STATUS & INDICATORS
  static const IconData iconCheck = Icons.check;
  static const IconData iconCheckCircle = Icons.check_circle;
  static const IconData iconError = Icons.error;
  static const IconData iconWarning = Icons.warning;
  static const IconData iconInfo = Icons.info;
  static const IconData iconCircle = Icons.circle;
  static const IconData iconCircleOutline = Icons.circle_outlined;
  static const IconData iconLoading = Icons.hourglass_empty;

  // ICONS - NAVIGATION
  static const IconData iconArrowBack = Icons.arrow_back;
  static const IconData iconArrowForward = Icons.arrow_forward;
  static const IconData iconArrowUp = Icons.arrow_upward;
  static const IconData iconArrowDown = Icons.arrow_downward;
  static const IconData iconExpandMore = Icons.expand_more;
  static const IconData iconExpandLess = Icons.expand_less;

  // ICONS - EMPTY STATES
  static const IconData iconEmptyChat = Icons.chat_bubble_outline;
  static const IconData iconEmptyList = Icons.inbox;
  static const IconData iconNoData = Icons.folder_open;

  // ============================================================================
  // DEPRECATED - Text Styles - Use ResponsiveConfig.textStyle* instead
  // ============================================================================
  
  @Deprecated('Use ResponsiveConfig.textStyleHeader instead')
  static TextStyle get textStyleHeader => TextStyle(
    fontSize: fontSizeXXL,
    fontWeight: fontWeightBold,
    color: colorWhite,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleTitle instead')
  static TextStyle get textStyleTitle => TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: fontWeightBold,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleSubtitle instead')
  static TextStyle get textStyleSubtitle => TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: fontWeightMedium,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleBody instead')
  static TextStyle get textStyleBody => TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: fontWeightRegular,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleCaption instead')
  static TextStyle get textStyleCaption => TextStyle(
    fontSize: fontSizeSmall,
    color: colorGrey600,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleSubtitle instead')
  static TextStyle get textStyleLabel => TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: fontWeightMedium,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleButton instead')
  static TextStyle get textStyleButton => TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: fontWeightMedium,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleBadge instead')
  static TextStyle get textStyleBadge => TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: fontWeightBold,
  );
  
  @Deprecated('Use ResponsiveConfig.textStyleTimestamp instead')
  static TextStyle get textStyleTimestamp => TextStyle(
    fontSize: fontSizeSmall,
    fontStyle: FontStyle.italic,
    color: colorGrey600,
  );

  // ============================================================================
  // DEPRECATED - EdgeInsets - Use ResponsiveConfig.padding* instead
  // ============================================================================
  
  @Deprecated('Use ResponsiveConfig.paddingZero instead')
  static EdgeInsets get paddingZero => const EdgeInsets.all(0);
  @Deprecated('Use ResponsiveConfig.paddingS instead')
  static EdgeInsets get paddingAllSmall => const EdgeInsets.all(spacingSmall);
  @Deprecated('Use ResponsiveConfig.paddingM instead')
  static EdgeInsets get paddingAllMedium => const EdgeInsets.all(spacingMedium);
  @Deprecated('Use ResponsiveConfig.paddingL instead')
  static EdgeInsets get paddingAllLarge => const EdgeInsets.all(spacingLarge);
  @Deprecated('Use ResponsiveConfig.paddingHorizontalS instead')
  static EdgeInsets get paddingHorizontalSmall => 
      const EdgeInsets.symmetric(horizontal: spacingSmall);
  @Deprecated('Use ResponsiveConfig.paddingHorizontalM instead')
  static EdgeInsets get paddingHorizontalMedium => 
      const EdgeInsets.symmetric(horizontal: spacingMedium);
  @Deprecated('Use ResponsiveConfig.paddingHorizontalL instead')
  static EdgeInsets get paddingHorizontalLarge => 
      const EdgeInsets.symmetric(horizontal: spacingLarge);
  @Deprecated('Use ResponsiveConfig.paddingVerticalS instead')
  static EdgeInsets get paddingVerticalSmall => 
      const EdgeInsets.symmetric(vertical: spacingSmall);
  @Deprecated('Use ResponsiveConfig.paddingVerticalM instead')
  static EdgeInsets get paddingVerticalMedium => 
      const EdgeInsets.symmetric(vertical: spacingMedium);
  @Deprecated('Use ResponsiveConfig.paddingVerticalL instead')
  static EdgeInsets get paddingVerticalLarge => 
      const EdgeInsets.symmetric(vertical: spacingLarge);
  @Deprecated('Use ResponsiveConfig.cardPaddingL instead')
  static EdgeInsets get paddingCard => 
      const EdgeInsets.all(cardPaddingLarge);
  @Deprecated('Use ResponsiveConfig.paddingSymmetric instead')
  static EdgeInsets get paddingListTile => 
      const EdgeInsets.symmetric(horizontal: spacingLarge, vertical: spacingSmall);
  @Deprecated('Use ResponsiveConfig for responsive padding')
  static EdgeInsets get paddingDrawerNested => 
      const EdgeInsets.only(left: drawerNestedIndent, right: spacingLarge);

  // ============================================================================
  // DEPRECATED - BorderRadius - Use ResponsiveConfig.borderRadius* instead
  // ============================================================================
  
  @Deprecated('Use ResponsiveConfig.borderRadiusXS or borderRadiusS instead')
  static BorderRadius get radiusSmall => 
      BorderRadius.circular(borderRadiusSmall);
  @Deprecated('Use ResponsiveConfig.borderRadiusS instead')
  static BorderRadius get radiusMedium => 
      BorderRadius.circular(borderRadiusMedium);
  @Deprecated('Use ResponsiveConfig.borderRadiusM instead')
  static BorderRadius get radiusLarge => 
      BorderRadius.circular(borderRadiusLarge);

  // ============================================================================
  // DEPRECATED - Durations - Use ResponsiveConfig.duration* instead
  // ============================================================================
  
  @Deprecated('Use ResponsiveConfig.durationFast instead')
  static Duration get durationFast => 
      const Duration(milliseconds: animationDurationFast);
  @Deprecated('Use ResponsiveConfig.durationNormal instead')
  static Duration get durationNormal => 
      const Duration(milliseconds: animationDurationNormal);
  @Deprecated('Use ResponsiveConfig.durationSnackbar instead')
  static Duration get durationSnackbar => 
      const Duration(milliseconds: snackbarDuration);
}
