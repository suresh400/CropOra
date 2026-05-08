import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_model.dart';

class NotificationStorage {
  static const String boxName = 'notifications_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(boxName);
  }

  Box<Map> get _box => Hive.box<Map>(boxName);

  Future<void> saveNotification(AppNotification notification) async {
    await _box.put(notification.id, notification.toMap());
  }

  Future<void> updateReadStatus(String id, bool isRead) async {
    final map = _box.get(id);
    if (map != null) {
      final notification = AppNotification.fromMap(Map<String, dynamic>.from(map));
      notification.isRead = isRead;
      await _box.put(id, notification.toMap());
    }
  }

  Future<void> deleteNotification(String id) async {
    await _box.delete(id);
  }

  List<AppNotification> getAllNotifications() {
    final List<AppNotification> notifications = [];
    for (var value in _box.values) {
      notifications.add(AppNotification.fromMap(Map<String, dynamic>.from(value)));
    }
    // Sort by timestamp descending
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  Future<void> markAllAsRead() async {
    final keys = _box.keys;
    for (var key in keys) {
      final map = _box.get(key);
      if (map != null) {
        final notification = AppNotification.fromMap(Map<String, dynamic>.from(map));
        if (!notification.isRead) {
          notification.isRead = true;
          await _box.put(key, notification.toMap());
        }
      }
    }
  }

  int getUnreadCount() {
    return _box.values.where((map) => map['isRead'] == false).length;
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
