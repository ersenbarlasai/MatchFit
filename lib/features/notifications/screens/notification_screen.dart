import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import '../repositories/notification_repository.dart';
import 'package:intl/intl.dart';
import 'package:matchfit/features/profile/repositories/social_repository.dart';
import '../../events/repositories/event_repository.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final t = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text(
            t.notifications,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  ref.read(notificationRepositoryProvider).markAllAsRead();
                  ref.invalidate(notificationsProvider);
                } else if (value == 'delete_all') {
                  ref
                      .read(notificationRepositoryProvider)
                      .deleteAllNotifications();
                  ref.invalidate(notificationsProvider);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_all_read',
                  child: Text(
                    t.markAllRead,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Text(
                    t.deleteAll,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            indicatorColor: MatchFitTheme.accentGreen,
            labelColor: MatchFitTheme.accentGreen,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: t.unread),
              Tab(text: t.read),
            ],
          ),
        ),
        body: notificationsAsync.when(
          data: (notifications) {
            final unread = notifications
                .where((n) => n['is_read'] != true)
                .toList();
            final readList = notifications
                .where((n) => n['is_read'] == true)
                .toList();

            return TabBarView(
              children: [
                _buildList(unread, t.great, t.noUnreadNotifications),
                _buildList(readList, t.noNotifications, ''),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
          ),
          error: (e, _) => Center(
            child: Text(
              '${t.error}: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> items,
    String emptyTitle,
    String emptySub,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySub,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final notification = items[index];
        return _NotificationItem(
          key: ValueKey(notification['id']),
          notification: notification,
        );
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
    final t = AppLocalizations.of(context);
    final isRead = widget.notification['is_read'] as bool? ?? false;
    final createdAt = DateTime.parse(widget.notification['created_at']);
    final timeStr = _formatTime(createdAt, t);
    final type = widget.notification['type'] as String?;
    final senderId = widget.notification['sender_id'] as String?;
    final senderProfile =
        widget.notification['sender'] as Map<String, dynamic>?;
    final senderName =
        senderProfile?['full_name'] as String? ?? 'Bir kullanıcı';

    // Title: use explicit title field if present, else derive from type
    final rawTitle = widget.notification['title'] as String?;
    final displayTitle = rawTitle ?? _titleForType(type);

    // Message: DB trigger uses 'message' column; manual inserts may use 'content'
    final message =
        widget.notification['message'] as String? ??
        widget.notification['content'] as String? ??
        '';

    // Check actual relationship status from DB to determine if buttons should show
    // This is the source of truth - not just is_read flag
    final relationshipAsync = (type == 'follow_request' && senderId != null)
        ? ref.watch(incomingFollowRequestProvider(senderId))
        : const AsyncValue.data(false);

    // Button should show if: it's a follow_request AND the request is still pending in DB
    final hasPendingRequest = relationshipAsync.value ?? false;
    final showButtons =
        type == 'follow_request' && hasPendingRequest && !_isHandled;
    final isEventRequest = (type == 'join_request' || type == 'event_request');
    final isEffectivelyRead =
        isRead ||
        _isHandled ||
        (type == 'follow_request' && !hasPendingRequest && !_isHandled);

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
        ref
            .read(notificationRepositoryProvider)
            .deleteNotification(widget.notification['id']);
        ref.invalidate(notificationsProvider);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isEffectivelyRead
              ? Colors.white.withOpacity(0.03)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEffectivelyRead
                ? Colors.white.withOpacity(0.05)
                : MatchFitTheme.accentGreen.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            ListTile(
              onTap: () async {
                if (!isRead && !_isHandled) {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markAsRead(widget.notification['id']);
                  ref.invalidate(notificationsProvider);
                }
                final eventId =
                    widget.notification['event_id'] as String? ??
                    widget.notification['data']?['event_id'] as String?;
                final isEventNotification =
                    type == 'join_request' ||
                    type == 'event_request' ||
                    type == 'join_approved' ||
                    type == 'join_rejected';

                if (isEventNotification && eventId != null) {
                  final eventData = await ref
                      .read(eventRepositoryProvider)
                      .getEventDetails(eventId);
                  if (eventData != null && context.mounted) {
                    context.push('/event-detail', extra: eventData);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Etkinlik bulunamadı veya silinmiş olabilir.',
                        ),
                      ),
                    );
                  }
                } else if (senderId != null && context.mounted) {
                  context.push('/user-profile', extra: senderId);
                }
              },
              leading: _getIconForType(type),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      displayTitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isEffectivelyRead
                            ? Colors.white70
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (senderName != 'Bir kullanıcı')
                      Text(
                        senderName,
                        style: TextStyle(
                          color: isEffectivelyRead
                              ? MatchFitTheme.accentGreen.withOpacity(0.5)
                              : MatchFitTheme.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (message.isNotEmpty)
                      Text(
                        message,
                        style: TextStyle(
                          color: isEffectivelyRead
                              ? Colors.white38
                              : Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
              trailing: !isEffectivelyRead
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: MatchFitTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
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
                            setState(() {
                              _isHandled = true;
                              _handleStatus = t.accepted;
                            });
                            await ref
                                .read(socialRepositoryProvider)
                                .updateFollowStatus(senderId, true);
                            await ref
                                .read(notificationRepositoryProvider)
                                .markAsRead(widget.notification['id']);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MatchFitTheme.accentGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          t.accept,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          if (senderId != null) {
                            setState(() {
                              _isHandled = true;
                              _handleStatus = t.rejected;
                            });
                            await ref
                                .read(socialRepositoryProvider)
                                .updateFollowStatus(senderId, false);
                            await ref
                                .read(notificationRepositoryProvider)
                                .markAsRead(widget.notification['id']);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          t.reject,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (isEventRequest && !isRead)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(notificationRepositoryProvider)
                          .markAsRead(widget.notification['id']);
                      final eventId =
                          widget.notification['event_id'] as String? ??
                          widget.notification['data']?['event_id'] as String?;
                      if (eventId != null && context.mounted) {
                        // Fetch the event data and navigate to detail screen
                        final eventData = await ref
                            .read(eventRepositoryProvider)
                            .getEventDetails(eventId);
                        if (eventData != null && context.mounted) {
                          context.push('/event-detail', extra: eventData);
                        } else if (context.mounted) {
                          // Fallback if event is deleted or not found
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Etkinlik bulunamadı veya silinmiş olabilir.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.sports,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Etkinliği Yönet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              )
            else if (_isHandled && _handleStatus != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Icon(
                      _handleStatus == t.accepted
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 16,
                      color: _handleStatus == t.accepted
                          ? MatchFitTheme.accentGreen
                          : Colors.white30,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _handleStatus!,
                      style: TextStyle(
                        color: _handleStatus == t.accepted
                            ? MatchFitTheme.accentGreen
                            : Colors.white30,
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

  String _titleForType(String? type) {
    switch (type) {
      case 'join_request':
      case 'event_request':
        return 'Yeni Katılım İsteği';
      case 'join_approved':
        return 'İstek Onaylandı! 🎉';
      case 'join_rejected':
        return 'İstek Reddedildi';
      case 'follow_request':
        return 'Takip İsteği';
      case 'follow_approved':
        return 'Takip İsteği Kabul Edildi';
      default:
        return 'Bildirim';
    }
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
      case 'event_request':
        iconData = Icons.sports_outlined;
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

  String _formatTime(DateTime date, AppLocalizations t) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return t.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${t.minutesAgo}';
    if (diff.inHours < 24) return '${diff.inHours} ${t.hoursAgo}';
    return DateFormat('MMM d').format(date);
  }
}
