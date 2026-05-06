import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import 'dart:async';

// Provider for user search
final userSearchResultsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.isEmpty || query.length < 2) return [];

  final supabase = Supabase.instance.client;
  
  // Search profiles where full_name ilike %query%
  final response = await supabase
      .from('profiles')
      .select('id, full_name, avatar_url, trust_score')
      .ilike('full_name', '%$query%')
      .limit(20);

  return List<Map<String, dynamic>>.from(response);
});

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.trim();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(userSearchResultsProvider(_searchQuery));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Kullanıcı Ara...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: searchResults.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
        ),
        error: (e, _) => Center(
          child: Text('Hata: $e', style: const TextStyle(color: Colors.red)),
        ),
        data: (users) {
          if (_searchQuery.isEmpty || _searchQuery.length < 2) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kişileri bulmak için arama yapın',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (users.isEmpty) {
            return Center(
              child: Text(
                'Sonuç bulunamadı',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: AvatarWidget(
                  name: user['full_name'] ?? 'Kullanıcı',
                  avatarUrl: user['avatar_url'],
                  radius: 24,
                  editable: false,
                ),
                title: Text(
                  user['full_name'] ?? 'Kullanıcı',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Güven Skoru: ${user['trust_score'] ?? 100}',
                  style: TextStyle(
                    color: MatchFitTheme.accentGreen.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  context.push('/user-profile', extra: user['id']);
                },
              );
            },
          );
        },
      ),
    );
  }
}
