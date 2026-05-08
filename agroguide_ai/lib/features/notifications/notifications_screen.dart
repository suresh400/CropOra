import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/notification_model.dart';
import '../../services/notification_storage.dart';
import '../../services/translation_service.dart';
import '../../core/theme/app_colors.dart';
import 'notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<NotificationStorage>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.translate(context, 'notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await storage.markAllAsRead();
              setState(() {});
            },
            child: Text(
              TranslationService.translate(context, 'mark_all_read'),
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: TranslationService.translate(context, 'all')),
            Tab(text: TranslationService.translate(context, 'unread')),
            Tab(text: TranslationService.translate(context, 'alerts')),
          ],
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Map>(NotificationStorage.boxName).listenable(),
        builder: (context, box, _) {
          final allNotifications = storage.getAllNotifications();

          if (allNotifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsRegular.bellSlash, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    TranslationService.translate(context, 'no_history'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationList(allNotifications, storage),
              _buildNotificationList(
                allNotifications.where((n) => !n.isRead).toList(),
                storage,
              ),
              _buildNotificationList(
                allNotifications.where((n) => n.type == 'weather').toList(),
                storage,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications, NotificationStorage storage) {
    if (notifications.isEmpty) {
      return const Center(
        child: Text("Nothing to see here yet!", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return NotificationTile(
          notification: notification,
          onTap: () async {
            await storage.updateReadStatus(notification.id, true);
            // Optional: Process based on type (e.g., navigate to specific screen)
          },
          onDelete: () async {
            await storage.deleteNotification(notification.id);
          },
        );
      },
    );
  }
}
