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
import 'friend_upcoming_events_screen.dart' show participationStatusProvider;

// ── Roster Provider ────────────────────────────────────────────────

final eventRosterProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, eventId) async {
      final response = await Supabase.instance.client
          .from('event_participants')
          .select('user_id, profiles(full_name, trust_score, avatar_url)')
          .eq('event_id', eventId)
          .eq('status', 'joined'); // Only show approved members in roster
      return List<Map<String, dynamic>>.from(response);
    });

final joinRequestsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, eventId) {
      return ref.read(eventRepositoryProvider).watchJoinRequests(eventId);
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
  }

  Future<void> _joinEvent() async {
    final eventId = widget.event['id'].toString();
    final participantData =
        await ref.read(eventRepositoryProvider).getParticipantData(eventId) ??
        ref.read(participationStatusProvider(eventId)).value;
    final rejectionCount = participantData?['rejection_count'] as int? ?? 0;

    if (rejectionCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'Önemli Uyarı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Bu etkinliğe 2. başvurunuz. Bir daha reddedilirseniz bu etkinlikten men edileceksiniz. Devam etmek istiyor musunuz?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Anladım, Devam Et',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isJoining = true);
    try {
      await ref.read(eventRepositoryProvider).joinEvent(eventId);
      if (mounted) {
        setState(() {
          _participantStatus = 'pending';
          _isJoining = false;
        });
        // Invalidate stream provider so it re-fetches from DB
        ref.invalidate(participationStatusProvider(eventId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Katılım isteği gönderildi! Onay bekleniyor.'),
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

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Etkinliği Sil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu etkinliği silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Sil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(eventRepositoryProvider)
          .deleteEvent(widget.event['id'].toString());
      if (mounted) {
        // Global sinyali tetikle (State değişince tüm izleyenler yenilenir)
        ref.read(eventChangeProvider.notifier).emit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlik başarıyla silindi')),
        );
        context.pop(); // Go back to the previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
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
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MatchFitTheme.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.celebration_outlined,
                    color: MatchFitTheme.accentGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tebrikler! 🎉",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bu anı arkadaşlarınla paylaşmak ister misin?',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Geç',
                      style: TextStyle(color: Colors.white70),
                    ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      'Anı Paylaş',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _sportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis':
        return Icons.sports_tennis;
      case 'running':
        return Icons.directions_run;
      case 'basketball':
        return Icons.sports_basketball;
      case 'football':
        return Icons.sports_soccer;
      default:
        return Icons.sports;
    }
  }

  Color _sportGradient(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis':
        return const Color(0xFF0A2A1A);
      case 'basketball':
        return const Color(0xFF1A1A0A);
      case 'football':
        return const Color(0xFF0A1A2A);
      default:
        return const Color(0xFF1A1A2A);
    }
  }

  String _formatDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Belli Değil';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '',
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara',
      ];

      String displayTime = '00:00';
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          displayTime =
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        }
      }
      return '${months[dt.month]} ${dt.day}, $displayTime';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title'] as String? ?? 'Etkinlik';
    final sport = widget.event['sports']?['name'] as String? ?? 'Spor';
    final description =
        widget.event['description'] as String? ?? 'Açıklama bulunmuyor.';
    final location =
        widget.event['location_name'] as String? ??
        widget.event['location_text'] as String? ??
        'Konum Belli Değil';
    final date = _formatDate(
      widget.event['event_date'] as String?,
      widget.event['start_time'] as String?,
    );
    final hostProfile = widget.event['profiles'] as Map<String, dynamic>?;
    final hostName = hostProfile?['full_name'] as String? ?? 'Host';
    final hostAvatar = hostProfile?['avatar_url'] as String?;
    final hostTrust =
        int.tryParse(hostProfile?['trust_score']?.toString() ?? '') ?? 0;
    final maxP =
        int.tryParse(widget.event['max_participants']?.toString() ?? '') ?? 10;
    final skillLevel = widget.event['required_level'] as String? ?? 'Open';
    final eventId = widget.event['id']?.toString() ?? '';
    final hostId = widget.event['host_id'] as String? ?? '';
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    final isHost = currentUser != null && currentUser.id == hostId;

    final rosterAsync = ref.watch(eventRosterProvider(eventId));
    final requestsAsync = isHost
        ? ref.watch(joinRequestsProvider(eventId))
        : null;

    // Watch status in real-time
    final statusAsync = ref.watch(participationStatusProvider(eventId));

    // Merge local state with stream state so the UI reflects the action instantly.
    // If the realtime stream has a newer concrete status (rejected/joined), trust it.
    Map<String, dynamic>? participantData = statusAsync.value;
    final streamedStatus = participantData?['status'] as String?;
    if (_participantStatus == 'pending' &&
        (streamedStatus == null || streamedStatus == 'pending')) {
      participantData = Map<String, dynamic>.from(participantData ?? {});
      participantData['status'] = 'pending';
    } else if (streamedStatus != null && streamedStatus != 'pending') {
      _participantStatus = null;
    }

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
        title: const Text(
          'Etkinlik Detayları',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          GestureDetector(
            onTap: _showShareBottomSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
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
                  _HeroSection(
                    sport: sport,
                    sportIcon: _sportIcon(sport),
                    gradientColor: _sportGradient(sport),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Badge(
                              label: sport,
                              color: const Color(0xFF0052FF),
                            ),
                            const SizedBox(width: 8),
                            _Badge(
                              label: skillLevel,
                              color: const Color(0xFF2A2A2A),
                              textColor: Colors.white70,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.attach_money,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const Text(
                              'Ücretsiz',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              ' / oyuncu',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                        const _Divider(),

                        const SizedBox(height: 20),
                        const Text(
                          'Etkinlik Hakkında',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 24),
                        const _Divider(),

                        const SizedBox(height: 20),
                        const Text(
                          'Konum',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _LocationCard(
                          location: location,
                          lat: widget.event['lat'] as double?,
                          lng: widget.event['lng'] as double?,
                        ),

                        const SizedBox(height: 24),
                        const _Divider(),

                        const SizedBox(height: 20),
                        const Text(
                          'Düzenleyen',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _HostCard(
                          hostName: hostName,
                          avatarUrl: hostAvatar,
                          trustScore: hostTrust,
                        ),

                        if (isHost) ...[
                          const SizedBox(height: 24),
                          const _Divider(),
                          const SizedBox(height: 20),
                          requestsAsync?.when(
                                loading: () => const SizedBox(),
                                error: (err, stack) => Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'İstekler yüklenirken hata oluştu: $err',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                data: (requests) => _JoinRequestsSection(
                                  requests: requests,
                                  onUpdate: () {
                                    ref.invalidate(
                                      joinRequestsProvider(eventId),
                                    );
                                    ref.invalidate(
                                      eventRosterProvider(eventId),
                                    );
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
            participantData: participantData,
            isJoining: _isJoining,
            onJoin: _joinEvent,
            onDelete: _deleteEvent,
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
  const _HeroSection({
    required this.sport,
    required this.sportIcon,
    required this.gradientColor,
  });

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

    final googleUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleUrl = 'https://maps.apple.com/?q=$lat,$lng';

    try {
      if (Platform.isIOS) {
        if (await canLaunchUrl(Uri.parse(appleUrl))) {
          await launchUrl(Uri.parse(appleUrl));
          return;
        }
      }

      if (await canLaunchUrl(Uri.parse(googleUrl))) {
        await launchUrl(
          Uri.parse(googleUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not open the map.';
      }
    } catch (e) {
      final webUrl =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
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
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
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
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MatchFitTheme.accentGreen
                                          .withOpacity(0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.black,
                                  size: 20,
                                ),
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
                        child: Icon(
                          Icons.map_outlined,
                          color: Colors.white24,
                          size: 32,
                        ),
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
                        Text(
                          location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
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
                    child: const Icon(
                      Icons.navigation_outlined,
                      color: Colors.white54,
                      size: 18,
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

// ── Host Card ─────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final String hostName;
  final String? avatarUrl;
  final int trustScore;
  const _HostCard({
    required this.hostName,
    this.avatarUrl,
    required this.trustScore,
  });

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
              AvatarWidget(
                name: hostName,
                radius: 22,
                avatarUrl: avatarUrl,
                editable: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hostName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: MatchFitTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MatchFitTheme.accentGreen.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 12,
                      color: MatchFitTheme.accentGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$trustScore Güven Puanı',
                      style: const TextStyle(
                        color: MatchFitTheme.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Yüksek güven puanına sahip onaylı organizatör.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Join Requests Section ─────────────────────────────────────────

class _JoinRequestsSection extends ConsumerWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onUpdate;

  const _JoinRequestsSection({required this.requests, required this.onUpdate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Katılım İstekleri',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bekleyen istek yok.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Katılım İstekleri',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${requests.length}',
                style: const TextStyle(
                  color: Color(0xFF4D9DFF),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...requests.map((request) {
          final profile = request['profiles'] as Map<String, dynamic>?;
          final name = profile?['full_name'] as String? ?? 'Oyuncu';
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
                AvatarWidget(
                  name: name,
                  radius: 20,
                  avatarUrl: avatarUrl,
                  editable: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if ((request['rejection_count'] ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: const Text(
                                '2. BAŞVURU',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if ((request['rejection_count'] ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Aynı kişi bu etkinliğe daha önce katılmak istedi reddetmiştiniz, bir daha red ederseniz bu etkinliğe hiçbir şekilde katılamayacak.',
                            style: TextStyle(
                              color: Colors.orange.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        '${profile?['trust_score'] ?? 0} Güven Puanı',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(eventRepositoryProvider)
                          .updateJoinStatus(eventId, userId, 'rejected');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('İstek reddedildi'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        onUpdate();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(eventRepositoryProvider)
                          .updateJoinStatus(eventId, userId, 'joined');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Oyuncu onaylandı!'),
                            backgroundColor: MatchFitTheme.accentGreen,
                          ),
                        );
                        onUpdate();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.check,
                    color: MatchFitTheme.accentGreen,
                    size: 20,
                  ),
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
            const Text(
              'Kadro',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const Spacer(),
            Text(
              '${roster.length} / $maxParticipants Oyuncu',
              style: const TextStyle(
                color: Color(0xFF4D9DFF),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (roster.isEmpty)
          Text(
            'Henüz kimse katılmadı. İlk katılan sen ol!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 13,
            ),
          )
        else
          ...roster.asMap().entries.map((e) {
            final profile = e.value['profiles'] as Map<String, dynamic>?;
            final name = profile?['full_name'] as String? ?? 'Oyuncu';
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
                  AvatarWidget(
                    name: name,
                    radius: 18,
                    avatarUrl: avatarUrl,
                    editable: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pos,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
  final Map<String, dynamic>? participantData;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onDelete;

  const _BottomCta({
    required this.event,
    required this.isHost,
    this.participantData,
    required this.isJoining,
    required this.onJoin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final participantStatus = participantData?['status'];
    final rejectionCount = participantData?['rejection_count'] as int? ?? 0;
    final lastRejectedAtStr = participantData?['last_rejected_at'];
    final lastRejectedAt = lastRejectedAtStr != null
        ? DateTime.tryParse(lastRejectedAtStr)
        : null;

    final isRejected = participantStatus == 'rejected';
    bool inCooldown = false;
    if (isRejected && lastRejectedAt != null) {
      final elapsed = DateTime.now().difference(lastRejectedAt);
      inCooldown = elapsed.inHours < 2;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
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
                        side: BorderSide(
                          color: MatchFitTheme.accentGreen.withOpacity(0.5),
                        ),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Etkinliği Düzenle',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(cardColor: const Color(0xFF1A1A1A)),
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Etkinliği Sil',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: _buildActionButton(
                context,
                participantStatus,
                isRejected,
                inCooldown,
                lastRejectedAt,
                rejectionCount,
              ),
            ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String? status,
    bool isRejected,
    bool inCooldown,
    DateTime? lastRejectedAt,
    int rejectionCount,
  ) {
    if (isRejected && rejectionCount >= 2) {
      return ElevatedButton(
        onPressed: null,
        style: _btnStyle(Colors.red.withOpacity(0.3), Colors.white54),
        child: const Text(
          'İSTEK ENGELLENDİ',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      );
    }

    if (isRejected && inCooldown && lastRejectedAt != null) {
      return _CooldownButton(
        lastRejectedAt: lastRejectedAt,
        style: _btnStyle(Colors.grey[800]!, Colors.white54),
        onTimerComplete: () {
          // Rebuild to show the "TEKRAR KATIL" button when time is up
          (context as Element).markNeedsBuild();
        },
      );
    }

    final label = _getLabel(status);
    final color = _getBtnColor(status);
    final textColor = _getBtnTextColor(status);
    final icon = _getIcon(status);

    return ElevatedButton.icon(
      onPressed: (status == 'pending' || status == 'joined' || isJoining)
          ? null
          : onJoin,
      style: _btnStyle(color, textColor),
      icon: isJoining
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  ButtonStyle _btnStyle(Color bg, Color fg) {
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: bg.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
    );
  }

  Color _getBtnColor(String? status) {
    if (status == 'joined') return const Color(0xFF1A1A1A);
    if (status == 'pending') return const Color(0xFF242424);
    if (status == 'rejected') return Colors.orangeAccent;
    return MatchFitTheme.accentGreen;
  }

  Color _getBtnTextColor(String? status) {
    if (status == 'joined' || status == 'pending') return Colors.white54;
    return Colors.black;
  }

  IconData _getIcon(String? status) {
    if (status == 'joined') return Icons.check_circle_outline;
    if (status == 'pending') return Icons.hourglass_empty;
    if (status == 'rejected') return Icons.refresh;
    return Icons.send_outlined;
  }

  String _getLabel(String? status) {
    if (status == 'joined') return 'KATILDIN';
    if (status == 'pending') return 'İSTEK GÖNDERİLDİ';
    if (status == 'rejected') return 'TEKRAR KATIL';
    return 'ETKİNLİĞE KATIL';
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Badge({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
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

class _CooldownButton extends StatefulWidget {
  final DateTime lastRejectedAt;
  final ButtonStyle style;
  final VoidCallback onTimerComplete;

  const _CooldownButton({
    required this.lastRejectedAt,
    required this.style,
    required this.onTimerComplete,
  });

  @override
  State<_CooldownButton> createState() => _CooldownButtonState();
}

class _CooldownButtonState extends State<_CooldownButton> {
  late Duration _remaining;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  void _updateRemaining() {
    final elapsed = DateTime.now().difference(widget.lastRejectedAt);
    final remaining = const Duration(hours: 2) - elapsed;
    if (remaining.isNegative) {
      _remaining = Duration.zero;
      _completed = true;
    } else {
      _remaining = remaining;
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() {
        _updateRemaining();
      });

      if (_completed) {
        widget.onTimerComplete();
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return const SizedBox.shrink(); // Handled by parent rebuild
    }

    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return ElevatedButton.icon(
      onPressed: null,
      style: widget.style,
      icon: const Icon(Icons.timer_outlined, size: 18),
      label: Text(
        '$h:$m:$s BEKLEME',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
