import 'dart:async';
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

  // ⭐️ NEW: Stream to handle navigation
  final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // ⭐️ FIX: Add onDidReceiveNotificationResponse
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle navigation here. For now, we'll just print payload.
        // You can add logic to navigate to specific screens based on payload.
        print("Notification Tapped: ${response.payload}");
      },
    );

    // ⭐️ CRITICAL FOR ANDROID 13+: Request Permission
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload, // 👈 Add this
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
      payload: payload, // 👈 Pass it here
    );
  }

  // 2. Schedule Notification (For Itineraries)
  Future<void> scheduleEventNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final now = DateTime.now();
    final triggerTime = scheduledTime.subtract(const Duration(minutes: 15));

    // ⭐️ FIX: If the 15-min warning time has passed but the event hasn't happened yet,
    // show the notification immediately (or 5 seconds from now).
    if (triggerTime.isBefore(now)) {
      if (scheduledTime.isAfter(now)) {
        // Event is soon (within 15 mins), notify in 5 seconds
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          'Happening Soon: $title',
          body,
          tz.TZDateTime.from(now.add(const Duration(seconds: 5)), tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'itinerary_channel',
              'Itinerary Reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      return;
    }

    // Standard scheduling logic...
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
