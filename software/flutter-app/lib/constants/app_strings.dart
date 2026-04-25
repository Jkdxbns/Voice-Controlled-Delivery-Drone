/// ============================================================================
/// APP STRINGS - All text content, labels, and messages
/// ============================================================================
/// 
/// Structure:
/// - Organized by screen/feature
/// - Grouped by category (labels, messages, errors, etc.)
/// 
/// Naming Convention:
/// - AppStrings.screenNameLabelName
/// - AppStrings.errorSomething
/// 
/// Usage:
/// - Text(AppStrings.homeTitle)
/// - showError(AppStrings.errorServerUnavailable)
/// 
/// Future: Can be extended for i18n/l10n support
/// ============================================================================

class AppStrings {
  AppStrings._();

  // ============================================================================
  // APP INFO
  // ============================================================================
  
  static const String appName = 'Audio Recorder';
  static const String appVersion = '2.1.0';
  static const String appBuild = '1';

  // ============================================================================
  // NAVIGATION - Menu items, tabs
  // ============================================================================
  
  static const String navHome = 'Home';
  static const String navTools = 'Tools';
  static const String navAiAssistant = 'AI Assistant';
  static const String navChatHistory = 'Chat History';
  static const String navModelSelection = 'Model Selection';
  static const String navSettings = 'Settings';
  static const String navScanner = 'Scanner';
  static const String navTerminal = 'Terminal';
  static const String navController = 'Controller';
  static const String navServerConfig = 'Server Configuration';
  static const String navDeviceLookup = 'Device Lookup';
  static const String navAppSettings = 'App Settings';

  // ============================================================================
  // HOME SCREEN
  // ============================================================================
  
  static const String homeTitle = 'Home';
  static const String homeSubtitleAi = 'Chat with AI';
  static const String homeSubtitleHistory = 'View past chats';
  static const String homeSubtitleModels = 'Manage models';
  static const String homeSubtitleSettings = 'App settings';

  // ============================================================================
  // AI ASSISTANT SCREEN
  // ============================================================================
  
  static const String aiTitle = 'Voice Assistant';
  static const String aiStt = 'STT:';
  static const String aiLocal = 'Local';
  static const String aiServer = 'Server';
  static const String aiLocalInference = 'Local Inference';
  static const String aiStartConversation = 'Start a conversation';
  static const String aiTypeOrRecord = 'Type a message or record audio';
  static const String aiTypeMessage = 'Type a message...';
  static const String aiNewChat = 'New Chat';
  
  /// Placeholders for model names
  static const String aiSttNoInternet = 'STT (No Internet)';
  static const String aiLmNoInternet = 'LM (No Internet)';
  static const String aiWhisperBaseLocal = 'whisper-base (local)';
  static const String aiWhisperSmallServer = 'whisper-small (server)';
  static const String aiGeminiFlashServer = 'Gemini 2.5 Flash (server)';
  static const String aiGeminiFlash = 'Gemini 2.5 Flash';
  
  /// Role identifiers
  static const String roleUser = 'user';
  static const String roleAssistant = 'assistant';

  // ============================================================================
  // SETTINGS SCREEN
  // ============================================================================
  
  static const String settingsTitle = 'Settings';
  static const String settingsTheme = 'Theme';
  static const String settingsUseDarkMode = 'Use Dark Mode';
  static const String settingsEnableDarkTheme = 'Enable dark theme for the app';
  static const String settingsDownload = 'Download Settings';
  static const String settingsAllowCellular = 'Allow Cellular Download';
  static const String settingsDownloadOverMobile = 'Download models over mobile data';
  static const String settingsTts = 'Text-to-Speech Settings';
  static const String settingsSpeechSpeed = 'Speech Speed';
  static const String settingsSpeechPitch = 'Speech Pitch';
  static const String settingsSpeechVolume = 'Speech Volume';
  static const String settingsServer = 'Server Configuration';
  static const String settingsServerAddress = 'Server Address';
  static const String settingsServerIp = 'Server IP Address';
  static const String settingsServerPort = 'Server Port';
  static const String settingsAbout = 'About';
  static const String settingsAppVersion = 'App Version';
  static const String settingsBuild = 'Build';
  static const String settingsPermissions = 'Permissions';
  static const String settingsSharedFolder = 'Shared Folder';
  static const String settingsSelectSharedFolder = 'Select shared folder';
  static const String settingsSharedFolderNotSet = 'No shared folder selected';
  static const String settingsSharedFolderSet = 'Shared folder selected';
  static const String settingsClearSharedFolder = 'Clear shared folder';
  static const String settingsSharedFolderClearHint = 'Remove access to the current shared folder';
  static const String settingsMicPermission = 'Microphone Permission';
  static const String settingsMicGranted = 'Granted - Voice recording enabled';
  static const String settingsMicNotGranted = 'Not granted - Required for voice recording';
  static const String settingsChecking = 'Checking...';
  static const String settingsGrant = 'Grant';
  static const String settingsRequestPermissions = 'Request Permissions Again';
  static const String settingsShowPermDialogs = 'Show permission dialogs again';
  static const String settingsResetPermDialogs = 'Reset Permission Dialogs';
  static const String settingsAllowDialogsNextLaunch = 'Allow dialogs to show on next app launch';
  static const String settingsOpenAppSettings = 'App Settings';
  static const String settingsOpenSystemSettings = 'Open system app settings';
  static const String settingsResetDialogTitle = 'Reset Permission Dialogs';
  static const String settingsResetDialogContent = 'This will reset the permission dialog flags so you can see them again on next app restart. Current granted permissions will not be revoked.';
  static const String settingsReset = 'Reset';
  static const String settingsPermDialogsReset = 'Permission dialogs will show on next app launch';
  static const String settingsEnableTts = 'Enable Text-to-Speech';
  static const String settingsSpeakResponses = 'Speak AI responses aloud';
  static const String settingsCurrent = 'Current:';
  static const String settingsVersion = 'v10.0';

  // ============================================================================
  // MODEL SELECTION SCREEN
  // ============================================================================
  
  static const String modelsTitle = 'Models';
  static const String modelsDownloadInProgress = 'Download(s) already in progress';
  static const String modelsNoChanges = 'No changes to apply';
  static const String modelsDeleteTitle = 'Delete Model?';
  static const String modelsDeleteMessage = 'Delete %s model from device?';
  static const String modelsDownloadTitle = 'Download Model?';
  static const String modelsDownloadMessage = 'Download %s (%s MB)?';
  static const String modelsDownloadsStarted = '%s download(s) started';

  // ============================================================================
  // CHAT HISTORY SCREEN
  // ============================================================================
  
  static const String historyTitle = 'Chat History';
  static const String historyEmpty = 'No chat history';
  static const String historyEmptySubtitle = 'Start chatting to see your conversations here';
  static const String historyRenameTitle = 'Rename Chat';
  static const String historyRenameHint = 'Enter new title';
  static const String historyDeleteTitle = 'Delete Chat?';
  static const String historyDeleteMessage = 'Delete this chat permanently?';
  static const String historyClearAllTitle = 'Clear All Chats?';
  static const String historyClearAllMessage = 'Delete all chat history permanently?';

  // ============================================================================
  // COMMON ACTIONS
  // ============================================================================
  
  static const String actionCancel = 'CANCEL';
  static const String actionSave = 'SAVE';
  static const String actionDelete = 'DELETE';
  static const String actionDownload = 'DOWNLOAD';
  static const String actionRename = 'RENAME';
  static const String actionClear = 'CLEAR';
  static const String actionApply = 'Apply';
  static const String actionNewChat = 'New Chat';
  static const String actionClearAll = 'Clear All Chats';
  static const String actionRetry = 'Retry';
  static const String actionOk = 'OK';
  static const String actionYes = 'Yes';
  static const String actionNo = 'No';
  static const String actionConfirm = 'Confirm';
  static const String actionClose = 'Close';
  static const String actionDone = 'Done';
  static const String actionEdit = 'Edit';
  static const String actionRefresh = 'Refresh';

  // ============================================================================
  // STATUS MESSAGES
  // ============================================================================
  
  static const String statusRecordingTooShort = 'Recording too short';
  static const String statusTranscriptionCancelled = 'Transcription cancelled';
  static const String statusGenerationStopped = 'Generation stopped';
  static const String statusSettingsSaved = 'Settings saved (UI only - not persisted)';
  static const String statusServerConfigSaved = 'Server configuration saved';
  static const String statusResetToDefault = 'Reset to default configuration';

  // ============================================================================
  // ERROR MESSAGES
  // ============================================================================
  
  static const String errorGeneric = 'Something went wrong';
  static const String errorServerUnavailable = 'Cannot connect to server';
  static const String errorNoModels = 'No models available';
  static const String errorNoModelsDownload = 'No models available. Please download a model first.';
  static const String errorMicPermission = 'Microphone permission denied';
  static const String errorRecordingFailed = 'Failed to start recording';
  static const String errorTranscriptionFailed = 'Transcription failed';
  static const String errorChatFailed = 'Failed to get AI response';
  static const String errorDownloadFailed = 'Download failed';
  static const String errorUploadFailed = 'Upload failed';
  static const String errorApplyingChanges = 'Error applying changes: %s';
  static const String errorHostEmpty = 'Host cannot be empty';
  static const String errorInvalidPort = 'Invalid port number';
  static const String errorSaveFailed = 'Failed to save configuration';

  // ============================================================================
  // MODEL NAMES & IDENTIFIERS
  // ============================================================================
  
  static const String modelWhisperTiny = 'whisper-tiny';
  static const String modelWhisperBase = 'whisper-base';
  static const String modelWhisperSmall = 'whisper-small';
  static const String modelSizeTiny = 'tiny';
  static const String modelSizeBase = 'base';
  static const String modelSizeSmall = 'small';
  static const String modelFileEncoder = 'encoder.onnx';
  static const String modelFileDecoder = 'decoder.onnx';

  // ============================================================================
  // NETWORK & SERVER DEFAULTS
  // ============================================================================
  
  static const String defaultServerHost = '192.168.0.168';
  static const int defaultServerPort = 8000;

  // ============================================================================
  // BLUETOOTH
  // ============================================================================
  
  static const String bluetoothClassicPlusBle = 'Classic + BLE devices';
}
