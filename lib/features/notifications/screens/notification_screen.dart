import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import '../repositories/notification_repository.dart';
import 'package:intl/intl.dart';
import 'package:matchfit/features/profile/repositories/social_repository.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationRepositoryProvider).markAllAsRead(),
            child: const Text('Mark all as read',
                style: TextStyle(color: MatchFitTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text('All caught up!',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('No new notifications for now.',
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationItem(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final Map<String, dynamic> notification;
  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification['is_read'] as bool? ?? false;
    final createdAt = DateTime.parse(notification['created_at']);
    final timeStr = _formatTime(createdAt);
    final type = notification['type'] as String?;
    final senderId = notification['sender_id'] as String?;
    
    final senderName = notification['title'] ?? 'System';
    final message = notification['message'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRead ? Colors.white.withOpacity(0.05) : MatchFitTheme.accentGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              if (!isRead) {
                ref.read(notificationRepositoryProvider).markAsRead(notification['id']);
              }
              if (senderId != null) {
                context.push('/user-profile', extra: senderId);
              }
            },
            leading: _getIconForType(type),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(senderName,
                    style: TextStyle(
                      color: isRead ? Colors.white70 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
                Text(timeStr,
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message,
                  style: TextStyle(
                    color: isRead ? Colors.white38 : Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  )),
            ),
            trailing: !isRead
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: MatchFitTheme.accentGreen, shape: BoxShape.circle),
                  )
                : null,
          ),
          if (type == 'follow_request' && !isRead)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (senderId != null) {
                          await ref.read(socialRepositoryProvider).updateFollowStatus(senderId, true);
                          await ref.read(notificationRepositoryProvider).markAsRead(notification['id']);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MatchFitTheme.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (senderId != null) {
                          await ref.read(socialRepositoryProvider).updateFollowStatus(senderId, false);
                          await ref.read(notificationRepositoryProvider).markAsRead(notification['id']);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _getIconForType(String? type) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'join_request':
        iconData = Icons.person_add_outlined;
        color = const Color(0xFF0052FF);
        break;
      case 'join_approved':
        iconData = Icons.check_circle_outline;
        color = MatchFitTheme.accentGreen;
        break;
      case 'join_rejected':
        iconData = Icons.cancel_outlined;
        color = Colors.redAccent;
        break;
      default:
        iconData = Icons.notifications_outlined;
        color = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 18),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(date);
  }
}
