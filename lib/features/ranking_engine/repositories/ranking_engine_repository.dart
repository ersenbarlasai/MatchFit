import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RankingEngineRepository {
  final _supabase = Supabase.instance.client;

  /// Sadece etkinlik açılan şehirleri çeker
  Future<List<String>> getAvailableCities() async {
    try {
      final response = await _supabase.rpc('get_active_event_cities');

      final cities = List<Map<String, dynamic>>.from(response)
          .map((e) => e['city'] as String)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      cities.sort();
      return ['Tüm Şehirler', ...cities];
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching cities: $e');
      return ['Tüm Şehirler'];
    }
  }

  /// Mevcut branşları sports tablosundan çeker
  Future<List<String>> getAvailableSports() async {
    try {
      final response = await _supabase
          .from('sports')
          .select('name')
          .not('name', 'is', null)
          .neq('name', '');

      final sports = List<Map<String, dynamic>>.from(response)
          .map((e) => e['name'] as String)
          .toSet()
          .toList();
      sports.sort();
      return ['Tüm Branşlar', ...sports];
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching sports: $e');
      return ['Tüm Branşlar'];
    }
  }

  /// Filtreli Leaderboard verilerini çeker (Global, City, Sport)
  Future<List<Map<String, dynamic>>> getFilteredLeaderboard({
    String? city,
    String? sportName,
    int limit = 100,
  }) async {
    try {
      final response = await _supabase.rpc('get_filtered_leaderboard', params: {
        'p_city': city,
        'p_sport_name': sportName,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching filtered leaderboard: $e');
      return [];
    }
  }

  /// Global Leaderboard verilerini çeker
  Future<List<Map<String, dynamic>>> getGlobalLeaderboard({int limit = 100}) async {
    try {
      final response = await _supabase.rpc('get_global_leaderboard', params: {
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching global leaderboard: $e');
      return [];
    }
  }

  /// City Leaderboard verilerini çeker
  Future<List<Map<String, dynamic>>> getCityLeaderboard(String city, {int limit = 100}) async {
    try {
      final response = await _supabase.rpc('get_city_leaderboard', params: {
        'p_city': city,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching city leaderboard: $e');
      return [];
    }
  }

  /// Friends Leaderboard verilerini çeker
  Future<List<Map<String, dynamic>>> getFriendsLeaderboard({int limit = 100}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.rpc('get_friends_leaderboard', params: {
        'p_user_id': user.id,
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching friends leaderboard: $e');
      return [];
    }
  }

  /// Weekly Ranking verilerini çeker
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 100}) async {
    try {
      final response = await _supabase.rpc('get_weekly_leaderboard', params: {
        'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@RankingEngine] Error fetching weekly leaderboard: $e');
      return [];
    }
  }
}
