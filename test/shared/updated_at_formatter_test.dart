import 'package:flutter_test/flutter_test.dart';
import 'package:p5de/shared/updated_at_formatter.dart';

void main() {
  group('formatUpdatedAt', () {
    final now = DateTime(2026, 5, 25, 12);

    test('uses relative labels for recent edits', () {
      expect(
        formatUpdatedAt(
          now.subtract(const Duration(seconds: 20)).millisecondsSinceEpoch,
          now: now,
        ),
        'just now',
      );
      expect(
        formatUpdatedAt(
          now.subtract(const Duration(minutes: 8)).millisecondsSinceEpoch,
          now: now,
        ),
        '8m ago',
      );
      expect(
        formatUpdatedAt(
          now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
          now: now,
        ),
        '3h ago',
      );
      expect(
        formatUpdatedAt(
          now.subtract(const Duration(days: 21)).millisecondsSinceEpoch,
          now: now,
        ),
        '21d ago',
      );
    });

    test('uses day and month for older edits in the same year', () {
      expect(
        formatUpdatedAt(
          DateTime(2026, 4, 12, 9).millisecondsSinceEpoch,
          now: now,
        ),
        '12 Apr',
      );
    });

    test('includes the year for older edits from previous years', () {
      expect(
        formatUpdatedAt(
          DateTime(2025, 6, 12, 9).millisecondsSinceEpoch,
          now: now,
        ),
        '12 Jun 2025',
      );
    });
  });
}
