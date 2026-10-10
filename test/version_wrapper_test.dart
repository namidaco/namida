// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/version_wrapper.dart';

void main() {
  bool? isAfter(String version, String other) => VersionWrapper(version).isAfter(VersionWrapper(other));

  test('parses a beta release name with its build number and date', () {
    final version = VersionWrapper('v7.8.0-beta+260930207');
    expect(version.name, '7.8.0');
    expect(version.prettyVersionRaw, 'v7.8.0');
    expect(version.isBeta, true);
    expect(version.buildNumber, 260930207);
    expect(version.buildDate, DateTime.utc(2026, 9, 30, 20, 42));
  });

  test('a stable release name has no build number', () {
    final version = VersionWrapper('v7.1.2');
    expect(version.name, '7.1.2');
    expect(version.isBeta, false);
    expect(version.buildNumber, null);
    expect(version.buildDate, null);
  });

  test('only a beta shows the beta suffix', () {
    expect(VersionWrapper('v7.8.0-beta+260930207').prettyVersion, 'v7.8.0-beta');
    expect(VersionWrapper('v7.1.2').prettyVersion, 'v7.1.2');
    expect(VersionWrapper('7.1.2', '260919170').prettyVersion, 'v7.1.2');
  });

  test('differing build numbers decide over the version name', () {
    expect(isAfter('v1.0.0-beta+260101100', 'v9.0.0-beta+251231100'), true);
    expect(isAfter('v9.0.0-beta+251231100', 'v1.0.0-beta+260101100'), false);
  });

  test('the version name decides when builds are equal or missing', () {
    expect(isAfter('v8.0.0-beta+260101100', 'v7.9.9-beta+260101100'), true);
    expect(isAfter('8.0.0', '7.9.9'), true);
    expect(isAfter('7.9.9', '8.0.0'), false);
    expect(isAfter('7.8.0', '7.8.0'), false);
  });

  test('two digit major and minor parts compare as numbers', () {
    expect(isAfter('7.10.0', '7.9.0'), true);
    expect(isAfter('7.9.0', '7.10.0'), false);
    expect(isAfter('10.0.0', '9.9.0'), true);
    expect(isAfter('9.9.0', '10.0.0'), false);
  });

  test('the patch part compares as a decimal fraction', () {
    expect(isAfter('5.1.7', '5.1.68'), true);
    expect(isAfter('5.1.68', '5.1.7'), false);
  });

  test('the longer version wins when the shared parts are equal', () {
    expect(isAfter('3.3.2', '3.3'), true);
    expect(isAfter('3.3', '3.3.2'), false);
  });

  test('an unparsable version compares as unknown', () {
    expect(isAfter('vnext', '7.8.0'), null);
  });
}
