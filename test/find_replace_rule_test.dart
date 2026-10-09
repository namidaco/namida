// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';

void main() {
  String apply(String value, SmartPlaylistRuleFilterText filter, String find, String replaceWith, {bool matchCase = false}) =>
      debugApplyFindReplace(value, filter: filter, find: find, replaceWith: replaceWith, matchCase: matchCase);

  group('regex', () {
    test('a pattern matching the whole value replaces it once', () {
      expect(apply('Song', .regexMatch, '(.*)', r'$1 (Live)'), 'Song (Live)');
      expect(apply('Song', .regexMatch, r'^(.*)$', r'$1 (Live)'), 'Song (Live)');
    });
    test('an empty match is skipped only right after a match', () {
      expect(apply('baaac', .regexMatch, 'a*', '-'), '-b-c-');
      expect(apply('ab', .regexMatch, 'x*', '-'), '-a-b-');
    });
    test('group references expand and missing groups stay literal', () {
      expect(apply('Artist - Title', .regexMatch, r'(\w+) - (\w+)', r'$2 - $1'), 'Title - Artist');
      expect(apply('a', .regexMatch, '(a)', r'$2'), r'$2');
    });
  });

  group('plain text', () {
    test('matches literally and ignores case unless asked', () {
      expect(apply('Feat. A feat. B', .contains, 'feat.', 'ft.'), 'ft. A ft. B');
      expect(apply('Feat. A feat. B', .contains, 'feat.', 'ft.', matchCase: true), 'Feat. A ft. B');
      expect(apply('Song', .contains, 'Song', r'$1 x'), r'$1 x');
    });
    test('positional filters replace only where they match', () {
      expect(apply('Song', .isSame, 'song', 'Track'), 'Track');
      expect(apply('Song 2', .isSame, 'song', 'Track'), 'Song 2');
      expect(apply('The Song', .startsWith, 'the ', ''), 'Song');
      expect(apply('Song (Live)', .endsWith, ' (live)', ''), 'Song');
    });
    test('negative and presence filters replace the whole value', () {
      expect(apply('Song', .regexNotMatch, 'live', 'Studio'), 'Studio');
      expect(apply('Song (Live)', .regexNotMatch, 'live', 'Studio'), 'Song (Live)');
      expect(apply('', .missing, '', 'Unknown'), 'Unknown');
      expect(apply('Song', .missing, '', 'Unknown'), 'Song');
    });
  });
}
