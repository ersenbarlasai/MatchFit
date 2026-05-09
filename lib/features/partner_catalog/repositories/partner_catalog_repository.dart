import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PartnerCatalogRepository {
  final _supabase = Supabase.instance.client;

  /// Retrieves the list of active rewards based on optional filters.
  Future<List<Map<String, dynamic>>> getActiveRewards({
    String? city,
    String? sportTag,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_active_rewards',
        params: {
          if (city != null) 'p_city': city,
          if (sportTag != null) 'p_sport_tag': sportTag,
        },
      );
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching active rewards: $e');
      return [];
    }
  }

  /// Retrieves a personalized list of rewards based on user profile and behavior.
  Future<List<Map<String, dynamic>>> getPersonalizedRewards({int limit = 10}) async {
    try {
      final response = await _supabase.rpc(
        'get_personalized_rewards',
        params: {'p_limit': limit},
      );
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@RewardPersonalization] Error fetching personalized rewards: $e');
      return [];
    }
  }

  /// Retrieves detailed information for a single reward catalog item.
  Future<Map<String, dynamic>?> getRewardCatalogItem(String rewardId) async {
    try {
      final response = await _supabase.rpc(
        'get_reward_catalog_item',
        params: {'p_reward_id': rewardId},
      );
      
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching reward detail: $e');
      return null;
    }
  }

  /// Retrieves the redemption history for the current user.
  Future<List<Map<String, dynamic>>> getMyRedemptionHistory() async {
    try {
      final response = await _supabase.rpc('get_my_redemption_history');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching redemption history: $e');
      return [];
    }
  }

  /// Logs a reward interaction event (impression, view, click, redeem_start).
  Future<void> logRewardInteractionEvent({
    required String rewardId,
    required String eventType,
    String? source,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    try {
      await _supabase.rpc('log_reward_interaction_event', params: {
        'p_reward_id': rewardId,
        'p_event_type': eventType,
        if (source != null) 'p_source': source,
        'p_metadata': metadata ?? {},
        if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
      });
    } catch (e) {
      debugPrint('[@PartnerCatalog] Event log error (silent): $e');
      // Silent failure – event logging must never break user flow
    }
  }

  /// Retrieves the KPI summary for the admin dashboard.
  Future<Map<String, dynamic>?> getPartnerAdminKpiSummary() async {
    try {
      final response = await _supabase.rpc('get_partner_admin_kpi_summary');
      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching KPI summary: $e');
      rethrow;
    }
  }

  // ── Admin Methods ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPartnerAdminList() async {
    try {
      final response = await _supabase.rpc('get_partner_admin_list');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching partner admin list: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRewardAdminList() async {
    try {
      final response = await _supabase.rpc('get_reward_admin_list');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching reward admin list: $e');
      return [];
    }
  }

  Future<String?> upsertPartnerAdmin(Map<String, dynamic> data) async {
    try {
      final response = await _supabase.rpc('upsert_partner_admin', params: data);
      return response?.toString();
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error upserting partner: $e');
      rethrow;
    }
  }

  Future<String?> upsertRewardCatalogAdmin(Map<String, dynamic> data) async {
    try {
      final response = await _supabase.rpc('upsert_reward_catalog_admin', params: data);
      return response?.toString();
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error upserting reward: $e');
      rethrow;
    }
  }

  Future<void> updateRewardInventoryAdmin(String rewardId, int total, int remaining, bool isUnlimited) async {
    try {
      await _supabase.rpc('update_reward_inventory_admin', params: {
        'p_reward_id': rewardId,
        'p_stock_total': total,
        'p_stock_remaining': remaining,
        'p_is_unlimited': isUnlimited,
      });
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error updating inventory: $e');
      rethrow;
    }
  }

  // ── Sponsor Onboarding Methods ─────────────────────────────────────────────

  Future<String> submitPartnerApplication({
    required String businessName,
    String? category,
    String? city,
    String? contactName,
    String? contactEmail,
    String? taxNumber,
    String desiredTier = 'basic',
    String? desiredBillingModel,
    List<String> proposedRewardTypes = const [],
    String? notes,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc('submit_partner_application', params: {
        'p_business_name': businessName,
        if (category != null) 'p_category': category,
        if (city != null) 'p_city': city,
        if (contactName != null) 'p_contact_name': contactName,
        if (contactEmail != null) 'p_contact_email': contactEmail,
        if (taxNumber != null) 'p_tax_number': taxNumber,
        'p_desired_tier': desiredTier,
        if (desiredBillingModel != null) 'p_desired_billing_model': desiredBillingModel,
        'p_proposed_reward_types': proposedRewardTypes,
        if (notes != null) 'p_notes': notes,
        if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
      });
      return response.toString();
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error submitting application: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMyPartnerApplications() async {
    try {
      final response = await _supabase.rpc('get_my_partner_applications');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching applications: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPartnerApplicationAdminList({String? status}) async {
    try {
      final response = await _supabase.rpc('get_partner_application_admin_list', params: {
        if (status != null) 'p_status': status,
      });
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching application admin list: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> handlePartnerApplicationAdmin({
    required String applicationId,
    required String action,
    String? adminNote,
  }) async {
    try {
      final response = await _supabase.rpc('handle_partner_application_admin', params: {
        'p_application_id': applicationId,
        'p_action': action,
        if (adminNote != null) 'p_admin_note': adminNote,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error handling application: $e');
      rethrow;
    }
  }

  // ── Campaign Builder Methods ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPartnerCampaignAdminList({String? partnerId}) async {
    try {
      final response = await _supabase.rpc('get_partner_campaign_admin_list', params: {
        if (partnerId != null) 'p_partner_id': partnerId,
      });
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching campaigns: $e');
      return [];
    }
  }

  Future<String> upsertPartnerCampaignAdmin({
    String? campaignId,
    required String partnerId,
    required String name,
    String? description,
    String campaignType = 'standard',
    String status = 'draft',
    DateTime? startsAt,
    DateTime? endsAt,
    double? budgetAmount,
    String? billingModel,
    String? targetCity,
    List<String> sportTags = const [],
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.rpc('upsert_partner_campaign_admin', params: {
        if (campaignId != null) 'p_campaign_id': campaignId,
        'p_partner_id': partnerId,
        'p_name': name,
        if (description != null) 'p_description': description,
        'p_campaign_type': campaignType,
        'p_status': status,
        if (startsAt != null) 'p_starts_at': startsAt.toIso8601String(),
        if (endsAt != null) 'p_ends_at': endsAt.toIso8601String(),
        if (budgetAmount != null) 'p_budget_amount': budgetAmount,
        if (billingModel != null) 'p_billing_model': billingModel,
        if (targetCity != null) 'p_target_city': targetCity,
        'p_sport_tags': sportTags,
        'p_metadata': metadata ?? {},
      });
      return response.toString();
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error upserting campaign: $e');
      rethrow;
    }
  }

  Future<void> attachRewardToCampaignAdmin({
    required String rewardId,
    String? campaignId,
  }) async {
    try {
      await _supabase.rpc('attach_reward_to_campaign_admin', params: {
        'p_reward_id': rewardId,
        if (campaignId != null) 'p_campaign_id': campaignId,
      });
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error attaching reward to campaign: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPartnerDetailKpi(String partnerId) async {
    try {
      final response = await _supabase.rpc('get_partner_detail_kpi', params: {
        'p_partner_id': partnerId,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('[@PartnerCatalog] Error fetching partner detail KPI: $e');
      rethrow;
    }
  }
}
