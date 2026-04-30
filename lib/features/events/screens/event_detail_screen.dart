import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/initials_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/event_repository.dart';
import '../../auth/repositories/auth_repository.dart';

// ── Roster Provider ────────────────────────────────────────────────

final eventRosterProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final response = await Supabase.instance.client
      .from('event_participants')
      .select('user_id, profiles(full_name, trust_score)')
      .eq('event_id', eventId);
  return List<Map<String, dynamic>>.from(response);
});

// ── Event Detail Screen ────────────────────────────────────────────

class EventDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isJoining = false;
  bool _hasJoined = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyJoined();
  }

  Future<void> _checkIfAlreadyJoined() async {
    final eventId = widget.event['id']?.toString() ?? '';
    if (eventId.isEmpty) return;
    final joined = await ref.read(eventRepositoryProvider).isAlreadyJoined(eventId);
    if (mounted) setState(() => _hasJoined = joined);
  }

  Future<void> _joinEvent() async {
    setState(() => _isJoining = true);
    try {
      await ref.read(eventRepositoryProvider).joinEvent(widget.event['id'].toString());
      setState(() => _hasJoined = true);
      if (mounted) _showShareBottomSheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showShareBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: MatchFitTheme.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.celebration_outlined, color: MatchFitTheme.accentGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("You're in! 🎉",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Want to share this moment with your followers?',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/share-event-post', extra: widget.event);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MatchFitTheme.accentGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Share Moment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _sportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis': return Icons.sports_tennis;
      case 'running': return Icons.directions_run;
      case 'basketball': return Icons.sports_basketball;
      case 'football': return Icons.sports_soccer;
      default: return Icons.sports;
    }
  }

  Color _sportGradient(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis': return const Color(0xFF0A2A1A);
      case 'basketball': return const Color(0xFF1A1A0A);
      case 'football': return const Color(0xFF0A1A2A);
      default: return const Color(0xFF1A1A2A);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month]} ${dt.day}, $h:$m $ampm';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title'] as String? ?? 'Event';
    final sport = widget.event['sports']?['name'] as String? ?? 'Sport';
    final description = widget.event['description'] as String? ?? 'No description available.';
    final location = widget.event['location_name'] as String? ?? widget.event['location_text'] as String? ?? 'Location TBD';
    final date = _formatDate(widget.event['event_date'] as String?);
    final hostName = widget.event['profiles']?['full_name'] as String? ?? 'Host';
    final hostTrust = widget.event['profiles']?['trust_score'] as int? ?? 100;
    final maxP = widget.event['max_participants'] as int? ?? 10;
    final skillLevel = widget.event['skill_level'] as String? ?? 'Open';
    final eventId = widget.event['id']?.toString() ?? '';
    final hostId = widget.event['host_id'] as String? ?? '';
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    final isHost = currentUser != null && currentUser.id == hostId;

    final rosterAsync = ref.watch(eventRosterProvider(eventId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        title: const Text('Event Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Image ──
                  _HeroSection(sport: sport, sportIcon: _sportIcon(sport), gradientColor: _sportGradient(sport)),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Tags ──
                        Row(
                          children: [
                            _Badge(label: sport, color: const Color(0xFF0052FF)),
                            const SizedBox(width: 8),
                            _Badge(label: skillLevel, color: const Color(0xFF2A2A2A), textColor: Colors.white70),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Title ──
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
                        const SizedBox(height: 10),

                        // ── Date & Price ──
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text(date, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(width: 16),
                            const Icon(Icons.attach_money, size: 14, color: Colors.white54),
                            Text('Free', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(' / player', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
                          ],
                        ),

                        const SizedBox(height: 28),
                        const _Divider(),

                        // ── About ──
                        const SizedBox(height: 20),
                        const Text('About the Event',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 10),
                        Text(description,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                height: 1.6)),

                        const SizedBox(height: 24),
                        const _Divider(),

                        // ── Location ──
                        const SizedBox(height: 20),
                        const Text('Location',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 12),
                        _LocationCard(location: location),

                        const SizedBox(height: 24),
                        const _Divider(),

                        // ── Hosted By ──
                        const SizedBox(height: 20),
                        const Text('Hosted By',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 12),
                        _HostCard(
                            hostName: hostName,
                            trustScore: hostTrust),

                        const SizedBox(height: 24),
                        const _Divider(),

                        // ── Roster ──
                        const SizedBox(height: 20),
                        rosterAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                          data: (roster) => _RosterSection(
                            roster: roster,
                            maxParticipants: maxP,
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom CTA ──
          _BottomCta(
            isHost: isHost,
            hasJoined: _hasJoined,
            isJoining: _isJoining,
            onJoin: _joinEvent,
          ),
        ],
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final String sport;
  final IconData sportIcon;
  final Color gradientColor;
  const _HeroSection({required this.sport, required this.sportIcon, required this.gradientColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradientColor, const Color(0xFF121212)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(0.06), Colors.transparent],
              ),
            ),
          ),
          // Sport icon big
          Icon(sportIcon, size: 80, color: Colors.white.withOpacity(0.08)),
          // Spotlight lines (decorative)
          CustomPaint(
            size: const Size(double.infinity, 240),
            painter: _SpotlightPainter(),
          ),
          // Centered sport icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(sportIcon, size: 48, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60.0) * (3.14159 / 180);
      final dx = size.width / 2 + 200 * (i % 2 == 0 ? 1 : -1);
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(dx, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Location Card ─────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final String location;
  const _LocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          // Mini map preview
          Container(
            height: 90,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: const LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF0D1F3C)],
              ),
            ),
            child: Center(
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: MatchFitTheme.accentGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: MatchFitTheme.accentGreen.withOpacity(0.5), blurRadius: 14)],
                ),
                child: const Icon(Icons.location_on, color: Colors.black, size: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.navigation_outlined, color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Host Card ─────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final String hostName;
  final int trustScore;
  const _HostCard({required this.hostName, required this.trustScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: hostName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(hostName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MatchFitTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 12, color: MatchFitTheme.accentGreen),
                    const SizedBox(width: 4),
                    Text('$trustScore Trust',
                        style: const TextStyle(
                            color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Verified event organizer with high trust rating.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Roster Section ────────────────────────────────────────────────

class _RosterSection extends StatelessWidget {
  final List<Map<String, dynamic>> roster;
  final int maxParticipants;
  const _RosterSection({required this.roster, required this.maxParticipants});

  static const _positions = ['PG', 'SG', 'SF', 'PF', 'C', 'LW', 'RW', 'MF'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Roster',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            const Spacer(),
            Text('${roster.length} / $maxParticipants Players',
                style: const TextStyle(color: Color(0xFF4D9DFF), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 14),
        if (roster.isEmpty)
          Text('No players yet. Be the first to join!',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13))
        else
          ...roster.asMap().entries.map((e) {
            final profile = e.value['profiles'] as Map<String, dynamic>?;
            final name = profile?['full_name'] as String? ?? 'Player';
            final pos = _positions[e.key % _positions.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  InitialsAvatar(name: name, radius: 18, fontSize: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(pos,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 4),
        Row(
          children: [
            _AddPlayerBtn(),
            const SizedBox(width: 10),
            _AddPlayerBtn(),
          ],
        ),
      ],
    );
  }
}

class _AddPlayerBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), style: BorderStyle.solid),
      ),
      child: const Icon(Icons.person_add_outlined, color: Colors.white38, size: 18),
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  final bool isHost;
  final bool hasJoined;
  final bool isJoining;
  final VoidCallback onJoin;

  const _BottomCta({
    required this.isHost,
    required this.hasJoined,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: isHost
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF0052FF).withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF4D9DFF), size: 18),
                  SizedBox(width: 8),
                  Text("You're the Host",
                      style: TextStyle(
                          color: Color(0xFF4D9DFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5)),
                ],
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasJoined || isJoining ? null : onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasJoined ? const Color(0xFF1A1A1A) : const Color(0xFF0052FF),
                  foregroundColor: hasJoined ? Colors.white54 : Colors.white,
                  disabledBackgroundColor: hasJoined ? const Color(0xFF1A1A1A) : const Color(0xFF0052FF).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                icon: isJoining
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(hasJoined ? Icons.check_circle_outline : Icons.send_outlined, size: 18),
                label: Text(
                  hasJoined ? 'Joined ✓' : 'Send Join Request',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.3),
                ),
              ),
            ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Badge({required this.label, required this.color, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(color: Colors.white.withOpacity(0.07), height: 1);
  }
}
