import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

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

    // Remove any existing relationship in both directions first
    await _supabase.from('user_relationships')
        .delete()
        .or('and(sender_id.eq.$myId,receiver_id.eq.$targetUserId),and(sender_id.eq.$targetUserId,receiver_id.eq.$myId)');

    // Then insert the block record fresh
    await _supabase.from('user_relationships').insert({
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
        .map((data) {
          final match = data.where((row) => row['receiver_id'] == targetUserId);
          return match.isEmpty ? null : match.first['status'] as String?;
        });
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

// Checks if the CURRENT user has blocked the target (reverse direction)
final isBlockingProvider = FutureProvider.autoDispose.family<bool, String>((ref, targetUserId) async {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return false;

  final response = await Supabase.instance.client
      .from('user_relationships')
      .select()
      .eq('sender_id', myId)
      .eq('receiver_id', targetUserId)
      .eq('status', 'blocked')
      .maybeSingle();

  return response != null;
});

final incomingFollowRequestProvider = FutureProvider.autoDispose.family<bool, String>((ref, senderId) async {
  final myId = Supabase.instance.client.auth.currentUser?.id;
  if (myId == null) return false;

  final response = await Supabase.instance.client
      .from('user_relationships')
      .select()
      .eq('sender_id', senderId)
      .eq('receiver_id', myId)
      .eq('status', 'pending')
      .maybeSingle();
  
  return response != null;
});

final userFriendsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final sb = Supabase.instance.client;
  
  try {
    // Step 1: Get all receiver_ids that this user is following
    final relationships = await sb
        .from('user_relationships')
        .select('receiver_id')
        .eq('sender_id', userId)
        .eq('status', 'following');
    
    final receiverIds = List<Map<String, dynamic>>.from(relationships)
        .map((r) => r['receiver_id'] as String)
        .toList();

    if (receiverIds.isEmpty) return [];

    // Step 2: Fetch profiles for those IDs
    final profiles = await sb
        .from('profiles')
        .select('id, full_name, avatar_url, trust_score')
        .inFilter('id', receiverIds);

    return List<Map<String, dynamic>>.from(profiles);
  } catch (e) {
    debugPrint('Friends query error: $e');
    return [];
  }
});
