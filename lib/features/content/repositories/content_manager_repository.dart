import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contentManagerProvider = Provider((ref) => ContentManagerRepository());

class ContentManagerRepository {
  final _supabase = Supabase.instance.client;

  /// Creates a post-event content (Success Card)
  Future<void> createEventPost({
    required String eventId,
    String? caption,
    String? mediaUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final post = await _supabase.from('posts').insert({
      'user_id': user.id,
      'event_id': eventId,
      'caption': caption ?? 'Had a great workout!',
      'media_url': mediaUrl,
    }).select('id').single();

    // Optionally: Tag other participants
    final participants = await _supabase
        .from('event_participants')
        .select('user_id')
        .eq('event_id', eventId)
        .neq('user_id', user.id);

    for (var p in participants) {
      await _supabase.from('post_tags').insert({
        'post_id': post['id'],
        'tagged_user_id': p['user_id'],
        'status': 'pending', // Requires their approval
      });
    }
  }

  /// Approves a tag request
  Future<void> approveTag(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('post_tags')
        .update({'status': 'approved'})
        .eq('post_id', postId)
        .eq('tagged_user_id', user.id);
  }
}
