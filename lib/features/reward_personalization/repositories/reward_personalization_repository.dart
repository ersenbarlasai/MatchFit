import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rewardPersonalizationRepositoryProvider = Provider((ref) => RewardPersonalizationRepository());

class RewardPersonalizationRepository {
  final _supabase = Supabase.instance.client;

  /// Generates personalized reward recommendations for the user.
  /// Uses @RewardPersonalization scoring engine.
  Future<Map<String, dynamic>> generateRecommendations({
    String? city,
    String? sportId,
    String? idempotencyKey,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return {'status': 'error', 'message': 'User not authenticated'};

      final response = await _supabase.rpc('generate_reward_recommendations', params: {
        'p_user_id': user.id,
        'p_city': city,
        'p_sport_id': sportId,
        'p_idempotency_key': idempotencyKey,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Fetches existing recommendations for the current user.
  Future<List<Map<String, dynamic>>> getRecommendations() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.rpc('get_reward_recommendations', params: {
        'p_user_id': user.id,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Logs engagement events (impression, click, dismiss) for a reward.
  Future<String?> logRecommendationEvent({
    required String rewardId,
    required String eventType,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc('log_reward_recommendation_event', params: {
        'p_reward_id': rewardId,
        'p_event_type': eventType,
        'p_metadata': metadata ?? {},
        'p_idempotency_key': idempotencyKey,
      });
      return response as String?;
    } catch (e) {
      return null;
    }
  }
}
