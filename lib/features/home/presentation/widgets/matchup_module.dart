import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'package:matchfit/features/matchmaker/providers/matchmaker_provider.dart';
import 'package:matchfit/features/profile/models/trust_system.dart';

class MatchUpModule extends ConsumerStatefulWidget {
  const MatchUpModule({super.key});

  @override
  ConsumerState<MatchUpModule> createState() => _MatchUpModuleState();
}

class _MatchUpModuleState extends ConsumerState<MatchUpModule>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late AudioPlayer _audioPlayer;
  String? _lastMatchedUserId;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flashController.dispose();
    super.dispose();
  }

  void _triggerMatchEffects() async {
    // Play sound
    await _audioPlayer.play(AssetSource('sounds/ding.mp3'));

    // Flash ring 3 times
    for (int i = 0; i < 3; i++) {
      await _flashController.forward();
      await _flashController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final matchupState = ref.watch(matchupProvider);

    // Listen for match success
    if (matchupState.matchedUser != null &&
        matchupState.matchedUser!['id'] != _lastMatchedUserId) {
      _lastMatchedUserId = matchupState.matchedUser!['id'];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerMatchEffects();
      });
    } else if (matchupState.matchedUser == null) {
      _lastMatchedUserId = null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: MatchFitTheme.primaryBlue.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: MatchFitTheme.primaryBlue.withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: MatchFitTheme.primaryBlue.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DiagonalPatternPainter(
                color: MatchFitTheme.primaryBlue.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
              // Current User
              Column(
                children: [
                  // Current User Avatar
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Center(
                      child: profileAsync.when(
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
                        loading: () => const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white10,
                        ),
                        error: (_, __) => const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Animated Icon or VS
              Icon(Icons.bolt, color: MatchFitTheme.accentGreen, size: 32),

              // Potential Match
              Column(
                children: [
                  // Potential Match Avatar
                  if (matchupState.matchedUser == null)
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Center(
                        child: _buildPlaceholder(matchupState.isLoading),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => context.push(
                        '/user-profile',
                        extra: matchupState.matchedUser!['id'],
                      ),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _flashController,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Color.lerp(
                                      Colors.blueAccent,
                                      MatchFitTheme.accentGreen,
                                      _flashController.value,
                                    )!,
                                    width: 2 + (_flashController.value * 4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MatchFitTheme.accentGreen
                                          .withOpacity(
                                            _flashController.value * 0.5,
                                          ),
                                      blurRadius: 10 * _flashController.value,
                                      spreadRadius: 2 * _flashController.value,
                                    ),
                                  ],
                                ),
                                child: AvatarWidget(
                                  name:
                                      matchupState.matchedUser!['full_name'] ??
                                      '?',
                                  avatarUrl:
                                      matchupState.matchedUser!['avatar_url'],
                                  radius: 36,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'SPOR ARKADAŞIN SENİ BEKLİYOR',
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
            Builder(
              builder: (context) {
                final score = int.tryParse(matchupState.matchedUser!['trust_score']?.toString() ?? '') ?? 0;
                final info = getTrustLevelInfo(score);
                return Text(
                  'Bugün ${matchupState.matchedUser!['full_name']} (${info.label} • $score Puan) ile spor yapabilirsin!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MatchFitTheme.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
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
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
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
            ),
          ],
        ),
      );
    }

  Widget _buildPlaceholder(bool isLoading) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 2),
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(
                color: Colors.white24,
                strokeWidth: 2,
              )
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

class DiagonalPatternPainter extends CustomPainter {
  final Color color;

  DiagonalPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const double spacing = 30.0;

    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
