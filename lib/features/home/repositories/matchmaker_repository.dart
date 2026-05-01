import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchmakerRepository {
  final SupabaseClient _supabase;

  MatchmakerRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getSuggestedMembers() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // 1. Get current user's sports interests
      final mySportsResponse = await _supabase
          .from('user_sports_preferences')
          .select('sport_id')
          .eq('user_id', currentUser.id);
      
      final mySportIds = (mySportsResponse as List).map((s) => s['sport_id'] as String).toList();

      if (mySportIds.isEmpty) {
        // Fallback: Get active members with high trust score
        final fallbackResponse = await _supabase
            .from('profiles')
            .select('*')
            .neq('id', currentUser.id)
            .order('trust_score', ascending: false)
            .limit(8);
        return List<Map<String, dynamic>>.from(fallbackResponse);
      }

      // 2. Find other users who have at least one matching sport
      // Using a join-like query to get profiles directly
      final suggestionsResponse = await _supabase
          .from('user_sports_preferences')
          .select('profiles(*)')
          .filter('sport_id', 'in', mySportIds)
          .neq('user_id', currentUser.id)
          .limit(20);

      // 3. Process and de-duplicate profiles
      final seenIds = <String>{};
      final List<Map<String, dynamic>> finalSuggestions = [];
      
      for (final item in suggestionsResponse) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        if (profile != null && !seenIds.contains(profile['id'])) {
          seenIds.add(profile['id']);
          finalSuggestions.add(profile);
        }
      }

      // If we don't have enough suggestions from sports, add some high trust users
      if (finalSuggestions.length < 5) {
        final extras = await _supabase
            .from('profiles')
            .select('*')
            .neq('id', currentUser.id)
            .order('trust_score', ascending: false)
            .limit(5);
        
        for (final profile in extras) {
          if (!seenIds.contains(profile['id'])) {
            seenIds.add(profile['id']);
            finalSuggestions.add(profile);
          }
        }
      }

      return finalSuggestions.take(10).toList();
    } catch (e) {
      print('Error fetching suggestions: $e');
      return [];
    }
  }
}

final matchmakerRepositoryProvider = Provider<MatchmakerRepository>((ref) {
  return MatchmakerRepository(Supabase.instance.client);
});

final suggestedMembersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(matchmakerRepositoryProvider).getSuggestedMembers();
});
