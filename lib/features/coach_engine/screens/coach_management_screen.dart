import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../providers/coach_admin_provider.dart';
import '../providers/coach_provider.dart';

class CoachManagementScreen extends ConsumerWidget {
  const CoachManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingCoachesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Koç Başvuruları',
          style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
            tooltip: 'Tüm Koçlar',
            onPressed: () => context.push('/admin/coach-directory'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(pendingCoachesProvider),
          ),
        ],
      ),
      body: pendingAsync.when(
        data: (coaches) {
          if (coaches.isEmpty) {
            return const Center(
              child: Text(
                'Bekleyen başvuru bulunmuyor.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coaches.length,
            itemBuilder: (context, index) {
              final coach = coaches[index];
              final profile = coach['profiles'] as Map<String, dynamic>?;
              final name = profile?['full_name'] as String? ?? 'İsimsiz Kullanıcı';
              final branch = coach['sub_branch'] ?? 'Belirtilmemiş';
              final experience = coach['experience_years'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: MatchFitTheme.accentGreen.withOpacity(0.1),
                    backgroundImage: profile?['avatar_url'] != null 
                        ? NetworkImage(profile!['avatar_url']) 
                        : null,
                    child: profile?['avatar_url'] == null 
                        ? Text(name[0], style: const TextStyle(color: MatchFitTheme.accentGreen)) 
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '$branch • $experience Yıl Deneyim',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _showReviewDialog(context, ref, coach),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MatchFitTheme.accentGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('İncele'),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, stack) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> coach) {
    final docs = List<Map<String, dynamic>>.from(coach['coach_documents'] ?? []);
    final userId = coach['user_id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Başvuru Detayları',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Bio', coach['bio'] ?? '-'),
              _buildInfoRow('Lokasyon', coach['work_location'] ?? '-'),
              _buildInfoRow('Video', coach['intro_video_url'] ?? '-'),
              const SizedBox(height: 32),
              const Text(
                'Belgeler',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...docs.map((doc) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          doc['doc_type'].toString().toUpperCase(),
                          style: const TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.white70),
                          tooltip: 'Belgeyi İndir / Aç',
                          onPressed: () async {
                            final url = Uri.parse(doc['file_url']);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        doc['file_url'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Text('Görsel yüklenemedi', style: TextStyle(color: Colors.white24)),
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleDecision(context, ref, userId, 'none', false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Reddet'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleDecision(context, ref, userId, 'basic', true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MatchFitTheme.accentGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Onayla'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDecision(BuildContext context, WidgetRef ref, String userId, String level, bool isActive) async {
    try {
      await ref.read(coachEngineRepositoryProvider).updateCoachStatus(
        userId: userId,
        level: level,
        isActive: isActive,
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ref.invalidate(pendingCoachesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Koç başarıyla onaylandı!' : 'Başvuru reddedildi.'),
            backgroundColor: isActive ? MatchFitTheme.accentGreen : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
