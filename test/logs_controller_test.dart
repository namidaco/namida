// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/logs_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  final sep = Platform.pathSeparator;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_logs_test');
    AppDirs.USER_DATA = '${dir.path}${sep}data$sep';
    File(AppPaths.LOGS).parent.createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('repeats keep the first time and rewrite the last one in place', () async {
    final stampRegex = RegExp(r'\d{4}-\d\d-\d\d \d\d:\d\d:\d\d');

    logger.error('single');
    for (int i = 0; i < 3; i++) {
      logger.error('repeated', e: 'same error');
    }
    logger.error('after');
    await logger.dispose();

    final lines = File(AppPaths.LOGS).readAsLinesSync();
    final headerIndices = [
      for (int i = 0; i < lines.length; i++)
        if (lines[i].startsWith('x0')) i,
    ];
    expect(headerIndices.length, 3);

    final single = lines[headerIndices[0]];
    final repeated = lines[headerIndices[1]];
    final after = lines[headerIndices[2]];

    expect(RegExp('^x0001 ${stampRegex.pattern} +\$').hasMatch(single), isTrue, reason: single);
    expect(RegExp('^x0003 ${stampRegex.pattern} \\(last ${stampRegex.pattern}\\)\$').hasMatch(repeated), isTrue, reason: repeated);
    expect(single.length, repeated.length);
    expect(after.startsWith('x0001 '), isTrue);

    expect(lines[headerIndices[0] + 1], 'single');
    expect(lines[headerIndices[1] + 1], 'same error');
    expect(lines[headerIndices[1] + 2], 'repeated');
    expect(lines[headerIndices[2] + 1], 'after');
  });
}
