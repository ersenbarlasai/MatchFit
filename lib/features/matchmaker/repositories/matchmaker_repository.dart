import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matchmakerProvider = Provider((ref) => MatchmakerRepository());

class MatchmakerRepository {
  final _supabase = Supabase.instance.client;

  /// Suggests the best events based on user location, skill level, and trust score
  Future<List<Map<String, dynamic>>> getSmartMatches(String userId) async {
    // 1. Get user preferences
    final prefsResponse = await _supabase
        .from('user_sports_preferences')
        .select('sport_id, skill_level')
        .eq('user_id', userId);
        
    final preferredSports = prefsResponse.map((p) => p['sport_id']).toList();

    // 2. Fetch events that match sports and require high trust score
    var query = _supabase
        .from('events')
        .select('*, sports(name), profiles(full_name, trust_score)')
        .eq('status', 'open');
        
    if (preferredSports.isNotEmpty) {
      query = query.inFilter('sport_id', preferredSports);
    }

    final response = await query.order('event_date', ascending: true);
    
    // In a real Matchmaker Agent, we would calculate a "Match Score" here
    // based on GPS distance, mutual friends, and trust score parity.
    
    return List<Map<String, dynamic>>.from(response);
  }
}
