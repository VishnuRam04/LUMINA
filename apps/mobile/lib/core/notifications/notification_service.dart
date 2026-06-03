import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
        print('Notification Tapped! Payload: ${notificationResponse.payload}');
      },
    );

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

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
        matchDateTimeComponents: DateTimeComponents.time, 
      );
      print(">>>>> NOTIFICATION SCHEDULED SUCCESSFULLY! <<<<<");
    } catch (e, stacktrace) {
      print(">>>>> SCHEDULING FAILED: $e <<<<<");
      print(stacktrace);
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
