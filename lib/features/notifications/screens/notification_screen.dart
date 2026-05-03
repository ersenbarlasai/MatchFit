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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  ref.read(notificationRepositoryProvider).markAllAsRead();
                } else if (value == 'delete_all') {
                  ref.read(notificationRepositoryProvider).deleteAllNotifications();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Text('Tümünü okundu işaretle', style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Text('Tümünü sil', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: MatchFitTheme.accentGreen,
            labelColor: MatchFitTheme.accentGreen,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Okunmamış'),
              Tab(text: 'Okunmuş'),
            ],
          ),
        ),
        body: notificationsAsync.when(
          data: (notifications) {
            final unread = notifications.where((n) => n['is_read'] != true).toList();
            final read = notifications.where((n) => n['is_read'] == true).toList();

            return TabBarView(
              children: [
                _buildList(unread, 'Harika!', 'Okunmamış bildiriminiz yok.'),
                _buildList(read, 'Bildirim yok', ''),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String emptyTitle, String emptySub) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(emptySub,
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final notification = items[index];
        return _NotificationItem(key: ValueKey(notification['id']), notification: notification);
      },
    );
  }
}


class _NotificationItem extends ConsumerStatefulWidget {
  final Map<String, dynamic> notification;
  const _NotificationItem({super.key, required this.notification});

  @override
  ConsumerState<_NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends ConsumerState<_NotificationItem> {
  bool _isHandled = false;
  String? _handleStatus;

  @override
  Widget build(BuildContext context) {
    final isRead = widget.notification['is_read'] as bool? ?? false;
    final createdAt = DateTime.parse(widget.notification['created_at']);
    final timeStr = _formatTime(createdAt);
    final type = widget.notification['type'] as String?;
    final senderId = widget.notification['sender_id'] as String?;

    final senderName = widget.notification['title'] ?? 'System';
    final message = widget.notification['message'] ?? '';

    // Check actual relationship status from DB to determine if buttons should show
    // This is the source of truth - not just is_read flag
    final relationshipAsync = (type == 'follow_request' && senderId != null)
        ? ref.watch(incomingFollowRequestProvider(senderId))
        : const AsyncValue.data(false);
    
    // Button should show if: it's a follow_request AND the request is still pending in DB
    final hasPendingRequest = relationshipAsync.value ?? false;
    final showButtons = type == 'follow_request' && hasPendingRequest && !_isHandled;
    final isEffectivelyRead = isRead || _isHandled || (type == 'follow_request' && !hasPendingRequest && !_isHandled);

    return Dismissible(
      key: Key(widget.notification['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        ref.read(notificationRepositoryProvider).deleteNotification(widget.notification['id']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isEffectivelyRead ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEffectivelyRead ? Colors.white.withOpacity(0.05) : MatchFitTheme.accentGreen.withOpacity(0.2),
          ),
        ),
        child: Column(
        children: [
          ListTile(
            onTap: () {
              if (!isRead && !_isHandled) {
                ref.read(notificationRepositoryProvider).markAsRead(widget.notification['id']);
              }
              if (senderId != null) {
                context.push('/user-profile', extra: senderId);
              }
            },
            leading: _getIconForType(type),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(senderName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isEffectivelyRead ? Colors.white70 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                ),
                const SizedBox(width: 8),
                Text(timeStr,
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message,
                  style: TextStyle(
                    color: isEffectivelyRead ? Colors.white38 : Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  )),
            ),
            trailing: !isEffectivelyRead
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: MatchFitTheme.accentGreen, shape: BoxShape.circle),
                  )
                : null,
          ),
          if (showButtons)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (senderId != null) {
                          setState(() { _isHandled = true; _handleStatus = 'Accepted'; });
                          await ref.read(socialRepositoryProvider).updateFollowStatus(senderId, true);
                          await ref.read(notificationRepositoryProvider).markAsRead(widget.notification['id']);
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
                          setState(() { _isHandled = true; _handleStatus = 'Rejected'; });
                          await ref.read(socialRepositoryProvider).updateFollowStatus(senderId, false);
                          await ref.read(notificationRepositoryProvider).markAsRead(widget.notification['id']);
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
            )
          else if (_isHandled && _handleStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(
                    _handleStatus == 'Accepted' ? Icons.check_circle_outline : Icons.cancel_outlined,
                    size: 16,
                    color: _handleStatus == 'Accepted' ? MatchFitTheme.accentGreen : Colors.white30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _handleStatus!,
                    style: TextStyle(
                      color: _handleStatus == 'Accepted' ? MatchFitTheme.accentGreen : Colors.white30,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _getIconForType(String? type) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'follow_request':
        iconData = Icons.person_add_outlined;
        color = MatchFitTheme.accentGreen;
        break;
      case 'follow_approved':
        iconData = Icons.check_circle_outline;
        color = MatchFitTheme.accentGreen;
        break;
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
