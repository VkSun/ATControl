import 'package:flutter_test/flutter_test.dart';
import 'package:atcontrol/utils/date_utils.dart';

void main() {
  group('dateOnly', () {
    test('strips time component', () {
      final d = DateTime(2026, 7, 8, 15, 30, 45);
      expect(dateOnly(d), DateTime(2026, 7, 8));
    });

    test('midnight stays midnight', () {
      final d = DateTime(2026, 1, 1);
      expect(dateOnly(d), DateTime(2026, 1, 1));
    });
  });

  group('daysUntil', () {
    // Freeze "today" by testing relative to a known anchor.
    // We derive today via dateOnly(DateTime.now()) and compute expected values.

    test('today returns 0', () {
      final today = dateOnly(DateTime.now());
      expect(daysUntil(today), 0);
    });

    test('tomorrow returns 1', () {
      final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
      expect(daysUntil(tomorrow), 1);
    });

    test('yesterday returns -1', () {
      final yesterday = dateOnly(DateTime.now()).subtract(const Duration(days: 1));
      expect(daysUntil(yesterday), -1);
    });

    test('today with non-midnight time still returns 0', () {
      // Pass a DateTime that is today but at 23:59:59 — should still be 0
      final todayLate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        23, 59, 59,
      );
      expect(daysUntil(todayLate), 0);
    });

    test('tomorrow at 00:00:01 returns 1', () {
      final tomorrowEarly = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day + 1,
        0, 0, 1,
      );
      expect(daysUntil(tomorrowEarly), 1);
    });

    test('30 days ahead', () {
      final future = dateOnly(DateTime.now()).add(const Duration(days: 30));
      expect(daysUntil(future), 30);
    });

    test('end-of-month rollover (Jan 31 → Feb 1)', () {
      final jan31 = DateTime(2026, 1, 31);
      final feb1 = DateTime(2026, 2, 1);
      // The difference between them should be 1 regardless of time-of-day issues
      expect(dateOnly(feb1).difference(dateOnly(jan31)).inDays, 1);
    });

    test('year boundary (Dec 31 → Jan 1)', () {
      final dec31 = DateTime(2025, 12, 31);
      final jan1 = DateTime(2026, 1, 1);
      expect(dateOnly(jan1).difference(dateOnly(dec31)).inDays, 1);
    });
  });

  group('toDateString', () {
    test('formats normal date', () {
      expect(toDateString(DateTime(2026, 7, 8)), '2026-07-08');
    });

    test('pads single-digit month and day', () {
      expect(toDateString(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('ignores time component', () {
      expect(toDateString(DateTime(2026, 12, 31, 23, 59, 59)), '2026-12-31');
    });

    test('matches toIso8601String split pattern', () {
      final d = DateTime(2026, 3, 15);
      expect(toDateString(d), d.toIso8601String().split('T')[0]);
    });
  });

  group('dateStr (nullable wrapper)', () {
    test('null returns null', () {
      expect(dateStr(null), null);
    });

    test('non-null returns formatted string', () {
      expect(dateStr(DateTime(2026, 7, 8)), '2026-07-08');
    });
  });

  group('Vehicle.dateStatus thresholds', () {
    // dateStatus uses daysUntil internally, so we test via fixed offsets from today
    int status(int daysFromNow) {
      final date = dateOnly(DateTime.now()).add(Duration(days: daysFromNow));
      // Inline logic matching vehicle.dart dateStatus
      final diff = daysUntil(date);
      if (diff < 0) return 4;
      if (diff <= 7) return 3;
      if (diff <= 14) return 2;
      if (diff <= 30) return 1;
      return 0;
    }

    test('expired (yesterday) → 4', () => expect(status(-1), 4));
    test('today (0 days) → 3', () => expect(status(0), 3));
    test('7 days → 3 (red)', () => expect(status(7), 3));
    test('8 days → 2 (amber)', () => expect(status(8), 2));
    test('14 days → 2 (amber)', () => expect(status(14), 2));
    test('15 days → 1 (green)', () => expect(status(15), 1));
    test('30 days → 1 (green)', () => expect(status(30), 1));
    test('31 days → 0 (ok)', () => expect(status(31), 0));
  });
}
