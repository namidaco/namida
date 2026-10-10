// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensubsonic_api/opensubsonic_api.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  late SplitArtistGenreConfigsWrapper splitConfig;
  const server = 'https://music.example.com/?namida_t=server';

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_server_tracks_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    splitConfig = SplitArtistGenreConfigsWrapper(
      dbPath: '',
      artistsConfig: ArtistsSplitConfig(addFeatArtist: true, separators: const ['&', ',', ';', '//', ' ft. ', ' x '], separatorsBlacklist: const []),
      genresConfig: GenresSplitConfig(separators: const ['&', ',', ';', '//', ' x '], separatorsBlacklist: const []),
      albumConfig: AlbumsSplitConfig(separators: const [';'], separatorsBlacklist: const []),
      generalConfig: GeneralSplitConfig(),
    );
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  TrackExtended reload(TrackExtended trExt) {
    final json = jsonDecode(jsonEncode(trExt.toJsonWithoutPath())) as Map<String, dynamic>;
    return TrackExtended.fromJson(trExt.path, json, splitConfig: splitConfig);
  }

  Map<String, Object?> everythingOf(TrackExtended trExt) => {
    'path': trExt.path,
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
    'bpm': trExt.bpm,
    'chapters': trExt.chapters,
    'json': jsonDecode(jsonEncode(trExt.toJsonWithoutPath())),
  };

  group('jellyfin', () {
    TrackExtended trackOf(Map<String, dynamic> itemJson) => debugJellyfinItemToTrack(itemJson, splitConfig: splitConfig, server: server);

    test('a fully tagged item is the same after a reload, a title feat artist added once', () {
      final fresh = trackOf({
        'Id': 'jf1',
        'Name': 'Song (feat. C)',
        'Type': 'Audio',
        'Artists': ['A', 'B'],
        'AlbumArtist': 'Band',
        'Album': 'First; Second',
        'Genres': ['Rock', 'Pop'],
        'IndexNumber': 3,
        'ParentIndexNumber': 1,
        'ProductionYear': 2019,
        'RunTimeTicks': 1800000000,
        'Container': 'flac',
        'DateCreated': '2024-01-02T03:04:05.000Z',
        'UserData': {'Rating': 8},
        'MediaSources': [
          {'Size': 20000000, 'Bitrate': 900000},
        ],
      });
      expect(fresh.artistsList, ['A', 'B', 'C']);
      expect(fresh.albumsList, ['First', 'Second']);
      expect(fresh.genresList, ['Rock', 'Pop']);
      expect(fresh.hashKey, 'jf1');
      expect(everythingOf(reload(fresh)), everythingOf(fresh));
    });

    test('album artists, composers, label, mbids, gain and stream info are mapped', () {
      final fresh = trackOf({
        'Id': 'jf3',
        'Name': 'California Love',
        'Type': 'Audio',
        'Artists': ['2Pac', 'Dr. Dre'],
        'AlbumArtist': '2Pac',
        'AlbumArtists': [
          {'Name': '2Pac', 'Id': 'a1'},
          {'Name': 'Outlawz', 'Id': 'a2'},
        ],
        'Album': 'All Eyez on Me',
        'ProductionYear': 1996,
        'PremiereDate': '1996-02-13T00:00:00.0000000Z',
        'Overview': 'remastered',
        'Tags': ['west coast', 'classic'],
        'Studios': [
          {'Name': 'Death Row'},
        ],
        'People': [
          {'Name': 'Roger Troutman', 'Type': 'Composer'},
          {'Name': 'Someone', 'Type': 'Producer'},
        ],
        'ProviderIds': {'MusicBrainzAlbum': 'mb-album', 'MusicBrainzAlbumArtist': 'mb-aa'},
        'NormalizationGain': -6.5,
        'MediaStreams': [
          {'Type': 'Audio', 'Codec': 'flac', 'SampleRate': 44100, 'BitDepth': 16, 'Channels': 2, 'Language': 'eng'},
        ],
        'MediaSources': [
          {'Size': 1, 'Bitrate': 1000000, 'Container': 'flac'},
        ],
      });
      expect(fresh.albumArtistsList, ['2Pac', 'Outlawz']);
      expect(fresh.albumArtist, '2Pac; Outlawz');
      expect(fresh.composersList, ['Roger Troutman']);
      expect(fresh.tagsList, ['west coast', 'classic']);
      expect(fresh.label, 'Death Row');
      expect(fresh.comment, 'remastered');
      expect(fresh.yearText, '1996-02-13');
      expect(fresh.year, 1996);
      expect(fresh.albumsIdentifiersWrappers.first.mbAlbumId, 'mb-album');
      expect(fresh.albumsIdentifiersWrappers.first.mbAlbumArtistId, 'mb-aa');
      expect(fresh.gainData?.trackGain, -6.5);
      expect(fresh.sampleRate, 44100);
      expect(fresh.bits, 16);
      expect(fresh.channels, 'stereo');
      expect(fresh.languagesList, isNotEmpty);
      expect(everythingOf(reload(fresh)), everythingOf(fresh));
    });

    test('an item without tags is the same after a reload', () {
      final fresh = trackOf({'Id': 'jf2', 'Name': 'Bare'});
      expect(fresh.artistsList, [UnknownTags.ARTIST]);
      expect(fresh.genresList, [UnknownTags.GENRE]);
      expect(everythingOf(reload(fresh)), everythingOf(fresh));
    });
  });

  group('subsonic', () {
    TrackExtended trackOf(MediaModel media, {AlbumModel? album}) => debugSubsonicMediaToTrack(media, album: album, splitConfig: splitConfig, server: server);

    test('a fully tagged song is the same after a reload', () {
      final fresh = trackOf(
        MediaModel(
          id: 'so1',
          isDir: false,
          title: 'Song (feat. C)',
          album: 'Album',
          artist: 'A & B',
          genre: 'Rock; Pop',
          track: 2,
          year: 2001,
          size: 5000000,
          suffix: 'mp3',
          duration: const Duration(seconds: 200),
          bitRate: 320,
          userRating: 4,
          discNumber: 1,
          created: DateTime.utc(2024, 1, 2),
        ),
      );
      expect(fresh.artistsList, ['A', 'B', 'C']);
      expect(fresh.genresList, ['Rock', 'Pop']);
      expect(everythingOf(reload(fresh)), everythingOf(fresh));
    });

    test('album artist falls back to the album artist of plain subsonic', () {
      const album = AlbumModel(id: 'al1', name: 'All Eyez on Me', artist: '2Pac', songCount: 1, duration: null);
      final fresh = trackOf(
        const MediaModel(id: 'so3', isDir: false, title: 'California Love', artist: '2Pac ft. Dr. Dre', album: 'All Eyez on Me'),
        album: album,
      );
      expect(fresh.albumArtist, '2Pac');
      expect(fresh.albumArtistsList, ['2Pac']);
      expect(fresh.artistsList, ['2Pac', 'Dr. Dre']);
    });

    test('opensubsonic fields win over plain subsonic ones', () {
      const album = AlbumModel(
        id: 'al2',
        name: 'Album',
        artist: 'Various Artists',
        songCount: 1,
        duration: null,
        musicBrainzId: 'mb-album',
        sortName: 'album, the',
        recordLabels: [
          RecordLabelModel(name: 'Label A'),
          RecordLabelModel(name: 'Label B'),
        ],
        releaseTypes: ['album', 'compilation'],
        originalReleaseDate: ItemDateModel(year: 2001, month: 5, day: 7),
      );
      final fresh = trackOf(
        const MediaModel(
          id: 'so4',
          isDir: false,
          title: 'Song',
          album: 'Album',
          artist: 'A & B',
          artists: [
            ArtistRefModel(id: '1', name: 'A & B'),
            ArtistRefModel(id: '2', name: 'C'),
          ],
          displayArtist: 'A & B feat. C',
          albumArtists: [
            ArtistRefModel(id: '3', name: 'AA'),
            ArtistRefModel(id: '4', name: 'BB'),
          ],
          displayAlbumArtist: 'AA & BB',
          genre: 'Rock',
          genres: [
            ItemGenreModel(name: 'Rock'),
            ItemGenreModel(name: 'Pop'),
          ],
          contributors: [
            ContributorModel(
              role: 'composer',
              artist: ArtistRefModel(id: '5', name: 'Comp 1'),
            ),
            ContributorModel(
              role: 'producer',
              artist: ArtistRefModel(id: '6', name: 'Prod'),
            ),
            ContributorModel(
              role: 'composer',
              artist: ArtistRefModel(id: '7', name: 'Comp 2'),
            ),
          ],
          moods: ['Happy', 'Energetic'],
          comment: 'a comment',
          bpm: 128,
          sortName: 'song, the',
          year: 2001,
          bitDepth: 24,
          samplingRate: 96000,
          channelCount: 1,
          replayGain: ReplayGainModel(trackGain: -3.5, albumGain: -4, trackPeak: 0.9),
          userRating: 5,
        ),
        album: album,
      );
      expect(fresh.artistsList, ['A & B', 'C']);
      expect(fresh.originalArtist, 'A & B; C');
      expect(fresh.albumArtistsList, ['AA', 'BB']);
      expect(fresh.genresList, ['Rock', 'Pop']);
      expect(fresh.composersList, ['Comp 1', 'Comp 2']);
      expect(fresh.moodList, ['Happy', 'Energetic']);
      expect(fresh.comment, 'a comment');
      expect(fresh.bpm, 128);
      expect(fresh.sortInfo?.title, 'song, the');
      expect(fresh.sortInfo?.album, 'album, the');
      expect(fresh.albumsIdentifiersWrappers.first.mbAlbumId, 'mb-album');
      expect(fresh.label, 'Label A; Label B');
      expect(fresh.releaseType, 'album; compilation');
      expect(fresh.yearText, '2001-05-07');
      expect(fresh.year, 2001);
      expect(fresh.bits, 24);
      expect(fresh.sampleRate, 96000);
      expect(fresh.channels, 'mono');
      expect(fresh.gainData?.trackGain, -3.5);
      expect(fresh.gainData?.albumGain, -4);
      expect(fresh.gainData?.trackPeak, 0.9);
      expect(fresh.rating, 1.0);
      expect(everythingOf(reload(fresh)), everythingOf(fresh));
    });

    test('album date is ignored when it is not the song year', () {
      const album = AlbumModel(id: 'al3', name: 'Album', songCount: 1, duration: null, releaseDate: ItemDateModel(year: 2001, month: 5, day: 7));
      final fresh = trackOf(
        const MediaModel(id: 'so5', isDir: false, title: 'Song', year: 1999),
        album: album,
      );
      expect(fresh.yearText, '1999');
    });

    test('a song without artist and genre is the same after a reload', () {
      final fresh = trackOf(const MediaModel(id: 'so2', isDir: false, title: 'Bare'));
      expect(fresh.artistsList, [UnknownTags.ARTIST]);
      expect(fresh.genresList, [UnknownTags.GENRE]);
      expect(everythingOf(reload(fresh)), everythingOf(fresh));
    });
  });
}
