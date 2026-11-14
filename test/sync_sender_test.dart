// by claude
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_sync_sender_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// any error counts, the device id lookup fails first in tests.
  Matcher endsWithError() => throwsA(isNot(isA<TimeoutException>()));

  test('a failed fingerprints send ends, and the next one starts fresh', () async {
    const deviceId = 'not_connected';
    final first = SyncSender.inst.resendFingerprints(deviceId);
    await expectLater(first.timeout(const Duration(seconds: 20)), endsWithError());
    final second = SyncSender.inst.resendFingerprints(deviceId);
    expect(identical(first, second), isFalse);
    await expectLater(second.timeout(const Duration(seconds: 20)), endsWithError());
  });
}
