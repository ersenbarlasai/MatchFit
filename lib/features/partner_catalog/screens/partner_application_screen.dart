import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/partner_catalog_provider.dart';

class PartnerApplicationScreen extends ConsumerStatefulWidget {
  const PartnerApplicationScreen({super.key});

  @override
  ConsumerState<PartnerApplicationScreen> createState() => _PartnerApplicationScreenState();
}

class _PartnerApplicationScreenState extends ConsumerState<PartnerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _desiredTier = 'basic';
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _categoryCtrl.dispose();
    _cityCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _taxNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final idempotencyKey = 'partner_apply:${userId ?? 'anon'}:${_businessNameCtrl.text.trim()}:${DateTime.now().toIso8601String().substring(0, 10)}';

      await ref.read(partnerCatalogRepositoryProvider).submitPartnerApplication(
        businessName: _businessNameCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        contactName: _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
        contactEmail: _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim(),
        taxNumber: _taxNumberCtrl.text.trim().isEmpty ? null : _taxNumberCtrl.text.trim(),
        desiredTier: _desiredTier,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        idempotencyKey: idempotencyKey,
      );

      ref.invalidate(myPartnerApplicationsProvider);
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Sponsor Başvurusu', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_submitted) _buildSuccessState() else _buildForm(),
            const SizedBox(height: 32),
            _buildMyApplications(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 56),
          const SizedBox(height: 16),
          const Text('Başvurunuz Alındı!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Admin ekibimiz başvurunuzu inceleyecek ve e-posta ile bilgilendirme yapacaktır.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _submitted = false),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
            child: const Text('Yeni Başvuru'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.purple.withValues(alpha: 0.2), Colors.blue.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront, color: Colors.purpleAccent, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MatchFit Sponsor Ol', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Kullanıcılara özel ödüller sunun ve markanızı büyütün.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('İşletme Bilgileri'),
          _buildField(_businessNameCtrl, 'İşletme Adı *', required: true),
          _buildField(_categoryCtrl, 'Kategori (örn: Spor, Gıda, Teknoloji)'),
          _buildField(_cityCtrl, 'Şehir'),
          const SizedBox(height: 16),
          _sectionLabel('Yetkili Bilgileri'),
          _buildField(_contactNameCtrl, 'Yetkili Adı Soyadı'),
          _buildField(_contactEmailCtrl, 'İletişim E-posta', keyboardType: TextInputType.emailAddress),
          _buildField(_taxNumberCtrl, 'Vergi Numarası (Opsiyonel)'),
          const SizedBox(height: 16),
          _sectionLabel('Sponsorluk Tercihleri'),
          DropdownButtonFormField<String>(
            value: _desiredTier,
            dropdownColor: const Color(0xFF2C2C2C),
            decoration: _inputDecoration('İstenen Paket'),
            items: const [
              DropdownMenuItem(value: 'basic', child: Text('Basic', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'premium', child: Text('Premium', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'enterprise', child: Text('Enterprise', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (v) => setState(() => _desiredTier = v!),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildField(_notesCtrl, 'Ek Notlar / Önerilen Ödül Türleri', maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Başvuruyu Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyApplications() {
    final appsAsync = ref.watch(myPartnerApplicationsProvider);

    return appsAsync.when(
      data: (apps) {
        if (apps.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Başvurularım', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...apps.map((app) => _buildAppCard(app)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'pending';
    final createdAt = app['created_at'] != null ? DateTime.tryParse(app['created_at']) : null;
    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved': statusColor = Colors.greenAccent; statusText = 'Onaylandı'; break;
      case 'rejected': statusColor = Colors.redAccent; statusText = 'Reddedildi'; break;
      case 'revision_requested': statusColor = Colors.orangeAccent; statusText = 'Revizyon İstendi'; break;
      default: statusColor = Colors.white38; statusText = 'Beklemede'; break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(app['business_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM yyyy').format(createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          if (app['admin_note'] != null && app['admin_note'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Admin Notu: ${app['admin_note']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label zorunludur' : null : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.purpleAccent)),
    );
  }
}
