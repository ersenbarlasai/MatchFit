import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/partner_catalog_provider.dart';
import '../../economy_engine/providers/economy_engine_provider.dart';

class RewardCatalogScreen extends ConsumerStatefulWidget {
  const RewardCatalogScreen({super.key});

  @override
  ConsumerState<RewardCatalogScreen> createState() => _RewardCatalogScreenState();
}

class _RewardCatalogScreenState extends ConsumerState<RewardCatalogScreen> {
  String? _selectedCity;
  String? _selectedSportTag;

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final balanceAsync = userId != null ? ref.watch(userMFBalanceProvider(userId)) : null;
    final rewardsAsync = ref.watch(activeRewardsProvider((
      city: _selectedCity,
      sportTag: _selectedSportTag,
    )));

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // MatchFit base dark background
      appBar: AppBar(
        title: const Text('Ödül Mağazası', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (balanceAsync != null)
            balanceAsync.when(
              data: (balanceMap) {
                final balance = balanceMap?['balance'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Chip(
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    side: const BorderSide(color: Colors.green),
                    avatar: const Icon(Icons.stars, color: Colors.green, size: 18),
                    label: Text(
                      '$balance MF',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const SizedBox(),
            ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined, color: Colors.purpleAccent),
            tooltip: 'Sponsor Ol',
            onPressed: () => context.push('/partner-apply'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recommended Rewards Section (Sana Özel)
          _buildRecommendedSection(context, ref),

          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'Şehir Seç',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    dropdownColor: const Color(0xFF2C2C2C),
                    value: _selectedCity,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tüm Şehirler', style: TextStyle(color: Colors.white70))),
                      DropdownMenuItem(value: 'Istanbul', child: Text('Istanbul', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Ankara', child: Text('Ankara', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Izmir', child: Text('Izmir', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'Bursa', child: Text('Bursa', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _selectedCity = val),
                  ),
                ),
              ],
            ),
          ),
          
          // Rewards List
          Expanded(
            child: rewardsAsync.when(
              data: (rewards) {
                if (rewards.isEmpty) {
                  return const Center(
                    child: Text('Şu anda aktif ödül bulunmuyor.', style: TextStyle(color: Colors.white70)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rewards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    return _buildRewardCard(context, reward);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Bir hata oluştu: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(BuildContext context, Map<String, dynamic> reward) {
    final name = reward['name'] ?? 'İsimsiz Ödül';
    final shortDesc = reward['short_description'] ?? '';
    final imageUrl = reward['image_url'];
    final partnerName = reward['partner_name'] ?? 'Sponsor';
    final cost = reward['cost_points'] ?? 0;
    final isFree = reward['is_free'] == true;
    final stockRemaining = reward['stock_remaining'];
    final isUnlimited = reward['is_unlimited'] == true;
    final rewardId = reward['id'] as String?;

    void _handleCardTap() {
      if (rewardId != null) {
        // Log click event (fire and forget)
        final userId = Supabase.instance.client.auth.currentUser?.id;
        ref.read(partnerCatalogRepositoryProvider).logRewardInteractionEvent(
          rewardId: rewardId,
          eventType: 'click',
          source: 'reward_catalog',
          idempotencyKey: 'reward_click:${userId ?? 'anon'}:$rewardId:${DateTime.now().millisecondsSinceEpoch}',
        );
        context.push('/reward-detail', extra: rewardId);
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: _handleCardTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Placeholder
            Container(
              height: 140,
              color: Colors.black26,
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48, color: Colors.white24))
                  : const Center(child: Icon(Icons.card_giftcard, size: 48, color: Colors.white24)),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName.toUpperCase(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (shortDesc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      shortDesc,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stock Info
                      if (!isUnlimited && stockRemaining != null)
                        Text(
                          'Kalan: $stockRemaining',
                          style: TextStyle(
                            color: stockRemaining < 10 ? Colors.orangeAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (isUnlimited)
                        const Text('Sınırsız', style: TextStyle(color: Colors.white70))
                      else
                        const SizedBox(),

                      // Cost
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFree ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isFree ? Colors.blue : Colors.green),
                        ),
                        child: Text(
                          isFree ? 'ÜCRETSİZ' : '$cost MF',
                          style: TextStyle(
                            color: isFree ? Colors.blue : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(BuildContext context, WidgetRef ref) {
    final recAsync = ref.watch(recommendedRewardsProvider);

    return recAsync.when(
      data: (rewards) {
        if (rewards.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Sana Özel Ödüller',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: rewards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final reward = rewards[index];
                  return _buildRecCard(context, reward);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecCard(BuildContext context, Map<String, dynamic> reward) {
    final name = reward['name'] ?? 'Ödül';
    final partnerName = reward['partner_name'] ?? 'Sponsor';
    final imageUrl = reward['image_url'];
    final cost = reward['cost_points'] ?? 0;
    final isFree = reward['is_free'] == true;
    final stockRemaining = reward['stock_remaining'];
    final isUnlimited = reward['is_unlimited'] == true;
    final boostActive = reward['boost_active'] == true;
    final rewardId = reward['id'] as String?;

    // Log impression once per session for this card (fire & forget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rewardId != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final today = DateTime.now().toIso8601String().substring(0, 10);
        ref.read(partnerCatalogRepositoryProvider).logRewardInteractionEvent(
          rewardId: rewardId,
          eventType: 'impression',
          source: 'personalized_section',
          idempotencyKey: 'reward_impression:${userId ?? 'anon'}:$rewardId:$today',
        );
      }
    });

    void _handleRecTap() {
      if (rewardId != null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        ref.read(partnerCatalogRepositoryProvider).logRewardInteractionEvent(
          rewardId: rewardId,
          eventType: 'click',
          source: 'personalized_section',
          idempotencyKey: 'reward_click:${userId ?? 'anon'}:$rewardId:${DateTime.now().millisecondsSinceEpoch}',
        );
        context.push('/reward-detail', extra: rewardId);
      }
    }

    return GestureDetector(
      onTap: _handleRecTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: boostActive ? Border.all(color: Colors.amberAccent.withValues(alpha: 0.5), width: 1) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.toString().isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white24))
                      : Container(color: Colors.black26, child: const Icon(Icons.card_giftcard, color: Colors.white24)),
                  if (isFree)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
                        child: const Text('ÜCRETSİZ', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (!isUnlimited && stockRemaining != null && stockRemaining <= 5)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                        child: Text('Son $stockRemaining!', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partnerName, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(isFree ? '0 MF' : '$cost MF', style: TextStyle(color: isFree ? Colors.blue : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
