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
import 'package:matchfit/core/l10n/app_localizations.dart';
import 'package:geocoding/geocoding.dart';

// ── Providers ──────────────────────────────────────────────────────

final locationNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final userLoc = await ref.watch(userLocationProvider.future);
  if (userLoc == null) return 'Konum Bulunamadı';

  try {
    final placemarks = await placemarkFromCoordinates(userLoc.latitude, userLoc.longitude);
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      final city = place.administrativeArea ?? '';
      final district = place.subAdministrativeArea ?? place.locality ?? '';
      if (district.isNotEmpty && city.isNotEmpty && district != city) {
        return '$city, $district';
      }
      return city.isNotEmpty ? city : 'Konum Bulunamadı';
    }
  } catch (e) {
    debugPrint('Geocoding error: $e');
  }
  return 'Konum Bulunamadı';
});

final eventsProvider = FutureProvider.autoDispose((ref) async {
  final userLoc = await ref.watch(userLocationProvider.future);
  return ref.read(eventRepositoryProvider).getNearbyEvents(
    lat: userLoc?.latitude,
    lng: userLoc?.longitude,
    radius: 50000, // 50 km çapında
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
  final points = int.tryParse(profileData?['trust_score']?.toString() ?? '') ?? 0;
  return {'runs': runs, 'games': games, 'points': points, 'total': list.length};
});

final recommendedEventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return [];

  try {
    final activityResponse = await Supabase.instance.client
        .from('event_participants')
        .select('events(sport_id, sports(category))')
        .eq('user_id', user.id);
    
    final hostedResponse = await Supabase.instance.client
        .from('events')
        .select('sport_id, sports(category)')
        .eq('host_id', user.id);

    final activity = List<Map<String, dynamic>>.from(activityResponse);
    final hosted = List<Map<String, dynamic>>.from(hostedResponse);

    final preferredSports = {
      ...activity.map((e) => e['events']?['sport_id']),
      ...hosted.map((e) => e['sport_id']),
    }.where((id) => id != null).cast<int>().toList();

    final preferredCategories = {
      ...activity.map((e) => e['events']?['sports']?['category']),
      ...hosted.map((e) => e['sports']?['category']),
    }.where((cat) => cat != null).cast<String>().toList();

    dynamic query = Supabase.instance.client
        .from('events')
        .select('*, sports(name, category), profiles(full_name, avatar_url)')
        .eq('status', 'open')
        .neq('host_id', user.id);

    if (preferredSports.isNotEmpty) {
      query = query.filter('sport_id', 'in', '(${preferredSports.join(',')})');
    } else if (preferredCategories.isNotEmpty) {
      query = query.filter('sports.category', 'in', '(${preferredCategories.map((c) => "\"$c\"").join(',')})');
    }

    final response = await query.limit(10);
    final allEvents = List<Map<String, dynamic>>.from(response);

    final joinedIdsResponse = await Supabase.instance.client
        .from('event_participants')
        .select('event_id')
        .eq('user_id', user.id);
    final joinedIds = List<Map<String, dynamic>>.from(joinedIdsResponse).map((e) => e['event_id'].toString()).toList();

    final filtered = allEvents.where((e) => !joinedIds.contains(e['id'].toString())).toList();
    
    if (filtered.isEmpty && (preferredSports.isNotEmpty || preferredCategories.isNotEmpty)) {
      final fallback = await Supabase.instance.client
          .from('events')
          .select('*, sports(name, category), profiles(full_name, avatar_url)')
          .eq('status', 'open')
          .neq('host_id', user.id)
          .limit(5);
      final fallbackList = List<Map<String, dynamic>>.from(fallback);
      return fallbackList.where((e) => !joinedIds.contains(e['id'].toString())).toList();
    }

    return filtered;
  } catch (e) {
    print('Error: $e');
    return [];
  }
});

// ── Home Screen ─────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildHeader(context, ref),
               const SizedBox(height: 16),
               _buildActionButtons(context),
               const SizedBox(height: 32),
               _buildSectionTitle('Senin İçin Etkinlikler'),
               _buildRecommendedEvents(context),
               const SizedBox(height: 32),
               _buildNearbyEventsSection(context, ref),
               const SizedBox(height: 32),
               _buildSectionTitle('Sana Uygun Kişiler'),
               _buildPeopleForYou(context),
               const SizedBox(height: 32),
               _buildWeeklyGoal(context),
               const SizedBox(height: 32),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Row(
                   children: const [
                     Text('Onaylı Antrenörler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                     SizedBox(width: 6),
                     Icon(Icons.verified, color: Colors.blue, size: 16),
                   ]
                 ),
               ),
               _buildVerifiedCoaches(context),
               const SizedBox(height: 32),
               _buildSponsoredAd(context),
               const SizedBox(height: 32),
               _buildSectionTitle('Bursa\'da Yükselen Branşlar'),
               _buildTrendingSports(context),
               const SizedBox(height: 32),
               _buildSectionTitle('Aktiviteler'),
               _buildActivities(context),
               const SizedBox(height: 100),
            ]
          )
        )
      )
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: profileAsync.when(
              data: (p) => AvatarWidget(
                name: p?['full_name'] ?? 'E',
                avatarUrl: p?['avatar_url'],
                radius: 20,
                editable: false,
              ),
              loading: () => const CircleAvatar(radius: 20, backgroundColor: Color(0xFF1E1E1E)),
              error: (_, __) => const CircleAvatar(radius: 20, backgroundColor: Color(0xFF1E1E1E)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'Merhaba Ersen ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      TextSpan(text: '👋', style: TextStyle(fontSize: 16)),
                    ]
                  )
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withOpacity(0.5), size: 12),
                    const SizedBox(width: 4),
                    Text('Bursa / Nilüfer', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ]
                )
              ]
            )
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.blue),
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ]
      )
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => context.push('/create-event'),
            icon: const Icon(Icons.add, color: Colors.black, size: 18),
            label: const Text('Etkinlik Oluştur', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.near_me_outlined, color: Colors.white, size: 18),
            label: const Text('Yakında Ara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(12),
            ),
            child: const Icon(Icons.people_outline, color: Colors.white, size: 18),
          ),
        ]
      )
    );
  }

  Widget _buildRecommendedEvents(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildEventCard(
            title: 'Akşam Tenis Maçı',
            emoji: '🎾',
            verified: true,
            distance: '1.5 km',
            time: '19:30',
            capacity: '3/4 kişi',
            imageColor: Colors.green.shade900,
          ),
          const SizedBox(width: 16),
          _buildEventCard(
            title: 'Sabah Koşusu',
            emoji: '🏃',
            verified: false,
            distance: '3.0 km',
            time: '07:00',
            capacity: '5/10 kişi',
            imageColor: Colors.blue.shade900,
          ),
        ]
      )
    );
  }

  Widget _buildEventCard({required String title, required String emoji, required bool verified, required String distance, required String time, required String capacity, required Color imageColor}) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: imageColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, const Color(0xFF1E1E1E).withOpacity(0.9)],
                    ),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  )
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: MatchFitTheme.accentGreen, size: 12),
                        const SizedBox(width: 4),
                        Text(capacity, style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    )
                  )
                )
              ]
            )
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                    if (verified) const Icon(Icons.verified, color: Colors.blue, size: 16),
                  ]
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(distance, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, color: Colors.white54, size: 12),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildNearbyEventsSection(BuildContext context, WidgetRef ref) {
    final locationNameAsync = ref.watch(locationNameProvider);
    final eventsAsync = ref.watch(eventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Yakınındaki Etkinlikler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              locationNameAsync.when(
                data: (loc) => Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(loc, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white54)),
                  ]
                ),
                loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      const Text('Yakınında etkinlik bulunamadı.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/create-event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MatchFitTheme.accentGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('İlk Etkinliği Sen Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ]
                  ),
                ),
              );
            }

            // Sort by distance (assuming dist_meters is available) and limit to 5 events
            final sortedEvents = List<Map<String, dynamic>>.from(events);
            sortedEvents.sort((a, b) {
              final dA = (a['dist_meters'] as num?)?.toDouble() ?? 999999.0;
              final dB = (b['dist_meters'] as num?)?.toDouble() ?? 999999.0;
              return dA.compareTo(dB);
            });

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                children: sortedEvents.take(5).map((e) {
                  final title = e['title'] as String? ?? 'Etkinlik';
                  final sport = e['sports']?['name'] as String? ?? 'Spor';
                  final distMeters = (e['dist_meters'] as num?)?.toDouble() ?? 0.0;
                  final distance = distMeters > 0 ? '${(distMeters / 1000).toStringAsFixed(1)} km' : '? km';
                  
                  // handle start_time safely, some might be full ISO strings or just time strings
                  String time = '?';
                  if (e['start_time'] != null) {
                    final st = e['start_time'].toString();
                    if (st.length >= 5) {
                       time = st.contains('T') ? st.split('T')[1].substring(0, 5) : st.substring(0, 5);
                    } else {
                       time = st;
                    }
                  }
                  
                  final participants = int.tryParse(e['participant_count']?.toString() ?? '') ?? 1;
                  final maxP = int.tryParse(e['max_participants']?.toString() ?? '') ?? 10;
                  final trustScore = int.tryParse(e['profiles']?['trust_score']?.toString() ?? '') ?? 0;
                  final verified = trustScore > 80;
                  
                  return _buildLiveEventItem(
                    context, 
                    title: title, 
                    sport: sport, 
                    distance: distance, 
                    time: time, 
                    participantCount: '$participants/$maxP kişi', 
                    verified: verified,
                    eventData: e
                  );
                }).toList(),
              )
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: MatchFitTheme.accentGreen))),
          error: (err, _) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Hata: $err', style: const TextStyle(color: Colors.red)))),
        ),
      ],
    );
  }

  Widget _buildLiveEventItem(BuildContext context, {required String title, required String sport, required String distance, required String time, required String participantCount, required bool verified, required Map<String, dynamic> eventData}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_getSportEmoji(sport), style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Colors.blue, size: 16)),
                  ]
                ),
                const SizedBox(height: 6),
                Text('$distance • $time • $participantCount', style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w400)),
              ]
            )
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => context.push('/event-detail', extra: eventData),
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('İncele', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          )
        ]
      )
    );
  }

  String _getSportEmoji(String sport) {
    final s = sport.toLowerCase();
    if (s.contains('tenis') || s.contains('padel')) return '🎾';
    if (s.contains('basketbol')) return '🏀';
    if (s.contains('futbol') || s.contains('halı saha')) return '⚽';
    if (s.contains('koşu')) return '🏃';
    if (s.contains('yoga')) return '🧘‍♀️';
    if (s.contains('fitness')) return '🏋️‍♀️';
    return '🏅';
  }

  Widget _buildPeopleForYou(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildPersonCard('Mert', '1.5 km • 85 Güven Puanı', ['🎾 Tenis', '🏃 Koşu'], 'https://i.pravatar.cc/150?img=11'),
          const SizedBox(width: 16),
          _buildPersonCard('Elif', '5.8 km • 98 Güven Puanı', ['🧘‍♀️ Yoga', '🏋️‍♀️ Fitness'], 'https://i.pravatar.cc/150?img=5'),
        ]
      )
    );
  }

  Widget _buildPersonCard(String name, String subtitle, List<String> tags, String avatarUrl) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundImage: NetworkImage(avatarUrl)),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: tags.map((t) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(t, style: const TextStyle(color: MatchFitTheme.accentGreen, fontSize: 10)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Takip Et', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white54, size: 18),
                  onPressed: () {},
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(10),
                )
              )
            ]
          )
        ]
      )
    );
  }

  Widget _buildWeeklyGoal(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥 Haftalık Hedefin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Haftada 3 etkinlik tamamla', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Detay Gör ', style: TextStyle(color: Colors.blue.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward, color: Colors.blue.shade400, size: 12),
                  ]
                )
              ]
            )
          ),
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 2/3,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(MatchFitTheme.accentGreen),
                ),
                const Center(
                  child: Text('2/3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildVerifiedCoaches(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildCoachCard('Coach Burak', '🎾 Tenis', '⭐ 4.9', '₺400/saat', 'https://i.pravatar.cc/150?img=33'),
          const SizedBox(width: 16),
          _buildCoachCard('Coach Zeynep', '🏆 Fitness', '⭐ 4.8', '₺350/saat', 'https://i.pravatar.cc/150?img=47'),
        ]
      )
    );
  }

  Widget _buildCoachCard(String name, String sport, String rating, String price, String avatarUrl) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(sport, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]
                )
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Text(rating, style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ]
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Book', style: TextStyle(color: Colors.white, fontSize: 11)),
              )
            ]
          )
        ]
      )
    );
  }

  Widget _buildSponsoredAd(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF152A55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('SPONSORLU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          const Text('DECATHLON', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          const Text('Tüm Spor Ekipmanlarında %15 İndirim!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('MatchFit üyelerine özel fırsatı kaçırma.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Fırsatı Yakala', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ]
      )
    );
  }

  Widget _buildTrendingSports(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildTrendingItem('1', '🎾 Padel', true),
          const Divider(color: Colors.white12, height: 24),
          _buildTrendingItem('2', '🏃 Koşu', true),
          const Divider(color: Colors.white12, height: 24),
          _buildTrendingItem('3', '🏀 Basketbol', false),
        ]
      )
    );
  }

  Widget _buildTrendingItem(String rank, String title, bool isUp) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(rank, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        Icon(isUp ? Icons.trending_up : Icons.arrow_forward, color: isUp ? MatchFitTheme.accentGreen : Colors.white54, size: 18),
      ]
    );
  }

  Widget _buildActivities(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActivityItem('https://i.pravatar.cc/150?img=12', 'Ahmet', ' tenis etkinliği oluşturdu.', '2 saat önce'),
          _buildActivityItem('https://i.pravatar.cc/150?img=5', 'Elif', ' "Sabah Kuşu" rozeti kazandı.', '5 saat önce'),
          _buildActivityItem('https://i.pravatar.cc/150?img=11', 'Mert', ' haftalık challenge tamamladı.', '1 gün önce'),
        ]
      )
    );
  }

  Widget _buildActivityItem(String avatar, String name, String action, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: name, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                      TextSpan(text: action, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ]
                  )
                ),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
    );
  }
}
