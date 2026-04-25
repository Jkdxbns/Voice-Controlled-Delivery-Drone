import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';

class SystemControlService {
  static final SystemControlService instance = SystemControlService._();
  SystemControlService._();

  Future<bool> setAlarm({
    required int hour,
    required int minute,
    String? label,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          if (label != null && label.trim().isNotEmpty)
            'android.intent.extra.alarm.MESSAGE': label.trim(),
        },
      );

      await intent.launch();
      AppLogger.success('[SYSTEM] Alarm intent launched');
      return true;
    } catch (e) {
      AppLogger.error('[SYSTEM] Failed to set alarm: $e');
      return false;
    }
  }

  Future<bool> addCalendarEvent({
    required DateTime startTime,
    required int durationMinutes,
    required String title,
    String? location,
    String? notes,
  }) async {
    try {
      final endTime = startTime.add(Duration(minutes: durationMinutes));
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        data: 'content://com.android.calendar/events',
        arguments: <String, dynamic>{
          'beginTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
          'title': title,
          if (location != null && location.trim().isNotEmpty) 'eventLocation': location.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'description': notes.trim(),
        },
      );

      await intent.launch();
      AppLogger.success('[SYSTEM] Calendar intent launched');
      return true;
    } catch (e) {
      AppLogger.error('[SYSTEM] Failed to add calendar event: $e');
      return false;
    }
  }

  Future<bool> placeCall({
    required String phoneNumber,
  }) async {
    try {
      final uri = Uri.parse('tel:$phoneNumber');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        AppLogger.error('[SYSTEM] Could not launch dialer');
        return false;
      }
      AppLogger.success('[SYSTEM] Dialer launched');
      return true;
    } catch (e) {
      AppLogger.error('[SYSTEM] Failed to place call: $e');
      return false;
    }
  }
}
