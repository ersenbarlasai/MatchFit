import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialRepository {
  final SupabaseClient _supabase;
  SocialRepository(this._supabase);

  Future<void> sendFollowRequest(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase.from('user_relationships').upsert({
      'sender_id': myId,
      'receiver_id': targetUserId,
      'status': 'pending',
    });
  }

  Future<void> unfollowUser(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase.from('user_relationships')
        .delete()
        .eq('sender_id', myId)
        .eq('receiver_id', targetUserId);
  }

  Future<void> updateFollowStatus(String senderId, bool approve) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    if (approve) {
      await _supabase.from('user_relationships')
          .update({'status': 'following'})
          .eq('sender_id', senderId)
          .eq('receiver_id', myId);
    } else {
      await _supabase.from('user_relationships')
          .delete()
          .eq('sender_id', senderId)
          .eq('receiver_id', myId);
    }
  }

  Future<void> blockUser(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase.from('user_relationships').upsert({
      'sender_id': myId,
      'receiver_id': targetUserId,
      'status': 'blocked',
    });
  }

  Future<void> unblockUser(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase.from('user_relationships')
        .delete()
        .eq('sender_id', myId)
        .eq('receiver_id', targetUserId)
        .eq('status', 'blocked');
  }

  Stream<String?> watchRelationshipStatus(String targetUserId) {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return Stream.value(null);

    return _supabase
        .from('user_relationships')
        .stream(primaryKey: ['id'])
        .eq('sender_id', myId)
        .eq('receiver_id', targetUserId)
        .map((data) => data.isEmpty ? null : data.first['status'] as String?);
  }

  Future<bool> isBlockedBy(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return false;

    final response = await _supabase.rpc('is_blocked', params: {
      'target_user_id': targetUserId,
      'observer_id': myId,
    });
    return response as bool? ?? false;
  }
}

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository(Supabase.instance.client);
});

final relationshipStatusProvider = StreamProvider.autoDispose.family<String?, String>((ref, targetUserId) {
  return ref.read(socialRepositoryProvider).watchRelationshipStatus(targetUserId);
});

final isBlockedByProvider = FutureProvider.autoDispose.family<bool, String>((ref, targetUserId) async {
  return ref.read(socialRepositoryProvider).isBlockedBy(targetUserId);
});
