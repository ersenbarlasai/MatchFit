import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('notifications')
        .select(
          '*, sender:profiles!notifications_sender_id_fkey(full_name, avatar_url)',
        )
        .eq('receiver_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('receiver_id', user.id)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  Future<void> deleteAllNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('notifications').delete().eq('receiver_id', user.id);
  }

  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', user.id)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final senderIds = data
              .map((n) => n['sender_id'])
              .whereType<String>()
              .toSet()
              .toList();

          final senderProfiles = <String, Map<String, dynamic>>{};
          if (senderIds.isNotEmpty) {
            final profiles = await _supabase
                .from('profiles')
                .select('id, full_name, avatar_url')
                .inFilter('id', senderIds);

            for (final profile in List<Map<String, dynamic>>.from(profiles)) {
              senderProfiles[profile['id'] as String] = profile;
            }
          }

          return data.map<Map<String, dynamic>>((n) {
            final senderId = n['sender_id'] as String?;
            return Map<String, dynamic>.from({
              ...n,
              'sender': senderId == null ? null : senderProfiles[senderId],
            });
          }).toList();
        });
  }

  Future<void> createNotification({
    required String receiverId,
    required String title,
    required String content,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final senderId = _supabase.auth.currentUser?.id;
    if (senderId == null) return;

    await _supabase.from('notifications').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'title': title,
      'content': content,
      'type': type,
      'data': data,
      'is_read': false,
    });
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

final notificationsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.read(notificationRepositoryProvider).watchNotifications();
    });

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? [];
  return notifications.where((n) => n['is_read'] == false).length;
});
