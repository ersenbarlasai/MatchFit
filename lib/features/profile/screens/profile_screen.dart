import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../../auth/repositories/auth_repository.dart';
import '../repositories/social_repository.dart';
import 'package:matchfit/core/providers/profile_provider.dart';
import 'package:matchfit/core/l10n/app_localizations.dart';

// ── Providers ──────────────────────────────────────────────────────

final profileDataProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String?>((ref, userId) async {
  final targetId = userId ?? ref.read(authRepositoryProvider).currentUser?.id;
  if (targetId == null) return {};
  
  final sb = Supabase.instance.client;

  final profile = await sb.from('profiles').select('full_name, trust_score, avatar_url').eq('id', targetId).maybeSingle();
  final hosted = await sb.from('events').select('id, status').eq('host_id', targetId);
  final joined = await sb.from('event_participants').select('id').eq('user_id', targetId);
  final posts  = await sb.from('posts').select('id').eq('user_id', targetId);

  final hostedList = List<Map<String, dynamic>>.from(hosted);
  final completed = hostedList.where((e) => e['status'] == 'completed').length;
  final completionPct = hostedList.isEmpty ? 100 : ((completed / hostedList.length) * 100).round();

  return {
    'full_name': profile?['full_name'] ?? 'Player',
    'trust_score': profile?['trust_score'] ?? 100,
    'avatar_url': profile?['avatar_url'] as String? ?? '',
    'user_id': targetId,
    'events_joined': (joined as List).length,
    'events_hosted': hostedList.length,
    'completion_pct': completionPct,
    'posts_count': (posts as List).length,
  };
});

final userPostsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, userId) async {
  final targetId = userId ?? ref.read(authRepositoryProvider).currentUser?.id;
  if (targetId == null) return [];

  final response = await Supabase.instance.client
      .from('posts')
      .select('*, events(title, sports(name))')
      .eq('user_id', targetId)
      .order('created_at', ascending: false);
  
  return List<Map<String, dynamic>>.from(response);
});

final userPastEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, userId) async {
  final targetId = userId ?? ref.read(authRepositoryProvider).currentUser?.id;
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
  return list.where((item) => item['events'] != null).map((item) => item['events'] as Map<String, dynamic>).toList();
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

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
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
          return dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _buildBody(data, relationshipAsync.value),
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
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block_flipped, size: 64, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text('User not found',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('This profile is private or you have been blocked.',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context).logOut, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B4B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).logOut, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await _showLogoutDialog(context);
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<bool?> _showBlockDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalizations.of(context).block, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to block $name?\n\nThey will no longer be able to view your profile or events.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).block, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data, String? relationshipStatus) {
    final name = data['full_name'] as String;
    final trustScore = int.tryParse(data['trust_score']?.toString() ?? '') ?? 100;
    final joined = int.tryParse(data['events_joined']?.toString() ?? '') ?? 0;
    final hosted = int.tryParse(data['events_hosted']?.toString() ?? '') ?? 0;
    final completion = int.tryParse(data['completion_pct']?.toString() ?? '') ?? 0;
    final userId = data['user_id'] as String? ?? '';
    final isMe = widget.userId == null || widget.userId == ref.read(authRepositoryProvider).currentUser?.id;

    // Use local state if user already changed avatar, else use DB value
    final avatarUrl = _avatarUrl ?? (data['avatar_url'] as String? ?? '');
    
    final incomingRequestAsync = userId.isNotEmpty 
        ? ref.watch(incomingFollowRequestProvider(userId))
        : const AsyncValue.data(false);

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text(isMe ? AppLocalizations.of(context).profile : 'Oyuncu Profili',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          actions: [
            if (isMe)
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                color: const Color(0xFF1E1E1E),
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) async {
                  if (value == 'settings') {
                    context.push('/privacy-settings');
                  } else if (value == 'logout') {
                    await _handleLogout();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context).privacySettings, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, color: Color(0xFFFF4B4B), size: 18),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context).logOut, style: const TextStyle(color: Color(0xFFFF4B4B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              )
            else
              Builder(
                builder: (context) {
                  final isBlockingAsync = ref.watch(isBlockingProvider(userId));
                  final isBlocking = isBlockingAsync.value ?? false;
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (value) async {
                      if (value == 'block') {
                        final confirmed = await _showBlockDialog(context, name);
                        if (confirmed == true) {
                          await ref.read(socialRepositoryProvider).blockUser(userId);
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
                        await ref.read(socialRepositoryProvider).unblockUser(userId);
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
                              Icon(Icons.lock_open_outlined, color: Colors.white70, size: 18),
                              const SizedBox(width: 12),
                              const Text('Engeli Kaldır', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        )
                      else
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              const Icon(Icons.block_outlined, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context).block, style: const TextStyle(color: Colors.redAccent)),
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
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ── Avatar (editable only if isMe) ──
              AvatarWidget(
                name: name,
                radius: 46,
                avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                editable: isMe,
                userId: userId,
                onUploaded: (url) {
                  setState(() => _avatarUrl = url);
                  ref.invalidate(currentUserProfileProvider);
                  ref.invalidate(profileDataProvider(userId));
                },
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
                  Text('MatchFit Oyuncusu',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 20),
              
              // ── Incoming Follow Request Banner ──
              if (incomingRequestAsync.value == true)
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MatchFitTheme.accentGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MatchFitTheme.accentGreen.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MatchFitTheme.accentGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_add_outlined, color: MatchFitTheme.accentGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('$name seni takip etmek istiyor',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref.read(socialRepositoryProvider).updateFollowStatus(userId, true);
                                ref.invalidate(incomingFollowRequestProvider(userId));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MatchFitTheme.accentGreen,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(AppLocalizations.of(context).accept, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref.read(socialRepositoryProvider).updateFollowStatus(userId, false);
                                ref.invalidate(incomingFollowRequestProvider(userId));
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(AppLocalizations.of(context).reject, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (isMe) {
                            // Edit profile logic
                          } else {
                            if (relationshipStatus == 'following') {
                              await ref.read(socialRepositoryProvider).unfollowUser(userId);
                            } else if (relationshipStatus == 'pending') {
                              await ref.read(socialRepositoryProvider).unfollowUser(userId);
                            } else {
                              await ref.read(socialRepositoryProvider).sendFollowRequest(userId);
                            }
                            // Refresh relationship status immediately
                            ref.invalidate(relationshipStatusProvider(userId));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMe
                              ? MatchFitTheme.accentGreen
                              : (relationshipStatus == 'following'
                                  ? const Color(0xFF1E1E1E)
                                  : MatchFitTheme.accentGreen),
                          foregroundColor: isMe || relationshipStatus != 'following' ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: (isMe || relationshipStatus != 'following')
                                ? BorderSide.none
                                : BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                            isMe
                                ? AppLocalizations.of(context).editProfile
                                : (relationshipStatus == 'following'
                                    ? 'Takip Ediliyor ✓'
                                    : (relationshipStatus == 'pending' ? AppLocalizations.of(context).followRequested : AppLocalizations.of(context).follow)),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isMe)
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
                          label: const Text('Davet Et',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      )
                    else ...[
                      // Message button (icon only to save space)
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2A3B6E), width: 1.5),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          minimumSize: Size.zero,
                        ),
                        child: const Icon(Icons.mail_outline, size: 20),
                      ),
                      const SizedBox(width: 10),
                      // Block / Unblock button
                      ref.watch(isBlockingProvider(userId)).when(
                        loading: () => const SizedBox(width: 44),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (isBlocking) => OutlinedButton(
                          onPressed: () async {
                            if (isBlocking) {
                              await ref.read(socialRepositoryProvider).unblockUser(userId);
                              ref.invalidate(isBlockingProvider(userId));
                              ref.invalidate(isBlockedByProvider(userId));
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User unblocked')),
                              );
                            } else {
                              final confirmed = await _showBlockDialog(context, name);
                              if (confirmed == true) {
                                await ref.read(socialRepositoryProvider).blockUser(userId);
                                ref.invalidate(isBlockingProvider(userId));
                                ref.invalidate(isBlockedByProvider(userId));
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$name has been blocked'),
                                    backgroundColor: Colors.red.shade800,
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isBlocking ? Colors.orange.shade700 : Colors.red.shade800,
                              width: 1.5,
                            ),
                            foregroundColor: isBlocking ? Colors.orange.shade400 : Colors.red.shade400,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            minimumSize: Size.zero,
                          ),
                          child: Icon(
                            isBlocking ? Icons.lock_open_outlined : Icons.block_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _StatCard(value: '$joined', label: 'KATILDIĞI\nETKİNLİKLER', accentColor: Colors.white),
                    const SizedBox(width: 10),
                    _StatCard(value: '$hosted', label: 'DÜZENLEDİĞİ\nETKİNLİKLER', accentColor: Colors.white),
                    const SizedBox(width: 10),
                    _StatCard(
                        value: '$completion%',
                        label: 'TAMAMLAMA',
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
                tabs: [
                  const Tab(text: 'Paylaşımlar'),
                  Tab(text: AppLocalizations.of(context).pastEvents),
                  const Tab(text: 'Rozetler'),
                  Tab(text: AppLocalizations.of(context).followers),
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
          _PostsGrid(userId: widget.userId),
          _PastEventsTab(userId: widget.userId),
          _BadgesTab(),
          _FriendsTab(userId: widget.userId),
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
                    Text(AppLocalizations.of(context).trustScore,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Topluluk saygınlığı ve güvenilirlik.',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ],
                ),
              ),
              _CircularScore(score: score),
            ],
          ),
          const SizedBox(height: 20),
          _TrustRow(icon: Icons.access_time_outlined, label: 'Dakiklik', delta: '+5', positive: true),
          const SizedBox(height: 12),
          _TrustRow(icon: Icons.thumb_up_outlined, label: 'İyi Sporcu', delta: '+10', positive: true),
          const SizedBox(height: 12),
          _TrustRow(icon: Icons.calendar_month_outlined, label: 'Geç İptal', delta: '-2', positive: false),
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

class _PostsGrid extends ConsumerWidget {
  final String? userId;
  const _PostsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white24))),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_on_outlined, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),
                Text('Henüz paylaşım yok', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
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
            final sport = post['events']?['sports']?['name'] as String? ?? 'Sport';

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                image: mediaUrl != null ? DecorationImage(image: NetworkImage(mediaUrl), fit: BoxFit.cover) : null,
              ),
              child: mediaUrl == null
                  ? Center(child: Icon(_getSportIcon(sport), color: Colors.white10, size: 32))
                  : null,
            );
          },
        );
      },
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'tennis': return Icons.sports_tennis;
      case 'running': return Icons.directions_run;
      case 'basketball': return Icons.sports_basketball;
      case 'football': return Icons.sports_soccer;
      default: return Icons.sports;
    }
  }
}

class _PastEventsTab extends ConsumerWidget {
  final String? userId;
  const _PastEventsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(userPastEventsProvider(userId));

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white24))),
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_outlined, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),
                Text('No past events', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MatchFitTheme.accentGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: MatchFitTheme.accentGreen, size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event['title'] ?? 'Event',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(event['sports']?['name'] ?? 'Sport',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    (event['event_date'] as String).substring(0, 10),
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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

class _FriendsTab extends ConsumerWidget {
  final String? userId;
  const _FriendsTab({this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetId = userId ?? ref.read(authRepositoryProvider).currentUser?.id;
    if (targetId == null) return const SizedBox.shrink();

    final friendsAsync = ref.watch(userFriendsProvider(targetId));

    return friendsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white24))),
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),
                Text('No friends yet', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: AvatarWidget(
                name: profile['full_name'] ?? 'Player',
                radius: 22,
                avatarUrl: profile['avatar_url'],
              ),
              title: Text(profile['full_name'] ?? 'Player',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('Trust Score: ${profile['trust_score'] ?? 100}',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.2)),
              onTap: () => context.push('/user-profile', extra: friendId),
            );
          },
        );
      },
    );
  }
}
