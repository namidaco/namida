import 'dart:io';

import 'package:flutter/material.dart' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/subtitle_cue.dart';

void main() {
  test('parses colors, bold & the karaoke split out of a styled cue', () {
    const content = '''
WEBVTT
Style:
::cue(c.colorE23CE7) { color: rgb(226,60,231);
 }
::cue(c.colorFEFEFE) { color: rgb(254,254,254);
 }
##

00:00:23.707 --> 00:00:23.774 position:63% line:0%
<c.colorE23CE7><b>Nee </b></c><c.colorFEFEFE><b>kono sekai ni wa</b></c>

00:00:23.707 --> 00:00:23.774
<c.colorE23CE7><b>You know in this world</b></c>
''';

    final cues = SubtitleCues.parseVTT(content);
    expect(cues, isNotNull);
    expect(cues!.hasStyling, true);
    expect(cues.groups.length, 1);

    final group = cues.groups.first;
    expect(group.start, 23707);
    expect(group.end, 23774);
    expect(group.lines.length, 2);

    final top = group.lines[0];
    expect(top.line, 0.0);
    expect(top.spans.length, 2);
    expect(top.spans[0].text, 'Nee ');
    expect(top.spans[0].color, const Color(0xFFE23CE7));
    expect(top.spans[0].bold, true);
    expect(top.spans[1].text, 'kono sekai ni wa');
    expect(top.spans[1].color, const Color(0xFFFEFEFE));

    final bottom = group.lines[1];
    expect(bottom.line, null); // -- no `line` setting means the default bottom placement
    expect(bottom.plainText, 'You know in this world');
  });

  test('lines outliving each other stay on screen together', () {
    // -- the translation runs far past the karaoke line above it
    const content = '''
WEBVTT

00:00:23.907 --> 00:00:26.343 line:0%
Nee kono sekai ni wa takusan no

00:00:23.907 --> 00:00:31.515
You know in this world

00:00:26.343 --> 00:00:28.000 line:0%
Kanashii koto ga aru keredo
''';

    final cues = SubtitleCues.parseVTT(content)!;

    final both = _groupAt(cues, 24000)!;
    expect(both.lines.length, 2);
    expect(both.lines[0].plainText, 'Nee kono sekai ni wa takusan no');
    expect(both.lines[1].plainText, 'You know in this world');

    final afterTopChanged = _groupAt(cues, 27000)!;
    expect(afterTopChanged.lines.length, 2);
    expect(afterTopChanged.lines[0].plainText, 'Kanashii koto ga aru keredo');
    expect(afterTopChanged.lines[1].plainText, 'You know in this world');

    // -- only the translation is left
    final translationOnly = _groupAt(cues, 29000)!;
    expect(translationOnly.lines.length, 1);
    expect(translationOnly.lines.single.plainText, 'You know in this world');

    expect(_groupAt(cues, 40000), null);
  });

  test('a plain cue carries no styling, the player renders it better', () {
    const content = '''
WEBVTT

00:00:01.000 --> 00:00:02.000
hello there
''';
    final cues = SubtitleCues.parseVTT(content);
    expect(cues, isNotNull);
    expect(cues!.hasStyling, false);
    expect(cues.groups.single.lines.single.plainText, 'hello there');
  });

  test('a real youtube caption file', () {
    final file = File('files/W10RXr9c44Y_.en.vtt');
    if (!file.existsSync()) return;

    final cues = SubtitleCues.parseVTT(file.readAsStringSync())!;
    expect(cues.hasStyling, true);

    // -- segments are contiguous & ordered, the widget scans them incrementally
    for (int i = 1; i < cues.groups.length; i++) {
      expect(cues.groups[i].start >= cues.groups[i - 1].end, true, reason: 'group $i overlaps the previous one');
      expect(cues.groups[i].end > cues.groups[i].start, true);
    }

    // -- the romaji & its translation are re-emitted on separate timings, both must stay on screen
    for (final positionMs in const [24000, 27000, 31000]) {
      final group = _groupAt(cues, positionMs)!;
      expect(group.lines.length, 2, reason: 'at $positionMs');
      expect(group.lines[0].plainText, 'Nee kono sekai ni wa takusan no');
      expect(group.lines[1].plainText, 'You know in this world');
    }

    final next = _groupAt(cues, 32000)!;
    expect(next.lines[0].plainText, 'Shiawase ga arunda ne');
    expect(next.lines[1].plainText, 'There are all kinds of happiness');
  });
}

SubtitleCueGroup? _groupAt(SubtitleCues cues, int positionMs) {
  for (final group in cues.groups) {
    if (group.start <= positionMs && group.end > positionMs) return group;
  }
  return null;
}
