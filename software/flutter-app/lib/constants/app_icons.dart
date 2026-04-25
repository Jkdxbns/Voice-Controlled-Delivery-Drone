import 'package:flutter/material.dart';

/// ============================================================================
/// APP ICONS - Icon data and responsive icon sizing
/// ============================================================================
/// 
/// Structure:
/// - AppIcons: IconData constants organized by category
/// - IconSize: Static icon size values
/// - AppIconSize: Responsive icon sizing with constraints
/// 
/// Naming Convention:
/// - IconSize.small, IconSize.medium, IconSize.large, IconSize.xlarge
/// - AppIcons.home, AppIcons.settings, AppIcons.actionDelete
/// 
/// Usage:
/// - Icon: Icon(AppIcons.home)
/// - Static size: Icon(AppIcons.home, size: IconSize.medium)
/// - Responsive: Icon(AppIcons.home, size: AppIconSize(context).medium)
/// ============================================================================

/// Icon size constants - Base values in logical pixels
class IconSize {
  IconSize._();

  // ============================================================================
  // ICON SIZES - 4 Main variants + extras
  // ============================================================================
  
  /// Extra small - inline text icons, badges
  static const double xsmall = 12.0;
  
  /// Small - list item icons, compact UI
  static const double small = 16.0;
  
  /// Medium - default icon size, buttons
  static const double medium = 20.0;
  
  /// Large - prominent actions, navigation
  static const double large = 24.0;
  
  /// Extra large - feature icons, cards
  static const double xlarge = 32.0;
  
  /// 2X large - empty states, hero icons
  static const double xxlarge = 48.0;
  
  /// 3X large - splash, major illustrations
  static const double xxxlarge = 64.0;
  
  /// 4X large - full screen illustrations
  static const double xxxxlarge = 96.0;

  // ============================================================================
  // MIN/MAX CONSTRAINTS - For responsive scaling
  // ============================================================================
  
  /// Minimum tappable icon size (accessibility)
  static const double minTappable = 24.0;
  
  /// Minimum visible icon size
  static const double minVisible = 12.0;
  
  /// Maximum practical icon size for UI
  static const double maxUI = 64.0;
  
  /// Maximum practical icon size for illustrations
  static const double maxIllustration = 128.0;
}

/// Responsive icon sizing with min/max constraints
/// Scales icons based on screen size while maintaining usability
class AppIconSize {
  final BuildContext context;
  late final double _screenWidth;
  late final _DeviceCategory _device;

  AppIconSize(this.context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _device = _getDeviceCategory(_screenWidth);
  }

  _DeviceCategory _getDeviceCategory(double width) {
    if (width < 360) return _DeviceCategory.smallPhone;
    if (width < 600) return _DeviceCategory.phone;
    if (width < 900) return _DeviceCategory.tablet;
    if (width < 1200) return _DeviceCategory.laptop;
    return _DeviceCategory.desktop;
  }

  double _getScaleFactor() {
    switch (_device) {
      case _DeviceCategory.smallPhone:
        return 0.85;
      case _DeviceCategory.phone:
        return 1.0;
      case _DeviceCategory.tablet:
        return 1.2;
      case _DeviceCategory.laptop:
        return 1.3;
      case _DeviceCategory.desktop:
        return 1.4;
    }
  }

  /// Scale icon size with constraints
  double _scale(double baseSize, {double? min, double? max}) {
    final scaled = baseSize * _getScaleFactor();
    final minVal = min ?? IconSize.minVisible;
    final maxVal = max ?? (baseSize * 1.6);
    return scaled.clamp(minVal, maxVal);
  }

  // ============================================================================
  // RESPONSIVE ICON SIZES
  // ============================================================================
  
  /// Extra small icons - badges, inline
  double get xsmall => _scale(IconSize.xsmall, min: 10, max: 18);
  
  /// Small icons - compact lists
  double get small => _scale(IconSize.small, min: 14, max: 22);
  
  /// Medium icons - buttons, default
  double get medium => _scale(IconSize.medium, min: 18, max: 28);
  
  /// Large icons - navigation, actions
  double get large => _scale(IconSize.large, min: 22, max: 36);
  
  /// Extra large icons - cards, features
  double get xlarge => _scale(IconSize.xlarge, min: 28, max: 48);
  
  /// 2X large icons - empty states
  double get xxlarge => _scale(IconSize.xxlarge, min: 40, max: 72);
  
  /// 3X large icons - illustrations
  double get xxxlarge => _scale(IconSize.xxxlarge, min: 56, max: 96);

  // ============================================================================
  // PERCENTAGE-BASED SIZES (relative to screen width)
  // ============================================================================
  
  /// Icon as percentage of screen width with constraints
  double percent(double percentage, {double min = 16, double max = 64}) {
    return (_screenWidth * percentage / 100).clamp(min, max);
  }
}

enum _DeviceCategory {
  smallPhone,
  phone,
  tablet,
  laptop,
  desktop,
}

/// Extension for easy access to responsive icon sizes
extension IconSizeExtension on BuildContext {
  AppIconSize get iconSize => AppIconSize(this);
}

/// All app icons organized by category
/// Using Material Icons - can be extended with custom icon fonts
class AppIcons {
  AppIcons._();

  // ============================================================================
  // APP & BRANDING
  // ============================================================================
  
  static const IconData app = Icons.mic;
  static const IconData logo = Icons.mic;

  // ============================================================================
  // NAVIGATION - Primary navigation icons
  // ============================================================================
  
  static const IconData home = Icons.home;
  static const IconData homeOutlined = Icons.home_outlined;
  static const IconData chat = Icons.chat;
  static const IconData chatOutlined = Icons.chat_outlined;
  static const IconData history = Icons.history;
  static const IconData ai = Icons.psychology;
  static const IconData aiOutlined = Icons.psychology_outlined;
  static const IconData model = Icons.model_training;
  static const IconData settings = Icons.settings;
  static const IconData settingsOutlined = Icons.settings_outlined;
  static const IconData menu = Icons.menu;
  static const IconData menuOpen = Icons.menu_open;
  static const IconData moreVert = Icons.more_vert;
  static const IconData moreHoriz = Icons.more_horiz;

  // ============================================================================
  // ACTIONS - Common action icons
  // ============================================================================
  
  static const IconData add = Icons.add;
  static const IconData addCircle = Icons.add_circle;
  static const IconData addCircleOutlined = Icons.add_circle_outline;
  static const IconData remove = Icons.remove;
  static const IconData removeCircle = Icons.remove_circle;
  static const IconData delete = Icons.delete;
  static const IconData deleteOutlined = Icons.delete_outline;
  static const IconData deleteSweep = Icons.delete_sweep;
  static const IconData edit = Icons.edit;
  static const IconData editOutlined = Icons.edit_outlined;
  static const IconData save = Icons.save;
  static const IconData saveOutlined = Icons.save_outlined;
  static const IconData cancel = Icons.cancel;
  static const IconData close = Icons.close;
  static const IconData done = Icons.done;
  static const IconData doneAll = Icons.done_all;
  static const IconData copy = Icons.copy;
  static const IconData paste = Icons.paste;
  static const IconData share = Icons.share;
  static const IconData download = Icons.download;
  static const IconData upload = Icons.upload;
  static const IconData refresh = Icons.refresh;
  static const IconData restore = Icons.restore;
  static const IconData sync = Icons.sync;
  static const IconData search = Icons.search;
  static const IconData filter = Icons.filter_list;
  static const IconData sort = Icons.sort;
  static const IconData clear = Icons.clear;

  // ============================================================================
  // MEDIA & RECORDING
  // ============================================================================
  
  static const IconData microphone = Icons.mic;
  static const IconData microphoneOff = Icons.mic_off;
  static const IconData microphoneNone = Icons.mic_none;
  static const IconData send = Icons.send;
  static const IconData sendOutlined = Icons.send_outlined;
  static const IconData stop = Icons.stop;
  static const IconData stopCircle = Icons.stop_circle;
  static const IconData play = Icons.play_arrow;
  static const IconData playCircle = Icons.play_circle;
  static const IconData pause = Icons.pause;
  static const IconData pauseCircle = Icons.pause_circle;
  static const IconData record = Icons.fiber_manual_record;
  static const IconData volumeUp = Icons.volume_up;
  static const IconData volumeDown = Icons.volume_down;
  static const IconData volumeMute = Icons.volume_off;
  static const IconData volumeOff = Icons.volume_off;
  static const IconData speaker = Icons.speaker;
  static const IconData headphones = Icons.headphones;

  // ============================================================================
  // STATUS & INDICATORS
  // ============================================================================
  
  static const IconData check = Icons.check;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData checkCircleOutlined = Icons.check_circle_outline;
  static const IconData error = Icons.error;
  static const IconData errorOutlined = Icons.error_outline;
  static const IconData warning = Icons.warning;
  static const IconData warningAmber = Icons.warning_amber;
  static const IconData info = Icons.info;
  static const IconData infoOutlined = Icons.info_outline;
  static const IconData help = Icons.help;
  static const IconData helpOutlined = Icons.help_outline;
  static const IconData circle = Icons.circle;
  static const IconData circleOutlined = Icons.circle_outlined;
  static const IconData radioChecked = Icons.radio_button_checked;
  static const IconData radioUnchecked = Icons.radio_button_unchecked;
  static const IconData loading = Icons.hourglass_empty;
  static const IconData pending = Icons.pending;

  // ============================================================================
  // NAVIGATION ARROWS
  // ============================================================================
  
  static const IconData arrowBack = Icons.arrow_back;
  static const IconData arrowBackIos = Icons.arrow_back_ios;
  static const IconData arrowForward = Icons.arrow_forward;
  static const IconData arrowForwardIos = Icons.arrow_forward_ios;
  static const IconData arrowUp = Icons.arrow_upward;
  static const IconData arrowDown = Icons.arrow_downward;
  static const IconData arrowLeft = Icons.arrow_left;
  static const IconData arrowRight = Icons.arrow_right;
  static const IconData expandMore = Icons.expand_more;
  static const IconData expandLess = Icons.expand_less;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData unfoldMore = Icons.unfold_more;
  static const IconData unfoldLess = Icons.unfold_less;

  // ============================================================================
  // EMPTY STATES & PLACEHOLDERS
  // ============================================================================
  
  static const IconData emptyChat = Icons.chat_bubble_outline;
  static const IconData emptyInbox = Icons.inbox;
  static const IconData emptyFolder = Icons.folder_open;
  static const IconData emptySearch = Icons.search_off;
  static const IconData noData = Icons.folder_open;
  static const IconData noConnection = Icons.wifi_off;
  static const IconData noResults = Icons.sentiment_dissatisfied;

  // ============================================================================
  // CONNECTIVITY & NETWORK
  // ============================================================================
  
  static const IconData wifi = Icons.wifi;
  static const IconData wifiOff = Icons.wifi_off;
  static const IconData bluetooth = Icons.bluetooth;
  static const IconData bluetoothOff = Icons.bluetooth_disabled;
  static const IconData bluetoothConnected = Icons.bluetooth_connected;
  static const IconData bluetoothSearching = Icons.bluetooth_searching;
  static const IconData cloud = Icons.cloud;
  static const IconData cloudOff = Icons.cloud_off;
  static const IconData cloudDone = Icons.cloud_done;
  static const IconData cloudUpload = Icons.cloud_upload;
  static const IconData cloudDownload = Icons.cloud_download;
  static const IconData signal = Icons.signal_cellular_4_bar;
  static const IconData signalOff = Icons.signal_cellular_off;
  static const IconData server = Icons.dns;

  // ============================================================================
  // DEVICES
  // ============================================================================
  
  static const IconData phone = Icons.phone_android;
  static const IconData tablet = Icons.tablet_android;
  static const IconData laptop = Icons.laptop;
  static const IconData desktop = Icons.desktop_windows;
  static const IconData device = Icons.devices;
  static const IconData deviceOther = Icons.devices_other;
  static const IconData watch = Icons.watch;
  static const IconData tv = Icons.tv;

  // ============================================================================
  // USER & PROFILE
  // ============================================================================
  
  static const IconData person = Icons.person;
  static const IconData personOutlined = Icons.person_outline;
  static const IconData personAdd = Icons.person_add;
  static const IconData people = Icons.people;
  static const IconData group = Icons.group;
  static const IconData account = Icons.account_circle;
  static const IconData accountOutlined = Icons.account_circle_outlined;

  // ============================================================================
  // SETTINGS & PREFERENCES
  // ============================================================================
  
  static const IconData tune = Icons.tune;
  static const IconData brightness = Icons.brightness_6;
  static const IconData darkMode = Icons.dark_mode;
  static const IconData lightMode = Icons.light_mode;
  static const IconData language = Icons.language;
  static const IconData notifications = Icons.notifications;
  static const IconData notificationsOff = Icons.notifications_off;
  static const IconData security = Icons.security;
  static const IconData lock = Icons.lock;
  static const IconData lockOpen = Icons.lock_open;
  static const IconData privacy = Icons.privacy_tip;
  static const IconData storage = Icons.storage;
  static const IconData memory = Icons.memory;

  // ============================================================================
  // MISCELLANEOUS
  // ============================================================================
  
  static const IconData star = Icons.star;
  static const IconData starOutlined = Icons.star_outline;
  static const IconData starHalf = Icons.star_half;
  static const IconData favorite = Icons.favorite;
  static const IconData favoriteOutlined = Icons.favorite_outline;
  static const IconData bookmark = Icons.bookmark;
  static const IconData bookmarkOutlined = Icons.bookmark_outline;
  static const IconData flag = Icons.flag;
  static const IconData flagOutlined = Icons.flag_outlined;
  static const IconData label = Icons.label;
  static const IconData labelOutlined = Icons.label_outline;
  static const IconData tag = Icons.local_offer;
  static const IconData calendar = Icons.calendar_today;
  static const IconData time = Icons.access_time;
  static const IconData timer = Icons.timer;
  static const IconData schedule = Icons.schedule;
  static const IconData attachment = Icons.attachment;
  static const IconData link = Icons.link;
  static const IconData linkOff = Icons.link_off;
  static const IconData code = Icons.code;
  static const IconData terminal = Icons.terminal;
}
