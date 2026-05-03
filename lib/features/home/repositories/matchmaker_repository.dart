import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/core/services/location_service.dart';

class MatchmakerRepository {
  final SupabaseClient _supabase;

  MatchmakerRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getSuggestedMembers({double? lat, double? lng}) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // 1. Eğer konum varsa, PostGIS üzerinden tam eşleşme ve mesafe hesabı yapan RPC'yi çağır (25km)
      if (lat != null && lng != null) {
        try {
          final response = await _supabase.rpc('get_recommended_users', params: {
            'user_lat': lat,
            'user_lng': lng,
            'radius_meters': 25000,
          });
          
          if (response != null) {
            final List list = response as List;
            if (list.isNotEmpty) {
              return List<Map<String, dynamic>>.from(list);
            }
          }
        } catch (rpcErr) {
          print('Matchmaker RPC Error: $rpcErr');
        }
      }

      // 2. Fallback: Konum yoksa veya RPC sonucu boşsa standart ilgi alanlarına göre getir (eski mantık)
      final mySportsResponse = await _supabase
          .from('user_sports_preferences')
          .select('sport_id')
          .eq('user_id', currentUser.id);
      
      final mySportIds = (mySportsResponse as List).map((s) => s['sport_id'] as String).toList();

      if (mySportIds.isEmpty) {
        return []; // Kullanıcının hiçbir spor ilgi alanı yoksa ve yakınlarda da kimse yoksa WhatsApp davetine düşsün
      }

      final suggestionsResponse = await _supabase
          .from('user_sports_preferences')
          .select('profiles(*)')
          .filter('sport_id', 'in', mySportIds)
          .neq('user_id', currentUser.id)
          .limit(20);

      final seenIds = <String>{};
      final List<Map<String, dynamic>> finalSuggestions = [];
      
      for (final item in suggestionsResponse) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        if (profile != null && !seenIds.contains(profile['id'])) {
          seenIds.add(profile['id']);
          profile['shared_sports'] = []; // Fallback için boş dizi
          finalSuggestions.add(profile);
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
  final userLoc = await ref.watch(userLocationProvider.future);
  return ref.read(matchmakerRepositoryProvider).getSuggestedMembers(
    lat: userLoc?.latitude,
    lng: userLoc?.longitude,
  );
});
