import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import '../providers/coach_provider.dart';

class CoachAdminHubScreen extends ConsumerWidget {
  const CoachAdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Koçluk Yönetimi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: CircularProgressIndicator());

          final role = profile['role']?.toString();
          final isAdmin = role == 'admin' || role == 'system_admin';
          final isCoach = profile['is_coach'] ?? false;
          final userId = profile['id'] as String?;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (isAdmin)
                _buildHubCard(
                  context,
                  title: 'Koç Başvuruları',
                  subtitle: 'Yeni başvuruları ve belgeleri incele',
                  icon: Icons.assignment_ind_outlined,
                  color: MatchFitTheme.accentGreen,
                  route: '/admin/coaches',
                ),
              
              if (isCoach || isAdmin)
                _buildHubCard(
                  context,
                  title: isAdmin ? 'Seans Yönetimi (Genel)' : 'Seanslarım',
                  subtitle: 'Aktif ve geçmiş seans taleplerini yönet',
                  icon: Icons.calendar_today_outlined,
                  color: Colors.blueAccent,
                  route: '/coach-sessions',
                ),

              if (isCoach) ...[
                _buildHubCard(
                  context,
                  title: 'Uygunluk Saatlerim',
                  subtitle: 'Haftalık takvimini ve saatlerini düzenle',
                  icon: Icons.more_time_outlined,
                  color: Colors.orangeAccent,
                  route: '/coach-availability',
                ),
                _buildHubCard(
                  context,
                  title: 'Koç Profilim',
                  subtitle: 'Kullanıcılara görünen profilini incele',
                  icon: Icons.person_outline,
                  color: Colors.purpleAccent,
                  route: '/coach-detail',
                  extra: userId,
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white10),
              ),

              _buildHubCard(
                context,
                title: 'Koçları Gör',
                subtitle: 'MatchFit koç topluluğuna göz at',
                icon: Icons.explore_outlined,
                color: Colors.white70,
                route: '/coaches',
              ),

              if (!isCoach) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white10),
                ),
                _buildHubCard(
                  context,
                  title: 'Koç Ol',
                  subtitle: 'Eğitmenlik başvurunu yap ve kazanmaya başla',
                  icon: Icons.sports_outlined,
                  color: Colors.amber,
                  route: '/coach-info',
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
    dynamic extra,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: () => context.push(route, extra: extra),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      ),
    );
  }
}
