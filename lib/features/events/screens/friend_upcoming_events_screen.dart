import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import 'package:matchfit/core/widgets/avatar_widget.dart';
import '../repositories/event_repository.dart';
import 'package:matchfit/core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final friendUpcomingEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, friendId) async {
      final sb = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await sb
          .from('events')
          .select(
            '*, sports(name, category), profiles(full_name, trust_score, avatar_url)',
          )
          .eq('host_id', friendId)
          .gte('event_date', today)
          .order('event_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    });

final participationStatusProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, eventId) {
      // Use a custom stream to get the full participant data in real-time
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return Stream.value(null);

      return supabase
          .from('event_participants')
          .stream(primaryKey: ['id'])
          .eq('event_id', eventId)
          .map((data) {
            final filtered = data
                .where((row) => row['user_id'] == user.id)
                .toList();
            return filtered.isEmpty
                ? null
                : Map<String, dynamic>.from(filtered.first);
          });
    });

final eventJoiningStatesProvider =
    NotifierProvider<EventJoiningStatesNotifier, Map<String, bool>>(
      EventJoiningStatesNotifier.new,
    );

class EventJoiningStatesNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void setJoining(String eventId, bool value) {
    final newState = Map<String, bool>.from(state);
    newState[eventId] = value;
    state = newState;
  }
}

// Başarılı join sonrası status'u yerel olarak override etmek için
final statusOverrideProvider =
    NotifierProvider<StatusOverrideNotifier, Map<String, String>>(
      StatusOverrideNotifier.new,
    );

class StatusOverrideNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void setStatus(String eventId, String status) {
    final newState = Map<String, String>.from(state);
    newState[eventId] = status;
    state = newState;
  }

  void clear(String eventId) {
    final newState = Map<String, String>.from(state);
    newState.remove(eventId);
    state = newState;
  }
}

class CountdownJoinButton extends StatefulWidget {
  final DateTime lastRejectedAt;
  final VoidCallback onTimerFinished;
  final VoidCallback onPressed;
  final double? fontSize;
  final EdgeInsets? padding;

  const CountdownJoinButton({
    super.key,
    required this.lastRejectedAt,
    required this.onTimerFinished,
    required this.onPressed,
    this.fontSize,
    this.padding,
  });

  @override
  State<CountdownJoinButton> createState() => _CountdownJoinButtonState();
}

class _CountdownJoinButtonState extends State<CountdownJoinButton> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateRemaining();
        if (_remaining.inSeconds <= 0) {
          timer.cancel();
          widget.onTimerFinished();
        }
      }
    });
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final waitUntil = widget.lastRejectedAt.add(const Duration(hours: 2));
    _remaining = waitUntil.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.inSeconds <= 0) {
      return ElevatedButton.icon(
        onPressed: widget.onPressed,
        icon: const Icon(Icons.refresh, color: Colors.black, size: 18),
        label: Text(
          'Tekrar Katıl',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: widget.fontSize,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent,
          padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final hours = _remaining.inHours.toString().padLeft(2, '0');

    return ElevatedButton.icon(
      onPressed: widget.onPressed,
      icon: const Icon(Icons.timer_outlined, color: Colors.black, size: 16),
      label: Text(
        'Bekle ($hours:$minutes:$seconds)',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: widget.fontSize ?? 13,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orangeAccent.withOpacity(0.6),
        padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// Provider to manage which events have reminders set
final eventRemindersProvider =
    NotifierProvider<EventRemindersNotifier, List<String>>(
      EventRemindersNotifier.new,
    );

class EventRemindersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadReminders();
    return [];
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('event_reminders') ?? [];
  }

  Future<void> addReminder(String eventId) async {
    if (!state.contains(eventId)) {
      state = [...state, eventId];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('event_reminders', state);
    }
  }

  Future<void> removeReminder(String eventId) async {
    state = state.where((id) => id != eventId).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('event_reminders', state);
  }
}

class FriendUpcomingEventsScreen extends ConsumerWidget {
  final String friendId;
  final String friendName;
  final String? friendAvatar;

  const FriendUpcomingEventsScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
  }) : super(key: key);

  String _getSportImage(String sportName) {
    final lower = sportName.toLowerCase();
    if (lower.contains('tenis') || lower.contains('tennis'))
      return 'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?q=80&w=1000&auto=format&fit=crop';
    if (lower.contains('basket') || lower.contains('basketball'))
      return 'https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=1000&auto=format&fit=crop';
    if (lower.contains('futbol') ||
        lower.contains('football') ||
        lower.contains('saha'))
      return 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=1000&auto=format&fit=crop';
    if (lower.contains('voleybol') || lower.contains('volleyball'))
      return 'https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?q=80&w=1000&auto=format&fit=crop';
    if (lower.contains('koşu') || lower.contains('run'))
      return 'https://images.unsplash.com/photo-1552674605-15c2145eba82?q=80&w=1000&auto=format&fit=crop';
    return 'https://images.unsplash.com/photo-1521537634581-0dced2fee2ef?q=80&w=1000&auto=format&fit=crop';
  }

  IconData _getSportIcon(String sportName) {
    final lower = sportName.toLowerCase();
    if (lower.contains('basket')) return Icons.sports_basketball;
    if (lower.contains('futbol') || lower.contains('saha'))
      return Icons.sports_soccer;
    if (lower.contains('voleybol')) return Icons.sports_volleyball;
    if (lower.contains('tenis')) return Icons.sports_tennis;
    if (lower.contains('koşu')) return Icons.directions_run;
    return Icons.sports;
  }

  String _formatDateLabel(String? dateStr) {
    if (dateStr == null) return 'Belirtilmedi';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventDate = DateTime(dt.year, dt.month, dt.day);
      final diff = eventDate.difference(today).inDays;
      if (diff == 0) return 'Bugün';
      if (diff == 1) return 'Yarın';
      return '${dt.day} ${_getMonthName(dt.month)}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return months[month - 1];
  }

  Future<void> _handleJoin(
    BuildContext context,
    WidgetRef ref,
    String eventId,
  ) async {
    // Check if previously rejected to show warning
    final participantData =
        await ref.read(eventRepositoryProvider).getParticipantData(eventId) ??
        ref.read(participationStatusProvider(eventId)).value;
    final rejectionCount = participantData?['rejection_count'] as int? ?? 0;

    if (rejectionCount > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'Önemli Uyarı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Bu etkinliğe 2. başvurunuz. Bir daha reddedilirseniz bu etkinlikten men edileceksiniz. Devam etmek istiyor musunuz?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Vazgeç',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: MatchFitTheme.accentGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Anladım, Devam Et',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    ref.read(eventJoiningStatesProvider.notifier).setJoining(eventId, true);
    try {
      await ref.read(eventRepositoryProvider).joinEvent(eventId);
      // Immediately override status locally so UI updates instantly
      ref.read(statusOverrideProvider.notifier).setStatus(eventId, 'pending');
      ref.invalidate(participationStatusProvider(eventId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Katılım isteği başarıyla gönderildi!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      ref.read(eventJoiningStatesProvider.notifier).setJoining(eventId, false);
    }
  }

  Future<void> _showReminderDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> evt,
  ) async {
    final eventId = evt['id'].toString();
    final eventDateStr = evt['event_date'];
    final eventTimeStr = evt['event_time'] ?? '00:00';

    if (eventDateStr == null) return;

    final eventDateTime = DateTime.parse('${eventDateStr}T$eventTimeStr');
    final now = DateTime.now();
    final limitTime = eventDateTime.subtract(const Duration(hours: 1));

    if (now.isAfter(limitTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Etkinliğe 1 saatten az kaldığı için hatırlatıcı kurulamaz.',
          ),
        ),
      );
      return;
    }

    // Başlangıç değerleri:
    // Eğer etkinlik yarına veya daha sonraysa, bugünü seç.
    // Eğer bugünse, şu anki saati 5 dk ileri alıp seç.
    DateTime selectedDate = DateTime(now.year, now.month, now.day);
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(
      now.add(const Duration(minutes: 5)),
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'Hatırlatıcı Kur',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Etkinlikten önce ne zaman bildirim almak istersin?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  // Tarih Seçimi
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        'Tarih: ${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: MatchFitTheme.accentGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: now,
                          lastDate: eventDateTime,
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: MatchFitTheme.accentGreen,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E1E1E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          setState(() => selectedDate = pickedDate);
                        }
                      },
                    ),
                  ),

                  // Saat Seçimi
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        'Saat: ${selectedTime.format(context)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: MatchFitTheme.accentGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () async {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: MatchFitTheme.accentGreen,
                                  onPrimary: Colors.black,
                                  surface: Color(0xFF1E1E1E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedTime != null) {
                          setState(() => selectedTime = pickedTime);
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MatchFitTheme.accentGreen,
                  ),
                  onPressed: () async {
                    final reminderDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    if (reminderDateTime.isBefore(DateTime.now())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Geçmiş bir zamana hatırlatıcı kurulamaz.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (reminderDateTime.isAfter(limitTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Hatırlatıcı etkinlikten en geç 1 saat önceye kurulabilir.',
                          ),
                        ),
                      );
                      return;
                    }

                    await NotificationService().scheduleNotification(
                      id: eventId.hashCode,
                      title: 'Etkinlik Hatırlatıcısı',
                      body:
                          '"${evt['title'] ?? 'Spor Etkinliği'}" birazdan başlayacak!',
                      scheduledDate: reminderDateTime,
                    );

                    await ref
                        .read(eventRemindersProvider.notifier)
                        .addReminder(eventId);
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hatırlatıcı başarıyla kuruldu!'),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Kur',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelReminder(
    BuildContext context,
    WidgetRef ref,
    String eventId,
  ) async {
    await NotificationService().cancelNotification(eventId.hashCode);
    await ref.read(eventRemindersProvider.notifier).removeReminder(eventId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatırlatıcı iptal edildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(friendUpcomingEventsProvider(friendId));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
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
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: eventsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Hata: $err',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          data: (events) {
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Yaklaşan etkinlik bulunamadı.',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              );
            }

            final nextEvent = events.first;
            final upcomingEvents = events.skip(1).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ORGANIZER CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        AvatarWidget(
                          name: friendName,
                          avatarUrl: friendAvatar,
                          radius: 24,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ETKİNLİĞİ DÜZENLEYEN',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              friendName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // NEXT EVENT HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sıradaki Etkinlik',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'AZ KALDI',
                          style: TextStyle(
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // FEATURED EVENT CARD
                  _buildFeaturedCard(context, ref, nextEvent),

                  if (upcomingEvents.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Yaklaşanlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...upcomingEvents.map(
                      (evt) => _buildSmallCard(context, ref, evt),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> evt,
  ) {
    final eventId = evt['id'].toString();
    final sportName = evt['sports']?['name'] ?? 'Etkinlik';
    final title = evt['title'] ?? sportName;
    final timeStr = evt['start_time']?.toString().substring(0, 5) ?? '19:30';
    final endTimeStr = evt['end_time']?.toString().substring(0, 5) ?? '21:00';
    final locationName = evt['location_name'] ?? 'Tesis Seçilmedi';
    final dateLabel = _formatDateLabel(evt['event_date']);

    final statusAsync = ref.watch(participationStatusProvider(eventId));
    final reminders = ref.watch(eventRemindersProvider);
    final isReminderSet = reminders.contains(eventId);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Area
          GestureDetector(
            onTap: () => context.push('/event-detail', extra: evt),
            child: Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_getSportImage(sportName)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MatchFitTheme.accentGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dateLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getSportIcon(sportName),
                        color: MatchFitTheme.accentGreen,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '$timeStr - $endTimeStr',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$locationName • 1.2 km',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action Buttons
                statusAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: MatchFitTheme.accentGreen,
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) {
                    // Check local override first (set after successful join)
                    final overrides = ref.watch(statusOverrideProvider);
                    final overriddenStatus = overrides[eventId];

                    final status = data?['status'] ?? overriddenStatus;
                    final isPending = status == 'pending';
                    final isJoined = status == 'joined';
                    final isRejected = status == 'rejected';

                    final lastRejectedAtStr = data?['last_rejected_at'];
                    final lastRejectedAt = lastRejectedAtStr != null
                        ? DateTime.tryParse(lastRejectedAtStr)
                        : null;
                    final rejectionCount =
                        data?['rejection_count'] as int? ?? 0;

                    final joiningStates = ref.watch(eventJoiningStatesProvider);
                    final isJoining = joiningStates[eventId] ?? false;

                    // Determine if we're in a cooldown period
                    bool inCooldown = false;
                    if (isRejected && lastRejectedAt != null) {
                      final elapsed = DateTime.now().difference(lastRejectedAt);
                      inCooldown = elapsed.inHours < 2;
                    }

                    // Determine button widget
                    Widget joinButton;

                    if (isRejected && rejectionCount >= 2) {
                      // Permanently blocked - 2 rejections
                      joinButton = ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(
                          Icons.block,
                          color: Colors.white54,
                          size: 18,
                        ),
                        label: const Text(
                          'İstek Engellendi',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    } else if (isRejected &&
                        inCooldown &&
                        lastRejectedAt != null) {
                      // In 2-hour cooldown - show countdown
                      joinButton = CountdownJoinButton(
                        lastRejectedAt: lastRejectedAt,
                        onTimerFinished: () => ref.invalidate(
                          participationStatusProvider(eventId),
                        ),
                        onPressed: () {
                          // Timer still running, show warning
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bekleme süresi dolmadan istek gönderemezsiniz.',
                              ),
                            ),
                          );
                        },
                      );
                    } else if (isRejected) {
                      // Rejected but cooldown over (or no lastRejectedAt) - can re-apply
                      joinButton = ElevatedButton.icon(
                        onPressed: isJoining
                            ? null
                            : () => _handleJoin(context, ref, eventId),
                        icon: isJoining
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Colors.black,
                                size: 18,
                              ),
                        label: Text(
                          isJoining ? 'Gönderiliyor...' : 'Tekrar Katıl',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    } else if (isPending) {
                      // Request sent, waiting for approval
                      joinButton = ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(
                          Icons.hourglass_empty,
                          color: Colors.black,
                          size: 18,
                        ),
                        label: const Text(
                          'İstek Gönderildi',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    } else if (isJoined) {
                      // Already joined
                      joinButton = ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.black,
                          size: 18,
                        ),
                        label: const Text(
                          'Katıldın',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    } else {
                      // No status - first time join
                      joinButton = ElevatedButton.icon(
                        onPressed: isJoining
                            ? null
                            : () => _handleJoin(context, ref, eventId),
                        icon: isJoining
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline,
                                color: Colors.black,
                                size: 18,
                              ),
                        label: Text(
                          isJoining ? 'Gönderiliyor...' : 'Katıl',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MatchFitTheme.accentGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: joinButton),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isReminderSet
                                ? () => _cancelReminder(context, ref, eventId)
                                : () => _showReminderDialog(context, ref, evt),
                            icon: Icon(
                              isReminderSet
                                  ? Icons.notifications_off
                                  : Icons.notifications_none,
                              color: isReminderSet
                                  ? Colors.redAccent
                                  : Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              isReminderSet ? 'İptal Et' : 'Hatırlat',
                              style: TextStyle(
                                color: isReminderSet
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReminderSet
                                  ? Colors.red.withOpacity(0.1)
                                  : const Color(0xFF2A2A2A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> evt,
  ) {
    final eventId = evt['id'].toString();
    final sportName = evt['sports']?['name'] ?? 'Etkinlik';
    final title = evt['title'] ?? sportName;
    final timeStr = evt['start_time']?.toString().substring(0, 5) ?? '19:30';
    final locationName = evt['location_name'] ?? 'Tesis Seçilmedi';
    final dateLabel = _formatDateLabel(evt['event_date']);

    final statusAsync = ref.watch(participationStatusProvider(eventId));
    final reminders = ref.watch(eventRemindersProvider);
    final isReminderSet = reminders.contains(eventId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Left Image
          GestureDetector(
            onTap: () => context.push('/event-detail', extra: evt),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(_getSportImage(sportName)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Right Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isReminderSet
                            ? Icons.notifications_off
                            : Icons.notifications_none,
                        color: isReminderSet
                            ? Colors.redAccent
                            : Colors.white38,
                        size: 20,
                      ),
                      onPressed: isReminderSet
                          ? () => _cancelReminder(context, ref, eventId)
                          : () => _showReminderDialog(context, ref, evt),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel, $timeStr • $locationName',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                statusAsync.when(
                  loading: () => const SizedBox(
                    height: 28,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MatchFitTheme.accentGreen,
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) {
                    // Check local override first (set after successful join)
                    final overrides = ref.watch(statusOverrideProvider);
                    final overriddenStatus = overrides[eventId];

                    final status = data?['status'] ?? overriddenStatus;
                    final isPending = status == 'pending';
                    final isJoined = status == 'joined';
                    final isRejected = status == 'rejected';

                    final lastRejectedAtStr = data?['last_rejected_at'];
                    final lastRejectedAt = lastRejectedAtStr != null
                        ? DateTime.tryParse(lastRejectedAtStr)
                        : null;
                    final rejectionCount =
                        data?['rejection_count'] as int? ?? 0;

                    final joiningStates = ref.watch(eventJoiningStatesProvider);
                    final isJoining = joiningStates[eventId] ?? false;

                    bool inCooldown = false;
                    if (isRejected && lastRejectedAt != null) {
                      final elapsed = DateTime.now().difference(lastRejectedAt);
                      inCooldown = elapsed.inHours < 2;
                    }

                    Widget actionButton;

                    if (isRejected && rejectionCount >= 2) {
                      actionButton = ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Engellendi',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      );
                    } else if (isRejected &&
                        inCooldown &&
                        lastRejectedAt != null) {
                      actionButton = CountdownJoinButton(
                        lastRejectedAt: lastRejectedAt,
                        onTimerFinished: () => ref.invalidate(
                          participationStatusProvider(eventId),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bekleme süresi dolmadan istek gönderemezsiniz.',
                              ),
                            ),
                          );
                        },
                        fontSize: 11,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      );
                    } else if (isRejected) {
                      actionButton = ElevatedButton(
                        onPressed: isJoining
                            ? null
                            : () => _handleJoin(context, ref, eventId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isJoining
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Tekrar Katıl',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      );
                    } else if (isPending) {
                      actionButton = ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'İstek Gönderildi',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    } else if (isJoined) {
                      actionButton = ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Katıldın',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    } else {
                      actionButton = ElevatedButton(
                        onPressed: isJoining
                            ? null
                            : () => _handleJoin(context, ref, eventId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isJoining
                              ? Colors.grey
                              : MatchFitTheme.accentGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isJoining
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Katıl',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              context.push('/event-detail', extra: evt),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'DETAYLAR',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(height: 28, child: actionButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
