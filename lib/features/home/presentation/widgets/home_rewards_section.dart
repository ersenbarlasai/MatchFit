import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/features/partner_catalog/providers/partner_catalog_provider.dart';

class HomeRewardsSection extends ConsumerWidget {
  const HomeRewardsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedRewardsProvider);

    return recommendedAsync.when(
      data: (rewards) {
        if (rewards.isEmpty) return _buildCtaBanner(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rewards.length,
                itemBuilder: (context, index) {
                  return _RewardPreviewCard(reward: rewards[index]);
                },
              ),
            ),
            const SizedBox(height: 24),
            _buildCtaBanner(context),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _buildCtaBanner(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Sana Özel Fırsatlar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/rewards'),
            child: const Text(
              'Tümünü Gör',
              style: TextStyle(
                color: MatchFitTheme.accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MatchFitTheme.accentGreen.withOpacity(0.15),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MF Points\'lerini ödüle çevir',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kuponlar, indirimler ve özel kampanyalar seni bekliyor.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => context.push('/rewards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            child: const Text(
              'Mağaza',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPreviewCard extends ConsumerWidget {
  final Map<String, dynamic> reward;

  const _RewardPreviewCard({required this.reward});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardId = reward['id'];
    final name = reward['name'] ?? 'Ödül';
    final partnerName = reward['partner_name'] ?? 'Sponsor';
    final imageUrl = reward['image_url'];
    final cost = reward['cost_points'] ?? 0;
    final isFree = reward['is_free'] == true;
    final isBoosted = reward['boost_active'] == true;
    final stockRemaining = reward['stock_remaining'] as int?;
    final isUnlimited = reward['is_unlimited'] == true;
    final isLowStock = !isUnlimited && stockRemaining != null && stockRemaining <= 5;

    return GestureDetector(
      onTap: () {
        // Log click event
        ref.read(partnerCatalogRepositoryProvider).logRewardInteractionEvent(
          rewardId: rewardId,
          eventType: 'click',
          source: 'home_featured',
          idempotencyKey: 'home_click_${rewardId}_${DateTime.now().millisecondsSinceEpoch}',
        );
        context.push('/reward-detail', extra: rewardId);
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.toString().isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white.withOpacity(0.05),
                          child: const Icon(Icons.broken_image_outlined, color: Colors.white10, size: 32),
                        ),
                      )
                    else
                      Container(
                        color: Colors.white.withOpacity(0.05),
                        child: const Icon(Icons.card_giftcard, color: Colors.white24, size: 32),
                      ),
                    
                    // Badges
                    if (isBoosted)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ÖNE ÇIKAN',
                            style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    if (isLowStock)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AZ KALDI',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Info Section
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partnerName.toUpperCase(),
                            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Text(
                        isFree ? 'Ücretsiz' : '$cost MF',
                        style: TextStyle(
                          color: isFree ? Colors.blueAccent : MatchFitTheme.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
