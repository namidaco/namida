// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

void main() {
  late Directory dir;
  final sep = Platform.pathSeparator;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_extensions_group_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Track trackOf(String name, {int dateAdded = 0, List<String> artists = const ['A'], String albumArtist = ''}) {
    final path = '${dir.path}$sep$name.mp3';
    Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
      path: path,
      dateAdded: dateAdded,
      artistsList: artists,
      albumArtist: albumArtist,
      generatePathHash: false,
    );
    return Track.explicit(path);
  }

  group('date added of a group', () {
    test('a track without creation date does not hide the others, whatever the order', () {
      const date = 1600000000000;
      final undated = trackOf('undated');
      final dated = trackOf('dated', dateAdded: date);
      expect([undated, dated].getDateAddedEffective(), date);
      expect([dated, undated].getDateAddedEffective(), date);
    });

    test('the oldest valid date wins', () {
      final newer = trackOf('newer', dateAdded: 1700000000000);
      final older = trackOf('older', dateAdded: 1600000000000);
      final undated = trackOf('undated2');
      expect([newer, undated, older].getDateAddedEffective(), 1600000000000);
      expect([undated, older, newer].getDateAddedEffective(), 1600000000000);
    });

    test('an empty group has none', () {
      expect(<Track>[].getDateAddedEffective(), null);
    });

    test('a group without any valid date has none', () {
      final undated = trackOf('undated3');
      final tooOld = trackOf('too_old', dateAdded: DateTime(1975).millisecondsSinceEpoch);
      expect([undated].getDateAddedEffective(), null);
      expect([tooOld, undated].getDateAddedEffective(), null);
    });
  });

  group('album artist of a group', () {
    test('a single common artist, inputs untouched', () {
      final t0 = trackOf('aa0', artists: ['A', 'B']);
      final t1 = trackOf('aa1', artists: ['A']);
      expect([t0, t1].albumArtist, 'A');
      expect(t0.artistsList, ['A', 'B']);
      expect(t1.artistsList, ['A']);
    });

    test('artists common to several multi artist tracks, inputs untouched', () {
      final t0 = trackOf('ab0', artists: ['A', 'B', 'C']);
      final t1 = trackOf('ab1', artists: ['B', 'C', 'D']);
      final t2 = trackOf('ab2', artists: ['C', 'B']);
      expect([t0, t1, t2].albumArtist, 'B, C');
      expect(t0.artistsList, ['A', 'B', 'C']);
      expect(t1.artistsList, ['B', 'C', 'D']);
      expect(t2.artistsList, ['C', 'B']);
    });

    test('nothing in common gives nothing', () {
      final t0 = trackOf('ac0', artists: ['A', 'B']);
      final t1 = trackOf('ac1', artists: ['C']);
      expect([t0, t1].albumArtist, '');
      expect(t0.artistsList, ['A', 'B']);
    });

    test('the first album artist tag wins', () {
      final t0 = trackOf('ad0', artists: ['X']);
      final t1 = trackOf('ad1', artists: ['Y'], albumArtist: 'Band');
      final t2 = trackOf('ad2', artists: ['Z'], albumArtist: 'Other');
      expect([t0, t1, t2].albumArtist, 'Band');
    });
  });
}
