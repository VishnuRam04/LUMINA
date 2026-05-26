import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone package for scheduled alarms
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    // Android Initialization Settings
    // Note: 'app_icon' must exist in android/app/src/main/res/drawable/
    // You can use @mipmap/ic_launcher for now if you haven't created a custom one.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization Settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        // Here you can handle what happens when the user taps on the notification
        print('Notification Tapped! Payload: ${notificationResponse.payload}');
      },
    );

    // Explicitly ask for iOS permissions
    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Helper method to setup the platform-specific visual channel details
  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'lumina_reminders_channel',
        'Study Reminders',
        channelDescription: 'Reminders for study plans and tasks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // 1. Instant Notification (For testing)
  Future<void> showInstantNotification({int id = 0, required String title, required String body}) async {
    print(">>>>> TRIGGERING INSTANT NOTIFICATION: $title <<<<<");
    try {
      await flutterLocalNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(),
      );
      print(">>>>> INSTANT NOTIFICATION TRIGGERED SUCCESSFULLY! <<<<<");
    } catch (e, stacktrace) {
      print(">>>>> INSTANT NOTIFICATION FAILED: $e <<<<<");
      print(stacktrace);
    }
  }

  // 2. Scheduled Notification (For Tasks / Events)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    print(">>>>> SCHEDULING NOTIFICATION FOR $scheduledTime: $title <<<<<");
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Optional: if it repeats
      );
      print(">>>>> NOTIFICATION SCHEDULED SUCCESSFULLY! <<<<<");
    } catch (e, stacktrace) {
      print(">>>>> SCHEDULING FAILED: $e <<<<<");
      print(stacktrace);
    }
  }

  // 3. Cancel a specific notification (If user deletes the task)
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  // 4. Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
