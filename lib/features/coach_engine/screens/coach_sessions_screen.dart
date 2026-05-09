import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:matchfit/core/theme.dart';
import '../providers/coach_provider.dart';

class CoachSessionsScreen extends ConsumerWidget {
  const CoachSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(myCoachSessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Seanslarım', style: TextStyle(color: MatchFitTheme.accentGreen, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(myCoachSessionsProvider),
          ),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('Henüz seans bulunmuyor.', style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionCard(session: session);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final Map<String, dynamic> session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = session['status'] as String;
    final dateStr = session['session_date'] as String;
    final startTime = session['start_time'] as String;
    final endTime = session['end_time'] as String;
    
    // Profiles are returned as JSONB from RPC
    final coachProfile = session['coach_profile'] as Map<String, dynamic>?;
    final studentProfile = session['student_profile'] as Map<String, dynamic>?;
    
    final otherName = studentProfile?['full_name'] ?? coachProfile?['full_name'] ?? 'Bilinmiyor';
    final otherAvatar = studentProfile?['avatar_url'] ?? coachProfile?['avatar_url'];

    Color statusColor;
    String statusText;
    switch (status) {
      case 'requested':
        statusColor = Colors.orange;
        statusText = 'Talep Edildi';
        break;
      case 'confirmed':
        statusColor = MatchFitTheme.accentGreen;
        statusText = 'Onaylandı';
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusText = 'Reddedildi';
        break;
      case 'completed':
        statusColor = Colors.blueAccent;
        statusText = 'Tamamlandı';
        break;
      default:
        statusColor = Colors.white24;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundImage: otherAvatar != null ? NetworkImage(otherAvatar) : null,
              child: otherAvatar == null ? const Icon(Icons.person) : null,
            ),
            title: Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.white38),
                      const SizedBox(width: 6),
                      Text('$startTime - $endTime', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          if (status == 'requested' && (session['coach_id'] == Supabase.instance.client.auth.currentUser?.id)) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _handleRequest(context, ref, 'reject'),
                      child: const Text('Reddet', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleRequest(context, ref, 'confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MatchFitTheme.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Onayla'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'completed' && (session['student_id'] == Supabase.instance.client.auth.currentUser?.id)) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReviewSheet(context, ref),
                  icon: const Icon(Icons.star_rate, size: 18),
                  label: const Text('Deneyimi Değerlendir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showReviewSheet(BuildContext context, WidgetRef ref) {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Seansı Değerlendir', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(
                    index < selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => selectedRating = index + 1),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Yorumunuzu buraya yazın (isteğe bağlı)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(coachEngineRepositoryProvider).submitCoachReview(
                        sessionId: session['id'],
                        rating: selectedRating,
                        comment: commentController.text.trim(),
                        idempotencyKey: 'rev_${session['id']}_${DateTime.now().millisecondsSinceEpoch}',
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Değerlendirmeniz iletildi.')));
                        ref.invalidate(myCoachSessionsProvider);
                        ref.invalidate(coachDetailProvider(session['coach_id']));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MatchFitTheme.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleRequest(BuildContext context, WidgetRef ref, String action) async {
    try {
      await ref.read(coachEngineRepositoryProvider).handleCoachSessionRequest(
        sessionId: session['id'],
        action: action,
      );
      ref.invalidate(myCoachSessionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'confirm' ? 'Seans onaylandı.' : 'Seans reddedildi.'),
            backgroundColor: action == 'confirm' ? MatchFitTheme.accentGreen : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
