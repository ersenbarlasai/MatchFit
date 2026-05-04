import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/repositories/auth_repository.dart';
import '../repositories/social_repository.dart';
import '../models/trust_system.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';
import '../../events/repositories/event_repository.dart';

// ── Providers ──────────────────────────────────────────────────────

final userSportsPreferencesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, userId) async {
      final targetId =
          userId ?? ref.read(authRepositoryProvider).currentUser?.id;
      if (targetId == null) return [];

      final res = await Supabase.instance.client
          .from('user_sports_preferences')
          .select('sport_id, skill_level, sports(name)')
          .eq('user_id', targetId);
      return List<Map<String, dynamic>>.from(res);
    });

final profileDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, userId) async {
      ref.watch(eventChangeProvider); // Watch for global changes
      final targetId =
          userId ?? ref.read(authRepositoryProvider).currentUser?.id;
      if (targetId == null) return {};

      final sb = Supabase.instance.client;

      Map<String, dynamic>? profile;
      try {
        profile = await sb
            .from('profiles')
            .select(
              'full_name, trust_score, avatar_url, cover_url, accepts_partnership, city, district, created_at',
            )
            .eq('id', targetId)
            .maybeSingle();
      } catch (e) {
        // If cover_url doesn't exist yet, fallback to a query without it
        profile = await sb
            .from('profiles')
            .select(
              'full_name, trust_score, avatar_url, accepts_partnership, city, district, created_at',
            )
            .eq('id', targetId)
            .maybeSingle();
      }

      final hosted = await sb
          .from('events')
          .select('id, status')
          .eq('host_id', targetId);
      final joined = await sb
          .from('event_participants')
          .select('id')
          .eq('user_id', targetId)
          .eq('status', 'joined');
      final posts = await sb.from('posts').select('id').eq('user_id', targetId);

      final hostedList = List<Map<String, dynamic>>.from(hosted);
      final completed = hostedList
          .where((e) => e['status'] == 'completed')
          .length;
      final completionPct = hostedList.isEmpty
          ? 100
          : ((completed / hostedList.length) * 100).round();

      // Extract year from created_at
      String joinedYear = '2024';
      if (profile?['created_at'] != null) {
        try {
          joinedYear = DateTime.parse(profile!['created_at']).year.toString();
        } catch (_) {}
      }

      final followersRes = await sb
          .from('user_relationships')
          .select('id')
          .eq('receiver_id', targetId)
          .eq('status', 'following');
      final followingRes = await sb
          .from('user_relationships')
          .select('id')
          .eq('sender_id', targetId)
          .eq('status', 'following');

      return {
        'full_name': profile?['full_name'] ?? 'Player',
        'trust_score': profile?['trust_score'] ?? 0,
        'avatar_url': profile?['avatar_url'] as String? ?? '',
        'cover_url': profile != null && profile.containsKey('cover_url')
            ? profile['cover_url'] as String?
            : null,
        'accepts_partnership': profile?['accepts_partnership'] ?? true,
        'city': profile?['city'] ?? 'Bilinmiyor',
        'district': profile?['district'] ?? '',
        'joined_year': joinedYear,
        'user_id': targetId,
        'events_joined': (joined as List).length,
        'events_hosted': hostedList.length,
        'completion_pct': completionPct,
        'posts_count': (posts as List).length,
        'followers_count': (followersRes as List).length,
        'following_count': (followingRes as List).length,
      };
    });

final userPostsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, userId) async {
      final targetId =
          userId ?? ref.read(authRepositoryProvider).currentUser?.id;
      if (targetId == null) return [];

      final response = await Supabase.instance.client
          .from('posts')
          .select('*, events(title, sports(name))')
          .eq('user_id', targetId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    });

final userPastEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, userId) async {
      final targetId =
          userId ?? ref.read(authRepositoryProvider).currentUser?.id;
      if (targetId == null) return [];

      final response = await Supabase.instance.client
          .from('event_participants')
          .select('events(*, sports(name), profiles(full_name, avatar_url))')
          .eq('user_id', targetId)
          .eq('status', 'joined')
          .lt('events.event_date', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      // Filter out null events (if any inner join issue)
      final list = List<Map<String, dynamic>>.from(response);
      return list
          .where((item) => item['events'] != null)
          .map((item) => item['events'] as Map<String, dynamic>)
          .toList();
    });

// ── Profile Screen ─────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _avatarUrl;

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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}m';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(profileDataProvider(widget.userId));
    final relationshipAsync = widget.userId != null
        ? ref.watch(relationshipStatusProvider(widget.userId!))
        : const AsyncValue.data(null);
    final isBlockedAsync = widget.userId != null
        ? ref.watch(isBlockedByProvider(widget.userId!))
        : const AsyncValue.data(false);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: isBlockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (isBlocked) {
          if (isBlocked) {
            return _buildBlockedUI();
          }
          final partnershipAsync = widget.userId != null
              ? ref.watch(partnershipStatusProvider(widget.userId!))
              : const AsyncValue.data(null);

          final trustAsync = ref.watch(
            trustScoreProvider(
              widget.userId ??
                  ref.read(authRepositoryProvider).currentUser?.id ??
                  '',
            ),
          );
          final earnedKeys =
              trustAsync.whenData((d) => d.earnedBadgeKeys).asData?.value ??
              const <String>[];

          return dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _buildBody(
              data,
              relationshipAsync.value,
              partnershipAsync.value,
              earnedKeys,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlockedUI() {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_flipped,
                  size: 64,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 16),
                const Text(
                  'User not found',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This profile is private or you have been blocked.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showBlockDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context).block,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to block $name?\n\nThey will no longer be able to view your profile or events.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).block,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    Map<String, dynamic> data,
    String? relationshipStatus,
    String? partnershipStatus,
    List<String> earnedKeys,
  ) {
    final name = data['full_name'] as String;
    final trustScore = int.tryParse(data['trust_score']?.toString() ?? '') ?? 0;
    final joined = int.tryParse(data['events_joined']?.toString() ?? '') ?? 0;
    final hosted = int.tryParse(data['events_hosted']?.toString() ?? '') ?? 0;
    final userId = data['user_id'] as String? ?? '';
    final isMe =
        widget.userId == null ||
        widget.userId == ref.read(authRepositoryProvider).currentUser?.id;

    // Use local state if user already changed avatar, else use DB value
    String avatarUrl = _avatarUrl ?? (data['avatar_url'] as String? ?? '');
    if (avatarUrl.contains('pravatar.cc')) {
      avatarUrl = 'https://api.dicebear.com/7.x/avataaars/png?seed=$userId';
    }

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text(
            isMe ? AppLocalizations.of(context).profile : 'Oyuncu Profili',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          actions: [
            if (isMe)
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => context.push('/privacy-settings'),
              )
            else
              Builder(
                builder: (context) {
                  final isBlockingAsync = ref.watch(isBlockingProvider(userId));
                  final isBlocking = isBlockingAsync.value ?? false;
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) async {
                      if (value == 'block') {
                        final confirmed = await _showBlockDialog(context, name);
                        if (confirmed == true) {
                          await ref
                              .read(socialRepositoryProvider)
                              .blockUser(userId);
                          ref.invalidate(isBlockingProvider(userId));
                          ref.invalidate(isBlockedByProvider(userId));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$name has been blocked'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                          }
                        }
                      } else if (value == 'unblock') {
                        await ref
                            .read(socialRepositoryProvider)
                            .unblockUser(userId);
                        ref.invalidate(isBlockingProvider(userId));
                        ref.invalidate(isBlockedByProvider(userId));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User unblocked')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (isBlocking)
                        PopupMenuItem(
                          value: 'unblock',
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_open_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Engeli Kaldır',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        )
                      else
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.block_outlined,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context).block,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // ── Premium Profile Card ────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      // 1. Cover Image & Avatar Stack
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Cover Image
                          (() {
                            final coverUrl = data['cover_url'] as String?;
                            return Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                                gradient: coverUrl == null
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.blue.shade900,
                                          Colors.blue.shade600,
                                        ],
                                      )
                                    : null,
                                image: coverUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(coverUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : const DecorationImage(
                                        image: NetworkImage(
                                          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1000&auto=format&fit=crop',
                                        ),
                                        fit: BoxFit.cover,
                                        opacity: 0.4,
                                      ),
                              ),
                            );
                          })(),
                          // Avatar
                          Positioned(
                            bottom: -40,
                            left: 20,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A1A1A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: AvatarWidget(
                                    name: name,
                                    radius: 50,
                                    avatarUrl: avatarUrl.isNotEmpty
                                        ? avatarUrl
                                        : null,
                                    editable: isMe,
                                    userId: userId,
                                    onUploaded: (url) {
                                      setState(() => _avatarUrl = url);
                                      ref.invalidate(
                                        currentUserProfileProvider,
                                      );
                                      ref.invalidate(
                                        profileDataProvider(userId),
                                      );
                                    },
                                  ),
                                ),
                                // Badge removed per user feedback
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 2. Info Section (Name, Location, Buttons)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(135, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Builder(
                                            builder: (context) {
                                              final info = getTrustLevelInfo(
                                                trustScore,
                                              );
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: info.color.withOpacity(
                                                    0.15,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .emoji_events_outlined,
                                                      size: 12,
                                                      color: info.color,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      info.label,
                                                      style: TextStyle(
                                                        color: info.color,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${data['city']}, ${data['district']} • ${data['joined_year']}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.4),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Mini Badges Row
                                      Wrap(
                                        spacing: 6,
                                        children: kAllBadges.take(6).map((
                                          badge,
                                        ) {
                                          final earned = earnedKeys.contains(
                                            badge.key,
                                          );
                                          return Opacity(
                                            opacity: earned ? 1.0 : 0.25,
                                            child: Icon(
                                              badge.icon,
                                              size: 14,
                                              color: earned
                                                  ? badge.color
                                                  : Colors.white,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),

                                // Follow Button (Only if not me)
                                if (!isMe)
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (relationshipStatus == 'following') {
                                        await ref
                                            .read(socialRepositoryProvider)
                                            .unfollowUser(userId);
                                      } else if (relationshipStatus ==
                                          'pending') {
                                        await ref
                                            .read(socialRepositoryProvider)
                                            .unfollowUser(userId);
                                      } else {
                                        await ref
                                            .read(socialRepositoryProvider)
                                            .sendFollowRequest(userId);
                                      }
                                      ref.invalidate(
                                        relationshipStatusProvider(userId),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          relationshipStatus != 'following'
                                          ? MatchFitTheme.accentGreen
                                          : const Color(0xFF2A2A2A),
                                      foregroundColor:
                                          relationshipStatus != 'following'
                                          ? Colors.black
                                          : Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 0,
                                      ),
                                      minimumSize: const Size(0, 36),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      relationshipStatus == 'following'
                                          ? 'Following'
                                          : 'Follow',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 3. Stats Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StatItem(
                              value: _formatCount(data['followers_count'] ?? 0),
                              label: 'TAKİPÇİ',
                              onTap: () => context.push(
                                '/connections',
                                extra: {'userId': userId, 'initialTab': 0},
                              ),
                            ),
                            _StatItem(
                              value: _formatCount(data['following_count'] ?? 0),
                              label: 'TAKİP',
                              onTap: () => context.push(
                                '/connections',
                                extra: {'userId': userId, 'initialTab': 1},
                              ),
                            ),
                            _StatItem(
                              value: _formatCount(joined),
                              label: 'KATILIM',
                              onTap: () => context.push(
                                '/user-events',
                                extra: {'userId': userId, 'initialTab': 0},
                              ),
                            ),
                            _StatItem(
                              value: _formatCount(hosted),
                              label: 'DÜZENLEME',
                              onTap: () => context.push(
                                '/user-events',
                                extra: {'userId': userId, 'initialTab': 1},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Bar & Divider
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  labelColor: MatchFitTheme.accentGreen,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: MatchFitTheme.accentGreen,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Güven & Rozetler'),
                    Tab(text: 'İlgi Alanları'),
                    Tab(text: 'Arkadaşlar'),
                    Tab(text: 'Paylaşımlarım'),
                  ],
                ),
                const Divider(height: 1, color: Colors.white10),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _TrustBadgesTab(userId: widget.userId),
          _InterestsTab(userId: widget.userId, isMe: isMe),
          _FriendsTab(userId: widget.userId),
          _PostsGrid(userId: widget.userId),
        ],
      ),
    );
  }
}

// ── Trust Score Card 2.0 ──────────────────────────────────────────

class _Trust2Card extends ConsumerWidget {
  final String userId;
  const _Trust2Card({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustScoreProvider(userId));
    return trustAsync.when(
      loading: () => const _Trust2Skeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _Trust2CardContent(data: data),
    );
  }
}

class _Trust2Skeleton extends StatelessWidget {
  const _Trust2Skeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: MatchFitTheme.accentGreen,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _Trust2CardContent extends StatelessWidget {
  final TrustScoreData data;
  const _Trust2CardContent({required this.data});

  Color get _barColor {
    if (data.total >= 90) return const Color(0xFFFFD700);
    if (data.total >= 70) return const Color(0xFF60A5FA);
    if (data.total >= 40) return const Color(0xFFFBBF24);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final lvl = data.levelInfo;
    final nextLvl = kTrustLevels[data.nextLevel]!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lvl.color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                color: MatchFitTheme.accentGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Güven Skoru',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: lvl.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: lvl.color.withOpacity(0.4)),
                ),
                child: Text(
                  '${lvl.emoji} ${lvl.label}',
                  style: TextStyle(
                    color: lvl.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main score + segmented bar
          Row(
            children: [
              Text(
                '${data.total}',
                style: TextStyle(
                  color: lvl.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 38,
                ),
              ),
              Text(
                ' / 100',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SegmentedBar(score: data.total, color: _barColor),
          const SizedBox(height: 6),
          // Level labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: TrustLevel.values.map((lvl) {
              final info = kTrustLevels[lvl]!;
              final isActive = data.level == lvl;
              return Text(
                info.label.split(' ').first.toUpperCase(),
                style: TextStyle(
                  color: isActive ? _barColor : Colors.white24,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
                  fontSize: 9,
                  letterSpacing: 0.3,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // Sub scores
          _SubScoreRow(
            label: 'Güvenilirlik',
            icon: Icons.shield_outlined,
            value: data.reliability,
            color: const Color(0xFF34D399),
          ),
          const SizedBox(height: 8),
          _SubScoreRow(
            label: 'Sosyal',
            icon: Icons.favorite_outline,
            value: data.social,
            color: const Color(0xFFA78BFA),
          ),
          const SizedBox(height: 8),
          _SubScoreRow(
            label: 'Aktiflik',
            icon: Icons.bolt_outlined,
            value: data.activity,
            color: const Color(0xFF60A5FA),
          ),

          // Next level hint
          if (data.level != TrustLevel.legend) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    color: nextLvl.color,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12),
                        children: [
                          TextSpan(
                            text: '${data.pointsToNextLevel} puan ',
                            style: TextStyle(
                              color: nextLvl.color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: '→ ${nextLvl.label}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (data.streakCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFF59E0B),
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${data.streakCount}',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  final int score;
  final Color color;
  const _SegmentedBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final segments = [20, 20, 20, 20, 15, 5]; // widths summing to 100
    int cumulative = 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(segments.length, (i) {
            final segStart = cumulative;
            final segEnd = cumulative + segments[i];
            cumulative = segEnd;
            final filled =
                (score - segStart).clamp(0, segments[i]) / segments[i];
            final isLast = i == segments.length - 1;
            return Expanded(
              flex: segments[i],
              child: Container(
                margin: EdgeInsets.only(right: isLast ? 0 : 3),
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white12,
                ),
                child: FractionallySizedBox(
                  widthFactor: filled.toDouble(),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: color,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SubScoreRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final Color color;
  const _SubScoreRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _StatItem({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Contents ──────────────────────────────────────────────────

class _PostsGrid extends ConsumerWidget {
  final String? userId;
  const _PostsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white24)),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.grid_on_outlined,
                  size: 48,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 12),
                Text(
                  'Henüz paylaşım yok',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final mediaUrl = post['media_url'] as String?;
            final sport =
                post['events']?['sports']?['name'] as String? ?? 'Sport';

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                image: mediaUrl != null
                    ? DecorationImage(
                        image: NetworkImage(mediaUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: mediaUrl == null
                  ? Center(
                      child: Icon(
                        _getSportIcon(sport),
                        color: Colors.white10,
                        size: 32,
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  IconData _getSportIcon(String sport) {
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
}

class _BadgesContent extends StatelessWidget {
  final List<String> earnedKeys;
  const _BadgesContent({required this.earnedKeys});

  BadgeDef? get _featuredBadge {
    // Show first earned badge, or first badge if none earned
    for (final b in kAllBadges) {
      if (earnedKeys.contains(b.key)) return b;
    }
    return kAllBadges.isNotEmpty ? kAllBadges.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final featured = _featuredBadge;
    final featuredEarned =
        featured != null && earnedKeys.contains(featured.key);

    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          const Text(
            'Rozet Koleksiyonu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Maçları tamamlayarak, yüksek güven skoru tutturarak ve streak\'lere hâkim olarak rozet kazan.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // ── Featured Badge Card ──────────────────────
          if (featured != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: featuredEarned
                      ? featured.color.withOpacity(0.5)
                      : Colors.white12,
                ),
                boxShadow: featuredEarned
                    ? [
                        BoxShadow(
                          color: featured.color.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  // Glowing icon circle
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E1E),
                      border: Border.all(
                        color: featuredEarned
                            ? featured.color.withOpacity(0.7)
                            : Colors.white12,
                        width: 2.5,
                      ),
                      boxShadow: featuredEarned
                          ? [
                              BoxShadow(
                                color: featured.color.withOpacity(0.35),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      featured.icon,
                      color: featuredEarned ? featured.color : Colors.white24,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    featuredEarned ? 'ACTIVE' : 'LOCKED',
                    style: TextStyle(
                      color: featuredEarned
                          ? MatchFitTheme.accentGreen
                          : Colors.white30,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    featured.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    featured.requirement,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // ── All Badges grid ──────────────────────────
          const Text(
            'All Badges',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: kAllBadges.length,
            itemBuilder: (context, i) {
              final badge = kAllBadges[i];
              final earned = earnedKeys.contains(badge.key);
              return _BadgeIconCell(badge: badge, earned: earned);
            },
          ),

          const SizedBox(height: 28),

          // ── Badge detail list ─────────────────────────
          ...kAllBadges.map((badge) {
            final earned = earnedKeys.contains(badge.key);
            return _BadgeListRow(badge: badge, earned: earned);
          }),
        ],
      ),
    );
  }
}

class _BadgeIconCell extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  const _BadgeIconCell({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: earned ? badge.color.withOpacity(0.12) : const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned ? badge.color.withOpacity(0.5) : Colors.white10,
          width: earned ? 1.5 : 1,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: badge.color.withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          earned ? badge.icon : Icons.lock_rounded,
          color: earned ? badge.color : Colors.white.withOpacity(0.2),
          size: earned ? 22 : 16,
        ),
      ),
    );
  }
}

class _BadgeListRow extends StatelessWidget {
  final BadgeDef badge;
  final bool earned;
  const _BadgeListRow({required this.badge, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: earned
              ? badge.color.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? badge.color.withOpacity(0.15)
                  : Colors.white.withOpacity(0.04),
            ),
            child: Icon(
              earned ? badge.icon : Icons.lock_rounded,
              color: earned ? badge.color : Colors.white.withOpacity(0.2),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: TextStyle(
                    color: earned ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge.requirement,
                  style: TextStyle(
                    color: earned
                        ? Colors.white.withOpacity(0.45)
                        : Colors.white.withOpacity(0.2),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  final String? userId;
  const _FriendsTab({this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetId = userId ?? ref.read(authRepositoryProvider).currentUser?.id;
    if (targetId == null) return const SizedBox.shrink();

    final friendsAsync = ref.watch(userFriendsProvider(targetId));

    return friendsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white24)),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 12),
                Text(
                  'Henüz arkadaş yok',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final profile = friends[index];
            final friendId = profile['id'] as String;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 4,
              ),
              leading: AvatarWidget(
                name: profile['full_name'] ?? 'Player',
                radius: 22,
                avatarUrl: profile['avatar_url'],
              ),
              title: Text(
                profile['full_name'] ?? 'Player',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                'Güven Puanı: ${profile['trust_score'] ?? 100}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.white.withOpacity(0.2),
              ),
              onTap: () => context.push('/user-profile', extra: friendId),
            );
          },
        );
      },
    );
  }
}

// ── Spor İlgi Alanları Bölümü ──
class _SportsInterestsSection extends ConsumerStatefulWidget {
  final String? userId;
  final bool isMe;

  const _SportsInterestsSection({required this.userId, required this.isMe});

  @override
  ConsumerState<_SportsInterestsSection> createState() =>
      _SportsInterestsSectionState();
}

class _SportsInterestsSectionState
    extends ConsumerState<_SportsInterestsSection> {
  Future<void> _showManageSportsDialog(
    BuildContext context,
    List<Map<String, dynamic>> currentPrefs,
  ) async {
    final sb = Supabase.instance.client;

    // Fetch all sports
    final sportsResponse = await sb.from('sports').select('id, name');
    final List<Map<String, dynamic>> allSports =
        List<Map<String, dynamic>>.from(sportsResponse);
    allSports.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    final selectedSportIds = currentPrefs
        .map((e) => e['sport_id'] as String)
        .toSet();
    String selectedLevel = currentPrefs.isNotEmpty
        ? currentPrefs.first['skill_level'] as String
        : 'beginner';

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, controller) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'İlgi Alanlarını Düzenle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            controller: controller,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.5,
                                ),
                            itemCount: allSports.length,
                            itemBuilder: (context, index) {
                              final sport = allSports[index];
                              final id = sport['id'] as String;
                              final name = sport['name'] as String;
                              final isSelected = selectedSportIds.contains(id);

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    if (isSelected) {
                                      selectedSportIds.remove(id);
                                    } else {
                                      selectedSportIds.add(id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? MatchFitTheme.primaryBlue.withOpacity(
                                            0.1,
                                          )
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? MatchFitTheme.primaryBlue
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? MatchFitTheme.primaryBlue
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (selectedSportIds.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Genel Yetenek Seviyesi',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return MatchFitTheme.primaryBlue;
                                }
                                return Colors.transparent;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return Colors.white70;
                              }),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'beginner',
                                label: Text('Başlangıç'),
                              ),
                              ButtonSegment(
                                value: 'intermediate',
                                label: Text('Orta'),
                              ),
                              ButtonSegment(
                                value: 'advanced',
                                label: Text('İleri'),
                              ),
                            ],
                            selected: {selectedLevel},
                            onSelectionChanged: (Set<String> newSelection) {
                              setModalState(() {
                                selectedLevel = newSelection.first;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            final userId = sb.auth.currentUser?.id;
                            if (userId != null) {
                              // Delete old ones
                              await sb
                                  .from('user_sports_preferences')
                                  .delete()
                                  .eq('user_id', userId);
                              // Insert new ones
                              if (selectedSportIds.isNotEmpty) {
                                final inserts = selectedSportIds
                                    .map(
                                      (id) => {
                                        'user_id': userId,
                                        'sport_id': id,
                                        'skill_level': selectedLevel,
                                      },
                                    )
                                    .toList();
                                await sb
                                    .from('user_sports_preferences')
                                    .insert(inserts);
                              }
                              ref.invalidate(
                                userSportsPreferencesProvider(widget.userId),
                              );
                              if (widget.userId != userId)
                                ref.invalidate(
                                  userSportsPreferencesProvider(userId),
                                );
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MatchFitTheme.accentGreen,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Kaydet',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(userSportsPreferencesProvider(widget.userId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'İlgi Alanlarım',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (widget.isMe)
                  InkWell(
                    onTap: () {
                      final currentPrefs = prefsAsync.asData?.value ?? [];
                      _showManageSportsDialog(context, currentPrefs);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Düzenle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            prefsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: MatchFitTheme.accentGreen,
                ),
              ),
              error: (e, _) =>
                  Text('Hata: $e', style: const TextStyle(color: Colors.red)),
              data: (prefs) {
                if (prefs.isEmpty) {
                  return Text(
                    'Henüz spor branşı seçilmedi.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: prefs.map((pref) {
                    final sportName =
                        pref['sports']?['name'] as String? ?? 'Bilinmiyor';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: MatchFitTheme.primaryBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: MatchFitTheme.primaryBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        sportName,
                        style: const TextStyle(
                          color: MatchFitTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trust & Badges Tab ─────────────────────────────────────────────

class _TrustBadgesTab extends ConsumerWidget {
  final String? userId;
  const _TrustBadgesTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustScoreProvider(userId));
    final earnedKeys =
        trustAsync.whenData((d) => d.earnedBadgeKeys).asData?.value ??
        const <String>[];
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Trust2Card(userId: userId ?? ''),
          const SizedBox(height: 24),
          const Text(
            'Rozetler',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          _BadgesContent(earnedKeys: earnedKeys),
        ],
      ),
    );
  }
}

// ── Interests Tab ──────────────────────────────────────────────────

class _InterestsTab extends ConsumerStatefulWidget {
  final String? userId;
  final bool isMe;
  const _InterestsTab({required this.userId, required this.isMe});

  @override
  ConsumerState<_InterestsTab> createState() => _InterestsTabState();
}

class _InterestsTabState extends ConsumerState<_InterestsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const Map<String, String> _levelLabels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
  };
  static const Map<String, Color> _levelColors = {
    'beginner': Color(0xFF34D399),
    'intermediate': Color(0xFF60A5FA),
    'advanced': Color(0xFFFBBF24),
  };
  static const List<String> _suggested = ['Padel', 'Bisiklet', 'Yoga'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSportByName(String sportName) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await sb
          .from('sports')
          .select('id')
          .ilike('name', sportName)
          .maybeSingle();
      if (res == null) return;
      await sb.from('user_sports_preferences').upsert({
        'user_id': uid,
        'sport_id': res['id'],
        'skill_level': 'beginner',
      });
      ref.invalidate(userSportsPreferencesProvider(widget.userId));
      if (widget.userId != uid)
        ref.invalidate(userSportsPreferencesProvider(uid));
    } catch (_) {}
  }

  Future<void> _editSkillLevel(Map<String, dynamic> pref) async {
    const levels = ['beginner', 'intermediate', 'advanced'];
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pref['sports']?['name'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ...levels.map((lvl) {
                final isSelected = (pref['skill_level'] as String?) == lvl;
                final c = _levelColors[lvl] ?? Colors.white54;
                return InkWell(
                  onTap: () async {
                    final sb = Supabase.instance.client;
                    final uid = sb.auth.currentUser?.id;
                    if (uid != null) {
                      await sb
                          .from('user_sports_preferences')
                          .update({'skill_level': lvl})
                          .eq('user_id', uid)
                          .eq('sport_id', pref['sport_id']);
                      ref.invalidate(
                        userSportsPreferencesProvider(widget.userId),
                      );
                      if (widget.userId != uid)
                        ref.invalidate(userSportsPreferencesProvider(uid));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? c.withOpacity(0.12)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? c.withOpacity(0.5) : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _levelLabels[lvl] ?? lvl,
                          style: TextStyle(
                            color: isSelected ? c : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected) ...[
                          const Spacer(),
                          Icon(Icons.check_circle_rounded, color: c, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchSports(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final sb = Supabase.instance.client;
      final response = await sb
          .from('sports')
          .select('id, name')
          .ilike('name', '%$query%')
          .limit(8);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(userSportsPreferencesProvider(widget.userId));
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Interests',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 14),
          prefsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: MatchFitTheme.accentGreen,
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (prefs) {
              if (prefs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Henüz spor branşı eklenmedi.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4)),
                  ),
                );
              }
              return Column(
                children: prefs.map((pref) {
                  final name =
                      pref['sports']?['name'] as String? ?? 'Bilinmiyor';
                  final level = pref['skill_level'] as String? ?? 'beginner';
                  final lvlColor = _levelColors[level] ?? Colors.white54;
                  final lvlLabel = _levelLabels[level] ?? level;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: MatchFitTheme.primaryBlue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sports,
                            color: MatchFitTheme.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                lvlLabel,
                                style: TextStyle(
                                  color: lvlColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isMe)
                          GestureDetector(
                            onTap: () => _editSkillLevel(pref),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white54,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (widget.isMe) ...[
            const SizedBox(height: 24),
            Text(
              'Suggested for You',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _suggested
                  .map(
                    (s) => GestureDetector(
                      onTap: () => _addSportByName(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.add,
                              color: Colors.white38,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            const Text(
              'Add New Interest',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _searchSports(v);
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search sports...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: MatchFitTheme.accentGreen,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_searchQuery.isNotEmpty && _searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No sports found.',
                    style: TextStyle(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
              )
            else if (_searchResults.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final sport = _searchResults[index];
                  final name = sport['name'] as String;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MatchFitTheme.accentGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_rounded,
                          color: MatchFitTheme.accentGreen,
                          size: 16,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: MatchFitTheme.accentGreen,
                        size: 20,
                      ),
                      onTap: () {
                        _addSportByName(name);
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      },
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}
