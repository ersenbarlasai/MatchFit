import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/partner_catalog_provider.dart';

class RedemptionHistoryScreen extends ConsumerWidget {
  const RedemptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myRedemptionHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // MatchFit base dark background
      appBar: AppBar(
        title: const Text('Ödüllerim', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('Henüz ödül almadın.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/rewards'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Ödül Mağazasına Git', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryCard(context, item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Bir hata oluştu: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
    final rewardName = item['reward_name'] ?? 'İsimsiz Ödül';
    final partnerName = item['partner_name'] ?? 'Bilinmeyen Sponsor';
    final imageUrl = item['reward_image_url'];
    final costPoints = item['cost_points'] ?? 0;
    final status = item['status'] ?? 'pending';
    final rejectionReason = item['rejection_reason'];
    final metadata = item['metadata'] as Map<String, dynamic>? ?? {};
    final createdAtStr = item['created_at'];
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
    
    // Check for redemption codes inside metadata
    final redemptionCode = metadata['redemption_code'] ?? metadata['coupon_code'] ?? metadata['code'];

    Color statusColor;
    String statusText;

    switch (status) {
      case 'approved':
      case 'completed':
        statusColor = Colors.greenAccent;
        statusText = 'Alındı';
        break;
      case 'rejected':
      case 'failed':
        statusColor = Colors.redAccent;
        statusText = 'Reddedildi';
        break;
      case 'pending':
      default:
        statusColor = Colors.orangeAccent;
        statusText = 'Beklemede';
        break;
    }

    return Card(
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.white24))
                  : const Icon(Icons.card_giftcard, color: Colors.white24),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          partnerName.toUpperCase(),
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(rewardName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Text('$costPoints MF harcandı', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                  if (status == 'rejected' && rejectionReason != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.redAccent, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(rejectionReason, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                        ],
                      ),
                    ),
                  ],
                  if (statusText == 'Alındı' && redemptionCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kullanım Kodu:', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(height: 2),
                              Text(redemptionCode.toString(), style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ],
                          ),
                          const Icon(Icons.copy, color: Colors.white54, size: 16),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
