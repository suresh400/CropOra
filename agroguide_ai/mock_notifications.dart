import 'package:hive_flutter/hive_flutter.dart';
import 'package:cropora/models/notification_model.dart';
import 'package:cropora/services/notification_storage.dart';

void main() async {
  await Hive.initFlutter('.');
  final box = await Hive.openBox<Map>(NotificationStorage.boxName);
  
  final storage = NotificationStorage();
  
  final mockData = [
    AppNotification(
      id: '1',
      title: '⚠ Pest Alert',
      message: 'Brown plant hopper detected in nearby fields. Take preventive measures.',
      type: 'pest',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
    ),
    AppNotification(
      id: '2',
      title: 'Fertilizer Reminder',
      message: 'Apply nitrogen fertilizer to your rice crop this week.',
      type: 'fertilizer',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    AppNotification(
      id: '3',
      title: 'AI Expert Response',
      message: 'Your question about wheat rotation has been answered.',
      type: 'ai',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: true,
    ),
    AppNotification(
      id: '4',
      title: 'Weather Update',
      message: 'Heavy rain expected tomorrow. Avoid spraying pesticides.',
      type: 'weather',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
    ),
  ];

  for (var n in mockData) {
    await storage.saveNotification(n);
    print('Saved: ${n.title}');
  }

  print('Mocking complete. Box contains ${box.length} notifications.');
}
