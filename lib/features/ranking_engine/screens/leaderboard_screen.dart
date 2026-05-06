import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:matchfit/features/ranking_engine/providers/ranking_engine_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _selectedTab = 'Global'; // default to global
  String _selectedCity = 'Tüm Şehirler';
  String _selectedSport = 'Tüm Branşlar';

  final List<String> _tabs = ['Global', 'Şehir Bazlı', 'Branş Bazlı'];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Liderlik Tablosu',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Pill Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _tabs.map((tab) {
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = tab;
                      if (tab == 'Global') {
                        _selectedCity = 'Tüm Şehirler';
                        _selectedSport = 'Tüm Branşlar';
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.transparent : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? MatchFitTheme.accentGreen : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? MatchFitTheme.accentGreen : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // 2. Dropdowns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ref.watch(availableCitiesProvider).when(
                    data: (cities) => _buildDropdown(
                      value: cities.contains(_selectedCity) ? _selectedCity : cities.first,
                      items: cities,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCity = val;
                            if (_selectedTab == 'Global' && val != 'Tüm Şehirler') {
                              _selectedTab = 'Şehir Bazlı';
                            }
                          });
                        }
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ref.watch(availableSportsProvider).when(
                    data: (sports) => _buildDropdown(
                      value: sports.contains(_selectedSport) ? _selectedSport : sports.first,
                      items: sports,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSport = val;
                            if (_selectedTab == 'Global' && val != 'Tüm Branşlar') {
                              _selectedTab = 'Branş Bazlı';
                            }
                          });
                        }
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ],
            ),
          ),
          
          // 3. List
          Expanded(
            child: _LeaderboardList(
              tabType: _selectedTab,
              cityFilter: _selectedCity,
              sportFilter: _selectedSport,
            ),
          ),
          
          // 4. Sticky Bottom Rank Info
          const _StickyBottomRank(),
        ],
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  final String tabType;
  final String cityFilter;
  final String sportFilter;

  const _LeaderboardList({required this.tabType, required this.cityFilter, required this.sportFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dynamic provider with both filters
    final providerAsync = ref.watch(filteredLeaderboardProvider((
      city: cityFilter == 'Tüm Şehirler' ? null : cityFilter,
      sport: sportFilter == 'Tüm Branşlar' ? null : sportFilter,
    )));

    return providerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.white54))),
      data: (data) {
        if (data.isEmpty) {
          return const Center(child: Text('Sıralama verisi bulunamadı.', style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final user = data[index];
            final rank = index + 1;
            
            if (rank <= 3) {
              return _TopRankCard(rank: rank, user: user);
            } else {
              return _NormalRankRow(rank: rank, user: user);
            }
          },
        );
      },
    );
  }
}

class _TopRankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> user;

  const _TopRankCard({required this.rank, required this.user});

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color accentColor;

    if (rank == 1) {
      borderColor = Colors.amber.withOpacity(0.5);
      accentColor = Colors.amber;
    } else if (rank == 2) {
      borderColor = Colors.white54;
      accentColor = Colors.white70;
    } else {
      borderColor = Colors.deepOrange.withOpacity(0.5);
      accentColor = Colors.deepOrange;
    }

    return GestureDetector(
      onTap: () => context.push('/user-profile', extra: user['user_id']),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: rank == 1 ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ] : [],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16), // Space for overlapping rank badge
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: AvatarWidget(
                    name: user['full_name'] ?? 'User',
                    avatarUrl: user['avatar_url'],
                    radius: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? 'Bilinmeyen',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['league'] ?? 'Pro',
                        style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${user['xp_amount'] ?? 0}',
                      style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'XP',
                      style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Overlapping Rank Badge
          Positioned(
            left: 6,
            top: -2,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (rank == 1) const Icon(Icons.workspace_premium, size: 12, color: Colors.black87),
                  Text(
                    '$rank',
                    style: TextStyle(
                      color: rank == 2 ? Colors.black87 : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: rank == 1 ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NormalRankRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> user;

  const _NormalRankRow({required this.rank, required this.user});

  @override
  Widget build(BuildContext context) {
    final trustScore = user['trust_score'] as int? ?? 0;
    
    return GestureDetector(
      onTap: () => context.push('/user-profile', extra: user['user_id']),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            AvatarWidget(
              name: user['full_name'] ?? 'U',
              avatarUrl: user['avatar_url'],
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['full_name'] ?? 'Bilinmeyen',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.security, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text('$trustScore', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.white24, fontSize: 12)),
                      const SizedBox(width: 8),
                      // Mock sport icon
                      const Icon(Icons.directions_run, size: 12, color: Colors.white54),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${user['xp_amount'] ?? 0}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'XP',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyBottomRank extends ConsumerWidget {
  const _StickyBottomRank();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return const SizedBox.shrink();

    final asyncData = ref.watch(globalLeaderboardProvider);

    return asyncData.when(
      data: (data) {
        final myIndex = data.indexWhere((u) => u['user_id'] == myId);
        if (myIndex == -1) return const SizedBox.shrink();

        final myUser = data[myIndex];
        final myRank = myIndex + 1;
        final myXp = myUser['xp_amount'] ?? 0;
        final nextTarget = ((myXp ~/ 5000) + 1) * 5000; // Mock calculation for next tier
        final progress = (myXp % 5000) / 5000;

        return GestureDetector(
          onTap: () => context.push('/user-profile', extra: myUser['user_id']),
          child: Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$myRank',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sıralamanız', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            myUser['full_name'] ?? 'Ben',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$myXp XP',
                          style: const TextStyle(color: MatchFitTheme.accentGreen, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sonraki Kademe: $nextTarget',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(MatchFitTheme.accentGreen),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
