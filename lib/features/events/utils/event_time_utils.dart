class EventTimeUtils {
  const EventTimeUtils._();

  static bool isUpcoming(Map<String, dynamic> event, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final eventDateTime = parseEventDateTime(
      event['event_date'] as String?,
      event['start_time'] as String?,
      now: effectiveNow,
    );

    if (eventDateTime == null) return true;
    return !eventDateTime.isBefore(effectiveNow);
  }

  static DateTime? parseEventDateTime(
    String? dateStr,
    String? timeStr, {
    DateTime? now,
  }) {
    if (dateStr == null || dateStr.isEmpty) return null;

    final date = DateTime.tryParse(dateStr);
    if (date == null) return null;

    if (timeStr == null || timeStr.isEmpty) {
      return DateTime(date.year, date.month, date.day);
    }

    final parts = timeStr.split(':');
    if (parts.length < 2) return DateTime(date.year, date.month, date.day);

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static bool isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
