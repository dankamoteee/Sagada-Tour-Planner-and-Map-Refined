import 'dart:ui'; // Import this for Color
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    // CHANGE 1: Use a dedicated transparent icon for the small icon.
    // Make sure 'ic_notification.png' exists in android/app/src/main/res/drawable/
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');
    // If you haven't added the file yet, keep '@mipmap/ic_launcher' for now,
    // but it will likely remain a white square on newer Androids.

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'updates_channel',
          'News & Alerts',
          channelDescription: 'Notifications for news and road closures',
          importance: Importance.max,
          priority: Priority.high,

          // CHANGE 2: Add Color and Large Icon
          color: Color(0xFF3A6A55), // Your app's primary green color
          // This uses the full-color launcher icon as the "large" graphic on the right
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // 2. Schedule Notification (For Itineraries)
  Future<void> scheduleEventNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Notify 15 minutes before the event
    final triggerTime = scheduledTime.subtract(const Duration(minutes: 15));

    // Don't schedule if the time has already passed
    if (triggerTime.isBefore(DateTime.now())) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Upcoming Event: $title',
      body,
      tz.TZDateTime.from(triggerTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'itinerary_channel',
          'Itinerary Reminders',
          channelDescription: 'Reminders for your planned trips',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
