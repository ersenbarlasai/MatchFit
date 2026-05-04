import 'package:flutter_test/flutter_test.dart';
import 'package:matchfit/features/events/utils/event_time_utils.dart';

void main() {
  group('EventTimeUtils.isUpcoming', () {
    test('keeps future events', () {
      final event = {'event_date': '2026-05-05', 'start_time': '18:30:00'};

      expect(
        EventTimeUtils.isUpcoming(event, now: DateTime(2026, 5, 5, 18)),
        isTrue,
      );
    });

    test('filters earlier events from the same day', () {
      final event = {'event_date': '2026-05-05', 'start_time': '17:30:00'};

      expect(
        EventTimeUtils.isUpcoming(event, now: DateTime(2026, 5, 5, 18)),
        isFalse,
      );
    });
  });
}
