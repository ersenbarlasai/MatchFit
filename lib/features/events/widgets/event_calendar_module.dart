import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import 'package:matchfit/core/theme.dart';
import '../repositories/event_repository.dart';

final monthlyEventsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({String userId, DateTime month})>((ref, arg) async {
  return ref.read(eventRepositoryProvider).getUserMonthlyEvents(arg.userId, arg.month.year, arg.month.month);
});

class EventCalendarModule extends ConsumerStatefulWidget {
  final String userId;
  const EventCalendarModule({super.key, required this.userId});

  @override
  ConsumerState<EventCalendarModule> createState() => _EventCalendarModuleState();
}

class _EventCalendarModuleState extends ConsumerState<EventCalendarModule> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    // Watch events for the focused month
    final eventsAsync = ref.watch(monthlyEventsProvider((userId: widget.userId, month: DateTime(_focusedDay.year, _focusedDay.month))));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: MatchFitTheme.accentGreen, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Etkinlik Takvimi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              // A small legend
              Row(
                children: const [
                  _LegendItem(color: MatchFitTheme.accentGreen, text: 'Oluşturulan'),
                  SizedBox(width: 8),
                  _LegendItem(color: Color(0xFF0052FF), text: 'Katılınan'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          eventsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: MatchFitTheme.accentGreen),
              ),
            ),
            error: (err, _) => Center(
              child: Text('Hata: $err', style: const TextStyle(color: Colors.red)),
            ),
            data: (events) {
              return TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                eventLoader: (day) {
                  final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  return events.where((e) => e['event_date'] == dateStr).toList();
                },
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  weekendStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  todayDecoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  markerDecoration: const BoxDecoration(), // We use custom marker builder
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, loadedEvents) {
                    if (loadedEvents.isEmpty) return const SizedBox();

                    bool hasHosted = loadedEvents.any((e) => (e as Map)['isHost'] == true);
                    bool hasAttended = loadedEvents.any((e) => (e as Map)['isHost'] == false);

                    return Positioned(
                      bottom: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasHosted)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: const BoxDecoration(
                                color: MatchFitTheme.accentGreen,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: MatchFitTheme.accentGreen, blurRadius: 4)],
                              ),
                              width: 6,
                              height: 6,
                            ),
                          if (hasAttended)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0052FF),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Color(0xFF0052FF), blurRadius: 4)],
                              ),
                              width: 6,
                              height: 6,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Event list for the selected day
          if (_selectedDay != null)
            eventsAsync.maybeWhen(
              data: (events) {
                final dateStr = '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
                final dayEvents = events.where((e) => e['event_date'] == dateStr).toList();
                
                if (dayEvents.isEmpty) return const SizedBox();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedDay!.day} ${_getMonthName(_selectedDay!.month)} Etkinlikleri',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ...dayEvents.map((e) => _EventListItem(event: e)).toList(),
                  ],
                );
              },
              orElse: () => const SizedBox(),
            ),
        ],
      ),
    ),
  );
}

  String _getMonthName(int month) {
    const months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return months[month];
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
        ),
      ],
    );
  }
}

class _EventListItem extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventListItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final isHost = event['isHost'] == true;
    final title = event['title'] ?? 'Etkinlik';
    final time = event['start_time'] != null ? event['start_time'].toString().substring(0, 5) : 'Belli Değil';
    final location = event['location_name'] ?? event['location_text'] ?? 'Konum Belli Değil';

    return GestureDetector(
      onTap: () {
        context.push('/event-detail', extra: event);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isHost ? MatchFitTheme.accentGreen.withOpacity(0.1) : const Color(0xFF0052FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHost ? Icons.star_rounded : Icons.sports_kabaddi,
                color: isHost ? MatchFitTheme.accentGreen : const Color(0xFF0052FF),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white.withOpacity(0.5), size: 12),
                      const SizedBox(width: 4),
                      Text(time, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined, color: Colors.white.withOpacity(0.5), size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
