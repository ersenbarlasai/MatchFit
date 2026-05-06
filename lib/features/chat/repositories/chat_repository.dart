import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatRepository {
  final SupabaseClient _supabase;
  ChatRepository(this._supabase);

  // Send a message
  Future<void> sendMessage(String receiverId, String content) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase.from('direct_messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'content': content.trim(),
    });
  }

  // Get message stream between current user and a target user
  Stream<List<Map<String, dynamic>>> watchMessages(String targetUserId) {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return Stream.value([]);

    return _supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          // Filter messages that belong to this conversation
          return data.where((msg) {
            final isSender = msg['sender_id'] == myId && msg['receiver_id'] == targetUserId;
            final isReceiver = msg['sender_id'] == targetUserId && msg['receiver_id'] == myId;
            return isSender || isReceiver;
          }).toList();
        });
  }

  // Mark messages as read
  Future<void> markAsRead(String senderId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase
        .from('direct_messages')
        .update({'is_read': true})
        .eq('sender_id', senderId)
        .eq('receiver_id', myId)
        .eq('is_read', false);
  }

  // Get conversations list
  Future<List<Map<String, dynamic>>> getConversations() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _supabase.rpc('get_conversations', params: {
      'p_user_id': myId,
    });
    
    return List<Map<String, dynamic>>.from(response);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});

final conversationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(chatRepositoryProvider).getConversations();
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, targetUserId) {
  return ref.read(chatRepositoryProvider).watchMessages(targetUserId);
});
