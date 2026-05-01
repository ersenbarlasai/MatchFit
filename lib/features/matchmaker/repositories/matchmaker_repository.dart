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

  /// Recommendation Engine Rules
  List<String> getSuggestedSports(List<String> userSports) {
    final suggestions = <String>{};
    
    for (var sport in userSports) {
      final s = sport.toLowerCase();
      // Rules
      if (s.contains('tenis')) suggestions.add('Padel');
      if (s.contains('padel')) suggestions.add('Tenis');
      if (s.contains('yol koşusu') || s.contains('trail run')) suggestions.add('Yol Bisikleti');
      if (s.contains('yol bisikleti')) suggestions.add('Yol Koşusu');
      if (s.contains('ağırlık antrenmanı') || s.contains('functional')) suggestions.add('Calisthenics');
      if (s.contains('calisthenics')) suggestions.add('Functional Training');
    }
    
    // Remove duplicates that user already likes
    suggestions.removeWhere((s) => userSports.contains(s));
    return suggestions.toList();
  }

  Future<List<Map<String, dynamic>>> getPopularSportsInCity(String province) async {
    // This would typically be an aggregation query
    // For now, return a mocked list or a simplified query
    final response = await _supabase
        .from('events')
        .select('sports(name), location_name')
        .ilike('location_name', '%$province%');
        
    // Simple count aggregation logic
    final counts = <String, int>{};
    for (var e in response) {
      final name = e['sports']?['name'] as String?;
      if (name != null) counts[name] = (counts[name] ?? 0) + 1;
    }
    
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => {'name': e.key, 'count': e.value}).toList();
  }
}
