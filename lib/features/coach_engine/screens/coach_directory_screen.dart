import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/core/theme.dart';
import '../providers/coach_admin_provider.dart';
import '../providers/coach_provider.dart';

class CoachDirectoryScreen extends ConsumerWidget {
  const CoachDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(allCoachesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Koç Rehberi & Yönetimi',
          style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(allCoachesProvider),
          ),
        ],
      ),
      body: coachesAsync.when(
        data: (coaches) {
          if (coaches.isEmpty) {
            return const Center(
              child: Text(
                'Kayıtlı koç bulunmuyor.',
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
              final name = profile?['full_name'] ?? 'İsimsiz Kullanıcı';
              final level = coach['verification_level'] ?? 'none';
              final isActive = coach['is_active'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? MatchFitTheme.accentGreen.withOpacity(0.2) : Colors.white10,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _getLevelColor(level).withOpacity(0.1),
                    backgroundImage: profile?['avatar_url'] != null 
                        ? NetworkImage(profile!['avatar_url']) 
                        : null,
                    child: profile?['avatar_url'] == null 
                        ? Text(name[0], style: TextStyle(color: _getLevelColor(level))) 
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildLevelBadge(level),
                    ],
                  ),
                  subtitle: Text(
                    '${coach['sub_branch'] ?? 'Spor'} • ${coach['experience_years']} Yıl • ${isActive ? "Aktif" : "Pasif"}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onSelected: (val) => _handleAction(context, ref, coach, val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'activate', child: Text('Aktifleştir')),
                      const PopupMenuItem(value: 'deactivate', child: Text('Devre Dışı Bırak')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'level_basic', child: Text('Seviye: Basic')),
                      const PopupMenuItem(value: 'level_certified', child: Text('Seviye: Certified')),
                      const PopupMenuItem(value: 'level_elite', child: Text('Seviye: Elite')),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'elite': return Colors.amber;
      case 'certified': return Colors.blue;
      case 'basic': return MatchFitTheme.accentGreen;
      default: return Colors.grey;
    }
  }

  Widget _buildLevelBadge(String level) {
    final color = _getLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, Map<String, dynamic> coach, String action) async {
    final repo = ref.read(coachEngineRepositoryProvider);
    final userId = coach['user_id'];
    
    String newLevel = coach['verification_level'];
    bool newActive = coach['is_active'];

    if (action == 'activate') newActive = true;
    if (action == 'deactivate') newActive = false;
    if (action == 'level_basic') newLevel = 'basic';
    if (action == 'level_certified') newLevel = 'certified';
    if (action == 'level_elite') newLevel = 'elite';

    try {
      await repo.updateCoachStatus(
        userId: userId,
        level: newLevel,
        isActive: newActive,
      );
      ref.invalidate(allCoachesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güncelleme başarılı!'), backgroundColor: MatchFitTheme.accentGreen),
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
}
