import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'package:matchfit/features/matchmaker/providers/matchmaker_provider.dart';

class MatchUpModule extends ConsumerWidget {
  const MatchUpModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final matchupState = ref.watch(matchupProvider);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: MatchFitTheme.accentGreen.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: MatchFitTheme.accentGreen.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Current User
              Column(
                children: [
                  const Text(
                    'SEN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  profileAsync.when(
                    data: (p) => Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MatchFitTheme.accentGreen,
                          width: 2,
                        ),
                      ),
                      child: AvatarWidget(
                        name: p?['full_name'] ?? 'E',
                        avatarUrl: p?['avatar_url'],
                        radius: 36,
                      ),
                    ),
                    loading: () => const CircleAvatar(radius: 36, backgroundColor: Colors.white10),
                    error: (_, __) => const CircleAvatar(radius: 36, backgroundColor: Colors.white10),
                  ),
                ],
              ),
              
              // Animated Icon or VS
              Icon(
                Icons.bolt,
                color: MatchFitTheme.accentGreen,
                size: 32,
              ),

              // Potential Match
              Column(
                children: [
                  const Text(
                    'POTANSİYEL EŞLEŞME',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (matchupState.matchedUser == null)
                    _buildPlaceholder(matchupState.isLoading)
                  else
                    GestureDetector(
                      onTap: () => context.push('/user-profile', extra: matchupState.matchedUser!['id']),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent,
                            width: 2,
                          ),
                        ),
                        child: AvatarWidget(
                          name: matchupState.matchedUser!['full_name'] ?? '?',
                          avatarUrl: matchupState.matchedUser!['avatar_url'],
                          radius: 36,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'MÜKEMMEL EŞLEŞME İÇİN HAZIR MISIN?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (matchupState.matchedUser != null) ...[
            const SizedBox(height: 8),
            Text(
              'Bugün ${matchupState.matchedUser!['full_name']} ile spor yapabilirsin!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MatchFitTheme.accentGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: matchupState.isLoading 
              ? null 
              : () => ref.read(matchupProvider.notifier).findMatch(),
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: matchupState.isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MATCH UP',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.shuffle, size: 24),
                  ],
                ),
          ),
          if (matchupState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              matchupState.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isLoading) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white10,
          width: 2,
        ),
      ),
      child: Center(
        child: isLoading
          ? const CircularProgressIndicator(color: Colors.white24, strokeWidth: 2)
          : const Text(
              '?',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }
}
