import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_model.dart';
import 'notification_storage.dart';

// Top level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // We need to initialize Hive here as well since this runs in a separate isolate
  final storage = NotificationStorage();
  await storage.init(); 
  
  final notification = AppNotification(
    id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: message.notification?.title ?? message.data['title'] ?? 'New Alert',
    message: message.notification?.body ?? message.data['message'] ?? '',
    type: message.data['type'] ?? 'system',
    timestamp: DateTime.now(),
  );
  
  await storage.saveNotification(notification);
}

class NotificationService {
  final NotificationStorage storage;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService({required this.storage});

  Future<void> init() async {
    // Initialize Timezone for scheduling
    tz.initializeTimeZones();

    await requestPermissions();
    
    // Initialize Local Notifications (Unsupported on Web)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _localNotifications.initialize(
        settings: initializationSettings,
      );
    }

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get device token
    try {
      String? token = await _fcm.getToken();
      debugPrint("FCM Token: $token");
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
    }

    // Handle foreground messaging
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Got a message whilst in the foreground!');
      
      final notification = AppNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification?.title ?? message.data['title'] ?? 'New Alert',
        message: message.notification?.body ?? message.data['message'] ?? '',
        type: message.data['type'] ?? 'system',
        timestamp: DateTime.now(),
      );

      // Save to Hive
      await storage.saveNotification(notification);

      if (message.notification != null) {
        showLocalNotification(
          title: notification.title,
          body: notification.message,
          id: message.hashCode,
        );
      }
    });

    // Handle when app is opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened via notification!');
      // Navigation logic can be added here if needed
    });
  }

  Future<void> showLocalNotification({required String title, required String body, int id = 0}) async {
    if (kIsWeb) {
      debugPrint("Web Platform: Bypassing local notification show()");
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cropora_alerts',
      'System Alerts',
      channelDescription: 'Notifications for system alerts, pest and weather info',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  Future<void> scheduleFertilizerReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb) {
      debugPrint("Web Platform: Bypassing scheduleFertilizerReminder()");
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cropora_reminders',
      'Farming Reminders',
      channelDescription: 'Notifications for crop and fertilizer schedules',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> requestPermissions() async {
    // Request push notification permission
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('User granted notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting FCM permissions: $e');
    }

    // Request exact alarms and notification permissions natively for Android 13+
    if (!kIsWeb) {
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      
      // Request location permission via permission_handler for mobile
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
      ].request();
      
      debugPrint("Location permission: ${statuses[Permission.location]}");
    } else {
      // On Web, we usually rely on Geolocator's internal request or the browser's native prompt
      debugPrint("Web Platform: Skipping specific permission_handler requests for Camera/Photos");
    }
  }

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (e) {
      return null;
    }
  }
}
