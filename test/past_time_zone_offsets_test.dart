// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/past_time_zone_offsets.dart';

void main() {
  test('matches the system offset for every 10 minutes over 3 years, switch days included', () {
    final startMS = DateTime.utc(2024, 1, 1).millisecondsSinceEpoch;
    final endMS = DateTime.utc(2027, 1, 1).millisecondsSinceEpoch;
    final offsets = PastTimeZoneOffsets(endMS);
    const stepMS = 10 * Duration.millisecondsPerMinute;
    int mismatches = 0;
    for (int ms = startMS; ms < endMS; ms += stepMS) {
      final expectedOffsetMS = DateTime.fromMillisecondsSinceEpoch(ms).timeZoneOffset.inMilliseconds;
      if (offsets.offsetMSOf(ms) != expectedOffsetMS) mismatches++;
    }
    expect(mismatches, 0);
  });

  test('times after the limit read the system offset', () {
    final nowMS = DateTime.now().millisecondsSinceEpoch;
    final offsets = PastTimeZoneOffsets(nowMS);
    final laterMS = nowMS + 200 * Duration.millisecondsPerDay;
    expect(offsets.offsetMSOf(laterMS), DateTime.fromMillisecondsSinceEpoch(laterMS).timeZoneOffset.inMilliseconds);
  });
}
