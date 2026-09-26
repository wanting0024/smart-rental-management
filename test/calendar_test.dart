// test/calendar_test.dart
// Verifies the calendar helper used by ScheduleScreen.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/widgets/calendar_week_view.dart';

void main() {
  group('mondayOf()', () {
    test('a Monday returns itself at 00:00', () {
      // 2026-07-13 is a Monday
      final mon = DateTime(2026, 7, 13, 14, 30);
      final result = mondayOf(mon);
      expect(result.weekday, DateTime.monday);
      expect(result.year, 2026);
      expect(result.month, 7);
      expect(result.day, 13);
      expect(result.hour, 0);
      expect(result.minute, 0);
    });

    test('a Wednesday returns the previous Monday', () {
      // 2026-07-15 is a Wednesday
      final wed = DateTime(2026, 7, 15, 9, 0);
      final result = mondayOf(wed);
      expect(result.weekday, DateTime.monday);
      expect(result.day, 13);
    });

    test('a Sunday returns the Monday of the same week', () {
      // 2026-07-19 is a Sunday
      final sun = DateTime(2026, 7, 19, 23, 59);
      final result = mondayOf(sun);
      expect(result.weekday, DateTime.monday);
      expect(result.day, 13);
    });

    test('a Saturday returns the Monday of the same week', () {
      // 2026-07-18 is a Saturday
      final sat = DateTime(2026, 7, 18, 12, 0);
      final result = mondayOf(sat);
      expect(result.weekday, DateTime.monday);
      expect(result.day, 13);
    });

    test('crossing a month boundary', () {
      // 2026-08-02 is a Sunday; Monday is 2026-08-?? wait
      // 2026-08-01 is a Saturday; 2026-08-02 is a Sunday
      // So mondayOf(Sunday Aug 2) -> July 27? No wait, the previous Monday
      // weekday for Sunday is 7; weekday - 1 = 6 days back
      // Aug 2 - 6 days = July 27 (Monday)
      final sun = DateTime(2026, 8, 2);
      final result = mondayOf(sun);
      expect(result.weekday, DateTime.monday);
      expect(result.month, 7);
      expect(result.day, 27);
    });
  });
}
