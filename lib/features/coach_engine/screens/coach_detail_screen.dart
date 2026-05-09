import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/core/theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/coach_provider.dart';

class CoachDetailScreen extends ConsumerWidget {
  final String userId;

  const CoachDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachAsync = ref.watch(coachDetailProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: coachAsync.when(
        data: (coach) {
          if (coach == null) {
            return const Center(child: Text('Koç bulunamadı.', style: TextStyle(color: Colors.white54)));
          }
          return _CoachDetailContent(coach: coach);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: MatchFitTheme.accentGreen)),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}

class _CoachDetailContent extends StatelessWidget {
  final Map<String, dynamic> coach;

  const _CoachDetailContent({required this.coach});

  @override
  Widget build(BuildContext context) {
    final profile = coach['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? 'İsimsiz Koç';
    final avatarUrl = profile?['avatar_url'] as String?;
    final level = coach['verification_level']?.toString() ?? 'basic';
    final branch = coach['sub_branch'] ?? 'Spor';
    final bio = coach['bio'] ?? profile?['bio'] ?? 'Bu koç henüz detaylı bir açıklama eklemedi.';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 240,
          backgroundColor: const Color(0xFF0A0A0A),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF10251D), Color(0xFF0A0A0A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: _levelColor(level).withOpacity(0.16),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? Text(name.toString()[0], style: TextStyle(color: _levelColor(level), fontSize: 28)) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(name.toString(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('$branch • ${coach['work_location'] ?? 'Konum belirtilmedi'}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _metric('Seviye', level.toUpperCase()),
                    _metric('Deneyim', '${coach['experience_years'] ?? 0} yıl'),
                    _metric('Puan', '${coach['rating_avg'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('Hakkında'),
                Text(bio.toString(), style: const TextStyle(color: Colors.white70, height: 1.45)),
                const SizedBox(height: 24),
                _sectionTitle('Güven Durumu'),
                _trustPanel(level),
                const SizedBox(height: 24),
                _sectionTitle('Seans'),
                _BookingSection(coachId: coach['user_id'], coach: coach),
                const SizedBox(height: 24),
                _sectionTitle('Değerlendirmeler'),
                _ReviewsSection(coachId: coach['user_id']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
    );
  }

  Widget _trustPanel(String level) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _levelColor(level).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _levelColor(level).withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: _levelColor(level)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Belgeleri incelenmiş ve MatchFit koç standartlarına göre doğrulanmıştır.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSection extends ConsumerWidget {
  final String coachId;
  final Map<String, dynamic> coach;
  const _BookingSection({required this.coachId, required this.coach});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'Profesyonel koçluk seansı alarak oyununu bir üst seviyeye taşı.',
            style: TextStyle(color: Colors.white60, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showBookingSheet(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Seans Talep Et', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _BookingSheet(coachId: coachId),
    );
  }
}

class _BookingSheet extends ConsumerStatefulWidget {
  final String coachId;
  const _BookingSheet({required this.coachId});

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  Map<String, dynamic>? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final availabilityAsync = ref.watch(coachAvailabilityProvider(widget.coachId));

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Seans Talebi Oluştur', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Text('Tarih Seçin', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index + 1));
                final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDate = date;
                    _selectedSlot = null;
                  }),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? MatchFitTheme.accentGreen : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? MatchFitTheme.accentGreen : Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? Colors.black : Colors.white38, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(date.day.toString(), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('Uygun Saatler', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          availabilityAsync.when(
            data: (slots) {
              final dailySlots = slots.where((s) => s['day_of_week'] == (_selectedDate.weekday % 7)).toList();
              if (dailySlots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Bu gün için uygun slot bulunmuyor.', style: TextStyle(color: Colors.white38)),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: dailySlots.map((slot) {
                  final isSelected = _selectedSlot == slot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? MatchFitTheme.accentGreen : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? MatchFitTheme.accentGreen : Colors.white10),
                      ),
                      child: Text(
                        '${slot['start_time']} - ${slot['end_time']}',
                        style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Hata: $err', style: const TextStyle(color: Colors.redAccent)),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSlot == null ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Talebi Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _submitRequest() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final startTime = _selectedSlot!['start_time'];
      
      // Recommended idempotency key format: coach_session:{coach_id}:{student_id}:{date}:{start_time}
      final idempotencyKey = 'coach_session:${widget.coachId}:$userId:$dateStr:$startTime';

      await ref.read(coachEngineRepositoryProvider).requestCoachSession(
        coachId: widget.coachId,
        date: dateStr,
        startTime: startTime,
        endTime: _selectedSlot!['end_time'],
        idempotencyKey: idempotencyKey,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep başarıyla iletildi.'), backgroundColor: MatchFitTheme.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ReviewsSection extends ConsumerWidget {
  final String coachId;
  const _ReviewsSection({required this.coachId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(coachReviewsProvider(coachId));

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return const Text('Henüz değerlendirme yapılmamış.', style: TextStyle(color: Colors.white38));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: review['student_avatar'] != null ? NetworkImage(review['student_avatar']) : null,
                        child: review['student_avatar'] == null ? const Icon(Icons.person, size: 12) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(review['student_name'] ?? 'Kullanıcı', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          i < (review['rating'] ?? 0) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        )),
                      ),
                    ],
                  ),
                  if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(review['comment'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Hata: $err', style: const TextStyle(color: Colors.redAccent)),
    );
  }
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
