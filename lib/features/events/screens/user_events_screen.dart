import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final joinedEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final sb = Supabase.instance.client;
  
  try {
    final participations = await sb
        .from('event_participants')
        .select('event_id')
        .eq('user_id', userId)
        .eq('status', 'joined');
        
    final eventIds = List<Map<String, dynamic>>.from(participations).map((p) => p['event_id'] as String).toList();
    if (eventIds.isEmpty) return [];

    final eventsRes = await sb
        .from('events')
        .select('*, sports(name), profiles(full_name, avatar_url)')
        .inFilter('id', eventIds)
        .order('event_date', ascending: false);
        
    return List<Map<String, dynamic>>.from(eventsRes);
  } catch (e) {
    debugPrint('Joined events error: $e');
    return [];
  }
});

final hostedEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final sb = Supabase.instance.client;
  final response = await sb
      .from('events')
      .select('*, sports(name), profiles(full_name, avatar_url)')
      .eq('host_id', userId)
      .order('event_date', ascending: false);
      
  return List<Map<String, dynamic>>.from(response);
});

class UserEventsScreen extends ConsumerStatefulWidget {
  final String userId;
  final int initialTab;

  const UserEventsScreen({
    super.key,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<UserEventsScreen> createState() => _UserEventsScreenState();
}

class _UserEventsScreenState extends ConsumerState<UserEventsScreen> with SingleTickerProviderStateMixin {
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

  String _formatDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Belli Değil';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = dt.difference(today).inDays;
      
      String displayTime = '00:00';
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          displayTime = '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
      }

      if (diff == 0) return 'Bugün, $displayTime';
      if (diff == 1) return 'Yarın, $displayTime';
      
      const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
      return '${dt.day} ${months[dt.month]}, $displayTime';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildList(AsyncValue<List<Map<String, dynamic>>> asyncData, String emptyMessage) {
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.white54))),
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 48, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 12),
                Text(emptyMessage, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final sport = event['sports']?['name'] ?? 'Spor';
            final title = event['title'] ?? 'Etkinlik';
            final location = event['location_name'] ?? 'Konum belirtilmedi';
            final isExpired = DateTime.tryParse(event['event_date'] ?? '')?.isBefore(DateTime.now().subtract(const Duration(days: 1))) ?? false;

            return GestureDetector(
              onTap: () => context.push('/event-detail', extra: event),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isExpired 
                                ? Colors.white.withOpacity(0.1) 
                                : MatchFitTheme.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sport.toUpperCase(),
                            style: TextStyle(
                              color: isExpired ? Colors.white54 : MatchFitTheme.accentGreen, 
                              fontSize: 10, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                        if (isExpired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('TAMAMLANDI', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                          )
                        ],
                        const Spacer(),
                        const Icon(Icons.people_outline, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${event['participants_count'] ?? 0}/${event['max_participants'] ?? 0}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 14),
                        const SizedBox(width: 6),
                        Text(_formatDate(event['event_date'], event['start_time']),
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white38, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(location,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        title: const Text('Etkinlikler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: MatchFitTheme.accentGreen,
          unselectedLabelColor: Colors.white38,
          indicatorColor: MatchFitTheme.accentGreen,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Katılınan'),
            Tab(text: 'Düzenlenen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(ref.watch(joinedEventsProvider(widget.userId)), 'Henüz bir etkinliğe katılmadı.'),
          _buildList(ref.watch(hostedEventsProvider(widget.userId)), 'Henüz bir etkinlik düzenlemedi.'),
        ],
      ),
    );
  }
}
