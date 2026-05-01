import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import '../../events/repositories/event_repository.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../repositories/matchmaker_repository.dart';
import 'package:matchfit/core/services/location_service.dart';

// ── Providers ──────────────────────────────────────────────────────

final eventsProvider = FutureProvider.autoDispose((ref) async {
  final userLoc = ref.watch(userLocationProvider).value;
  return ref.read(eventRepositoryProvider).getNearbyEvents(
    lat: userLoc?.latitude,
    lng: userLoc?.longitude,
  );
});

final weeklyStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return {'runs': 0, 'games': 0, 'points': 0};

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekStartStr = weekStart.toIso8601String().substring(0, 10);

  final joined = await Supabase.instance.client
      .from('event_participants')
      .select('events(event_date, sports(name))')
      .eq('user_id', user.id)
      .gte('created_at', weekStartStr);

  final list = List<Map<String, dynamic>>.from(joined);
  int runs = 0, games = 0;
  for (final item in list) {
    final sport = item['events']?['sports']?['name'] as String? ?? '';
    if (sport.toLowerCase().contains('run')) runs++;
    else games++;
  }
  final profileData = await Supabase.instance.client
      .from('profiles')
      .select('trust_score')
      .eq('id', user.id)
      .maybeSingle();
  final points = profileData?['trust_score'] as int? ?? 0;
  return {'runs': runs, 'games': games, 'points': points, 'total': list.length};
});

// ── Home Screen ─────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final statsAsync = ref.watch(weeklyStatsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    final firstName = profileAsync.when(
      data: (p) => (p?['full_name'] as String? ?? 'Player').split(' ').first,
      loading: () => '...',
      error: (_, __) => 'Player',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-event'),
        backgroundColor: MatchFitTheme.accentGreen,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: RefreshIndicator(
        color: MatchFitTheme.accentGreen,
        onRefresh: () async {
          ref.refresh(eventsProvider);
          ref.refresh(currentUserProfileProvider);
          ref.refresh(weeklyStatsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/profile'),
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
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Hello $firstName ',
                                    style: const TextStyle(
                                      color: Color(0xFF4D9DFF),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const TextSpan(text: '👋', style: TextStyle(fontSize: 18)),
                                ],
                              ),
                            ),
                            Text('Ready to move?',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.notifications_outlined, color: Colors.white70, size: 20),
                              onPressed: () => context.push('/notifications'),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: MatchFitTheme.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Weekly Progress ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekly Progress',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20)),
                        TextButton(
                          onPressed: () => context.push('/profile'),
                          child: const Text('Details',
                              style: TextStyle(color: Color(0xFF4D9DFF), fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    statsAsync.when(
                      loading: () => const _ProgressCardSkeleton(),
                      error: (_, __) => const _ProgressCardSkeleton(),
                      data: (stats) => _WeeklyProgressCard(stats: stats),
                    ),
                  ],
                ),
              ),
            ),

            // ── Suggested Members ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Suggested Members',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                    const SizedBox(height: 14),
                    ref.watch(suggestedMembersProvider).when(
                      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen))),
                      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.white24)),
                      data: (members) => SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return _SuggestedMemberCard(member: member);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Near You ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 0, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Near You',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                    TextButton(
                      onPressed: () => context.push('/explore'),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: Text('See Map',
                            style: TextStyle(color: Color(0xFF4D9DFF), fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Event Cards (Horizontal Scroll) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                child: eventsAsync.when(
                  loading: () => const SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e', style: const TextStyle(color: Colors.white54)),
                  ),
                  data: (events) => events.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('No events nearby.',
                              style: TextStyle(color: Colors.white.withOpacity(0.35))),
                        )
                      : SizedBox(
                          height: 300,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(left: 20),
                            itemCount: events.length,
                            itemBuilder: (context, index) =>
                                EventCard(event: events[index]),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weekly Progress Card ──────────────────────────────────────────

class _WeeklyProgressCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _WeeklyProgressCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final runs = stats['runs'] as int;
    final games = stats['games'] as int;
    final points = stats['points'] as int;
    final total = stats['total'] as int;
    final streakDays = total > 0 ? (total * 1.5).clamp(1, 7).toInt() : 0;
    final goalPct = ((total / 5) * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined,
                  color: MatchFitTheme.accentGreen, size: 22),
              const SizedBox(width: 8),
              Text('$streakDays Day Streak',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
              const Spacer(),
              Text('$goalPct% Goal',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goalPct / 100,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(MatchFitTheme.accentGreen),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Runs', value: '$runs/3')),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Games', value: '$games/2')),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'Points', value: '$points')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ProgressCardSkeleton extends StatelessWidget {
  const _ProgressCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: MatchFitTheme.accentGreen, strokeWidth: 2),
      ),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const EventCard({super.key, required this.event});

  IconData _sportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis': return Icons.sports_tennis;
      case 'running': return Icons.directions_run;
      case 'basketball': return Icons.sports_basketball;
      case 'football': return Icons.sports_soccer;
      default: return Icons.sports;
    }
  }

  Color _sportGradientStart(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis': return const Color(0xFF0A2A1A);
      case 'running': return const Color(0xFF1A0A2A);
      case 'basketball': return const Color(0xFF1A1A0A);
      case 'football': return const Color(0xFF0A1A2A);
      default: return const Color(0xFF1A1A1A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String? ?? 'Event';
    final location = event['location_name'] as String? ?? event['location_text'] as String? ?? 'Nearby';
    final sport = event['sports']?['name'] as String? ?? 'Sport';
    final date = event['event_date'] as String? ?? '';
    final hostName = event['profiles']?['full_name'] as String? ?? 'Host';
    final maxParticipants = event['max_participants'] as int? ?? 10;
    final skillLevel = event['required_level'] as String? ?? 'All Levels';

    return GestureDetector(
      onTap: () => context.push('/event-detail', extra: event),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: _sportGradientStart(sport),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Stack(
          children: [
            // BG sport icon watermark
            Positioned(
              right: -20,
              top: 20,
              child: Icon(_sportIcon(sport),
                  size: 120, color: Colors.white.withOpacity(0.04)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge top-left
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MatchFitTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_sportIcon(sport), size: 12, color: MatchFitTheme.accentGreen),
                        const SizedBox(width: 4),
                        Text('$sport • $skillLevel',
                            style: const TextStyle(
                                color: MatchFitTheme.accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Title
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(location,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Date
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 13, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(date,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Bottom row: avatars + Join
                  Row(
                    children: [
                      AvatarWidget(
                        name: hostName,
                        radius: 13,
                        avatarUrl: event['profiles']?['avatar_url'],
                        editable: false,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: Text('+$maxParticipants',
                              style: const TextStyle(color: Colors.white70, fontSize: 9)),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => context.push('/event-detail', extra: event),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedMemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  const _SuggestedMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = member['full_name'] as String? ?? 'Player';
    final avatarUrl = member['avatar_url'] as String?;
    final trustScore = member['trust_score'] as int? ?? 100;
    final userId = member['id'] as String;

    return GestureDetector(
      onTap: () => context.push('/user-profile', extra: userId),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                AvatarWidget(
                  name: name,
                  radius: 32,
                  avatarUrl: avatarUrl,
                  editable: false,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MatchFitTheme.accentGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, size: 10, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name.split(' ').first,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$trustScore Trust',
              style: TextStyle(color: MatchFitTheme.accentGreen.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
