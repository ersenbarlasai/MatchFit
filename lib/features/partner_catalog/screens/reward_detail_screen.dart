import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/partner_catalog_provider.dart';
import '../../economy_engine/providers/economy_engine_provider.dart';

class RewardDetailScreen extends ConsumerStatefulWidget {
  final String rewardId;

  const RewardDetailScreen({super.key, required this.rewardId});

  @override
  ConsumerState<RewardDetailScreen> createState() => _RewardDetailScreenState();
}

class _RewardDetailScreenState extends ConsumerState<RewardDetailScreen> {
  bool _isRedeeming = false;

  @override
  void initState() {
    super.initState();
    // Log view event when detail page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final idempotencyKey = userId != null
          ? 'reward_view:$userId:${widget.rewardId}:${DateTime.now().toIso8601String().substring(0, 10)}'
          : null;
      ref.read(partnerCatalogRepositoryProvider).logRewardInteractionEvent(
        rewardId: widget.rewardId,
        eventType: 'view',
        source: 'reward_detail',
        idempotencyKey: idempotencyKey,
      );
    });
  }

  Future<void> _handleRedeem(Map<String, dynamic> reward) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnackBar('Devam etmek için giriş yapmalısın.', Colors.red);
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      // Log redeem_start event
      await ref.read(partnerCatalogRepositoryProvider).logRewardInteractionEvent(
        rewardId: widget.rewardId,
        eventType: 'redeem_start',
        source: 'reward_detail',
        idempotencyKey: 'reward_redeem_start:$userId:${widget.rewardId}:${DateTime.now().millisecondsSinceEpoch}',
      );

      final idempotencyKey = 'reward_redemption:$userId:${widget.rewardId}:${DateTime.now().millisecondsSinceEpoch}';
      
      final economyRepo = ref.read(economyEngineRepositoryProvider);
      final result = await economyRepo.attemptRewardRedemption(
        rewardId: widget.rewardId,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;

      if (result['status'] == 'approved' || result['status'] == 'completed') {
        // Success
        _showSnackBar(
          'Ödül başarıyla alındı!',
          Colors.green,
          SnackBarAction(
            label: 'Ödüllerim',
            textColor: Colors.white,
            onPressed: () => context.push('/my-rewards'),
          ),
        );
        
        // Refresh providers to update balance and stock
        ref.invalidate(userMFBalanceProvider(userId));
        ref.invalidate(rewardDetailProvider(widget.rewardId));
        ref.invalidate(activeRewardsProvider);
        
      } else {
        // Rejected
        final reason = result['reason'];
        String userMessage = 'Bir hata oluştu.';
        
        if (reason == 'insufficient_balance') {
          userMessage = 'Bakiyen bu ödül için yeterli değil.';
        } else if (reason == 'out_of_stock') {
          userMessage = 'Bu ödülün stoğu tükendi.';
        } else if (reason == 'trust_too_low') {
          userMessage = 'Bu ödül için güven puanın yeterli değil.';
        } else if (reason == 'not_authenticated') {
          userMessage = 'Devam etmek için giriş yapmalısın.';
        } else if (reason == 'reward_not_found' || reason == 'reward_inactive' || reason == 'reward_expired') {
          userMessage = 'Bu ödül şu anda alınamıyor.';
        }

        _showSnackBar(userMessage, Colors.orange);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Beklenmeyen bir hata oluştu.', Colors.red);
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  void _showSnackBar(String message, Color color, [SnackBarAction? action]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final balanceAsync = userId != null ? ref.watch(userMFBalanceProvider(userId)) : null;
    final rewardAsync = ref.watch(rewardDetailProvider(widget.rewardId));

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Ödül Detayı'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (balanceAsync != null)
            balanceAsync.when(
              data: (balanceMap) {
                final balance = balanceMap?['balance'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Text(
                      '$balance MF',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
        ],
      ),
      body: rewardAsync.when(
        data: (data) {
          if (data == null || data['reward'] == null) {
            return const Center(child: Text('Ödül bulunamadı.', style: TextStyle(color: Colors.white70)));
          }

          final reward = data['reward'];
          final partner = data['partner'] ?? {};
          final inventory = data['inventory'] ?? {};

          final name = reward['name'] ?? 'İsimsiz Ödül';
          final desc = reward['description'] ?? reward['short_description'] ?? '';
          final imageUrl = reward['image_url'];
          final partnerName = partner['name'] ?? 'Sponsor';
          final cost = reward['cost_points'] ?? 0;
          final isFree = reward['is_free'] == true;
          final stockRemaining = inventory['stock_remaining'];
          final isUnlimited = inventory['is_unlimited'] == true;

          final bool canRedeem = isUnlimited || (stockRemaining != null && stockRemaining > 0);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                Container(
                  height: 250,
                  color: Colors.black26,
                  child: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 64, color: Colors.white24))
                      : const Center(child: Icon(Icons.card_giftcard, size: 64, color: Colors.white24)),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partnerName.toUpperCase(),
                        style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      
                      // Info Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.monetization_on_outlined,
                              title: 'Bedel',
                              value: isFree ? 'Ücretsiz' : '$cost MF',
                              valueColor: isFree ? Colors.blue : Colors.greenAccent,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.inventory_2_outlined,
                              title: 'Stok Durumu',
                              value: isUnlimited ? 'Sınırsız' : '$stockRemaining Adet',
                              valueColor: canRedeem ? Colors.white : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      const Text(
                        'Açıklama',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            disabledBackgroundColor: Colors.grey.shade800,
                          ),
                          onPressed: (!canRedeem || _isRedeeming) ? null : () => _handleRedeem(reward),
                          child: _isRedeeming
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Ödülü Al', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Bir hata oluştu: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String title, required String value, required Color valueColor}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white70),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
