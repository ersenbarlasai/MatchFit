import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../providers/coach_provider.dart';

class CoachOnboardingInfoScreen extends ConsumerWidget {
  const CoachOnboardingInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(coachLandingContentProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: contentAsync.when(
        data: (content) {
          if (content == null) {
            return const Center(child: Text('İçerik bulunamadı.', style: TextStyle(color: Colors.white54)));
          }

          final benefits = List<String>.from(content['benefits'] ?? []);
          final requirements = List<String>.from(content['requirements'] ?? []);

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Icon(Icons.workspace_premium, color: MatchFitTheme.accentGreen, size: 80),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          content['title'] ?? 'Profesyonel Koç Ağına Katılın',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.2),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          content['description'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        
                        // Avantajlar
                        if (benefits.isNotEmpty) ...[
                          const Text('Neden Katılmalısın?', style: TextStyle(color: MatchFitTheme.accentGreen, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ...benefits.map((e) => _buildBulletPoint(e, Icons.check_circle_outline, MatchFitTheme.accentGreen)),
                          const SizedBox(height: 32),
                        ],

                        // Gereksinimler
                        if (requirements.isNotEmpty) ...[
                          const Text('Gereksinimler', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ...requirements.map((e) => _buildBulletPoint(e, Icons.assignment_outlined, Colors.amber)),
                          const SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                ),
                // Footer Button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF121212),
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.pushReplacement('/become-coach'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MatchFitTheme.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text(
                        'Başvuruyu Başlat',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildBulletPoint(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
