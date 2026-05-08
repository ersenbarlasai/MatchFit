import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final partnerCatalogRepositoryProvider = Provider((ref) => PartnerCatalogRepository());

class PartnerCatalogRepository {
  final _supabase = Supabase.instance.client;

  /// Fetches the list of active rewards from the catalog.
  /// Supports city and sport filtering.
  Future<List<Map<String, dynamic>>> getActiveRewards({
    String? city,
    String? sportId,
  }) async {
    try {
      final response = await _supabase.rpc('get_active_rewards', params: {
        'p_city': city,
        'p_sport_id': sportId,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Fetches a single reward item detail for validation or display.
  Future<Map<String, dynamic>?> getRewardItem(String rewardId) async {
    try {
      final response = await _supabase.rpc('get_reward_catalog_item', params: {
        'p_reward_id': rewardId,
      });
      final List<dynamic> results = response;
      if (results.isEmpty) return null;
      return Map<String, dynamic>.from(results.first);
    } catch (e) {
      return null;
    }
  }

  /// Reserves inventory for a reward.
  /// Usually called by @EconomyEngine during redemption.
  Future<bool> reserveInventory(
    String rewardId, {
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.rpc('reserve_reward_inventory', params: {
        'p_reward_id': rewardId,
        'p_idempotency_key': idempotencyKey,
        'p_metadata': metadata ?? {},
      });
      return response as bool;
    } catch (e) {
      return false;
    }
  }
}
