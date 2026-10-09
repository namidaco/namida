// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/media_chapter.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  late SplitArtistGenreConfigsWrapper splitConfig;
  final sep = Platform.pathSeparator;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_track_derive_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
    splitConfig = SplitArtistGenreConfigsWrapper(
      dbPath: '',
      artistsConfig: ArtistsSplitConfig(addFeatArtist: true, separators: const ['&', ',', ';', '//', ' ft. ', ' x '], separatorsBlacklist: const []),
      genresConfig: GenresSplitConfig(separators: const ['&', ',', ';', '//', ' x '], separatorsBlacklist: const []),
      albumConfig: SimpleSplitConfig(),
      generalConfig: GeneralSplitConfig(),
    );
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  String pathOf(String filename) => '${dir.path}$sep$filename';

  Future<TrackExtended> index(String path, FTags tags, {bool hasError = false}) async {
    final trExt = await Indexer.convertTagToTrack(
      trackPath: path,
      stats: const FileStatsAdv(creationDateMS: 1600000000000, modifiedMS: 1600000001000, size: 4000000),
      trackInfo: FAudioModel(tags: tags, durationMS: 180000, bitRate: 320, sampleRate: 44100, bits: 16, format: 'mp3', channels: '2', hasError: hasError),
      tryExtractingFromFilename: true,
      onMinDurTrigger: () => null,
      onMinSizeTrigger: () => null,
      onError: (err) => throw StateError(err),
      splittersConfigs: splitConfig,
    );
    return trExt!;
  }

  TrackExtended reload(TrackExtended trExt) {
    final json = jsonDecode(jsonEncode(trExt.toJsonWithoutPath())) as Map<String, dynamic>;
    return TrackExtended.fromJson(trExt.path, json, splitConfig: splitConfig);
  }

  TrackExtended editedFrom(TrackExtended base, FTags tags) => base.copyWithTag(tag: tags, splittersConfigs: splitConfig, generatePathHash: false);

  FTags editTags({
    String? title,
    String? artist,
    String? album,
    String? year,
    String? trackNumber,
    String? discNumber,
    String? discTotal,
    String? lyrics,
    double? ratingPercentage,
  }) => FTags.edit(
    path: '',
    artwork: FArtwork(),
    title: title,
    artist: artist,
    album: album,
    year: year,
    trackNumber: trackNumber,
    discNumber: discNumber,
    discTotal: discTotal,
    lyrics: lyrics,
    ratingPercentage: ratingPercentage,
  );

  FTags fullTags({String title = 'Song (feat. C)', String artist = 'A & B', String album = 'First; Second'}) => FTags(
    path: '',
    artwork: FArtwork(),
    title: title,
    album: album,
    albumArtist: 'Album  Band ',
    artist: artist,
    composer: 'Comp One, Comp Two',
    genre: 'Rock; rock; Pop',
    style: 'Indie',
    trackNumber: '3/12',
    trackTotal: '12',
    discNumber: '1/2',
    discTotal: '2',
    lyrics: 'la la',
    comment: 'nice',
    description: 'desc',
    synopsis: 'syn',
    year: '2019-05-12',
    language: 'eng; jpn',
    lyricist: null,
    djmixer: null,
    mixer: null,
    mood: 'Happy; Calm',
    rating: '80',
    remixer: null,
    tags: 'tag1, tag2',
    tempo: null,
    country: null,
    recordLabel: 'Label',
    releaseType: 'album',
    bpm: 120,
    musicalKey: 'Am',
    mbAlbumId: 'mb-album',
    mbAlbumArtistId: 'mb-album-artist',
    ratingPercentage: 0.8,
    gainData: ReplayGainData.fromMap({'tg': -6.5, 'tp': 0.98}),
    sortInfo: FTagsSortInfo.orNull(title: 'Song', artist: 'A'),
    extraTags: const {'ISRC': 'USX9P0000001'},
    chapters: const [
      MediaChapter(startMS: 0, title: 'Intro'),
      MediaChapter(startMS: 60000, title: 'Verse'),
    ],
  );

  Map<String, Object?> derivedOf(TrackExtended trExt) => {
    'artists': trExt.artistsList,
    'albums': trExt.albumsList,
    'albumArtists': trExt.albumArtistsList,
    'genres': trExt.genresList,
    'styles': trExt.stylesList,
    'moods': trExt.moodList,
    'composers': trExt.composersList,
    'languages': trExt.languagesList,
    'tags': trExt.tagsList,
    'wrappers': trExt.albumsIdentifiersWrappers.map((e) => e.toMap()).toList(),
    'year': trExt.year,
    'yearText': trExt.yearText,
    'trackNo': trExt.trackNo,
    'trackTo': trExt.trackTo,
    'discNo': trExt.discNo,
    'discTo': trExt.discTo,
  };

  Map<String, Object?> everythingOf(TrackExtended trExt) => {
    ...derivedOf(trExt),
    'path': trExt.path,
    'json': jsonDecode(jsonEncode(trExt.toJsonWithoutPath())),
  };

  group('every path derives the same from the same originals', () {
    test('indexing, reloading, editing with all tags and re-splitting agree', () async {
      final path = pathOf('file.mp3');
      final fresh = await index(path, fullTags());

      expect(derivedOf(fresh), {
        'artists': ['A', 'B', 'C'],
        'albums': ['First', 'Second'],
        'albumArtists': ['Album Band'],
        'genres': ['Rock', 'Pop'],
        'styles': ['Indie'],
        'moods': ['Happy', 'Calm'],
        'composers': ['Comp One', 'Comp Two'],
        'languages': hasLength(2),
        'tags': ['tag1', 'tag2'],
        'wrappers': [
          {'album': 'First', 'albumArtist': 'Album Band', 'year': '2019-05-12', 'mbAlbumId': 'mb-album', 'mbAlbumArtistId': 'mb-album-artist'},
          {'album': 'Second', 'albumArtist': 'Album Band', 'year': '2019-05-12', 'mbAlbumId': 'mb-album', 'mbAlbumArtistId': 'mb-album-artist'},
        ],
        'year': 20190512,
        'yearText': '2019-05-12',
        'trackNo': 3,
        'trackTo': 12,
        'discNo': 1,
        'discTo': 2,
      });

      expect(everythingOf(reload(fresh)), everythingOf(fresh));
      expect(everythingOf(fresh.rederive(splitConfig)), everythingOf(fresh));

      final edited = editedFrom(kDummyExtendedTrack.copyWith(path: path, generatePathHash: false), fullTags());
      expect(derivedOf(edited), derivedOf(fresh));
    });

    test('an untagged file takes its title and split artists from the filename', () async {
      final fresh = await index(pathOf('A & B - X (feat. C).mp3'), FTags.edit(path: '', artwork: FArtwork()), hasError: true);
      expect(fresh.title, 'X (feat. C)');
      expect(fresh.artistsList, ['A', 'B', 'C']);
      expect(derivedOf(reload(fresh)), derivedOf(fresh));
    });

    test('tags without title and artist fall back to the filename the same way', () async {
      final fresh = await index(pathOf('A & B - X (feat. C).mp3'), editTags(album: 'Alb'));
      expect(fresh.artistsList, ['A', 'B', 'C']);
      expect(fresh.albumsList, ['Alb']);
      expect(derivedOf(reload(fresh)), derivedOf(fresh));
    });

    test('a file without album gets the unknown album, before and after reload', () async {
      final fresh = await index(pathOf('no album.mp3'), editTags(title: 'T', artist: 'Ar'));
      expect(fresh.albumsList, [UnknownTags.ALBUM]);
      expect(fresh.albumsIdentifiersWrappers.map((e) => e.album), [UnknownTags.ALBUM]);
      expect(derivedOf(reload(fresh)), derivedOf(fresh));
    });

    test('non-breaking space album separators survive a reload', () async {
      final fresh = await index(pathOf('nbsp.mp3'), editTags(title: 'T', artist: 'Ar', album: 'One\u00A0Two'));
      expect(fresh.albumsList, ['One', 'Two']);
      expect(derivedOf(reload(fresh)), derivedOf(fresh));
    });

    test('editing with the same tags as indexing gives the same result, empty values included', () async {
      final path = pathOf('Art - Name.mp3');
      final tags = fullTags(title: '', artist: '', album: '');
      final fresh = await index(path, tags);
      final edited = editedFrom(kDummyExtendedTrack.copyWith(path: path, generatePathHash: false), tags);
      expect(derivedOf(edited), derivedOf(fresh));
      expect(fresh.title, 'Name');
      expect(fresh.artistsList, ['Art']);
    });
  });

  group('stored rows', () {
    test('a legacy single wrapper with cleaned up names is replaced by the real album', () {
      final trExt = TrackExtended.fromJson(
        pathOf('legacy.mp3'),
        {
          'title': 'Live Song',
          'originalArtist': 'AC/DC',
          'album': 'AC/DC: Live!',
          'albumArtist': 'AC/DC',
          'year': 1992,
          'yearText': '1992',
          'albumIdentifierWrapper': {'album': 'AC_DC_ Live_', 'albumArtist': 'AC_DC', 'year': '1992'},
        },
        splitConfig: splitConfig,
      );
      expect(trExt.albumsList, ['AC/DC: Live!']);
      expect(trExt.albumsIdentifiersWrappers.map((e) => e.toMap()), [
        {'album': 'AC/DC: Live!', 'albumArtist': 'AC/DC', 'year': '1992'},
      ]);
    });

    test('a row missing a wrapper for one of its albums gets one per album', () {
      final trExt = TrackExtended.fromJson(
        pathOf('missing.mp3'),
        {
          'originalAlbum': 'First; Second',
          'yearText': '2001',
          'year': 2001,
          'albumsIdentifiersWrappers': [
            {'album': 'First', 'albumArtist': '', 'year': '2001', 'mbAlbumId': 'mb1', 'mbAlbumArtistId': 'mb2'},
          ],
        },
        splitConfig: splitConfig,
      );
      expect(trExt.albumsIdentifiersWrappers.map((e) => e.toMap()), [
        {'album': 'First', 'albumArtist': '', 'year': '2001', 'mbAlbumId': 'mb1', 'mbAlbumArtistId': 'mb2'},
        {'album': 'Second', 'albumArtist': '', 'year': '2001', 'mbAlbumId': 'mb1', 'mbAlbumArtistId': 'mb2'},
      ]);
    });

    test('rows from before year text and wrappers existed still group by their year', () {
      final trExt = TrackExtended.fromJson(pathOf('old.mp3'), {'album': 'Old Album', 'year': 2001, 'duration': 200}, splitConfig: splitConfig);
      expect(trExt.durationMS, 200000);
      expect(trExt.albumsIdentifiersWrappers.map((e) => e.toMap()), [
        {'album': 'Old Album', 'albumArtist': '', 'year': '2001'},
      ]);
    });

    test('an empty row loads with defaults', () {
      final trExt = TrackExtended.fromJson(pathOf('empty.mp3'), {}, splitConfig: splitConfig);
      expect(trExt.artistsList, [UnknownTags.ARTIST]);
      expect(trExt.albumsList, isEmpty);
      expect(trExt.albumsIdentifiersWrappers, isEmpty);
    });
  });

  group('editing only some tags', () {
    test('an edit without year keeps the year text and the album wrappers', () async {
      final fresh = await index(pathOf('partial.mp3'), fullTags());
      for (final tags in [editTags(lyrics: 'new lyrics'), editTags(ratingPercentage: 0.6)]) {
        final edited = editedFrom(fresh, tags);
        expect(edited.yearText, '2019-05-12');
        expect(edited.year, 20190512);
        expect(edited.albumsIdentifiersWrappers, fresh.albumsIdentifiersWrappers);
        expect(edited.artistsList, fresh.artistsList);
        expect(edited.trackNo, 3);
        expect(edited.trackTo, 12);
      }
    });

    test('clearing year, track and disc numbers clears them', () async {
      final fresh = await index(pathOf('clear.mp3'), fullTags());
      final edited = editedFrom(fresh, editTags(year: '', trackNumber: '', discNumber: ''));
      expect(edited.year, 0);
      expect(edited.yearText, '');
      expect(edited.trackNo, 0);
      expect(edited.discNo, 0);
      expect(edited.albumsIdentifiersWrappers.map((e) => e.year), ['', '']);
    });

    test('a new title adds its feat artist like a reindex would', () async {
      final fresh = await index(pathOf('title.mp3'), fullTags());
      final edited = editedFrom(fresh, editTags(title: 'New (feat. D)'));
      expect(edited.artistsList, ['A', 'B', 'D']);
    });

    test('disc total is read when the disc number has none', () async {
      final fresh = await index(pathOf('disc.mp3'), editTags(title: 'T', artist: 'Ar', discNumber: '1', discTotal: '2'));
      expect(fresh.discNo, 1);
      expect(fresh.discTo, 2);
    });
  });

  group('youtube id from the filename', () {
    TrackExtended trackOf(String filename, {String comment = ''}) => kDummyExtendedTrack.copyWith(path: pathOf(filename), comment: comment, generatePathHash: false);

    test('an id in brackets at the end of the filename is read', () {
      final track = trackOf('Title [dQw4w9WgXcQ].m4a');
      expect(track.youtubeLink, 'youtu.be/dQw4w9WgXcQ');
      expect(track.youtubeID, 'dQw4w9WgXcQ');
      expect(trackOf('Artist - Title [-tJYN-eG1zk].opus').youtubeID, '-tJYN-eG1zk');
    });

    test('brackets that are not an exact id at the end are ignored', () {
      for (final filename in ['Title [dQw4w9WgXc].m4a', 'Title [dQw4w9WgXcQQ].m4a', 'Title [dQw4w9WgXcQ] (Live).m4a', 'Title [dQw4w9WgX.Q].m4a', 'Title (dQw4w9WgXcQ).m4a']) {
        expect(trackOf(filename).youtubeLink, '', reason: filename);
      }
    });

    test('11 chars in brackets whose last one can never end an id are ignored', () {
      for (final filename in ['Song [Sped-Up-Mix].mp3', 'Song [Demo-Take-3].mp3', 'Title [dQw4w9WgXcR].m4a']) {
        expect(trackOf(filename).youtubeLink, '', reason: filename);
      }
    });

    test('a filename that is only the id gives no id', () {
      for (final filename in ['dQw4w9WgXcQ.m4a', '_OBlgSz8sSM.webm', 'dQw4w9WgXcQ']) {
        expect(trackOf(filename).youtubeLink, '', reason: filename);
      }
    });

    test('words and counters that fit the id pattern in brackets are not ids', () {
      const names = [
        'Butterflies', 'Bonus_Track', 'Hidden_Song', 'theme_music', 'Love_Me_Now', 'TITLE_THEME', 'Music_Video', //
        'Track_01_04', 'REC00010004', 'VID20240104', 'My_Song_004', '07_Sunrises', '12345678904',
      ];
      for (final name in names) {
        expect(NamidaLinkUtils.extractYoutubeIdInTrailingBrackets('Artist - Title [$name].mp4'), isNull, reason: name);
      }
    });

    test('real ids are read in brackets only, never bare', () {
      const ids = ['dQw4w9WgXcQ', '9bZkp7q19f0', 'lYBUbBu4W08', 'kJQP7kiw5Fk', 'OPf0YbXqDm0', '_OBlgSz8sSM', '-tJYN-eG1zk'];
      for (final id in ids) {
        expect(NamidaLinkUtils.extractYoutubeIdInTrailingBrackets('Artist - Title [$id].m4a'), id);
        expect(NamidaLinkUtils.extractYoutubeIdInTrailingBrackets('$id.webm'), isNull, reason: id);
      }
    });

    test('an embedded link or the v= form keeps priority', () {
      expect(trackOf('Title v=AAAAAAAAAAA [dQw4w9WgXcQ].m4a').youtubeID, 'AAAAAAAAAAA');
      const link = 'https://www.youtube.com/watch?v=BBBBBBBBBBB';
      expect(trackOf('Title [dQw4w9WgXcQ].m4a', comment: link).youtubeLink, link);
    });
  });

  test('year parsing', () {
    final cases = <String?, int?>{
      '2019': 2019,
      '2019-05-12': 20190512,
      '2019-05': 20190501,
      '201905': 20190501,
      '20190512': 20190512,
      '5': 2005,
      '0': null,
      '0000': null,
      '': null,
      null: null,
    };
    for (final e in cases.entries) {
      expect(TrackExtended.enforceYearFormat(e.key), e.value, reason: '${e.key}');
    }
  });

  test('track number parsing', () {
    expect(TrackExtended.parseTrackNumber('3/12'), (3, 12));
    expect(TrackExtended.parseTrackNumber('03'), (3, null));
    expect(TrackExtended.parseTrackNumber('1-2'), (1, 2));
    expect(TrackExtended.parseTrackNumber(''), (null, null));
    expect(TrackExtended.parseTrackNumber(null), null);
  });
}
