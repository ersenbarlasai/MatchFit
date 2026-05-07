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
import '../../profile/models/trust_system.dart';
import 'package:matchfit/core/services/location_service.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:matchfit/features/xp_engine/providers/xp_engine_provider.dart';
import 'package:matchfit/features/economy_engine/providers/economy_engine_provider.dart';
import 'package:matchfit/features/home/presentation/widgets/matchup_module.dart';

// ── Providers ──────────────────────────────────────────────────────

class HomeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Yakınımda';

  void setFilter(String val) => state = val;
}

final homeFilterProvider = NotifierProvider<HomeFilterNotifier, String>(
  HomeFilterNotifier.new,
);

final randomBannerIndexProvider = Provider.autoDispose<int>((ref) {
  return DateTime.now().millisecondsSinceEpoch;
});

final locationNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final userLoc = await ref.watch(userLocationProvider.future);
  if (userLoc == null) return 'Konum Bulunamadı';

  try {
    final placemarks = await placemarkFromCoordinates(
      userLoc.latitude,
      userLoc.longitude,
    );
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      final city = place.administrativeArea ?? '';
      final district = place.subAdministrativeArea ?? place.locality ?? '';
      if (district.isNotEmpty && city.isNotEmpty && district != city) {
        return '$city, $district';
      }
      return city.isNotEmpty ? city : 'Mevcut Konum';
    }
  } catch (e) {
    debugPrint('Geocoding plugin error: $e');
  }

  // Fallback to Nominatim API (OpenStreetMap) if native geocoder fails
  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=${userLoc.latitude}&lon=${userLoc.longitude}&zoom=10&addressdetails=1',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'MatchFitApp/1.0'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final address = data['address'];
      if (address != null) {
        final city =
            address['province'] ?? address['city'] ?? address['state'] ?? '';
        final district =
            address['town'] ??
            address['county'] ??
            address['district'] ??
            address['suburb'] ??
            '';
        if (city.isNotEmpty && district.isNotEmpty && city != district) {
          return '$city, $district';
        }
        if (city.isNotEmpty) return city;
      }
    }
  } catch (e) {
    debugPrint('Nominatim API error: $e');
  }

  return 'Mevcut Konum';
});

final eventsProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(eventChangeProvider); // Watch for global changes
  final userLoc = await ref.watch(userLocationProvider.future);
  return ref
      .read(eventRepositoryProvider)
      .getNearbyEvents(
        lat: userLoc?.latitude,
        lng: userLoc?.longitude,
        radius: 50000, // 50 km çapında
      );
});

final friendsWithUpcomingEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.watch(eventChangeProvider); // Watch for global changes
      final sb = Supabase.instance.client;
      final myId = sb.auth.currentUser?.id;
      if (myId == null) return [];

      try {
        // Tüm arkadaşlık / takip ilişkilerini çekelim (status accepted veya following olabilir)
        final relsRes = await sb
            .from('user_relationships')
            .select('sender_id, receiver_id, status')
            .or('sender_id.eq.$myId,receiver_id.eq.$myId');

        final friendIds = <String>{};
        for (final rel in List<Map<String, dynamic>>.from(relsRes)) {
          final status = rel['status'] as String?;
          if (status == 'following' || status == 'accepted') {
            final sender = rel['sender_id'] as String;
            final receiver = rel['receiver_id'] as String;
            if (sender != myId) friendIds.add(sender);
            if (receiver != myId) friendIds.add(receiver);
          }
        }

        debugPrint('Found friendIds: $friendIds');
        if (friendIds.isEmpty) return [];

        // Etkinlikleri sadece tarih bazında sorgulayalım (saat farkından dolayı görünmeme ihtimaline karşı)
        final today = DateTime.now().toIso8601String().split('T')[0];

        final eventsRes = await sb
            .from('events')
            .select('host_id, profiles(full_name, avatar_url)')
            .inFilter('host_id', friendIds.toList())
            .gte('event_date', today)
            .order('event_date', ascending: true);

        debugPrint('Found events for friends: ${eventsRes.length}');

        final uniqueFriends = <String, Map<String, dynamic>>{};
        for (final ev in List<Map<String, dynamic>>.from(eventsRes)) {
          final hostId = ev['host_id'] as String;
          final profile = ev['profiles'] as Map<String, dynamic>?;
          if (!uniqueFriends.containsKey(hostId) && profile != null) {
            uniqueFriends[hostId] = {
              'id': hostId,
              'full_name': profile['full_name'],
              'avatar_url': profile['avatar_url'],
            };
          }
        }

        return uniqueFriends.values.toList();
      } catch (e) {
        debugPrint('Friends upcoming events error: $e');
        return [];
      }
    });

// ── Social Pressure Provider ────────────────────────────────────────
final socialPressureProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(eventChangeProvider); // Watch for global changes
  final sb = Supabase.instance.client;
  final myId = sb.auth.currentUser?.id;
  if (myId == null) return [];

  try {
    // 1. Get friends
    final relsRes = await sb
        .from('user_relationships')
        .select('sender_id, receiver_id, status')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId');

    final friendIds = <String>{};
    for (final rel in List<Map<String, dynamic>>.from(relsRes)) {
      final status = rel['status'] as String?;
      if (status == 'following' || status == 'accepted') {
        final sender = rel['sender_id'] as String;
        final receiver = rel['receiver_id'] as String;
        if (sender != myId) friendIds.add(sender);
        if (receiver != myId) friendIds.add(receiver);
      }
    }

    if (friendIds.isEmpty) return [];

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // 2. Get recent event participation of friends (only upcoming)
    final recentParticipants = await sb
        .from('event_participants')
        .select('created_at, user_id, events!inner(*, sports(name, category), profiles(full_name, trust_score, avatar_url)), profiles!event_participants_user_id_fkey(full_name, avatar_url)')
        .inFilter('user_id', friendIds.toList())
        .gte('events.event_date', todayStr)
        .neq('events.status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(10);

    // 3. Get recently created events by friends (only upcoming)
    final recentEvents = await sb
        .from('events')
        .select('*, sports(name, category), profiles!events_host_id_fkey(full_name, trust_score, avatar_url)')
        .inFilter('host_id', friendIds.toList())
        .gte('event_date', todayStr)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(10);

    final activities = <Map<String, dynamic>>[];

    // Parse participants
    for (final p in List<Map<String, dynamic>>.from(recentParticipants)) {
      final profile = p['profiles'] as Map<String, dynamic>?;
      final event = p['events'] as Map<String, dynamic>?;
      final sportName = event?['sports']?['name'] ?? 'Etkinlik';
      if (profile != null && event != null) {
        activities.add({
          'type': 'joined',
          'user_id': p['user_id'],
          'full_name': profile['full_name'],
          'avatar_url': profile['avatar_url'],
          'event_title': event['title'] ?? '$sportName Etkinliği',
          'sport_name': sportName,
          'created_at': DateTime.parse(p['created_at']).toLocal(),
          'event_data': event,
        });
      }
    }

    // Parse creations
    for (final e in List<Map<String, dynamic>>.from(recentEvents)) {
      final profile = e['profiles'] as Map<String, dynamic>?;
      final sportName = e['sports']?['name'] ?? 'Etkinlik';
      if (profile != null) {
        activities.add({
          'type': 'created',
          'user_id': e['host_id'],
          'full_name': profile['full_name'],
          'avatar_url': profile['avatar_url'],
          'event_title': e['title'] ?? '$sportName Etkinliği',
          'sport_name': sportName,
          'created_at': DateTime.parse(e['created_at']).toLocal(),
          'event_data': e,
        });
      }
    }

    // Sort by most recent
    activities.sort((a, b) => (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));
    
    // Return top 5 recent activities to keep it focused
    return activities.take(5).toList();
  } catch (e) {
    debugPrint('Social pressure provider error: $e');
    return [];
  }
});

final weeklyStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
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
    if (sport.toLowerCase().contains('run'))
      runs++;
    else
      games++;
  }
  final profileData = await Supabase.instance.client
      .from('profiles')
      .select('trust_score')
      .eq('id', user.id)
      .maybeSingle();
  final points =
      int.tryParse(profileData?['trust_score']?.toString() ?? '') ?? 0;
  return {'runs': runs, 'games': games, 'points': points, 'total': list.length};
});

final recommendedEventsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) return [];

      try {
        final userSportsResponse = await Supabase.instance.client
            .from('user_sports_preferences')
            .select('sport_id')
            .eq('user_id', user.id);
            
        final preferredSports = List<Map<String, dynamic>>.from(userSportsResponse)
            .map((e) => e['sport_id'])
            .where((id) => id != null)
            .cast<int>()
            .toList();

        final userLoc = await ref.watch(userLocationProvider.future);
        final allNearbyEvents = await ref.read(eventRepositoryProvider).getNearbyEvents(
              lat: userLoc?.latitude,
              lng: userLoc?.longitude,
              radius: 100000, 
            );

        final joinedIdsResponse = await Supabase.instance.client
            .from('event_participants')
            .select('event_id')
            .eq('user_id', user.id);
        final joinedIds = List<Map<String, dynamic>>.from(joinedIdsResponse)
            .map((e) => e['event_id'].toString()).toList();

        var filtered = allNearbyEvents
            .where((e) => e['host_id'] != user.id)
            .where((e) => !joinedIds.contains(e['id'].toString()))
            .toList();

        if (preferredSports.isNotEmpty) {
          filtered = filtered.where((e) => preferredSports.contains(e['sport_id'])).toList();
        }

        return filtered;
      } catch (e) {
        debugPrint('Recommended events error: $e');
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
              _buildHeroEvent(context, ref),
              const SizedBox(height: 24),
              const MatchUpModule(),
              const SizedBox(height: 24),
              _buildCompactSocialFeed(context, ref),
              const SizedBox(height: 24),
              _buildSectionHeader('Fırsatlar ve Ödüller', null),
              _buildOpportunities(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Senin İçin Etkinlikler', 'Tümünü Gör', onActionTap: () => context.go('/explore')),
              _buildRecommendedEventsList(context, ref),
              const SizedBox(height: 24),
              _buildSectionHeader('Yakındaki Etkinlikler', 'Filtrele'),
              _buildNearbyEventsSection(context, ref),
              const SizedBox(height: 24),
              _buildSectionHeader('Spor Eşleşmeleri', 'Tümü'),
              _buildPeopleForYou(context, ref),
              const SizedBox(height: 24),
              _buildSectionHeader('Sana Uygun Eğitmenler', null),
              _buildVerifiedCoaches(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final user = ref.read(authRepositoryProvider).currentUser;
    
    final xpAsync = user != null ? ref.watch(userXPProfileProvider(user.id)) : const AsyncValue.loading();
    final mfAsync = user != null ? ref.watch(userMFBalanceProvider(user.id)) : const AsyncValue.loading();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: profileAsync.when(
              data: (p) => AvatarWidget(
                name: p?['full_name'] ?? 'E',
                avatarUrl: p?['avatar_url'],
                radius: 28,
                editable: false,
              ),
              loading: () => const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF1E1E1E),
              ),
              error: (_, __) => const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF1E1E1E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: profileAsync.when(
              data: (p) {
                final fullName = p?['full_name'] ?? 'Kullanıcı';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Merhaba $fullName ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const TextSpan(
                            text: '👋',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Trust Score
                        const Icon(Icons.security, color: Colors.blue, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${p?['trust_score'] ?? 0}',
                          style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        
                        // XP
                        const Icon(Icons.stars, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        xpAsync.when(
                          data: (xpData) => Text(
                            '${xpData?['xp_amount'] ?? 0} XP',
                            style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                          error: (_, __) => const Text('0 XP', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),

                        // MF Points
                        const Icon(Icons.monetization_on, color: MatchFitTheme.accentGreen, size: 14),
                        const SizedBox(width: 4),
                        mfAsync.when(
                          data: (mfData) => Text(
                            '${mfData?['balance'] ?? 0} MF',
                            style: const TextStyle(color: MatchFitTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: MatchFitTheme.accentGreen)),
                          error: (_, __) => const Text('0 MF', style: TextStyle(color: MatchFitTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final recommendedAsync = ref.watch(recommendedEventsProvider);
                        final randomIndex = ref.watch(randomBannerIndexProvider);
                        
                        return GestureDetector(
                          onTap: () {
                            // Go to explore tab to see more events
                            context.go('/explore');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MatchFitTheme.accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: recommendedAsync.maybeWhen(
                              data: (events) {
                                if (events.isNotEmpty) {
                                  final messages = [
                                    'Bugün sana uygun ${events.length} yeni etkinlik var ✨',
                                    'Şehrindeki ${events.length} fırsatı kaçırma 🎯',
                                    'Sana özel ${events.length} spor etkinliği bulundu 🏃',
                                    'Harekete geç, ${events.length} etkinlik seni bekliyor 🔥',
                                  ];
                                  final msg = messages[randomIndex % messages.length];
                                  
                                  return Text(
                                    msg,
                                    style: const TextStyle(
                                      color: MatchFitTheme.accentGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                
                                final emptyMessages = [
                                  'Haritayı aç ve yeni etkinlikleri keşfet 🗺️',
                                  'Bugün spor yapmak için harika bir gün 🏃‍♂️',
                                  'İlk adımı sen at, bir etkinlik oluştur! 👑',
                                  'Puanlarını artırmak için fırsatlara göz at 🔥',
                                  'Spor arkadaşların seni bekliyor 🤝',
                                  'Hemen bir spor dalı seç ve harekete geç 💪',
                                ];
                                final emptyMsg = emptyMessages[randomIndex % emptyMessages.length];
                                
                                return Text(
                                  emptyMsg,
                                  style: const TextStyle(
                                    color: MatchFitTheme.accentGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                              orElse: () => const Text(
                                'Sana özel öneriler hazırlanıyor... ⏳',
                                style: TextStyle(
                                  color: MatchFitTheme.accentGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              error: (_, __) => const Text(
                'Merhaba!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
            onPressed: () => context.push('/leaderboard'),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => context.push('/user-search'),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? actionText, {IconData? icon, Color? iconColor, VoidCallback? onActionTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: iconColor ?? Colors.white, size: 18),
              ],
            ],
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionText,
                style: const TextStyle(
                  color: MatchFitTheme.accentGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroEvent(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedEventsProvider);

    return recommendedAsync.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final event = events.first;
        final title = event['title'] as String? ?? 'Öne Çıkan Etkinlik';
        final sport = event['sports']?['name'] as String? ?? 'Spor';
        final distMeters = (event['distance'] as num?)?.toDouble() ?? 0.0;
        final distance = distMeters > 0 ? '${(distMeters / 1000).toStringAsFixed(1)} km' : 'Bölgene yakın';
        
        String time = '?';
        if (event['start_time'] != null) {
          final st = event['start_time'].toString();
          time = st.length >= 5 ? (st.contains('T') ? st.split('T')[1].substring(0, 5) : st.substring(0, 5)) : st;
        }
        final participants = int.tryParse(event['participant_count']?.toString() ?? '') ?? 1;
        final maxP = int.tryParse(event['max_participants']?.toString() ?? '') ?? 10;
        final verified = (int.tryParse(event['profiles']?['trust_score']?.toString() ?? '') ?? 0) > 80;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: MatchFitTheme.accentGreen.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: MatchFitTheme.accentGreen.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: MatchFitTheme.accentGreen, size: 14),
                    const SizedBox(width: 4),
                    const Text('Bugün Sana En Uygun', style: TextStyle(color: MatchFitTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (verified)
                      const Icon(Icons.verified, color: Colors.blue, size: 14),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(_getSportEmoji(sport), style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$distance • $time • $participants/$maxP Kişi',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MatchFitTheme.accentGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Katıl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => context.push('/event-detail', extra: event),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Detay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCompactSocialFeed(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(socialPressureProvider);

    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Arkadaşların Ne Yapıyor',
              'Tümünü Gör',
              icon: Icons.local_fire_department,
              iconColor: Colors.orange,
            ),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final act = activities[index];
                  final isCreation = act['type'] == 'created';
                  final sName = act['sport_name']?.toString() ?? '';
                  final String descText = (sName.toLowerCase() == 'etkinlik' || sName.isEmpty)
                      ? (isCreation ? 'Bir etkinlik oluşturdu' : 'Bir etkinliğe katıldı')
                      : (isCreation ? '$sName etkinliği oluşturdu' : '$sName etkinliğine katıldı');
                  
                  return GestureDetector(
                    onTap: () {
                      if (act['event_data'] != null) {
                        context.push('/event-detail', extra: act['event_data']);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          AvatarWidget(
                            name: act['full_name'] ?? 'U',
                            avatarUrl: act['avatar_url'],
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                act['full_name'] ?? 'Bilinmeyen',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                descText,
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRecommendedEventsList(BuildContext context, WidgetRef ref) {
    final recommendedAsync = ref.watch(recommendedEventsProvider);

    return recommendedAsync.when(
      data: (events) {
        if (events.length <= 1) return const SizedBox.shrink(); // Zaten Hero'da gösterildi.
        final listEvents = events.skip(1).take(5).toList(); // Sonraki 5 etkinliği al
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: listEvents.map((e) {
              final title = e['title'] as String? ?? 'Etkinlik';
              final sport = e['sports']?['name'] as String? ?? 'Spor';
              final distMeters = (e['distance'] as num?)?.toDouble() ?? 0.0;
              final distance = distMeters > 0 ? '${(distMeters / 1000).toStringAsFixed(1)} km' : '? km';
              
              String time = '?';
              if (e['start_time'] != null) {
                final st = e['start_time'].toString();
                time = st.length >= 5 ? (st.contains('T') ? st.split('T')[1].substring(0, 5) : st.substring(0, 5)) : st;
              }
              final participants = int.tryParse(e['participant_count']?.toString() ?? '') ?? 1;
              final maxP = int.tryParse(e['max_participants']?.toString() ?? '') ?? 10;
              final fillRate = participants / maxP;

              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_getSportEmoji(sport), style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 12),
                        const SizedBox(width: 4),
                        Text(distance, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const Spacer(),
                        const Icon(Icons.access_time, color: Colors.white54, size: 12),
                        const SizedBox(width: 4),
                        Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fillRate,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(MatchFitTheme.accentGreen),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$participants/$maxP', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/event-detail', extra: e),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 0,
                        ),
                        child: const Text('İncele', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOpportunities(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2A1E), Color(0xFF121A12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: MatchFitTheme.accentGreen, size: 18),
                    const SizedBox(width: 8),
                    const Text('Haftalık Görev', style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('3 Etkinliğe Katıl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Görev bitimine 2 gün kaldı', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('+50 MF Kazan', style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MatchFitTheme.accentGreen.withOpacity(0.2),
                        foregroundColor: MatchFitTheme.accentGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        elevation: 0,
                      ),
                      child: const Text('Katıl', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1F35), Color(0xFF0F1220)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    const Text('Partner Fırsatı', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Decathlon %15 İndirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('300 MF Puan ile aç', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        foregroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        elevation: 0,
                      ),
                      child: const Text('İncele', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard({
    required String title,
    required String emoji,
    required bool verified,
    required String distance,
    required String time,
    required String capacity,
    required Color imageColor,
  }) {
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1E1E1E).withOpacity(0.9),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people,
                          color: MatchFitTheme.accentGreen,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          capacity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (verified)
                      const Icon(Icons.verified, color: Colors.blue, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white54,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      distance,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time,
                      color: Colors.white54,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Join',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MatchFitTheme.accentGreen : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? MatchFitTheme.accentGreen : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyEventsSection(BuildContext context, WidgetRef ref) {
    final locationNameAsync = ref.watch(locationNameProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final selectedFilter = ref.watch(homeFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('Yakınımda', selectedFilter == 'Yakınımda', () => ref.read(homeFilterProvider.notifier).setFilter('Yakınımda')),
              const SizedBox(width: 8),
              _buildFilterChip('Bugün', selectedFilter == 'Bugün', () => ref.read(homeFilterProvider.notifier).setFilter('Bugün')),
              const SizedBox(width: 8),
              _buildFilterChip('Arkadaşlarım', selectedFilter == 'Arkadaşlarım', () => ref.read(homeFilterProvider.notifier).setFilter('Arkadaşlarım')),
              const SizedBox(width: 8),
              _buildFilterChip('Başlangıç', selectedFilter == 'Başlangıç', () => ref.read(homeFilterProvider.notifier).setFilter('Başlangıç')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E2429), Color(0xFF0F141A)],
                  ),
                ),
                child: Column(
                  children: [
                    // Image placeholder (Stadium lights)
                    Container(
                      height: 200,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1577223625816-7546f13df25d?q=80&w=600',
                          ),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black54,
                            BlendMode.darken,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: MatchFitTheme.accentGreen.withOpacity(
                                  0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sports_basketball,
                                color: MatchFitTheme.accentGreen,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Yakınında henüz\nhareket yok.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ama bu harika bir fırsat! Bölgedeki ilk etkinliği sen başlat ve topluluğu harekete geçir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/create-event'),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.black,
                              size: 20,
                            ),
                            label: const Text(
                              'ETKİNLİK OLUŞTUR',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MatchFitTheme.accentGreen,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/explore'),
                            icon: const Icon(
                              Icons.explore_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: const Text(
                              'BAŞKA BÖLGELERİ KEŞFET',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.blue.withOpacity(0.5),
                                width: 2,
                              ),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Filter the events locally
            List<Map<String, dynamic>> filteredEvents = List<Map<String, dynamic>>.from(events);
            final now = DateTime.now();
            final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

            if (selectedFilter == 'Bugün') {
              filteredEvents = filteredEvents.where((e) {
                return e['event_date']?.toString() == todayStr;
              }).toList();
            } else if (selectedFilter == 'Yakınımda') {
              filteredEvents = filteredEvents.where((e) {
                final distMeters = (e['distance'] as num?)?.toDouble() ?? 0.0;
                return distMeters <= 10000; // 10 km
              }).toList();
            } else if (selectedFilter == 'Arkadaşlarım') {
              final friendsAsync = ref.watch(friendsWithUpcomingEventsProvider);
              final friendIds = friendsAsync.value?.map((f) => f['id']).toSet() ?? {};
              filteredEvents = filteredEvents.where((e) {
                return friendIds.contains(e['host_id']);
              }).toList();
            } else if (selectedFilter == 'Başlangıç') {
              filteredEvents = filteredEvents.where((e) {
                final title = (e['title']?.toString() ?? '').toLowerCase();
                final desc = (e['description']?.toString() ?? '').toLowerCase();
                return title.contains('başlangıç') || title.contains('yeni') || desc.contains('başlangıç');
              }).toList();
            }

            if (filteredEvents.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        '"$selectedFilter" için uygun etkinlik bulunamadı.',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Sort by distance
            filteredEvents.sort((a, b) {
              final dA = (a['distance'] as num?)?.toDouble() ?? 999999.0;
              final dB = (b['distance'] as num?)?.toDouble() ?? 999999.0;
              return dA.compareTo(dB);
            });

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: filteredEvents.take(5).map((e) {
                  final title = e['title'] as String? ?? 'Etkinlik';
                  final sport = e['sports']?['name'] as String? ?? 'Spor';
                  final distMeters = (e['distance'] as num?)?.toDouble() ?? 0.0;
                  final distance = distMeters > 0
                      ? '${(distMeters / 1000).toStringAsFixed(1)} km'
                      : '? km';

                  // handle start_time safely, some might be full ISO strings or just time strings
                  String time = '?';
                  if (e['start_time'] != null) {
                    final st = e['start_time'].toString();
                    if (st.length >= 5) {
                      time = st.contains('T')
                          ? st.split('T')[1].substring(0, 5)
                          : st.substring(0, 5);
                    } else {
                      time = st;
                    }
                  }

                  final participants =
                      int.tryParse(e['participant_count']?.toString() ?? '') ??
                      1;
                  final maxP =
                      int.tryParse(e['max_participants']?.toString() ?? '') ??
                      10;
                  final trustScore =
                      int.tryParse(
                        e['profiles']?['trust_score']?.toString() ?? '',
                      ) ??
                      0;
                  final verified = trustScore > 80;

                  return _buildLiveEventItem(
                    context,
                    title: title,
                    sport: sport,
                    distance: distance,
                    time: time,
                    participantCount: '$participants/$maxP kişi',
                    verified: verified,
                    eventData: e,
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                color: MatchFitTheme.accentGreen,
              ),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hata: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveEventItem(
    BuildContext context, {
    required String title,
    required String sport,
    required String distance,
    required String time,
    required String participantCount,
    required bool verified,
    required Map<String, dynamic> eventData,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _getSportEmoji(sport),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (verified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$distance • $time • $participantCount',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => context.push('/event-detail', extra: eventData),
            style: ElevatedButton.styleFrom(
              backgroundColor: MatchFitTheme.accentGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'İncele',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
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

  Widget _buildPeopleForYou(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestedMembersProvider);

    return suggestionsAsync.when(
      data: (users) {
        if (users.isEmpty) {
          // WhatsApp Davet Empty State
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2429), Color(0xFF0F141A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF25D366).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFF25D366),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bölgende Eşleşme Yok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '25km çevrende seninle aynı sporlarla ilgilenen kimseyi bulamadık. Çevreni davet et ve topluluğu sen büyüt!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // WhatsApp davet tetikleyicisi
                  },
                  icon: const Icon(Icons.share, color: Colors.black, size: 20),
                  label: const Text(
                    'WhatsApp ile Davet Et',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Yeşili
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 310, // Taşmayı engellemek için yeterli yükseklik
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: users.map((user) {
                final name = user['full_name'] as String? ?? 'Kullanıcı';
                // i.pravatar.cc yerine CORS dostu DiceBear kullanımı
                final avatar =
                    user['avatar_url']?.contains('pravatar.cc') == true
                    ? 'https://api.dicebear.com/7.x/avataaars/png?seed=${user['id']}'
                    : (user['avatar_url'] as String? ??
                          'https://api.dicebear.com/7.x/avataaars/png?seed=${user['id']}');

                final distanceNum =
                    (user['distance'] as num?)?.toDouble() ?? 0.0;
                final distanceStr = distanceNum > 0
                    ? '${(distanceNum / 1000).toStringAsFixed(1)} km'
                    : '? km';

                List<String> tags = [];
                if (user['shared_sports'] != null &&
                    user['shared_sports'] is List) {
                  tags = (user['shared_sports'] as List)
                      .map(
                        (e) =>
                            '${_getSportEmoji(e.toString())} ${e.toString()}',
                      )
                      .toList();
                }
                if (tags.isEmpty) tags = ['🏅 Sporcu'];

                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 200,
                    child: _buildPersonCard(
                      context,
                      user['id'],
                      name,
                      '$distanceStr',
                      tags.take(2).toList(),
                      avatar,
                      int.tryParse(user['trust_score']?.toString() ?? '') ?? 0,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
        ),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildPersonCard(
    BuildContext context,
    String userId,
    String name,
    String subtitle,
    List<String> tags,
    String avatarUrl,
    int trustScore,
  ) {
    final lvlInfo = getTrustLevelInfo(trustScore);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: lvlInfo.color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AvatarWidget(
                name: name,
                radius: 28,
                avatarUrl: avatarUrl.contains('supabase.co') ? avatarUrl : null,
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: lvlInfo.color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1E1E1E),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    lvlInfo.label.split(' ').first,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: tags
                .map(
                  (t) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: MatchFitTheme.accentGreen,
                        fontSize: 9,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          // Trust score mini bar
          Row(
            children: [
              Icon(Icons.shield_rounded, color: lvlInfo.color, size: 11),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: trustScore / 100,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(lvlInfo.color),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$trustScore',
                style: TextStyle(
                  color: lvlInfo.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/user-profile', extra: userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              child: const Text(
                'Profili İncele',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
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
                const Text(
                  '🔥 Haftalık Hedefin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Haftada 3 etkinlik tamamla',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Detay Gör ',
                      style: TextStyle(
                        color: Colors.blue.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.blue.shade400,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 2 / 3,
                  strokeWidth: 5,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    MatchFitTheme.accentGreen,
                  ),
                ),
                const Center(
                  child: Text(
                    '2/3',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedCoaches(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildCoachCard(
            'Coach Burak',
            '🎾 Tenis',
            '⭐ 4.9',
            '₺400/saat',
            'https://i.pravatar.cc/150?img=33',
          ),
          const SizedBox(width: 16),
          _buildCoachCard(
            'Coach Zeynep',
            '🏆 Fitness',
            '⭐ 4.8',
            '₺350/saat',
            'https://i.pravatar.cc/150?img=47',
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(
    String name,
    String sport,
    String rating,
    String price,
    String avatarUrl,
  ) {
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
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      sport,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Text(
                  rating,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'Book',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
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
            child: const Text(
              'SPONSORLU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'DECATHLON',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tüm Spor Ekipmanlarında %15 İndirim!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'MatchFit üyelerine özel fırsatı kaçırma.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Fırsatı Yakala',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSports(BuildContext context, WidgetRef ref) {
    final locationNameAsync = ref.watch(locationNameProvider);
    final eventsAsync = ref.watch(eventsProvider);

    String city = 'Bulunduğun Bölge';
    if (locationNameAsync.hasValue && locationNameAsync.value != null) {
      final locValue = locationNameAsync.value!;
      if (locValue != 'Mevcut Konum') {
        final parts = locValue.split(',');
        city = parts[0].trim();
      }
    }

    final suffix = _getLocativeSuffix(city);
    final title = city == 'Bulunduğun Bölge'
        ? "Bölgede Yükselen Branşlar"
        : "$city'$suffix Yükselen Branşlar";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: eventsAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      'Henüz yeterli veri yok.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                );
              }

              final Map<String, int> sportCounts = {};
              for (final e in events) {
                final sport = e['sports']?['name'] as String? ?? 'Diğer';
                sportCounts[sport] = (sportCounts[sport] ?? 0) + 1;
              }

              final sortedSports = sportCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final top3 = sortedSports.take(3).toList();

              return Column(
                children: List.generate(top3.length, (index) {
                  final entry = top3[index];
                  final isUp = index < 2; // İlk iki yükselişte varsayımı
                  return Column(
                    children: [
                      _buildTrendingItem(
                        (index + 1).toString(),
                        '${_getSportEmoji(entry.key)} ${entry.key}',
                        isUp,
                      ),
                      if (index < top3.length - 1)
                        const Divider(color: Colors.white12, height: 24),
                    ],
                  );
                }),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: MatchFitTheme.accentGreen,
                ),
              ),
            ),
            error: (_, __) => const SizedBox(),
          ),
        ),
      ],
    );
  }

  String _getLocativeSuffix(String city) {
    if (city.isEmpty) return 'da';
    final lower = city.toLowerCase();
    final lastChar = lower[lower.length - 1];
    final hardConsonants = ['p', 'ç', 't', 'k', 'f', 'h', 's', 'ş'];
    final isHard = hardConsonants.contains(lastChar);

    // Find last vowel
    final vowels = ['a', 'e', 'ı', 'i', 'o', 'ö', 'u', 'ü'];
    String lastVowel = 'a';
    for (int i = lower.length - 1; i >= 0; i--) {
      if (vowels.contains(lower[i])) {
        lastVowel = lower[i];
        break;
      }
    }

    final isFront = ['e', 'i', 'ö', 'ü'].contains(lastVowel);

    if (isHard) {
      return isFront ? 'te' : 'ta';
    } else {
      return isFront ? 'de' : 'da';
    }
  }

  Widget _buildTrendingItem(String rank, String title, bool isUp) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            rank,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Icon(
          isUp ? Icons.trending_up : Icons.arrow_forward,
          color: isUp ? MatchFitTheme.accentGreen : Colors.white54,
          size: 18,
        ),
      ],
    );
  }

  Widget _buildActivities(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActivityItem(
            'https://i.pravatar.cc/150?img=12',
            'Ahmet',
            ' tenis etkinliği oluşturdu.',
            '2 saat önce',
          ),
          _buildActivityItem(
            'https://i.pravatar.cc/150?img=5',
            'Elif',
            ' "Sabah Kuşu" rozeti kazandı.',
            '5 saat önce',
          ),
          _buildActivityItem(
            'https://i.pravatar.cc/150?img=11',
            'Mert',
            ' haftalık challenge tamamladı.',
            '1 gün önce',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String avatar,
    String name,
    String action,
    String time,
  ) {
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
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: action,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}
