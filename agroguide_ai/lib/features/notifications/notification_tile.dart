import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/notification_model.dart';
import '../../../core/theme/app_colors.dart';

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case 'weather':
        return PhosphorIconsRegular.cloudSun;
      case 'fertilizer':
        return PhosphorIconsRegular.leaf;
      case 'recommendation':
        return PhosphorIconsRegular.listChecks;
      case 'ai':
        return PhosphorIconsRegular.robot;
      case 'system':
      default:
        return PhosphorIconsRegular.bell;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'weather':
        return Colors.blue;
      case 'fertilizer':
        return Colors.green;
      case 'recommendation':
        return Colors.orange;
      case 'ai':
        return Colors.purple;
      case 'system':
      default:
        return Colors.grey;
    }
  }

  bool _isAlert() {
    return notification.type == 'weather';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAlert = _isAlert();
    final bool isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnread ? (isAlert ? Colors.red.withOpacity(0.05) : Colors.blue.withOpacity(0.05)) : null,
            border: isAlert
                ? Border.all(color: Colors.red.withOpacity(0.3), width: 1.5)
                : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
            borderRadius: isAlert ? BorderRadius.circular(12) : null,
          ),
          margin: isAlert ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getIconColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(), color: _getIconColor(), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: isUnread || isAlert ? FontWeight.bold : FontWeight.w500,
                              fontSize: 16,
                              color: isAlert ? Colors.red.shade900 : null,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a').format(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
