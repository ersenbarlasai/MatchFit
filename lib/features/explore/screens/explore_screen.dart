import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'dart:math' as math;
import '../../matchmaker/repositories/matchmaker_repository.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../home/screens/home_screen.dart'; // EventCard

// ── Providers ─────────────────────────────────────────────────────

final exploreMatchesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return [];
  return await ref.read(matchmakerProvider).getSmartMatches(user.id);
});

// ── Explore Screen ─────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _selectedSport = 'All';
  String _selectedDistance = '< 5km';
  String _searchQuery = '';
  bool _showAdvanced = false;

  final _sports = ['All', 'Basketball', 'Tennis', 'Running', 'Football'];
  final _distances = ['< 5km', '< 10km', '< 20km', 'Any'];

  String _greetingTime() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(exploreMatchesProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // ── Header ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: profileAsync.when(
                      data: (p) => AvatarWidget(
                        name: p?['full_name'] ?? 'P',
                        avatarUrl: p?['avatar_url'],
                        radius: 21,
                        editable: false,
                      ),
                      loading: () => const CircleAvatar(radius: 21, backgroundColor: Color(0xFF1E1E1E)),
                      error: (_, __) => const CircleAvatar(radius: 21, backgroundColor: Color(0xFF1E1E1E)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greetingTime()}, Champ',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 19),
                  ),
                ],
              ),
            ),
          ),

          // ── Filter Chips ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 0, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Sport dropdown
                  GestureDetector(
                    onTap: () => _showSportPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0052FF).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF0052FF).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sports, color: Color(0xFF4D9DFF), size: 14),
                          const SizedBox(width: 6),
                          Text(_selectedSport,
                              style: const TextStyle(
                                  color: Color(0xFF4D9DFF), fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF4D9DFF), size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Distance
                  GestureDetector(
                    onTap: () => _showDistancePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Colors.white.withOpacity(0.6), size: 14),
                          const SizedBox(width: 6),
                          Text(_selectedDistance,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Advanced
                  GestureDetector(
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _showAdvanced
                            ? MatchFitTheme.accentGreen.withOpacity(0.12)
                            : const Color(0xFF242424),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _showAdvanced
                                ? MatchFitTheme.accentGreen.withOpacity(0.4)
                                : Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bar_chart_rounded,
                              color: _showAdvanced ? MatchFitTheme.accentGreen : Colors.white60,
                              size: 14),
                          const SizedBox(width: 6),
                          Text('Advanced',
                              style: TextStyle(
                                  color: _showAdvanced ? MatchFitTheme.accentGreen : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),

          // ── Map Placeholder ──
          const SizedBox(height: 12),
          _MapSection(),

          // ── Handle ──
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // ── Nearby Matches ──
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Nearby Matches',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          ),
          const SizedBox(height: 14),

          // ── Event List ──
          Expanded(
            child: matchesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
              error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
              data: (events) {
                final filtered = events.where((e) {
                  if (_selectedSport == 'All') return true;
                  final sport = e['sports']?['name'] as String? ?? '';
                  return sport.toLowerCase() == _selectedSport.toLowerCase();
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, color: Colors.white.withOpacity(0.2), size: 48),
                        const SizedBox(height: 12),
                        Text('No matches found nearby',
                            style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _NearbyEventCard(event: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSportPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24,
            MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Select Sport',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _sports.map((s) {
                final active = s == _selectedSport;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSport = s);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? MatchFitTheme.accentGreen : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            color: active ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistancePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24,
            MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Select Distance',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _distances.map((d) {
                final active = d == _selectedDistance;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDistance = d);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? MatchFitTheme.accentGreen : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(d,
                        style: TextStyle(
                            color: active ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Map Section ───────────────────────────────────────────────────

class _MapSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        children: [
          // Dark map background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF0D1F3C), Color(0xFF122040)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Grid lines (street simulation)
          CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _MapGridPainter(),
          ),
          // Event pin — neon green basketball
          Positioned(
            left: MediaQuery.of(context).size.width * 0.3,
            top: 60,
            child: _MapPin(
              color: MatchFitTheme.accentGreen,
              icon: Icons.sports_basketball_outlined,
              iconColor: Colors.black,
            ),
          ),
          // User pin — blue
          Positioned(
            right: MediaQuery.of(context).size.width * 0.2,
            top: 80,
            child: _MapPin(
              color: const Color(0xFF0052FF),
              icon: Icons.person,
              iconColor: Colors.white,
              size: 38,
            ),
          ),
          // Second event pin
          Positioned(
            left: MediaQuery.of(context).size.width * 0.55,
            top: 30,
            child: _MapPin(
              color: MatchFitTheme.accentGreen.withOpacity(0.7),
              icon: Icons.sports_tennis_outlined,
              iconColor: Colors.black,
              size: 36,
            ),
          ),
          // Bottom fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, const Color(0xFF121212).withOpacity(0.95)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final double size;

  const _MapPin({
    required this.color,
    required this.icon,
    required this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    // Horizontal streets
    for (double y = 20; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical streets (angled slightly)
    for (double x = 0; x < size.width + 60; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x - 20, size.height), paint);
    }
    // Highlight a main road
    final mainPaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.55), Offset(size.width, size.height * 0.45), mainPaint);
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.35, size.height), mainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Nearby Event Card ─────────────────────────────────────────────

class _NearbyEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _NearbyEventCard({required this.event});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = dt.difference(DateTime(now.year, now.month, now.day));
      final timeStr =
          '${dt.hour > 12 ? dt.hour - 12 : dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
      if (diff.inDays == 0) return 'Tonight, $timeStr';
      if (diff.inDays == 1) return 'Tomorrow, $timeStr';
      return '${_months[dt.month - 1]} ${dt.day}, $timeStr';
    } catch (_) {
      return dateStr;
    }
  }

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? 'Event';
    final sport = event['sports']?['name'] as String? ?? 'Sport';
    final date = _formatDate(event['event_date'] as String?);
    final maxP = event['max_participants'] as int? ?? 10;
    final skillLevel = event['skill_level'] as String? ?? '5v5';

    return GestureDetector(
      onTap: () => context.push('/event-detail', extra: event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0052FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${sport.toUpperCase()} • ${skillLevel.toUpperCase()}',
                      style: const TextStyle(
                          color: Color(0xFF4D9DFF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 13, color: Colors.white.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text('1/$maxP',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 15, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(date,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.65), fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/event-detail', extra: event),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      decoration: BoxDecoration(
                        color: MatchFitTheme.accentGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Join',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
