// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lrc/lrc.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/lyrics.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/lyrics_editor_page.dart';

void main() {
  group('round trip', () {
    test('saving keeps every line, word and timing of the dart_lrc fixtures', () {
      for (final (:name, :lrc) in _lrcFixtures()) {
        final doc = debugCreateLyricsDocument()..loadLrc(lrc, durationMS: 0);
        final saved = LrcParser.parse(doc.toLrcText(durationMS: 0));
        _expectSameLyrics(saved, lrc, name);
      }
    });

    test('loading and saving what the editor saved changes no line, word or timing', () {
      for (final (:name, :lrc) in _lrcFixtures()) {
        final firstDoc = debugCreateLyricsDocument()..loadLrc(lrc, durationMS: 0);
        final firstSaved = LrcParser.parse(firstDoc.toLrcText(durationMS: 0));
        final secondDoc = debugCreateLyricsDocument()..loadLrc(firstSaved, durationMS: 0);
        final secondSaved = LrcParser.parse(secondDoc.toLrcText(durationMS: 0));
        _expectSameLyrics(secondSaved, firstSaved, name);
      }
    });
  });

  group('plain text edits', () {
    test('lines that stayed or were edited in place keep their times, inserted lines are untimed', () {
      final doc = debugCreateLyricsDocument()..loadSource('[00:01.00]one\n[00:02.00]two\n[00:03.00]three\n[00:04.00]four', durationMS: 0);
      doc.applyPlainText('one\ntwo edited\nthree\nextra\nfour');
      expect(doc.lines.map((e) => (e.text, e.startMS)), [('one', 1000), ('two edited', 2000), ('three', 3000), ('extra', null), ('four', 4000)]);
    });

    test('removed lines take nothing with them', () {
      final doc = debugCreateLyricsDocument()..loadSource('[00:01.00]one\n[00:02.00]two\n[00:03.00]three', durationMS: 0);
      doc.applyPlainText('one\nthree');
      expect(doc.lines.map((e) => (e.text, e.startMS)), [('one', 1000), ('three', 3000)]);
    });

    test('words that stayed keep their times, a replaced word takes the old one and an inserted word is untimed', () {
      final doc = debugCreateLyricsDocument()..loadSource('[00:01.00]<00:01.00>hello <00:01.50>big <00:02.00>world<00:02.50>', durationMS: 0);
      doc.applyPlainText('hello small world');
      final line = doc.lines.single;
      expect(line.toJson()['w'], [
        ['hello ', 1000, 1500],
        ['small ', 1500, 2000],
        ['world', 2000, 2500],
      ]);

      line.setText('hello wide small world');
      expect(line.text, 'hello wide small world');
      expect(line.toJson()['w'], [
        ['hello ', 1000, 1500],
        ['wide ', null, null],
        ['small ', 1500, 2000],
        ['world', 2000, 2500],
      ]);
    });
  });

  group('buildParts', () {
    test('a pause between words becomes an empty part and a missing end waits for the next word', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 1000,
              't': 'a b c',
              'w': [
                ['a ', 1000, 1400],
                ['b ', 1600, null],
                ['c', 2000, 2600],
              ],
            },
          ],
        }, durationMS: 0);
      final parts = doc.lines.single.buildParts(1000, 5000);
      expect(_partsOf(parts), [('a ', 1000, 1400), ('', 1400, 1600), ('b ', 1600, 2000), ('c', 2000, 2600)]);
    });

    test('untimed words join the part before them, leading ones start with the line', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 900,
              't': 'so a b',
              'w': [
                ['so ', null, null],
                ['a ', 1000, 1400],
                ['b', null, null],
              ],
            },
          ],
        }, durationMS: 0);
      final parts = doc.lines.single.buildParts(900, 5000);
      expect(_partsOf(parts), [('so ', 900, 1000), ('a b', 1000, 1400)]);
    });

    test('the last word ends at the next line, or a second later without one', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 1000,
              't': 'a b',
              'w': [
                ['a ', 1000, 1400],
                ['b', 1600, null],
              ],
            },
          ],
        }, durationMS: 0);
      final line = doc.lines.single;
      expect(_partsOf(line.buildParts(1000, 3000)).last, ('b', 1600, 3000));
      expect(_partsOf(line.buildParts(1000, null)).last, ('b', 1600, 2600));
    });

    test('a word running past the next one is cut at its start', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 1000,
              't': 'a b',
              'w': [
                ['a ', 1000, 1800],
                ['b', 1600, 2000],
              ],
            },
          ],
        }, durationMS: 0);
      final parts = doc.lines.single.buildParts(1000, null);
      expect(_partsOf(parts), [('a ', 1000, 1600), ('b', 1600, 2000)]);
    });

    test('no timed word means no parts', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 1000,
              't': 'a b',
              'w': [
                ['a ', null, null],
                ['b', null, null],
              ],
            },
          ],
        }, durationMS: 0);
      expect(doc.lines.single.buildParts(1000, null), null);
    });
  });

  group('replaceWord', () {
    test('a timed word spreads its time over the pieces by their length', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 1000,
              't': 'hello world',
              'w': [
                ['hello ', 1000, 2200],
                ['world', 2200, 3000],
              ],
            },
          ],
        }, durationMS: 0);
      doc.replaceWord(0, 0, ['h', 'ello ']);
      final line = doc.lines.single;
      expect(line.toJson()['w'], [
        ['h', 1000, 1200],
        ['ello ', 1200, 2200],
        ['world', 2200, 3000],
      ]);
      expect(line.text, 'hello world');
    });

    test('a word without an end keeps its start on the first piece only', () {
      final doc = debugCreateLyricsDocument()
        ..loadJson({
          'lines': [
            {
              's': 1000,
              't': 'hello world',
              'w': [
                ['hello ', 1000, null],
                ['world', 2200, 3000],
              ],
            },
          ],
        }, durationMS: 0);
      doc.replaceWord(0, 0, ['hel', 'lo ']);
      expect(doc.lines.single.toJson()['w'], [
        ['hel', 1000, null],
        ['lo ', null, null],
        ['world', 2200, 3000],
      ]);
    });
  });

  test('the playing line follows time order and skips untimed lines', () {
    final doc = debugCreateLyricsDocument()
      ..loadJson({
        'lines': [
          {'s': 5000, 't': 'late'},
          {'t': 'untimed'},
          {'s': 1000, 't': 'early'},
        ],
      }, durationMS: 0);
    doc.refreshDerived(durationMS: 0);
    expect(doc.lineIndexAt(500), -1);
    expect(doc.lineIndexAt(995), 2);
    expect(doc.lineIndexAt(4000), 2);
    expect(doc.lineIndexAt(5000), 0);
    expect(doc.lineIndexAt(800), -1);
    expect(doc.nextStartAfter(1000), 5000);
    expect(doc.nextStartAfter(5000), null);
  });

  group('length tag', () {
    test('lyrics stretch to the item duration', () {
      final doc = debugCreateLyricsDocument()..loadSource('[length:00:10.00]\n[00:05.00]a', durationMS: 20000);
      expect(doc.lines.single.startMS, 10000);
    });

    test('an hour long length tag stretches nothing', () {
      final doc = debugCreateLyricsDocument()..loadSource('[length:01:02:03]\n[00:05.00]a', durationMS: 3723000);
      expect(doc.lines.single.startMS, 5000);
    });

    test('lines loaded before the duration is known are stretched once it is, words included', () {
      final doc = debugCreateLyricsDocument()..loadSource('[length:00:10.00]\n[00:05.00]<00:05.00>a <00:06.00>b<00:07.00>', durationMS: 0);
      expect(doc.lines.single.startMS, 5000);
      expect(doc.stretchToDuration(20000), 2.0);
      expect(doc.lines.single.startMS, 10000);
      expect(doc.lines.single.toJson()['w'], [
        ['a ', 10000, 12000],
        ['b', 12000, 14000],
      ]);
      expect(doc.stretchToDuration(20000), null);
      expect(doc.lines.single.startMS, 10000);
    });

    test('a line stamped once the duration is known plays where it was heard', () {
      final doc = debugCreateLyricsDocument()..loadSource('[length:00:10.00]\n[00:01.00]a\n[00:05.00]b', durationMS: 0);
      doc.stretchToDuration(20000);
      doc.stampLine(0, 7000);
      final saved = LrcParser.parse(doc.toLrcText(durationMS: 20000));
      expect(saved.length, '00:20.000');
      expect(_heardStartsMS(saved, 20000), [7000, 10000]);
    });

    test('the length tag is kept only while the duration is unknown, drafts included', () {
      final doc = debugCreateLyricsDocument()..loadSource('[length:00:10.00]\n[00:05.00]a', durationMS: 0);
      final saved = LrcParser.parse(doc.toLrcText(durationMS: 0));
      expect(saved.length, '00:10.00');
      expect(saved.lyrics.single.timestamp, const Duration(seconds: 5));

      final draft = debugCreateLyricsDocument()..loadJson(doc.toJson(), durationMS: 0);
      final savedFromDraft = LrcParser.parse(draft.toLrcText(durationMS: 0));
      expect(savedFromDraft.length, '00:10.00');

      final draftWithDuration = debugCreateLyricsDocument()..loadJson(doc.toJson(), durationMS: 20000);
      final savedFromDraftWithDuration = LrcParser.parse(draftWithDuration.toLrcText(durationMS: 20000));
      expect(savedFromDraftWithDuration.length, '00:20.000');
      expect(savedFromDraftWithDuration.lyrics.single.timestamp, const Duration(seconds: 10));
    });

    test('stretched lines and lyrics without a length tag save the item duration', () {
      final stretched = debugCreateLyricsDocument()..loadSource('[length:00:10.00]\n[00:05.00]a', durationMS: 20000);
      final savedStretched = LrcParser.parse(stretched.toLrcText(durationMS: 20000));
      expect(savedStretched.length, '00:20.000');
      expect(savedStretched.lyrics.single.timestamp, const Duration(seconds: 10));

      final untagged = debugCreateLyricsDocument()..loadSource('[00:05.00]a', durationMS: 0);
      final savedUntagged = LrcParser.parse(untagged.toLrcText(durationMS: 20000));
      expect(savedUntagged.length, '00:20.000');
    });

    test('a length tag without minutes gives no duration', () {
      final model = LyricsModel(lyrics: '[length:325]\n[00:01.00]a', synced: true, isInCache: false, fromInternet: true, isEmbedded: false, file: null);
      expect(model.durationMS, null);
      final valid = LyricsModel(lyrics: '[length:03:20.500]\n[00:01.00]a', synced: true, isInCache: false, fromInternet: true, isEmbedded: false, file: null);
      expect(valid.durationMS, 200500);
    });
  });
}

void _expectSameLyrics(Lrc saved, Lrc original, String name) {
  final singers = original.lyrics.map((e) => e.person).where((person) => person != null && person > 0).toSet();
  final keepsSingers = singers.length > 1;
  expect(saved.lyrics.length, original.lyrics.length, reason: name);
  for (var i = 0; i < original.lyrics.length; i++) {
    final expected = original.lyrics[i];
    final actual = saved.lyrics[i];
    final reason = '$name line $i';
    expect(actual.timestamp, _truncatedToCentiseconds(expected.timestamp), reason: reason);
    expect(_normalized(actual.readableText), _normalized(expected.readableText), reason: reason);
    final expectedPerson = expected.isBGLyrics ? 0 : (keepsSingers ? expected.person : null);
    expect(actual.person, expectedPerson, reason: reason);
    expect(_timedWordsOf(actual), _timedWordsOf(expected), reason: reason);
  }
}

Duration _truncatedToCentiseconds(Duration timestamp) => Duration(milliseconds: timestamp.inMilliseconds ~/ 10 * 10);

/// line starts after the stretch playback applies at [durationMS].
List<int> _heardStartsMS(Lrc lrc, int durationMS) {
  final stretchMultiplier = Lyrics.getStretchMultiplierFor(lrc.length, durationMS);
  return lrc.lyrics.map((e) {
    final startMS = e.timestamp.inMilliseconds;
    return stretchMultiplier == 0 ? startMS : (startMS * stretchMultiplier).round();
  }).toList();
}

String _normalized(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// a word ending before it starts is saved as ending at its start.
List<(String, Duration, Duration)> _timedWordsOf(LrcLine line) {
  final parts = line.parts;
  if (line.type != LrcTypes.enhanced || parts == null) return const [];
  return parts.where((e) => e.lyrics.isNotEmpty).map((e) {
    final start = _truncatedToCentiseconds(e.startTimestamp);
    final endPre = _truncatedToCentiseconds(e.endTimestamp);
    final end = endPre < start ? start : endPre;
    return (e.lyrics, start, end);
  }).toList();
}

List<(String, int, int)> _partsOf(List<LrcLinePart>? parts) {
  return parts!.map((e) => (e.lyrics, e.startTimestamp.inMilliseconds, e.endTimestamp.inMilliseconds)).toList();
}

/// every lyrics & subtitle fixture of the lrc package this app is built with.
Iterable<({String name, Lrc lrc})> _lrcFixtures() sync* {
  final configFile = File(p.join('.dart_tool', 'package_config.json'));
  final config = configFile.readAsJsonSync() as Map;
  final packages = config['packages'] as List;
  final lrcPackage = packages.firstWhere((e) => e['name'] == 'lrc') as Map;
  final packageUri = configFile.absolute.uri.resolve(lrcPackage['rootUri'] as String);
  final fixturesDirectory = Directory(p.join(packageUri.toFilePath(), 'test', 'files'));
  final files = fixturesDirectory.listSync(recursive: true).whereType<File>();
  for (final file in files) {
    final path = file.path;
    final parse = _parserFor(path);
    if (parse == null) continue;
    yield (name: p.basename(path), lrc: parse(file.readLrcStringSync()));
  }
}

Lrc Function(String content)? _parserFor(String path) {
  final extension = p.extension(path);
  return switch (extension) {
    '.lrc' => LrcParser.parse,
    '.xml' || '.ttml' => TtmlParser.parse,
    '.srt' || '.vtt' || '.sbv' || '.ass' => SubtitleParser.parse,
    _ => null,
  };
}
