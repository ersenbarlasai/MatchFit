import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Providers for connections
final followersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final sb = Supabase.instance.client;
  
  try {
    final rels = await sb
        .from('user_relationships')
        .select('sender_id')
        .eq('receiver_id', userId)
        .eq('status', 'following');
        
    final senderIds = List<Map<String, dynamic>>.from(rels).map((r) => r['sender_id'] as String).toList();
    if (senderIds.isEmpty) return [];

    final profiles = await sb
        .from('profiles')
        .select('id, full_name, avatar_url, trust_score')
        .inFilter('id', senderIds);
        
    return List<Map<String, dynamic>>.from(profiles);
  } catch (e) {
    debugPrint('Followers error: $e');
    return [];
  }
});

final followingProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final sb = Supabase.instance.client;
  
  try {
    final rels = await sb
        .from('user_relationships')
        .select('receiver_id')
        .eq('sender_id', userId)
        .eq('status', 'following');
        
    final receiverIds = List<Map<String, dynamic>>.from(rels).map((r) => r['receiver_id'] as String).toList();
    if (receiverIds.isEmpty) return [];

    final profiles = await sb
        .from('profiles')
        .select('id, full_name, avatar_url, trust_score')
        .inFilter('id', receiverIds);
        
    return List<Map<String, dynamic>>.from(profiles);
  } catch (e) {
    debugPrint('Following error: $e');
    return [];
  }
});

class ConnectionsScreen extends ConsumerStatefulWidget {
  final String userId;
  final int initialTab;

  const ConnectionsScreen({
    super.key,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildList(AsyncValue<List<Map<String, dynamic>>> asyncData, String emptyMessage) {
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.white54))),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),
                Text(emptyMessage, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final profile = users[index];
            final friendId = profile['id'] as String;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: AvatarWidget(
                name: profile['full_name'] ?? 'Oyuncu',
                radius: 22,
                avatarUrl: profile['avatar_url'],
              ),
              title: Text(profile['full_name'] ?? 'Oyuncu',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('Güven Puanı: ${profile['trust_score'] ?? 100}',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.2)),
              onTap: () => context.push('/user-profile', extra: friendId),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Bağlantılar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: MatchFitTheme.accentGreen,
          unselectedLabelColor: Colors.white38,
          indicatorColor: MatchFitTheme.accentGreen,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Takipçiler'),
            Tab(text: 'Takip Edilenler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(ref.watch(followersProvider(widget.userId)), 'Henüz takipçi yok.'),
          _buildList(ref.watch(followingProvider(widget.userId)), 'Henüz kimseyi takip etmiyor.'),
        ],
      ),
    );
  }
}
