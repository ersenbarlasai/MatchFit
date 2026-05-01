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
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:matchfit/core/services/location_service.dart';
import 'package:matchfit/core/constants/sports_data.dart';
import '../../events/repositories/event_repository.dart';

// ── Providers ─────────────────────────────────────────────────────

class ExploreDistanceNotifier extends Notifier<String> {
  @override
  String build() => 'Any';
  void setDistance(String val) => state = val;
}

final exploreDistanceProvider = NotifierProvider<ExploreDistanceNotifier, String>(ExploreDistanceNotifier.new);

class ExploreCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All Categories';
  void setCategory(String val) => state = val;
}
final exploreCategoryProvider = NotifierProvider<ExploreCategoryNotifier, String>(ExploreCategoryNotifier.new);

class ExploreSportNotifier extends Notifier<String> {
  @override
  String build() => 'All Sports';
  void setSport(String val) => state = val;
}
final exploreSportProvider = NotifierProvider<ExploreSportNotifier, String>(ExploreSportNotifier.new);

class ExploreLevelNotifier extends Notifier<String> {
  @override
  String build() => 'Any Level';
  void setLevel(String val) => state = val;
}
final exploreLevelProvider = NotifierProvider<ExploreLevelNotifier, String>(ExploreLevelNotifier.new);

class ExploreDateNotifier extends Notifier<String> {
  @override
  String build() => 'Any Date';
  void setDate(String val) => state = val;
}
final exploreDateProvider = NotifierProvider<ExploreDateNotifier, String>(ExploreDateNotifier.new);

class ExploreSettingNotifier extends Notifier<String> {
  @override
  String build() => 'All Settings'; // Indoor / Outdoor / All
  void setSetting(String val) => state = val;
}
final exploreSettingProvider = NotifierProvider<ExploreSettingNotifier, String>(ExploreSettingNotifier.new);

final exploreMatchesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userLoc = ref.watch(userLocationProvider).value;
  final distanceStr = ref.watch(exploreDistanceProvider);
  final selectedCategory = ref.watch(exploreCategoryProvider);
  final selectedSport = ref.watch(exploreSportProvider);
  final selectedLevel = ref.watch(exploreLevelProvider);
  final selectedDate = ref.watch(exploreDateProvider);
  final selectedSetting = ref.watch(exploreSettingProvider);
  
  double? radius = 50000;
  if (distanceStr == '< 5km') radius = 5000;
  if (distanceStr == '< 10km') radius = 10000;
  if (distanceStr == '< 20km') radius = 20000;
  if (distanceStr == 'Any') radius = null;

  final allEvents = await ref.read(eventRepositoryProvider).getNearbyEvents(
    lat: userLoc?.latitude,
    lng: userLoc?.longitude,
    radius: radius,
  );

  return allEvents.where((e) {
    // Category & Sport filter
    if (selectedCategory != 'All Categories') {
      final cat = e['sports']?['category'] as String? ?? '';
      if (cat != selectedCategory) return false;
    }
    if (selectedSport != 'All Sports') {
      final sName = e['sports']?['name'] as String? ?? '';
      if (sName != selectedSport) return false;
    }

    // Level filter
    if (selectedLevel != 'Any Level') {
      final level = e['required_level'] as String? ?? 'Any';
      if (level != selectedLevel) return false;
    }

    // Date filter
    if (selectedDate != 'Any Date') {
      final eDateStr = e['event_date'] as String?;
      if (eDateStr != null) {
        final eDate = DateTime.parse(eDateStr);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (selectedDate == 'Today') {
          if (eDate != today) return false;
        } else if (selectedDate == 'Tomorrow') {
          final tomorrow = today.add(const Duration(days: 1));
          if (eDate != tomorrow) return false;
        }
      }
    }

    // Setting filter (Indoor/Outdoor)
    if (selectedSetting != 'All Settings') {
      final isIndoor = e['is_indoor'] as bool? ?? false;
      if (selectedSetting == 'Indoor' && !isIndoor) return false;
      if (selectedSetting == 'Outdoor' && isIndoor) return false;
    }

    return true;
  }).toList();
});

// ── Explore Screen ─────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _showAdvanced = false;
  bool _mapExpanded = false;

  final _distances = ['< 5km', '< 10km', '< 20km', 'Any'];
  final _dates = ['Any Date', 'Today', 'Tomorrow'];
  final _levels = ['Any Level', 'Beginner', 'Intermediate', 'Advanced'];
  final _settings = ['All Settings', 'Indoor', 'Outdoor'];

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
          // ── Header (hidden when map expanded) ──
          if (!_mapExpanded)
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

          // ── Filter Chips (hidden when map expanded) ──
          if (!_mapExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 0, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Sport/Category filter
                    GestureDetector(
                      onTap: () => _showSportPicker(context),
                      child: _FilterChip(
                        label: ref.watch(exploreSportProvider) == 'All Sports' 
                          ? ref.watch(exploreCategoryProvider)
                          : ref.watch(exploreSportProvider),
                        icon: Icons.sports_tennis_outlined,
                        isActive: ref.watch(exploreCategoryProvider) != 'All Categories',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Distance
                    GestureDetector(
                      onTap: () => _showDistancePicker(context),
                      child: _FilterChip(
                        label: ref.watch(exploreDistanceProvider),
                        icon: Icons.location_on_outlined,
                        isActive: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date
                    GestureDetector(
                      onTap: () => _showDatePicker(context),
                      child: _FilterChip(
                        label: ref.watch(exploreDateProvider),
                        icon: Icons.calendar_today_outlined,
                        isActive: ref.watch(exploreDateProvider) != 'Any Date',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Setting (Indoor/Outdoor)
                    GestureDetector(
                      onTap: () => _showSettingPicker(context),
                      child: _FilterChip(
                        label: ref.watch(exploreSettingProvider),
                        icon: Icons.door_front_door_outlined,
                        isActive: ref.watch(exploreSettingProvider) != 'All Settings',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Level
                    GestureDetector(
                      onTap: () => _showLevelPicker(context),
                      child: _FilterChip(
                        label: ref.watch(exploreLevelProvider),
                        icon: Icons.trending_up,
                        isActive: ref.watch(exploreLevelProvider) != 'Any Level',
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),

          // ── Map ──
          if (!_mapExpanded) const SizedBox(height: 12),
          _MapSection(expanded: _mapExpanded, onToggle: () => setState(() => _mapExpanded = !_mapExpanded)),

          // ── Handle (hidden when expanded) ──
          if (!_mapExpanded) ...
          [
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: () => setState(() => _mapExpanded = !_mapExpanded),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Nearby Matches (hidden when map expanded) ──
          if (!_mapExpanded) ...
          [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Nearby Matches',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
            ),
            const SizedBox(height: 14),
          ],

          // ── Event List (hidden when map expanded) ──
          if (!_mapExpanded)
            Expanded(
              child: matchesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
                error: (e, _) => Center(
                    child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
                data: (events) {
                  final selectedSport = ref.watch(exploreSportProvider);
                  final filtered = events.where((e) {
                    if (selectedSport == 'All') return true;
                    final sport = e['sports']?['name'] as String? ?? '';
                    return sport.toLowerCase() == selectedSport.toLowerCase();
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final selectedCategory = ref.watch(exploreCategoryProvider);
          final selectedSport = ref.watch(exploreSportProvider);
          
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    if (selectedCategory != 'All Categories')
                      TextButton(
                        onPressed: () {
                          ref.read(exploreCategoryProvider.notifier).setCategory('All Categories');
                          ref.read(exploreSportProvider.notifier).setSport('All Sports');
                          Navigator.pop(context);
                        },
                        child: const Text('Reset', style: TextStyle(color: MatchFitTheme.accentGreen)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: sportsData.map((cat) {
                      final active = cat.name == selectedCategory;
                      return GestureDetector(
                        onTap: () {
                          ref.read(exploreCategoryProvider.notifier).setCategory(cat.name);
                          ref.read(exploreSportProvider.notifier).setSport('All Sports');
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? MatchFitTheme.accentGreen.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? MatchFitTheme.accentGreen : Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(cat.name, style: TextStyle(color: active ? MatchFitTheme.accentGreen : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (selectedCategory != 'All Categories') ...[
                  const SizedBox(height: 24),
                  const Text('Select Sub-branch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sportsData.firstWhere((c) => c.name == selectedCategory).subcategories.map((s) {
                      final active = s == selectedSport;
                      return GestureDetector(
                        onTap: () {
                          ref.read(exploreSportProvider.notifier).setSport(s);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? MatchFitTheme.accentGreen : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(s, style: TextStyle(color: active ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    _showSimplePicker(context, 'Select Date', _dates, exploreDateProvider, (ref, val) => ref.read(exploreDateProvider.notifier).setDate(val));
  }

  void _showLevelPicker(BuildContext context) {
    _showSimplePicker(context, 'Skill Level', _levels, exploreLevelProvider, (ref, val) => ref.read(exploreLevelProvider.notifier).setLevel(val));
  }

  void _showSettingPicker(BuildContext context) {
    _showSimplePicker(context, 'Environment', _settings, exploreSettingProvider, (ref, val) => ref.read(exploreSettingProvider.notifier).setSetting(val));
  }

  void _showSimplePicker(BuildContext context, String title, List<String> options, dynamic provider, Function(WidgetRef, String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(provider);
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: options.map((o) {
                    final active = o == current;
                    return GestureDetector(
                      onTap: () {
                        onSelect(ref, o);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? MatchFitTheme.accentGreen : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(o, style: TextStyle(color: active ? Colors.black : Colors.white70, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDistancePicker(BuildContext context) {
    _showSimplePicker(context, 'Max Distance', _distances, exploreDistanceProvider, (ref, val) => ref.read(exploreDistanceProvider.notifier).setDistance(val));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;

  const _FilterChip({required this.label, required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? MatchFitTheme.accentGreen.withOpacity(0.12) : const Color(0xFF242424),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? MatchFitTheme.accentGreen.withOpacity(0.4) : Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? MatchFitTheme.accentGreen : Colors.white60, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: isActive ? MatchFitTheme.accentGreen : Colors.white60, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: isActive ? MatchFitTheme.accentGreen : Colors.white30, size: 14),
        ],
      ),
    );
  }
}

// ── Map Section ───────────────────────────────────────────────────

class _MapSection extends ConsumerStatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const _MapSection({required this.expanded, required this.onToggle});

  @override
  ConsumerState<_MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends ConsumerState<_MapSection> {
  @override
  Widget build(BuildContext context) {
    final userLoc = ref.watch(userLocationProvider).value;
    final eventsAsync = ref.watch(exploreMatchesProvider);
    final distanceStr = ref.watch(exploreDistanceProvider);
    final expanded = widget.expanded;
    
    double radiusInMeters = 5000;
    if (distanceStr == '< 10km') radiusInMeters = 10000;
    if (distanceStr == '< 20km') radiusInMeters = 20000;
    if (distanceStr == 'Any') radiusInMeters = 0; // Don't show circle

    final center = userLoc != null 
        ? LatLng(userLoc.latitude, userLoc.longitude)
        : const LatLng(41.0082, 28.9784); // Istanbul fallback

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: expanded ? MediaQuery.of(context).size.height : 220,
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: radiusInMeters > 0 ? (radiusInMeters > 10000 ? 10.5 : 12.0) : 12.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.matchfit.app',
              ),
              if (userLoc != null && radiusInMeters > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radiusInMeters.toDouble(), // This represents the search radius
                      useRadiusInMeter: true,
                      color: MatchFitTheme.accentGreen.withOpacity(0.12),
                      borderColor: MatchFitTheme.accentGreen,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // User Marker
                  if (userLoc != null)
                    Marker(
                      point: center,
                      width: 40, height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0052FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: const Color(0xFF0052FF).withOpacity(0.5), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),
                  // Event Markers
                  ...eventsAsync.maybeWhen(
                    data: (events) => events.where((e) => e['lat'] != null && e['lng'] != null).map((e) {
                      final sportName = e['sports']?['name'] as String? ?? '';
                      final icon = _getSportIcon(sportName);

                      return Marker(
                        point: LatLng(e['lat'] as double, e['lng'] as double),
                        width: 40, height: 40,
                        child: GestureDetector(
                          onTap: () => context.push('/event-detail', extra: e),
                          child: Container(
                            decoration: BoxDecoration(
                              color: MatchFitTheme.accentGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: [BoxShadow(color: MatchFitTheme.accentGreen.withOpacity(0.5), blurRadius: 10)],
                            ),
                            child: Icon(icon, color: Colors.black, size: 20),
                          ),
                        ),
                      );
                    }).toList(),
                    orElse: () => [],
                  ),
                ],
              ),
            ],
          ),
          // Bottom fade (only when not expanded)
          if (!expanded)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xFF121212).withOpacity(0.9)],
                  ),
                ),
              ),
            ),
          // Expand / Collapse button
          Positioned(
            top: expanded ? 48 : 10,
            right: 12,
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8)],
                ),
                child: Icon(
                  expanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: const Color(0xFF1A1A2E),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sportName) {
    final s = sportName.toLowerCase();
    if (s.contains('tenis') || s.contains('padel')) return Icons.sports_tennis;
    if (s.contains('masa tenisi')) return Icons.table_restaurant;
    if (s.contains('basketbol')) return Icons.sports_basketball;
    if (s.contains('futbol') || s.contains('halı saha')) return Icons.sports_soccer;
    if (s.contains('voleybol')) return Icons.sports_volleyball;
    if (s.contains('yol koşusu') || s.contains('run')) return Icons.directions_run;
    if (s.contains('bisiklet')) return Icons.directions_bike;
    if (s.contains('fitness') || s.contains('antrenman') || s.contains('gym')) return Icons.fitness_center;
    if (s.contains('yürüyüş') || s.contains('hiking') || s.contains('trekking')) return Icons.terrain;
    if (s.contains('yüzme')) return Icons.pool;
    if (s.contains('sörf') || s.contains('sup') || s.contains('paddle')) return Icons.waves;
    if (s.contains('boks') || s.contains('mma') || s.contains('dövüş')) return Icons.sports_mma;
    if (s.contains('yoga') || s.contains('pilates')) return Icons.self_improvement;
    if (s.contains('kayak') || s.contains('snowboard')) return Icons.ac_unit;
    if (s.contains('tırmanış')) return Icons.landscape;
    if (s.contains('moto') || s.contains('atv')) return Icons.motorcycle;
    if (s.contains('calisthenics') || s.contains('street')) return Icons.reorder;
    return Icons.sports;
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

  String _formatDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = dt.difference(DateTime(now.year, now.month, now.day));
      
      String displayTime = '00:00 AM';
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          displayTime = '${h > 12 ? h - 12 : (h == 0 ? 12 : h)}:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
        }
      }

      if (diff.inDays == 0) return 'Tonight, $displayTime';
      if (diff.inDays == 1) return 'Tomorrow, $displayTime';
      return '${_months[dt.month - 1]} ${dt.day}, $displayTime';
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
    final date = _formatDate(event['event_date'] as String?, event['start_time'] as String?);
    final maxP = event['max_participants'] as int? ?? 10;
    final skillLevel = event['required_level'] as String? ?? 'Any';

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
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0052FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${sport.toUpperCase()} • ${skillLevel.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF4D9DFF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
