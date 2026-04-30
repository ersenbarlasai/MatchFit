import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../../auth/repositories/auth_repository.dart';

// ── Providers ──────────────────────────────────────────────────────

final profileDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return {};
  final sb = Supabase.instance.client;

  final profile = await sb.from('profiles').select('full_name, trust_score').eq('id', user.id).maybeSingle();
  final hosted = await sb.from('events').select('id, status').eq('host_id', user.id);
  final joined = await sb.from('event_participants').select('id').eq('user_id', user.id);
  final posts  = await sb.from('posts').select('id').eq('user_id', user.id);

  final hostedList = List<Map<String, dynamic>>.from(hosted);
  final completed = hostedList.where((e) => e['status'] == 'completed').length;
  final completionPct = hostedList.isEmpty ? 100 : ((completed / hostedList.length) * 100).round();

  return {
    'full_name': profile?['full_name'] ?? 'Player',
    'trust_score': profile?['trust_score'] ?? 100,
    'events_joined': (joined as List).length,
    'events_hosted': hostedList.length,
    'completion_pct': completionPct,
    'posts_count': (posts as List).length,
  };
});

// ── Profile Screen ─────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(profileDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _buildBody(data),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final name = data['full_name'] as String;
    final trustScore = data['trust_score'] as int;
    final joined = data['events_joined'] as int;
    final hosted = data['events_hosted'] as int;
    final completion = data['completion_pct'] as int;

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: const Text('Profile',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => context.push('/privacy-settings'),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ── Avatar ──
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: MatchFitTheme.accentGreen, width: 3),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0052FF), Color(0xFF003DB0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: MatchFitTheme.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF121212), width: 2),
                      ),
                      child: const Icon(Icons.verified, size: 12, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Name
              Text(name.split(' ').first,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text('MatchFit Player',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 20),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MatchFitTheme.accentGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        child: const Text('Edit Profile',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2A3B6E), width: 1.5),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        icon: const Icon(Icons.person_add_outlined, size: 16),
                        label: const Text('Invite',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _StatCard(value: '$joined', label: 'EVENTS\nJOINED', accentColor: Colors.white),
                    const SizedBox(width: 10),
                    _StatCard(value: '$hosted', label: 'EVENTS\nHOSTED', accentColor: Colors.white),
                    const SizedBox(width: 10),
                    _StatCard(
                        value: '$completion%',
                        label: 'COMPLETION',
                        accentColor: MatchFitTheme.accentGreen),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Trust Score Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _TrustScoreCard(score: trustScore),
              ),
              const SizedBox(height: 20),
              // Tab Bar
              TabBar(
                controller: _tabController,
                labelColor: MatchFitTheme.accentGreen,
                unselectedLabelColor: Colors.white38,
                indicatorColor: MatchFitTheme.accentGreen,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Past Events'),
                  Tab(text: 'Badges'),
                  Tab(text: 'Friends'),
                ],
              ),
              const Divider(height: 1, color: Colors.white10),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostsGrid(),
          _PastEventsTab(),
          _BadgesTab(),
          _FriendsTab(),
        ],
      ),
    );
  }
}

// ── Trust Score Card ──────────────────────────────────────────────

class _TrustScoreCard extends StatelessWidget {
  final int score;
  const _TrustScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: MatchFitTheme.accentGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trust Score',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Community standing and reliability.',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ],
                ),
              ),
              _CircularScore(score: score),
            ],
          ),
          const SizedBox(height: 20),
          _TrustRow(icon: Icons.access_time_outlined, label: 'Punctuality', delta: '+5', positive: true),
          const SizedBox(height: 12),
          _TrustRow(icon: Icons.thumb_up_outlined, label: 'Good Sport', delta: '+10', positive: true),
          const SizedBox(height: 12),
          _TrustRow(icon: Icons.calendar_month_outlined, label: 'Late Cancellation', delta: '-2', positive: false),
        ],
      ),
    );
  }
}

class _CircularScore extends StatelessWidget {
  final int score;
  const _CircularScore({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(60, 60),
            painter: _CirclePainter(score / 100),
          ),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  _CirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // BG ring
    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = MatchFitTheme.accentGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TrustRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String delta;
  final bool positive;
  const _TrustRow({required this.icon, required this.label, required this.delta, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Text(
            delta,
            style: TextStyle(
              color: positive ? MatchFitTheme.accentGreen : const Color(0xFFFF6B6B),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;
  const _StatCard({required this.value, required this.label, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ── Tab Contents ──────────────────────────────────────────────────

class _PostsGrid extends StatelessWidget {
  final List<_PostItem> _items = const [
    _PostItem(sport: 'Tennis', icon: Icons.sports_tennis, color: Color(0xFF1A3A2A)),
    _PostItem(sport: '10k Run', icon: Icons.directions_run, color: Color(0xFF1A1A3A)),
    _PostItem(sport: 'Weekend Warrior', icon: Icons.emoji_events_outlined, color: Color(0xFF2A2A0A), isBadge: true),
    _PostItem(sport: '5v5', icon: Icons.sports_soccer, color: Color(0xFF2A1A0A)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) => _PostCard(item: _items[index]),
    );
  }
}

class _PostItem {
  final String sport;
  final IconData icon;
  final Color color;
  final bool isBadge;
  const _PostItem({required this.sport, required this.icon, required this.color, this.isBadge = false});
}

class _PostCard extends StatelessWidget {
  final _PostItem item;
  const _PostCard({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isBadge) {
      return Container(
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: MatchFitTheme.accentGreen.withOpacity(0.1), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MatchFitTheme.accentGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: MatchFitTheme.accentGreen, size: 28),
            ),
            const SizedBox(height: 10),
            Text(item.sport,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Unlocked yesterday',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: item.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // BG pattern / icon
          Positioned.fill(
            child: Icon(item.icon, color: Colors.white.withOpacity(0.04), size: 80),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(item.sport,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    Icon(Icons.favorite_border, color: Colors.white54, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PastEventsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('Past Events — Coming soon', style: TextStyle(color: Colors.white38)));
  }
}

class _BadgesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final badges = [
      {'icon': Icons.emoji_events_outlined, 'name': 'Weekend Warrior', 'desc': 'Joined 5 weekend events'},
      {'icon': Icons.thumb_up_outlined, 'name': 'Good Sport', 'desc': 'Received 10 positive ratings'},
      {'icon': Icons.bolt_outlined, 'name': 'Quick Joiner', 'desc': 'Joined an event within 1 hour'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MatchFitTheme.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(badge['icon'] as IconData, color: MatchFitTheme.accentGreen),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge['name'] as String,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(badge['desc'] as String,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FriendsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Friends — Coming soon', style: TextStyle(color: Colors.white38)));
  }
}
