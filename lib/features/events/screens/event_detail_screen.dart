import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/event_repository.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../../auth/repositories/auth_repository.dart';

// ── Roster Provider ────────────────────────────────────────────────

final eventRosterProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final response = await Supabase.instance.client
      .from('event_participants')
      .select('user_id, profiles(full_name, trust_score, avatar_url)')
      .eq('event_id', eventId)
      .eq('status', 'joined'); // Only show approved members in roster
  return List<Map<String, dynamic>>.from(response);
});

final joinRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  return await ref.read(eventRepositoryProvider).getJoinRequests(eventId);
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
  String? _participantStatus;

  @override
  void initState() {
    super.initState();
    _checkParticipantStatus();
  }

  Future<void> _checkParticipantStatus() async {
    final eventId = widget.event['id']?.toString() ?? '';
    if (eventId.isEmpty) return;
    final status = await ref.read(eventRepositoryProvider).getParticipantStatus(eventId);
    if (mounted) setState(() => _participantStatus = status);
  }

  Future<void> _joinEvent() async {
    setState(() => _isJoining = true);
    try {
      await ref.read(eventRepositoryProvider).joinEvent(widget.event['id'].toString());
      if (mounted) {
        setState(() => _participantStatus = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent! Waiting for host approval.'),
            backgroundColor: Color(0xFF0052FF),
          ),
        );
      }
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

  String _formatDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      String displayTime = '00:00 AM';
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          displayTime = '${h > 12 ? h - 12 : (h == 0 ? 12 : h)}:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
        }
      }
      return '${months[dt.month]} ${dt.day}, $displayTime';
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
    final date = _formatDate(widget.event['event_date'] as String?, widget.event['start_time'] as String?);
    final hostProfile = widget.event['profiles'] as Map<String, dynamic>?;
    final hostName = hostProfile?['full_name'] as String? ?? 'Host';
    final hostAvatar = hostProfile?['avatar_url'] as String?;
    final hostTrust = hostProfile?['trust_score'] as int? ?? 100;
    final maxP = widget.event['max_participants'] as int? ?? 10;
    final skillLevel = widget.event['required_level'] as String? ?? 'Open';
    final eventId = widget.event['id']?.toString() ?? '';
    final hostId = widget.event['host_id'] as String? ?? '';
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    final isHost = currentUser != null && currentUser.id == hostId;

    final rosterAsync = ref.watch(eventRosterProvider(eventId));
    final requestsAsync = isHost ? ref.watch(joinRequestsProvider(eventId)) : null;

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
                  _HeroSection(sport: sport, sportIcon: _sportIcon(sport), gradientColor: _sportGradient(sport)),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Badge(label: sport, color: const Color(0xFF0052FF)),
                            const SizedBox(width: 8),
                            _Badge(label: skillLevel, color: const Color(0xFF2A2A2A), textColor: Colors.white70),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(title,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
                        const SizedBox(height: 10),

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

                        const SizedBox(height: 20),
                        const Text('Location',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 12),
                        _LocationCard(
                          location: location,
                          lat: widget.event['lat'] as double?,
                          lng: widget.event['lng'] as double?,
                        ),

                        const SizedBox(height: 24),
                        const _Divider(),

                        const SizedBox(height: 20),
                        const Text('Hosted By',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 12),
                        _HostCard(
                            hostName: hostName,
                            avatarUrl: hostAvatar,
                            trustScore: hostTrust),

                        if (isHost) ...[
                          const SizedBox(height: 24),
                          const _Divider(),
                          const SizedBox(height: 20),
                          requestsAsync?.when(
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                                data: (requests) => _JoinRequestsSection(
                                  requests: requests,
                                  onUpdate: () {
                                    ref.invalidate(joinRequestsProvider(eventId));
                                    ref.invalidate(eventRosterProvider(eventId));
                                  },
                                ),
                              ) ??
                              const SizedBox(),
                        ],

                        const SizedBox(height: 24),
                        const _Divider(),

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

          _BottomCta(
            event: widget.event,
            isHost: isHost,
            participantStatus: _participantStatus,
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
          Icon(sportIcon, size: 80, color: Colors.white.withOpacity(0.08)),
          CustomPaint(
            size: const Size(double.infinity, 240),
            painter: _SpotlightPainter(),
          ),
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
  final double? lat;
  final double? lng;
  const _LocationCard({required this.location, this.lat, this.lng});

  Future<void> _openMap() async {
    if (lat == null || lng == null) return;
    
    final googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleUrl = 'https://maps.apple.com/?q=$lat,$lng';
    
    try {
      if (Platform.isIOS) {
        if (await canLaunchUrl(Uri.parse(appleUrl))) {
          await launchUrl(Uri.parse(appleUrl));
          return;
        }
      }
      
      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open the map.';
      }
    } catch (e) {
      final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 140,
              child: (lat != null && lng != null)
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat!, lng!),
                        initialZoom: 14.0,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.matchfit.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat!, lng!),
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: MatchFitTheme.accentGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MatchFitTheme.accentGreen.withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on, color: Colors.black, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0A1628), Color(0xFF0D1F3C)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.map_outlined, color: Colors.white24, size: 32),
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
      ),
    );
  }
}

// ── Host Card ─────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final String hostName;
  final String? avatarUrl;
  final int trustScore;
  const _HostCard({required this.hostName, this.avatarUrl, required this.trustScore});

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
              AvatarWidget(name: hostName, radius: 22, avatarUrl: avatarUrl, editable: false),
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

// ── Join Requests Section ─────────────────────────────────────────

class _JoinRequestsSection extends ConsumerWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onUpdate;

  const _JoinRequestsSection({super.key, required this.requests, required this.onUpdate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Join Requests',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 14),
          Text('No pending requests.',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Join Requests',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${requests.length}',
                  style: const TextStyle(color: Color(0xFF4D9DFF), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...requests.map((request) {
          final profile = request['profiles'] as Map<String, dynamic>?;
          final name = profile?['full_name'] as String? ?? 'Player';
          final avatarUrl = profile?['avatar_url'] as String?;
          final userId = request['user_id'] as String;
          final eventId = request['event_id'] as String;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                AvatarWidget(name: name, radius: 20, avatarUrl: avatarUrl, editable: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${profile?['trust_score'] ?? 100} Trust Score',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    try {
                      await ref.read(eventRepositoryProvider).updateJoinStatus(eventId, userId, 'rejected');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request rejected'), backgroundColor: Colors.orange),
                        );
                        onUpdate();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    try {
                      await ref.read(eventRepositoryProvider).updateJoinStatus(eventId, userId, 'joined');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Player approved!'), backgroundColor: MatchFitTheme.accentGreen),
                        );
                        onUpdate();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check, color: MatchFitTheme.accentGreen, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
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
            final avatarUrl = profile?['avatar_url'] as String?;
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
                  AvatarWidget(name: name, radius: 18, avatarUrl: avatarUrl, editable: false),
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
      ],
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isHost;
  final String? participantStatus;
  final bool isJoining;
  final VoidCallback onJoin;

  const _BottomCta({
    required this.event,
    required this.isHost,
    this.participantStatus,
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
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/edit-event', extra: event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: MatchFitTheme.accentGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(color: MatchFitTheme.accentGreen.withOpacity(0.5)),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Event',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.more_horiz, color: Colors.white54),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (participantStatus != null || isJoining) ? null : onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getBtnColor(),
                  foregroundColor: _getBtnTextColor(),
                  disabledBackgroundColor: _getBtnColor().withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                icon: isJoining
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_getIcon(), size: 18),
                label: Text(
                  _getLabel(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                ),
              ),
            ),
    );
  }

  Color _getBtnColor() {
    if (participantStatus == 'joined') return const Color(0xFF1A1A1A);
    if (participantStatus == 'pending') return const Color(0xFF242424);
    if (participantStatus == 'rejected') return Colors.red.withOpacity(0.1);
    return const Color(0xFF0052FF);
  }

  Color _getBtnTextColor() {
    if (participantStatus == 'joined') return Colors.white54;
    if (participantStatus == 'pending') return Colors.white54;
    if (participantStatus == 'rejected') return Colors.redAccent;
    return Colors.white;
  }

  IconData _getIcon() {
    if (participantStatus == 'joined') return Icons.check_circle_outline;
    if (participantStatus == 'pending') return Icons.hourglass_empty;
    if (participantStatus == 'rejected') return Icons.block_flipped;
    return Icons.send_outlined;
  }

  String _getLabel() {
    if (participantStatus == 'joined') return 'JOINED';
    if (participantStatus == 'pending') return 'REQUEST SENT';
    if (participantStatus == 'rejected') return 'REJECTED';
    return 'JOIN EVENT';
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
