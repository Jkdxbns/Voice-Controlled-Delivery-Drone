import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/constants.dart';
import '../../services/preferences_service.dart';
import '../../services/shared_folder_service.dart';
import '../../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  // late bool _allowCellularDownload; // Commented out - feature removed
  late bool _useDarkMode;
  late bool _ttsEnabled;
  late double _ttsSpeed;
  late double _ttsPitch;
  late double _ttsVolume;
  String? _sharedFolderUri;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    final prefs = PreferencesService.instance;
    setState(() {
      // _allowCellularDownload = prefs.allowCellularDownload; // Commented out - feature removed
      _useDarkMode = prefs.isDarkMode;
      _ttsEnabled = prefs.ttsEnabled;
      _ttsSpeed = prefs.ttsSpeed;
      _ttsPitch = prefs.ttsPitch;
      _ttsVolume = prefs.ttsVolume;
      _sharedFolderUri = prefs.sharedFolderUri;
    });
  }

  Future<void> _saveThemePreference() async {
    final prefs = PreferencesService.instance;
    await prefs.setDarkMode(_useDarkMode);
    widget.onThemeChanged(_useDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final spacing = context.spacing;
    final typography = context.typography;
    
    return Scaffold(
      body: ListView(
        primary: false,
        children: [
          // Theme Settings
          _buildSectionHeader(AppStrings.settingsTheme),
          SwitchListTile(
            title: Text(AppStrings.settingsUseDarkMode),
            subtitle: Text(AppStrings.settingsEnableDarkTheme),
            value: _useDarkMode,
            onChanged: (value) {
              setState(() {
                _useDarkMode = value;
              });
              _saveThemePreference();
            },
          ),
          const Divider(),

          // Shared Folder Section
          _buildSectionHeader(AppStrings.settingsSharedFolder),
          ListTile(
            leading: const Icon(AppIcons.storage),
            title: const Text(AppStrings.settingsSelectSharedFolder),
            subtitle: Text(
              _sharedFolderUri == null || _sharedFolderUri!.isEmpty
                  ? AppStrings.settingsSharedFolderNotSet
                  : AppStrings.settingsSharedFolderSet,
            ),
            onTap: () async {
              final uri = await SharedFolderService.instance.pickSharedFolder();
              if (uri != null && mounted) {
                setState(() {
                  _sharedFolderUri = uri;
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text(AppStrings.settingsClearSharedFolder),
            subtitle: const Text(AppStrings.settingsSharedFolderClearHint),
            onTap: () async {
              await SharedFolderService.instance.clearSharedFolder();
              if (mounted) {
                setState(() {
                  _sharedFolderUri = null;
                });
              }
            },
          ),
          const Divider(),
          
          // Download Settings - COMMENTED OUT
          // _buildSectionHeader(AppStrings.settingsDownload),
          // SwitchListTile(
          //   title: Text(AppStrings.settingsAllowCellular),
          //   subtitle: Text(AppStrings.settingsDownloadOverMobile),
          //   value: _allowCellularDownload,
          //   onChanged: (value) {
          //     setState(() {
          //       _allowCellularDownload = value;
          //     });
          //   },
          // ),
          // const Divider(),

          // Permissions Section
          _buildSectionHeader(AppStrings.settingsPermissions),
          ListTile(
            leading: const Icon(AppIcons.settings),
            title: const Text(AppStrings.settingsOpenAppSettings),
            subtitle: const Text(AppStrings.settingsOpenSystemSettings),
            onTap: () async {
              await openAppSettings();
            },
          ),
          const Divider(),

          // TTS Settings
          _buildSectionHeader(AppStrings.settingsTts),
          SwitchListTile(
            title: const Text(AppStrings.settingsEnableTts),
            subtitle: const Text(AppStrings.settingsSpeakResponses),
            value: _ttsEnabled,
            onChanged: (value) async {
              setState(() {
                _ttsEnabled = value;
              });
              await PreferencesService.instance.setTtsEnabled(value);
              if (!value) {
                // Stop any ongoing speech
                TtsService.instance.stop();
              }
            },
          ),
          ListTile(
            title: Text(AppStrings.settingsSpeechSpeed),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.settingsCurrent} ${_ttsSpeed.toStringAsFixed(2)}x',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
                Slider(
                  value: _ttsSpeed,
                  min: 0.1,
                  max: 2.0,
                  divisions: 19,
                  label: '${_ttsSpeed.toStringAsFixed(2)}x',
                  onChanged: (value) {
                    setState(() {
                      _ttsSpeed = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Save to preferences when user finishes dragging slider
                    await TtsService.instance.updateSpeed(value);
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(AppStrings.settingsSpeechPitch),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.settingsCurrent} ${_ttsPitch.toStringAsFixed(2)}',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
                Slider(
                  value: _ttsPitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: _ttsPitch.toStringAsFixed(2),
                  onChanged: (value) {
                    setState(() {
                      _ttsPitch = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Save to preferences when user finishes dragging slider
                    await TtsService.instance.updatePitch(value);
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(AppStrings.settingsSpeechVolume),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.settingsCurrent} ${(_ttsVolume * 100).toStringAsFixed(0)}%',
                  style: typography.caption.copyWith(color: colors.textSecondary),
                ),
                Slider(
                  value: _ttsVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_ttsVolume * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() {
                      _ttsVolume = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Save to preferences when user finishes dragging slider
                    await TtsService.instance.updateVolume(value);
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          // App Info - COMMENTED OUT
          // _buildSectionHeader(AppStrings.settingsAbout),
          // ListTile(
          //   title: Text(AppStrings.settingsAppVersion),
          //   subtitle: Text(AppStrings.appVersion),
          // ),
          // ListTile(
          //   title: Text(AppStrings.settingsBuild),
          //   subtitle: Text(AppStrings.appBuild),
          // ),
          
          // Version Label at Bottom
          Padding(
            padding: spacing.all(Spacing.medium),
            child: Center(
              child: Text(
                AppStrings.settingsVersion,
                style: typography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeightStyle.medium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final spacing = context.spacing;
    final typography = context.typography;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.medium, 
        spacing.large, 
        spacing.medium, 
        spacing.small
      ),
      child: Text(
        title,
        style: typography.titleMedium.copyWith(
          fontWeight: FontWeightStyle.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
