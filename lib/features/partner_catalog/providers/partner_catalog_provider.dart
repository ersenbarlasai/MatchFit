import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/partner_catalog_repository.dart';

final partnerCatalogRepositoryProvider = Provider<PartnerCatalogRepository>((ref) {
  return PartnerCatalogRepository();
});

typedef RewardFilters = ({String? city, String? sportTag});

final activeRewardsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, RewardFilters>((ref, filters) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getActiveRewards(
    city: filters.city,
    sportTag: filters.sportTag,
  );
});

final rewardDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, rewardId) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getRewardCatalogItem(rewardId);
});

final myRedemptionHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getMyRedemptionHistory();
});

// ── Fallback Recommendations ───────────────────────────────────────────────
// Note: Since real backend RPCs (generate_reward_recommendations) don't exist yet, 
// this provider uses a client-side heuristic (boosts, affordability, urgency) on active rewards.

final recommendedRewardsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  
  try {
    // Attempt personalized RPC first
    final personalized = await repository.getPersonalizedRewards(limit: 5);
    if (personalized.isNotEmpty) return personalized;
  } catch (e) {
    debugPrint('[@RewardPersonalization] Fallback triggered: $e');
  }

  // Fallback heuristic if RPC fails or returns empty
  final allRewards = await repository.getActiveRewards();
  if (allRewards.isEmpty) return [];

  final sortedRewards = List<Map<String, dynamic>>.from(allRewards);
  sortedRewards.sort((a, b) {
    final aBoost = a['boost_active'] == true ? 1 : 0;
    final bBoost = b['boost_active'] == true ? 1 : 0;
    if (aBoost != bBoost) return bBoost.compareTo(aBoost);

    final aFree = a['is_free'] == true ? 1 : 0;
    final bFree = b['is_free'] == true ? 1 : 0;
    if (aFree != bFree) return bFree.compareTo(aFree);

    final aUnlimited = a['is_unlimited'] == true;
    final bUnlimited = b['is_unlimited'] == true;
    final aStock = (a['stock_remaining'] as int?) ?? 999999;
    final bStock = (b['stock_remaining'] as int?) ?? 999999;
    
    if (!aUnlimited && bUnlimited) return -1;
    if (aUnlimited && !bUnlimited) return 1;
    if (!aUnlimited && !bUnlimited) {
       return aStock.compareTo(bStock);
    }
    return 0;
  });

  return sortedRewards.take(5).toList();
});

// ── Admin Providers ────────────────────────────────────────────────────────

final partnerAdminKpiSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getPartnerAdminKpiSummary();
});

final partnerAdminListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getPartnerAdminList();
});

final rewardAdminListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getRewardAdminList();
});

// ── Sponsor Onboarding Providers ───────────────────────────────────────────

final myPartnerApplicationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getMyPartnerApplications();
});

final partnerApplicationAdminListProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, status) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getPartnerApplicationAdminList(status: status);
});

// ── Campaign Builder Providers ─────────────────────────────────────────────

final partnerCampaignAdminListProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, partnerId) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getPartnerCampaignAdminList(partnerId: partnerId);
});

final partnerDetailKpiProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, partnerId) {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  return repository.getPartnerDetailKpi(partnerId);
});

// ── Featured & Partner Helpers ──────────────────────────────────────────────

final featuredCampaignRewardProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  // We fetch without filters for the global hero banner
  final allRewards = await repository.getActiveRewards();
  if (allRewards.isEmpty) return null;

  // Selection logic:
  // 1. boost_active = true
  // 2. campaign_id is not null
  // 3. stock remaining is low / free / cheap
  final sorted = List<Map<String, dynamic>>.from(allRewards);
  sorted.sort((a, b) {
    final aBoost = a['boost_active'] == true ? 1 : 0;
    final bBoost = b['boost_active'] == true ? 1 : 0;
    if (aBoost != bBoost) return bBoost.compareTo(aBoost);

    final aCampaign = a['campaign_id'] != null ? 1 : 0;
    final bCampaign = b['campaign_id'] != null ? 1 : 0;
    if (aCampaign != bCampaign) return bCampaign.compareTo(aCampaign);

    final aFree = a['is_free'] == true ? 1 : 0;
    final bFree = b['is_free'] == true ? 1 : 0;
    if (aFree != bFree) return bFree.compareTo(aFree);

    return 0;
  });

  return sorted.first;
});

final activeRewardPartnersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(partnerCatalogRepositoryProvider);
  final allRewards = await repository.getActiveRewards();
  if (allRewards.isEmpty) return [];

  final partnersMap = <String, Map<String, dynamic>>{};
  for (final r in allRewards) {
    final pId = r['partner_id']?.toString();
    if (pId != null && !partnersMap.containsKey(pId)) {
      partnersMap[pId] = {
        'id': pId,
        'name': r['partner_name'] ?? 'Partner',
        'logo_url': r['partner_logo_url'],
      };
    }
  }
  
  final list = partnersMap.values.toList();
  // Limit to top 10 for the strip
  return list.take(10).toList();
});
