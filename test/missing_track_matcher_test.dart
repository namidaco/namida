// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/missing_track_matcher.dart';

void main() {
  const fillerPaths = [
    '/storage/emulated/0/Music/Someone Else - Different Track.mp3',
    '/storage/emulated/0/Music/Intro.mp3',
    '/storage/emulated/0/Music/Lemon.flac',
  ];

  String? topSuggestion(String missingPath, String renamedPath, {List<String> otherPaths = const []}) {
    final matcher = MissingTrackMatcher([...fillerPaths, ...otherPaths, renamedPath]);
    return matcher.getSuggestions(missingPath).firstOrNull;
  }

  final renames = <String, (String, String)>{
    'moved to another folder': ('/storage/emulated/0/Old/Artist - Song.mp3', '/storage/emulated/0/Music/Artist - Song.mp3'),
    'other extension': ('/storage/emulated/0/Music/Artist - Song.mp3', '/storage/emulated/0/Music/Artist - Song.flac'),
    'letter case': ('/storage/emulated/0/Music/artist - song.mp3', '/storage/emulated/0/Music/Artist - Song.mp3'),
    'symbols': ('/storage/emulated/0/Music/Artist_-_Song.mp3', '/storage/emulated/0/Music/Artist - Song.mp3'),
    'trailing dot': ('/storage/emulated/0/Music/Artist - Song..mp3', '/storage/emulated/0/Music/Artist - Song.mp3'),
    'accents': ('/storage/emulated/0/Music/Beyoncé - Café.mp3', '/storage/emulated/0/Music/Beyonce - Cafe.mp3'),
    'word added at the end': ('/storage/emulated/0/Music/Artist - Song.mp3', '/storage/emulated/0/Music/Artist - Song (Live).mp3'),
    'track number added': ('/storage/emulated/0/Music/Artist - Song.mp3', '/storage/emulated/0/Music/01. Artist - Song.mp3'),
    'brackets removed': ('/storage/emulated/0/Music/Artist - Song [dQw4w9WgXcQ].mp3', '/storage/emulated/0/Music/Artist - Song.mp3'),
    'brackets changed': ('/storage/emulated/0/Music/Artist - Song (Remastered 2011).mp3', '/storage/emulated/0/Music/Artist - Song (Remaster).mp3'),
    'words removed': ('/storage/emulated/0/Music/Song Title Remastered.mp3', '/storage/emulated/0/Music/Song Title.mp3'),
    'one word changed': ('/storage/emulated/0/Music/Artist - Song ft. Singer.mp3', '/storage/emulated/0/Music/Artist - Song feat. Singer.mp3'),
    'windows path': (r'C:\Users\u\Music\Artist - Song.mp3', '/storage/emulated/0/Music/Artist - Song.mp3'),
    'cjk': ('/storage/emulated/0/Music/米津玄師 - Lemon.mp3', '/storage/emulated/0/Music/米津玄師「Lemon」.mp3'),
    'title only, brackets removed': ('/storage/emulated/0/Music/[113] Lonely [(eto)].mp3', '/storage/emulated/0/Music/Lonely.mp3'),
    'typo fixed': ('/storage/emulated/0/Music/Beyonse - Halo.mp3', '/storage/emulated/0/Music/Beyoncé - Halo.mp3'),
    'plural': ('/storage/emulated/0/Music/Artist - Song.mp3', '/storage/emulated/0/Music/Artist - Songs.mp3'),
    'respelled': ('/storage/emulated/0/Music/The Colour of Love.mp3', '/storage/emulated/0/Music/The Color of Love.mp3'),
    'leading zeros': ('/storage/emulated/0/Music/Track 01 Intor.mp3', '/storage/emulated/0/Music/Track 1 Intro.mp3'),
  };

  group('renames', () {
    for (final e in renames.entries) {
      test(e.key, () {
        final (missingPath, renamedPath) = e.value;
        expect(topSuggestion(missingPath, renamedPath), renamedPath);
      });
    }
  });

  group('no suggestion', () {
    final unrelated = <String, (String, String)>{
      'different song': ('/storage/emulated/0/Music/Artist - Song.mp3', '/storage/emulated/0/Music/Somebody - Other Thing.mp3'),
      'a word inside another word': ('/storage/emulated/0/Music/Love.mp3', '/storage/emulated/0/Music/Glove.mp3'),
      'another part': ('/storage/emulated/0/Music/Artist - Song Part 1.mp3', '/storage/emulated/0/Music/Artist - Song Part 2.mp3'),
      'another part with zeros': ('/storage/emulated/0/Music/Artist - Song Part 10.mp3', '/storage/emulated/0/Music/Artist - Song Part 20.mp3'),
      'one letter of a short name': ('/storage/emulated/0/Music/Love Song.mp3', '/storage/emulated/0/Music/Dove Song.mp3'),
      'short names': ('/storage/emulated/0/Music/Lover.mp3', '/storage/emulated/0/Music/Lovers.mp3'),
      'one shared word of a long name': ('/storage/emulated/0/Music/Artist - Long Song Name Here.mp3', '/storage/emulated/0/Music/Artist - Short.mp3'),
    };
    for (final e in unrelated.entries) {
      test(e.key, () {
        final (missingPath, renamedPath) = e.value;
        expect(topSuggestion(missingPath, renamedPath), null);
      });
    }
  });

  test('same filename in several folders, the one sharing more parent folders comes first', () {
    const missingPath = r'D:\Music\Artist\Album\01.mp3';
    final matcher = MissingTrackMatcher([
      '/storage/emulated/0/Other/01.mp3',
      '/storage/emulated/0/Music/Artist/Album/01.mp3',
      '/storage/emulated/0/Music/Album/01.mp3',
    ]);
    expect(matcher.getSuggestions(missingPath), [
      '/storage/emulated/0/Music/Artist/Album/01.mp3',
      '/storage/emulated/0/Music/Album/01.mp3',
      '/storage/emulated/0/Other/01.mp3',
    ]);
  });

  test('stronger matches come before weaker ones', () {
    const missingPath = '/m/Artist - Song.mp3';
    final matcher = MissingTrackMatcher([
      '/m/Artist - Song (Live).mp3',
      '/m/x/Artist - Song.flac',
      '/m/y/Artist - Song.mp3',
    ]);
    expect(matcher.getSuggestions(missingPath), ['/m/y/Artist - Song.mp3', '/m/x/Artist - Song.flac', '/m/Artist - Song (Live).mp3']);
  });

  test('word matches in the same folder come first, then the ones keeping the title words in order', () {
    const missingPath = '/m/a/Nightcore - Myself & I (Lyrics).mp3';
    final matcher = MissingTrackMatcher([
      '/m/b/Nightcore - Myself & I.mp3',
      '/m/a/Nightcore - If I Lose Myself (Lyrics).mp3',
      '/m/a/Nightcore - Myself & I.mp3',
    ]);
    expect(matcher.getSuggestions(missingPath), [
      '/m/a/Nightcore - Myself & I.mp3',
      '/m/a/Nightcore - If I Lose Myself (Lyrics).mp3',
      '/m/b/Nightcore - Myself & I.mp3',
    ]);
  });

  test('a title only name matches title only names', () {
    final matcher = MissingTrackMatcher(['/m/Lonely.mp3', '/m/Artist - Lonely Road.mp3']);
    expect(matcher.getSuggestions('/m/old/Lonely (Live).mp3'), ['/m/Lonely.mp3']);
  });

  test('same size and duration wins over names', () {
    const missingPath = '/m/Track 01.mp3';
    const fingerprint = (size: 4200000, durationMS: 215000);
    final matcher = MissingTrackMatcher(
      ['/m/new/Track 01.mp3', '/m/Artist - Real Title.mp3'],
      fingerprintsByPath: {
        missingPath: fingerprint,
        '/m/Artist - Real Title.mp3': fingerprint,
        '/m/new/Track 01.mp3': (size: 3100000, durationMS: 215000),
      },
    );
    expect(matcher.getSuggestions(missingPath), ['/m/Artist - Real Title.mp3', '/m/new/Track 01.mp3']);
  });

  test('suggestions are capped', () {
    final paths = List.generate(20, (i) => '/m/$i/Song.mp3');
    final matcher = MissingTrackMatcher(paths);
    expect(matcher.getSuggestions('/old/Song.mp3').length, MissingTrackMatcher.kMaxSuggestions);
  });

  group('one track scan gives the same suggestions as the index', () {
    List<String> scan(String missingPath, Set<String> existingPaths, {MissingTrackFingerprint? fingerprint, List<String> sameFingerprintPaths = const []}) {
      final params = (missingPath: missingPath, existingPaths: existingPaths, fingerprint: fingerprint, sameFingerprintPaths: sameFingerprintPaths);
      return MissingTrackMatcher.scanSuggestions(params);
    }

    for (final e in renames.entries) {
      test(e.key, () {
        final (missingPath, renamedPath) = e.value;
        final existingPaths = {...fillerPaths, renamedPath, '/storage/emulated/0/Other/Artist - Song (Remix).mp3'};
        final indexed = MissingTrackMatcher(existingPaths).getSuggestions(missingPath);
        expect(scan(missingPath, existingPaths), indexed);
      });
    }

    test('loose matches', () {
      const missingPath = '/m/Artist - Song ft. Singer.mp3';
      final existingPaths = {'/m/Artist - Song feat. Singer.mp3', '/m/Lemon.mp3'};
      expect(scan(missingPath, existingPaths), ['/m/Artist - Song feat. Singer.mp3']);
    });

    test('loose matches without the longest word are found too', () {
      const missingPath = '/m/09. Fire Paradise Orqu.mp3';
      final existingPaths = {'/m/a/09. Fire.mp3', '/m/b/09. Paradise.mp3', '/m/Lemon.mp3'};
      expect(scan(missingPath, existingPaths).toSet(), {'/m/a/09. Fire.mp3', '/m/b/09. Paradise.mp3'});
    });

    test('same size and duration', () {
      const fingerprint = (size: 4200000, durationMS: 215000);
      final existingPaths = {'/m/Totally Different.mp3', '/m/Lemon.mp3'};
      final res = scan('/m/Track 01.mp3', existingPaths, fingerprint: fingerprint, sameFingerprintPaths: ['/m/Totally Different.mp3', '/m/gone.mp3']);
      expect(res, ['/m/Totally Different.mp3']);
    });
  });
}
