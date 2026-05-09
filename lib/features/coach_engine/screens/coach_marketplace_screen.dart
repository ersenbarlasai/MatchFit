import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../providers/coach_provider.dart';

class CoachMarketplaceScreen extends ConsumerStatefulWidget {
  const CoachMarketplaceScreen({super.key});

  @override
  ConsumerState<CoachMarketplaceScreen> createState() => _CoachMarketplaceScreenState();
}

class _CoachMarketplaceScreenState extends ConsumerState<CoachMarketplaceScreen> {
  final _searchController = TextEditingController();
  String _selectedLevel = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coachesAsync = ref.watch(activeCoachesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Koçlar', style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(activeCoachesProvider),
          ),
        ],
      ),
      body: coachesAsync.when(
        data: (coaches) {
          final filtered = _filterCoaches(coaches);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _buildSearchTools(),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: Text('Uygun koç bulunamadı.', style: TextStyle(color: Colors.white54))),
                )
              else
                ...filtered.map(_buildCoachCard),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  List<Map<String, dynamic>> _filterCoaches(List<Map<String, dynamic>> coaches) {
    final query = _searchController.text.trim().toLowerCase();
    return coaches.where((coach) {
      final profile = coach['profiles'] as Map<String, dynamic>?;
      final name = (profile?['full_name'] ?? '').toString().toLowerCase();
      final branch = (coach['sub_branch'] ?? '').toString().toLowerCase();
      final location = (coach['work_location'] ?? '').toString().toLowerCase();
      final level = (coach['verification_level'] ?? 'none').toString();
      final matchesQuery = query.isEmpty || name.contains(query) || branch.contains(query) || location.contains(query);
      final matchesLevel = _selectedLevel == 'all' || level == _selectedLevel;
      return matchesQuery && matchesLevel;
    }).toList();
  }

  Widget _buildSearchTools() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Koç, branş veya şehir ara',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: MatchFitTheme.accentGreen),
            filled: true,
            fillColor: const Color(0xFF151515),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildLevelChip('all', 'Tümü'),
              _buildLevelChip('basic', 'Basic'),
              _buildLevelChip('certified', 'Certified'),
              _buildLevelChip('elite', 'Elite'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelChip(String value, String label) {
    final selected = _selectedLevel == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedLevel = value),
        selectedColor: MatchFitTheme.accentGreen,
        backgroundColor: const Color(0xFF1A1A1A),
        labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.w700),
        side: BorderSide(color: selected ? MatchFitTheme.accentGreen : Colors.white12),
      ),
    );
  }

  Widget _buildCoachCard(Map<String, dynamic> coach) {
    final profile = coach['profiles'] as Map<String, dynamic>?;
    final userId = coach['user_id'] as String;
    final name = profile?['full_name'] ?? 'İsimsiz Koç';
    final avatarUrl = profile?['avatar_url'] as String?;
    final level = coach['verification_level']?.toString() ?? 'basic';
    final branch = coach['sub_branch'] ?? 'Spor';
    final rating = coach['rating_avg'] ?? 0;
    final sessions = coach['session_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _levelColor(level).withOpacity(0.28)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: _levelColor(level).withOpacity(0.14),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? Text(name.toString()[0], style: TextStyle(color: _levelColor(level))) : null,
        ),
        title: Text(name.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$branch • ${coach['experience_years'] ?? 0} yıl • $sessions seans • $rating puan',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () => context.push('/coach-detail', extra: userId),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'elite':
        return Colors.amber;
      case 'certified':
        return Colors.lightBlueAccent;
      default:
        return MatchFitTheme.accentGreen;
    }
  }
}
