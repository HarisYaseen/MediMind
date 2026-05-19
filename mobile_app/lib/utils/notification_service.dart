import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> init() async {
    if (kIsWeb) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Initialize Timezone Database
    tz.initializeTimeZones();
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      // Handle both old String and new TimezoneInfo return types seamlessly!
      final String timeZoneName = tzResult is String ? tzResult : tzResult.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // Default to Karachi, Pakistan (GMT+5) as robust fallback
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    }

    // Request native runtime permission for Android 13+ (Android 15)
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // Also request exact alarms permission (crucial for Android 13+ / 14 / 15)
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyMedicineAlarm({
    required int id,
    required String title,
    required String body,
    required String timeString,
  }) async {
    if (kIsWeb) return;

    // Parse standard formats like "08:00 AM" or "10:57 PM"
    int hour = 8;
    int minute = 0;
    try {
      final cleanTime = timeString.trim().toUpperCase();
      final parts = cleanTime.split(' ');
      final timeParts = parts[0].split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      final amPm = parts[1];

      if (amPm == 'PM' && hour != 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
    } catch (e) {
      print('Error parsing scheduled alarm time $timeString: $e');
      return;
    }

    final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

    // Strong repeating alarm vibration pattern
    final Int64List vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medimind_ringing_looping_alarms_v1', // Brand new channel ID to force Android to create a looping channel!
      'Medicine Looping Alarms',
      channelDescription: 'Continuous looping alarms for scheduled medications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      // Connects directly to default system alarm ringtone natively!
      sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      ongoing: true, // Persistent until handled
      category: AndroidNotificationCategory.alarm, // Classifies as a system-level alarm
      audioAttributesUsage: AudioAttributesUsage.alarm, // Route through the hardware alarm audio channel
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4: Loops the ringtone/sound endlessly until dismissed!
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default', // Plays default native iOS notification sound
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Using new v21 named parameter syntax and removed obsolete uiLocalNotificationDateInterpretation
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.alarmClock, // Uses Android native AlarmManager Clock API to wake up and ring
      matchDateTimeComponents: DateTimeComponents.time, // Repeating everyday
    );
  }

  Future<void> showNotification(int id, String title, String body) async {
    if (kIsWeb) return;
    
    // Strong repeating alarm vibration pattern (vibrate 1s, pause 0.5s, vibrate 1s, etc.)
    final Int64List vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medimind_ringing_looping_alarms_v1', // Route to the looping channel!
      'Medicine Looping Alarms',
      channelDescription: 'Continuous looping alarms for scheduled medications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      ongoing: true, // Persistent until handled
      category: AndroidNotificationCategory.alarm, // Classifies as a system-level alarm
      audioAttributesUsage: AudioAttributesUsage.alarm, // Route through the hardware alarm audio channel
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT = 4: Loops the ringtone/sound endlessly until dismissed!
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }
}
