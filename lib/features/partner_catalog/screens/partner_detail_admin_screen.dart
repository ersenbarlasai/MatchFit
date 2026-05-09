import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/partner_catalog_provider.dart';

class PartnerDetailAdminScreen extends ConsumerWidget {
  final String partnerId;
  const PartnerDetailAdminScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(partnerDetailKpiProvider(partnerId));

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Partner Detay Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: detailAsync.when(
        data: (data) {
          if (data == null) return const Center(child: Text('Veri bulunamadı.'));
          final partner = data['partner'] as Map<String, dynamic>;
          final kpi = data['kpi'] as Map<String, dynamic>;
          final campaigns = List<Map<String, dynamic>>.from(data['campaigns'] ?? []);
          final rewards = List<Map<String, dynamic>>.from(data['rewards'] ?? []);
          final recent = List<Map<String, dynamic>>.from(data['recent_redemptions'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(partner),
                const SizedBox(height: 24),
                _buildKpiGrid(kpi),
                const SizedBox(height: 24),
                _buildManualOpsSection(partner),
                const SizedBox(height: 32),
                _buildSectionHeader('Aktif Kampanyalar', campaigns.length.toString()),
                const SizedBox(height: 12),
                _buildCampaignList(campaigns),
                const SizedBox(height: 32),
                _buildSectionHeader('Ödüller & Stok', rewards.length.toString()),
                const SizedBox(height: 12),
                _buildRewardList(rewards),
                const SizedBox(height: 32),
                _buildSectionHeader('Son İşlemler', recent.length.toString()),
                const SizedBox(height: 12),
                _buildRecentRedemptions(recent),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> partner) {
    final status = partner['status'] ?? 'pending';
    final tier = partner['tier'] ?? 'basic';
    Color statusColor = status == 'active' ? Colors.greenAccent : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.business, color: Colors.white24, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${partner['category'] ?? "Kategori Belirtilmedi"} • ${partner['city'] ?? "Şehir Belirtilmedi"}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _badge(status.toString().toUpperCase(), statusColor),
                    const SizedBox(width: 8),
                    _badge(tier.toString().toUpperCase(), Colors.purpleAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> kpi) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _kpiItem('Aktif Ödül', '${kpi['active_rewards']}/${kpi['total_rewards']}', Icons.card_giftcard, Colors.blueAccent),
        _kpiItem('Kampanya', '${kpi['active_campaigns']}/${kpi['total_campaigns']}', Icons.campaign, Colors.purpleAccent),
        _kpiItem('Kullanım', kpi['approved_redemptions'].toString(), Icons.receipt_long, Colors.greenAccent),
        _kpiItem('Harcanan MF', kpi['total_points_spent'].toString(), Icons.stars, Colors.amberAccent),
        _kpiItem('Görüntüleme', kpi['total_views'].toString(), Icons.visibility, Colors.cyanAccent),
        _kpiItem('CTR', '%${kpi['ctr']}', Icons.trending_up, Colors.tealAccent),
      ],
    );
  }

  Widget _kpiItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildManualOpsSection(Map<String, dynamic> partner) {
    final metadata = partner['metadata'] as Map?;
    final ops = metadata?['manual_ops'] as Map?;
    if (ops == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              const Text('Manuel Operasyon Verileri', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          _opsRow('Sponsor Paketi', ops['sponsor_package']?.toString().toUpperCase() ?? 'TRIAL', Colors.purpleAccent),
          _opsRow('Sözleşme Durumu', ops['contract_status']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'BAŞLAMADI', Colors.blueAccent),
          _opsRow('Ödeme Durumu', ops['payment_status']?.toString().toUpperCase() ?? 'BAŞLAMADI', Colors.orangeAccent),
          if (ops['contract_url'] != null && ops['contract_url'].toString().isNotEmpty)
            _opsRow('Sözleşme URL', ops['contract_url'], Colors.cyanAccent, isLink: true),
          if (ops['internal_note'] != null && ops['internal_note'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('İç Not:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(ops['internal_note'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          if (ops['account_owner_note'] != null && ops['account_owner_note'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Account Owner Notu:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(ops['account_owner_note'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _opsRow(String label, String value, Color color, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                decoration: isLink ? TextDecoration.underline : null,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
          child: Text(count, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildCampaignList(List<Map<String, dynamic>> campaigns) {
    if (campaigns.isEmpty) return _emptyBox('Henüz kampanya oluşturulmadı.');
    return Column(
      children: campaigns.map((c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.purpleAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      Text('${c['reward_count']} ödül • ${c['redemption_count']} kullanım', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      if (c['metadata'] != null && (c['metadata'] as Map)['manual_ops'] != null) ...[
                        const SizedBox(width: 8),
                        _creativeBadge((c['metadata'] as Map)['manual_ops']['creative_status']),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _statusBadge(c['status'] ?? 'draft'),
          ],
        ),
      )).toList(),
    );
  }

  Widget _creativeBadge(String? status) {
    Color color = Colors.grey;
    String label = status?.toUpperCase() ?? 'PENDING';
    if (status == 'approved') color = Colors.greenAccent;
    if (status == 'rejected') color = Colors.redAccent;
    if (status == 'needs_revision') color = Colors.orangeAccent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRewardList(List<Map<String, dynamic>> rewards) {
    if (rewards.isEmpty) return _emptyBox('Henüz ödül eklenmedi.');
    return Column(
      children: rewards.map((r) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      if (r['campaign_name'] != null)
                        Text('Kampanya: ${r['campaign_name']}', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10)),
                    ],
                  ),
                ),
                Text('${r['cost_points']} MF', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniMetric(Icons.inventory, r['is_unlimited'] == true ? 'Sınırsız' : '${r['stock_remaining']} stok', Colors.orangeAccent),
                const SizedBox(width: 12),
                _miniMetric(Icons.visibility, r['view_count'].toString(), Colors.cyanAccent),
                const SizedBox(width: 12),
                _miniMetric(Icons.ads_click, r['click_count'].toString(), Colors.lightBlueAccent),
                const Spacer(),
                _statusBadge(r['status'] ?? 'pending'),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildRecentRedemptions(List<Map<String, dynamic>> recent) {
    if (recent.isEmpty) return _emptyBox('Henüz kullanım kaydı yok.');
    return Column(
      children: recent.map((ra) {
        final date = ra['created_at'] != null ? DateTime.tryParse(ra['created_at']) : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.white38, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ra['reward_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(date != null ? DateFormat('dd MMM HH:mm').format(date) : '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${ra['cost_points']} MF', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(ra['status'].toString().toUpperCase(), style: TextStyle(color: ra['status'] == 'approved' ? Colors.greenAccent : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'active' || status == 'approved') color = Colors.greenAccent;
    if (status == 'paused' || status == 'pending') color = Colors.orangeAccent;
    if (status == 'rejected' || status == 'inactive') color = Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _miniMetric(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
    );
  }
}
