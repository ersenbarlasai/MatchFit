import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final refereeRepositoryProvider = Provider((ref) => RefereeRepository());

class RefereeRepository {
  final _supabase = Supabase.instance.client;

  /// Fetches the user's trust score from their profile
  Future<int> getUserTrustScore(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('trust_score')
        .eq('id', userId)
        .maybeSingle();

    if (response != null && response['trust_score'] != null) {
      return response['trust_score'] as int;
    }
    return 100; // Default score
  }

  /// Checks if the user is currently in a restricted/bench mode (active penalty)
  Future<bool> isUserRestricted(String userId) async {
    final response = await _supabase
        .from('user_penalties')
        .select('id, expires_at')
        .eq('user_id', userId)
        .eq('status', 'active')
        .gte('expires_at', DateTime.now().toUtc().toIso8601String())
        .limit(1);

    return response.isNotEmpty;
  }

  /// Logs a check-in for an event using coordinates
  Future<void> logEventCheckin({
    required String eventId,
    required double lat,
    required double lng,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _supabase.from('event_checkins').insert({
      'event_id': eventId,
      'user_id': user.id,
      'location_lat': lat,
      'location_lng': lng,
      'status': 'successful',
    });
  }
}
