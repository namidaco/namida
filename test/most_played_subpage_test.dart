// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/ui/pages/subpages/most_played_subpage.dart';

void main() {
  test('a days radius pick covers whole days around the picked day, 2 * radius + 1 days', () {
    final range = MostPlayedItemsPage.debugRangeCenteredOnDay(DateTime(2026, 1, 12, 15), 2);
    expect(range, DateRange.wholeDays(oldest: DateTime(2026, 1, 10), newest: DateTime(2026, 1, 14)));
    expect(range.toDaysSafe(), 5);

    final acrossMonths = MostPlayedItemsPage.debugRangeCenteredOnDay(DateTime(2026, 3, 30), 3);
    expect(acrossMonths, DateRange.wholeDays(oldest: DateTime(2026, 3, 27), newest: DateTime(2026, 4, 2)));
    expect(acrossMonths.toDaysSafe(), 7);
  });
}
