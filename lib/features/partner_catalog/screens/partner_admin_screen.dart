import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/partner_catalog_provider.dart';

class PartnerAdminScreen extends ConsumerStatefulWidget {
  const PartnerAdminScreen({super.key});

  @override
  ConsumerState<PartnerAdminScreen> createState() => _PartnerAdminScreenState();
}

class _PartnerAdminScreenState extends ConsumerState<PartnerAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Sponsor & Ödül Yönetimi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.greenAccent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Genel Bakış'),
            Tab(text: 'Başvurular'),
            Tab(text: 'Kampanyalar'),
            Tab(text: 'Partnerler'),
            Tab(text: 'Ödüller & Stok'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _ApplicationsTab(),
          _CampaignsTab(),
          _PartnersTab(),
          _RewardsTab(),
        ],
      ),
    );
  }
}

// ── OVERVIEW / KPI TAB ──────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(partnerAdminKpiSummaryProvider);

    return kpiAsync.when(
      data: (kpi) {
        if (kpi == null) {
          return const Center(child: Text('KPI verisi bulunamadı.', style: TextStyle(color: Colors.white70)));
        }
        final topRewards = kpi['top_rewards'] as List? ?? [];

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(partnerAdminKpiSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Genel Bakış', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.0,
                children: [
                  _kpiCard('Aktif Partner', '${kpi['active_partners'] ?? 0}', Icons.storefront, Colors.greenAccent),
                  _kpiCard('Aktif Ödül', '${kpi['active_rewards'] ?? 0}', Icons.card_giftcard, Colors.blueAccent),
                  _kpiCard('Azalan Stok', '${kpi['low_stock_rewards'] ?? 0}', Icons.warning_amber, Colors.orangeAccent),
                  _kpiCard('Toplam Redemption', '${kpi['total_redemptions'] ?? 0}', Icons.receipt, Colors.purpleAccent),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _kpiCard('Onaylanan', '${kpi['approved_redemptions'] ?? 0}', Icons.check_circle, Colors.greenAccent),
                  _kpiCard('Reddedilen', '${kpi['rejected_redemptions'] ?? 0}', Icons.cancel, Colors.redAccent),
                  _kpiCard('Harcanan MF', '${kpi['total_points_spent'] ?? 0}', Icons.stars, Colors.amberAccent),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Etkileşim Metrikleri', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _kpiCard('Görüntüleme', '${kpi['total_views'] ?? 0}', Icons.visibility, Colors.cyanAccent),
                  _kpiCard('Tıklama', '${kpi['total_clicks'] ?? 0}', Icons.ads_click, Colors.lightBlueAccent),
                  _kpiCard('Ort. CTR', '%${kpi['average_ctr'] ?? 0}', Icons.trending_up, Colors.tealAccent),
                ],
              ),
              const SizedBox(height: 20),
              const Text('En Çok Alınan Ödüller', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (topRewards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz redemption verisi yok.', style: TextStyle(color: Colors.white38)),
                )
              else
                ...topRewards.map((r) {
                  final reward = r as Map<String, dynamic>;
                  final status = reward['status'] ?? 'pending';
                  final viewCount = reward['view_count'] ?? 0;
                  final clickCount = reward['click_count'] ?? 0;
                  final redemptionCount = reward['redemption_count'] ?? 0;
                  final conversion = reward['conversion_rate'];
                  Color statusColor = status == 'active' ? Colors.green : (status == 'inactive' ? Colors.red : Colors.orange);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(reward['reward_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(reward['partner_name'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _miniMetric(Icons.visibility, viewCount.toString(), Colors.cyanAccent),
                            const SizedBox(width: 12),
                            _miniMetric(Icons.ads_click, clickCount.toString(), Colors.lightBlueAccent),
                            const SizedBox(width: 12),
                            _miniMetric(Icons.receipt, redemptionCount.toString(), Colors.purpleAccent),
                            const Spacer(),
                            if (conversion != null)
                              Text('Conv: $conversion%', style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 40),
              const SizedBox(height: 12),
              Text('Erişim Engellendi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('$err', style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── PARTNERS TAB ──────────────────────────────────────────────────────

// ── APPLICATIONS TAB ──────────────────────────────────────────────────────

class _ApplicationsTab extends ConsumerStatefulWidget {
  const _ApplicationsTab();

  @override
  ConsumerState<_ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends ConsumerState<_ApplicationsTab> {
  String? _statusFilter = 'pending';

  void _showActionDialog(BuildContext context, Map<String, dynamic> app) {
    final noteCtrl = TextEditingController();
    String? selectedAction;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text('Başvuru: ${app['business_name']}', style: const TextStyle(color: Colors.white, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedAction,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: const InputDecoration(labelText: 'İşlem', labelStyle: TextStyle(color: Colors.white54)),
                items: const [
                  DropdownMenuItem(value: 'approve', child: Text('✅ Onayla', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'reject', child: Text('❌ Reddet', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'request_revision', child: Text('📝 Revizyon İste', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setDialogState(() => selectedAction = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Admin Notu (Opsiyonel)', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: selectedAction == null ? null : () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(partnerCatalogRepositoryProvider).handlePartnerApplicationAdmin(
                    applicationId: app['id'],
                    action: selectedAction!,
                    adminNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  );
                  ref.invalidate(partnerApplicationAdminListProvider);
                  ref.invalidate(partnerAdminListProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('İşlem başarılı: $selectedAction'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ) {
    final appsAsync = ref.watch(partnerApplicationAdminListProvider(_statusFilter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Status filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _filterChip('Bekleyen', 'pending'),
                const SizedBox(width: 8),
                _filterChip('Onaylanan', 'approved'),
                const SizedBox(width: 8),
                _filterChip('Reddedilen', 'rejected'),
                const SizedBox(width: 8),
                _filterChip('Revizyon', 'revision_requested'),
                const SizedBox(width: 8),
                _filterChip('Tümü', null),
              ],
            ),
          ),
          Expanded(
            child: appsAsync.when(
              data: (apps) {
                if (apps.isEmpty) {
                  return const Center(child: Text('Bu kategoride başvuru yok.', style: TextStyle(color: Colors.white70)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final status = app['status'] ?? 'pending';
                    Color statusColor;
                    switch (status) {
                      case 'approved': statusColor = Colors.greenAccent; break;
                      case 'rejected': statusColor = Colors.redAccent; break;
                      case 'revision_requested': statusColor = Colors.orangeAccent; break;
                      default: statusColor = Colors.white38; break;
                    }

                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(app['business_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (app['city'] != null) Text('${app['city']} • ${app['desired_tier'] ?? 'basic'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            if (app['contact_email'] != null) Text(app['contact_email'], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            if (status == 'pending') ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.manage_accounts, color: Colors.blueAccent),
                                onPressed: () => _showActionDialog(context, app),
                              ),
                            ],
                          ],
                        ),
                        onTap: status == 'pending' ? () => _showActionDialog(context, app) : null,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.greenAccent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── PARTNERS TAB ──────────────────────────────────────────────────────

class _PartnersTab extends ConsumerWidget {
  const _PartnersTab();

  void _showPartnerDialog(BuildContext context, WidgetRef ref, [Map<String, dynamic>? partner]) {
    showDialog(
      context: context,
      builder: (ctx) => _PartnerFormDialog(partner: partner),
    ).then((_) {
      ref.invalidate(partnerAdminListProvider);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(partnerAdminListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPartnerDialog(context, ref),
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: partnersAsync.when(
        data: (partners) {
          if (partners.isEmpty) return const Center(child: Text('Kayıtlı partner bulunamadı.', style: TextStyle(color: Colors.white70)));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final p = partners[index];
              return Card(
                color: const Color(0xFF2C2C2C),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(p['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Slug: ${p['slug'] ?? ''}\nAktif Ödül: ${p['active_rewards_count'] ?? 0}', style: const TextStyle(color: Colors.white54)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statusChip(p['status']),
                      IconButton(
                        icon: const Icon(Icons.assessment, color: Colors.greenAccent),
                        onPressed: () => context.push('/admin/partner-detail/${p['id']}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _showPartnerDialog(context, ref, p),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    switch (status) {
      case 'active': color = Colors.green; break;
      case 'inactive': color = Colors.red; break;
      default: color = Colors.orange; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text((status ?? 'pending').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _PartnerFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? partner;
  const _PartnerFormDialog({this.partner});

  @override
  ConsumerState<_PartnerFormDialog> createState() => _PartnerFormDialogState();
}

class _PartnerFormDialogState extends ConsumerState<_PartnerFormDialog> {
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _internalNoteController = TextEditingController();
  final _contractUrlController = TextEditingController();
  final _accountOwnerNoteController = TextEditingController();
  
  String _status = 'pending';
  String _contractStatus = 'not_started';
  String _paymentStatus = 'not_started';
  String _sponsorPackage = 'trial';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.partner != null) {
      _nameController.text = widget.partner!['name'] ?? '';
      _slugController.text = widget.partner!['slug'] ?? '';
      _status = widget.partner!['status'] ?? 'pending';
      
      final manualOps = (widget.partner!['metadata'] as Map?)?['manual_ops'] as Map?;
      if (manualOps != null) {
        _internalNoteController.text = manualOps['internal_note'] ?? '';
        _contractUrlController.text = manualOps['contract_url'] ?? '';
        _accountOwnerNoteController.text = manualOps['account_owner_note'] ?? '';
        _contractStatus = manualOps['contract_status'] ?? 'not_started';
        _paymentStatus = manualOps['payment_status'] ?? 'not_started';
        _sponsorPackage = manualOps['sponsor_package'] ?? 'trial';
      }
    }
  }

  void _save() async {
    setState(() => _isLoading = true);
    try {
      final existingMetadata = Map<String, dynamic>.from((widget.partner?['metadata'] as Map?) ?? {});
      final manualOps = {
        'internal_note': _internalNoteController.text.trim(),
        'contract_status': _contractStatus,
        'contract_url': _contractUrlController.text.trim(),
        'payment_status': _paymentStatus,
        'sponsor_package': _sponsorPackage,
        'account_owner_note': _accountOwnerNoteController.text.trim(),
      };
      
      existingMetadata['manual_ops'] = manualOps;

      final data = {
        'p_partner_id': widget.partner?['id'],
        'p_name': _nameController.text,
        'p_slug': _slugController.text,
        'p_status': _status,
        'p_metadata': existingMetadata,
      };
      await ref.read(partnerCatalogRepositoryProvider).upsertPartnerAdmin(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: Text(widget.partner == null ? 'Yeni Partner' : 'Partner Düzenle', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            TextField(controller: _slugController, decoration: const InputDecoration(labelText: 'Slug', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: const Color(0xFF1E1E1E),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'active', child: Text('Active', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _status = v!),
              decoration: const InputDecoration(labelText: 'Status', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            const Text('Manuel Sponsorluk Operasyonu', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: _internalNoteController, decoration: const InputDecoration(labelText: 'İç Not', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white), maxLines: 2),
            DropdownButtonFormField<String>(
              value: _contractStatus,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: const InputDecoration(labelText: 'Sözleşme Durumu', labelStyle: TextStyle(color: Colors.white54)),
              items: const [
                DropdownMenuItem(value: 'not_started', child: Text('Başlamadı', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'sent', child: Text('Gönderildi', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'signed', child: Text('İmzalandı', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'expired', child: Text('Süresi Doldu', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _contractStatus = v!),
            ),
            TextField(controller: _contractUrlController, decoration: const InputDecoration(labelText: 'Sözleşme URL', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            DropdownButtonFormField<String>(
              value: _paymentStatus,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: const InputDecoration(labelText: 'Ödeme Durumu', labelStyle: TextStyle(color: Colors.white54)),
              items: const [
                DropdownMenuItem(value: 'not_started', child: Text('Başlamadı', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'pending', child: Text('Beklemede', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'paid', child: Text('Ödendi', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'overdue', child: Text('Gecikti', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _paymentStatus = v!),
            ),
            DropdownButtonFormField<String>(
              value: _sponsorPackage,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: const InputDecoration(labelText: 'Sponsor Paketi', labelStyle: TextStyle(color: Colors.white54)),
              items: const [
                DropdownMenuItem(value: 'trial', child: Text('Trial', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'basic', child: Text('Basic', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'premium', child: Text('Premium', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'performance', child: Text('Performance', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _sponsorPackage = v!),
            ),
            TextField(controller: _accountOwnerNoteController, decoration: const InputDecoration(labelText: 'Account Owner Notu', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white), maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
        ),
      ],
    );
  }
}

// ── REWARDS TAB ──────────────────────────────────────────────────────

class _RewardsTab extends ConsumerWidget {
  const _RewardsTab();

  void _showRewardDialog(BuildContext context, WidgetRef ref, [Map<String, dynamic>? reward]) {
    showDialog(
      context: context,
      builder: (ctx) => _RewardFormDialog(reward: reward),
    ).then((_) {
      ref.invalidate(rewardAdminListProvider);
    });
  }

  void _showInventoryDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> reward) {
    showDialog(
      context: context,
      builder: (ctx) => _InventoryFormDialog(reward: reward),
    ).then((_) {
      ref.invalidate(rewardAdminListProvider);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardAdminListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRewardDialog(context, ref),
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: rewardsAsync.when(
        data: (rewards) {
          if (rewards.isEmpty) return const Center(child: Text('Kayıtlı ödül bulunamadı.', style: TextStyle(color: Colors.white70)));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rewards.length,
            itemBuilder: (context, index) {
              final r = rewards[index];
              return Card(
                color: const Color(0xFF2C2C2C),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(r['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Partner: ${r['partner_name']}${r['campaign_name'] != null ? " | Kampanya: ${r['campaign_name']}" : ""}\nCost: ${r['cost_points']} MF | Stok: ${r['is_unlimited'] == true ? "Sınırsız" : "${r['stock_remaining'] ?? 0}/${r['stock_total'] ?? 0}"}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.inventory, color: Colors.orangeAccent),
                        onPressed: () => _showInventoryDialog(context, ref, r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _showRewardDialog(context, ref, r),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _RewardFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? reward;
  const _RewardFormDialog({this.reward});

  @override
  ConsumerState<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends ConsumerState<_RewardFormDialog> {
  final _nameController = TextEditingController();
  final _costController = TextEditingController();
  String? _selectedPartnerId;
  String? _selectedCampaignId;
  String _status = 'pending';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.reward != null) {
      _nameController.text = widget.reward!['name'] ?? '';
      _costController.text = widget.reward!['cost_points']?.toString() ?? '0';
      _status = widget.reward!['status'] ?? 'pending';
      _selectedPartnerId = widget.reward!['partner_id'];
      _selectedCampaignId = widget.reward!['campaign_id'];
    }
  }

  void _save() async {
    setState(() => _isLoading = true);
    try {
      final data = {
        'p_reward_id': widget.reward?['id'],
        'p_partner_id': _selectedPartnerId,
        'p_name': _nameController.text,
        'p_cost_points': int.tryParse(_costController.text) ?? 0,
        'p_status': _status,
        'p_campaign_id': _selectedCampaignId,
      };
      await ref.read(partnerCatalogRepositoryProvider).upsertRewardCatalogAdmin(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnerAdminListProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: Text(widget.reward == null ? 'Yeni Ödül' : 'Ödül Düzenle', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            partnersAsync.when(
              data: (partners) => DropdownButtonFormField<String>(
                value: _selectedPartnerId,
                dropdownColor: const Color(0xFF1E1E1E),
                items: partners.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'], style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: widget.reward == null ? (v) => setState(() => _selectedPartnerId = v) : null,
                decoration: const InputDecoration(labelText: 'Partner', labelStyle: TextStyle(color: Colors.white54)),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Partnerler yüklenemedi', style: TextStyle(color: Colors.red)),
            ),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            TextField(controller: _costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost Points', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: const Color(0xFF1E1E1E),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'active', child: Text('Active', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _status = v!),
              decoration: const InputDecoration(labelText: 'Status', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 16),
            if (_selectedPartnerId != null) ...[
              ref.watch(partnerCampaignAdminListProvider(_selectedPartnerId)).when(
                data: (campaigns) => DropdownButtonFormField<String>(
                  value: _selectedCampaignId,
                  dropdownColor: const Color(0xFF1E1E1E),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Kampanyasız', style: TextStyle(color: Colors.white))),
                    ...campaigns.map((c) => DropdownMenuItem(
                      value: c['id'] as String, 
                      child: Text('${c['name']} (${c['status']})', style: const TextStyle(color: Colors.white, fontSize: 13))
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedCampaignId = v),
                  decoration: const InputDecoration(labelText: 'Kampanya (Opsiyonel)', labelStyle: TextStyle(color: Colors.white54)),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Kampanyalar yüklenemedi', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: _isLoading || _selectedPartnerId == null ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _InventoryFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> reward;
  const _InventoryFormDialog({required this.reward});

  @override
  ConsumerState<_InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends ConsumerState<_InventoryFormDialog> {
  final _totalController = TextEditingController();
  final _remainingController = TextEditingController();
  bool _isUnlimited = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _totalController.text = widget.reward['stock_total']?.toString() ?? '0';
    _remainingController.text = widget.reward['stock_remaining']?.toString() ?? '0';
    _isUnlimited = widget.reward['is_unlimited'] == true;
  }

  void _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(partnerCatalogRepositoryProvider).updateRewardInventoryAdmin(
        widget.reward['id'],
        int.tryParse(_totalController.text) ?? 0,
        int.tryParse(_remainingController.text) ?? 0,
        _isUnlimited,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: const Text('Stok Yönetimi', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text('Sınırsız Stok', style: TextStyle(color: Colors.white)),
            value: _isUnlimited,
            onChanged: (v) => setState(() => _isUnlimited = v ?? false),
            checkColor: Colors.black,
            activeColor: Colors.greenAccent,
          ),
          if (!_isUnlimited) ...[
            TextField(controller: _totalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Stock', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            TextField(controller: _remainingController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Remaining Stock', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
          ]
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
        ),
      ],
    );
  }
}

// ── CAMPAIGNS TAB ──────────────────────────────────────────────────────

class _CampaignsTab extends ConsumerStatefulWidget {
  const _CampaignsTab();

  @override
  ConsumerState<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends ConsumerState<_CampaignsTab> {
  String? _selectedPartnerId;

  void _showCampaignDialog([Map<String, dynamic>? campaign]) {
    showDialog(
      context: context,
      builder: (ctx) => _CampaignFormDialog(campaign: campaign, initialPartnerId: _selectedPartnerId),
    ).then((_) {
      ref.invalidate(partnerCampaignAdminListProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(partnerCampaignAdminListProvider(_selectedPartnerId));
    final partnersAsync = ref.watch(partnerAdminListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCampaignDialog(),
        backgroundColor: Colors.purpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Partner Filter
          partnersAsync.when(
            data: (partners) => Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                value: _selectedPartnerId,
                dropdownColor: const Color(0xFF2C2C2C),
                decoration: const InputDecoration(labelText: 'Partner Filtresi', labelStyle: TextStyle(color: Colors.white54)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tüm Partnerler', style: TextStyle(color: Colors.white))),
                  ...partners.map((p) => DropdownMenuItem(value: p['id'], child: Text(p['name'], style: const TextStyle(color: Colors.white)))),
                ],
                onChanged: (v) => setState(() => _selectedPartnerId = v),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: campaignsAsync.when(
              data: (campaigns) {
                if (campaigns.isEmpty) return const Center(child: Text('Kampanya bulunamadı.', style: TextStyle(color: Colors.white70)));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) {
                    final c = campaigns[index];
                    final status = c['status'] ?? 'draft';
                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['partner_name'] ?? '', style: const TextStyle(color: Colors.purpleAccent, fontSize: 11)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _statusBadge(status),
                                const SizedBox(width: 8),
                                Text('${c['reward_count'] ?? 0} Ödül', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                const SizedBox(width: 8),
                                Text('${c['redemption_count'] ?? 0} Kullanım', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white38, size: 20),
                          onPressed: () => _showCampaignDialog(c),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'active') color = Colors.greenAccent;
    if (status == 'paused') color = Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _CampaignFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? campaign;
  final String? initialPartnerId;
  const _CampaignFormDialog({this.campaign, this.initialPartnerId});

  @override
  ConsumerState<_CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends ConsumerState<_CampaignFormDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _cityController = TextEditingController();
  final _campaignInternalNoteController = TextEditingController();
  final _creativeNoteController = TextEditingController();
  final _agreedBudgetNoteController = TextEditingController();

  String? _partnerId;
  String _status = 'draft';
  String _type = 'standard';
  String _creativeStatus = 'pending';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.campaign != null) {
      _nameController.text = widget.campaign!['name'] ?? '';
      _descController.text = widget.campaign!['description'] ?? '';
      _cityController.text = widget.campaign!['target_city'] ?? '';
      _partnerId = widget.campaign!['partner_id'];
      _status = widget.campaign!['status'] ?? 'draft';
      _type = widget.campaign!['campaign_type'] ?? 'standard';
      
      final manualOps = (widget.campaign!['metadata'] as Map?)?['manual_ops'] as Map?;
      if (manualOps != null) {
        _campaignInternalNoteController.text = manualOps['campaign_internal_note'] ?? '';
        _creativeNoteController.text = manualOps['creative_note'] ?? '';
        _agreedBudgetNoteController.text = manualOps['agreed_budget_note'] ?? '';
        _creativeStatus = manualOps['creative_status'] ?? 'pending';
      }
    } else {
      _partnerId = widget.initialPartnerId;
    }
  }

  Future<void> _save() async {
    if (_partnerId == null || _nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final existingMetadata = Map<String, dynamic>.from((widget.campaign?['metadata'] as Map?) ?? {});
      final manualOps = {
        'campaign_internal_note': _campaignInternalNoteController.text.trim(),
        'creative_status': _creativeStatus,
        'creative_note': _creativeNoteController.text.trim(),
        'agreed_budget_note': _agreedBudgetNoteController.text.trim(),
      };
      existingMetadata['manual_ops'] = manualOps;

      await ref.read(partnerCatalogRepositoryProvider).upsertPartnerCampaignAdmin(
        campaignId: widget.campaign?['id'],
        partnerId: _partnerId!,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        campaignType: _type,
        status: _status,
        targetCity: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        metadata: existingMetadata,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnerAdminListProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: Text(widget.campaign == null ? 'Yeni Kampanya' : 'Kampanya Düzenle', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            partnersAsync.when(
              data: (partners) => DropdownButtonFormField<String>(
                value: _partnerId,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: const InputDecoration(labelText: 'Partner', labelStyle: TextStyle(color: Colors.white54)),
                items: partners.map((p) => DropdownMenuItem<String>(value: p['id'] as String, child: Text(p['name'], style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: widget.campaign != null ? null : (v) => setState(() => _partnerId = v),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Partnerler yüklenemedi', style: TextStyle(color: Colors.red)),
            ),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Kampanya Adı', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Açıklama', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white), maxLines: 2),
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Hedef Şehir (Opsiyonel)', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: const InputDecoration(labelText: 'Tür', labelStyle: TextStyle(color: Colors.white54)),
              items: ['standard', 'launch', 'seasonal', 'reactivation', 'city_exclusive', 'performance'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: const InputDecoration(labelText: 'Durum', labelStyle: TextStyle(color: Colors.white54)),
              items: ['draft', 'active', 'paused', 'completed', 'archived'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            const Text('Manuel Kampanya Operasyonu', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(controller: _campaignInternalNoteController, decoration: const InputDecoration(labelText: 'Kampanya İç Notu', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white), maxLines: 2),
            DropdownButtonFormField<String>(
              value: _creativeStatus,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: const InputDecoration(labelText: 'Creative Durumu', labelStyle: TextStyle(color: Colors.white54)),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Beklemede', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'approved', child: Text('Onaylandı', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'rejected', child: Text('Reddedildi', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'needs_revision', child: Text('Revizyon Gerekli', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _creativeStatus = v!),
            ),
            TextField(controller: _creativeNoteController, decoration: const InputDecoration(labelText: 'Creative Notu', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white), maxLines: 2),
            TextField(controller: _agreedBudgetNoteController, decoration: const InputDecoration(labelText: 'Bütçe Notu / Anlaşma', labelStyle: TextStyle(color: Colors.white54)), style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Kaydet'),
        ),
      ],
    );
  }
}
