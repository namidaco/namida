// by claude
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/base/tracks_search_wrapper.dart';
import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/core/enums.dart';

void main() {
  final receivePort = ReceivePort();
  tearDownAll(receivePort.close);

  final splitConfig = SplitArtistGenreConfigsWrapper(
    dbPath: '',
    artistsConfig: ArtistsSplitConfig(addFeatArtist: true, separators: const ['&', ',', ';'], separatorsBlacklist: const []),
    genresConfig: GenresSplitConfig(separators: const ['&', ',', ';'], separatorsBlacklist: const []),
    albumConfig: AlbumsSplitConfig(separators: const [';'], separatorsBlacklist: const []),
    generalConfig: GeneralSplitConfig(),
  );

  TracksSearchTrackParams trackOf(String path, {required String title, required String artist, String album = '', String composer = '', FTagsSortInfo? sortInfo}) {
    return (
      title: title,
      artist: artist,
      album: album,
      albumArtist: '',
      genre: '',
      style: '',
      composer: composer,
      multiValues: null,
      sortInfo: sortInfo,
      year: null,
      comment: null,
      description: null,
      lyrics: null,
      moods: null,
      tags: null,
      languages: null,
      networkFolderName: null,
      path: path,
      isVideo: false,
      listensCount: null,
    );
  }

  TracksSearchWrapper wrapperOf(List<TracksSearchTrackParams> tracks) {
    return TracksSearchWrapper.init((
      tracks: tracks,
      splitConfig: splitConfig,
      filters: const [TrackSearchFilter.title, TrackSearchFilter.artist, TrackSearchFilter.album, TrackSearchFilter.composer],
      cleanup: true,
      lyricsCacheDirectory: '',
      lyricsLocations: null,
      listensBoost: 0,
      sendPort: receivePort.sendPort,
    ));
  }

  group('tracks', () {
    final wrapper = wrapperOf([
      trackOf(
        '/a.mp3',
        title: 'ハロー',
        artist: 'ちょこ',
        sortInfo: FTagsSortInfo.orNull(artist: 'Chokottodake'),
      ),
      trackOf('/b.mp3', title: 'ハロー', artist: 'Chokottodake'),
      trackOf(
        '/c.mp3',
        title: '夜に駆ける',
        artist: 'YOASOBI',
        album: '夜',
        sortInfo: FTagsSortInfo.orNull(title: 'Yoru ni Kakeru', album: 'Yoru'),
      ),
      trackOf(
        '/d.mp3',
        title: 'Help',
        artist: 'The Beatles',
        sortInfo: FTagsSortInfo.orNull(artist: 'Beatles, The'),
      ),
      trackOf(
        '/e.mp3',
        title: 'One Last Kiss',
        artist: '宇多田ヒカル',
        sortInfo: FTagsSortInfo.orNull(artist: 'Utada, Hikaru'),
      ),
      trackOf(
        '/f.mp3',
        title: 'Song',
        artist: 'X',
        composer: '久石譲',
        sortInfo: FTagsSortInfo.orNull(composer: 'Hisaishi Joe'),
      ),
    ]);

    test('artist sort tag finds the track', () {
      expect(wrapper.filterIndicesAsList('chokottodake').toSet(), {0, 1});
    });

    test('a sort tag match scores like the same text in its own field', () {
      final withSort = wrapperOf([
        trackOf(
          '/a.mp3',
          title: 'ハロー',
          artist: 'ちょこ',
          sortInfo: FTagsSortInfo.orNull(artist: 'Chokottodake'),
        ),
      ]);
      final withMain = wrapperOf([trackOf('/b.mp3', title: 'ハロー', artist: 'Chokottodake')]);
      expect(withSort.filterSplitByRelevance('chokottodake').bestScore, withMain.filterSplitByRelevance('chokottodake').bestScore);
    });

    test('title, album and composer sort tags', () {
      expect(wrapper.filterIndicesAsList('yoru ni kakeru'), [2]);
      expect(wrapper.filterIndicesAsList('kakeru'), [2]);
      expect(wrapper.filterIndicesAsList('hisaishi'), [5]);
    });

    test('`Last, First` artist sort tag stays one name', () {
      final withSort = wrapperOf([
        trackOf(
          '/e.mp3',
          title: 'One Last Kiss',
          artist: '宇多田ヒカル',
          sortInfo: FTagsSortInfo.orNull(artist: 'Utada, Hikaru'),
        ),
      ]);
      final withMain = wrapperOf([trackOf('/e.mp3', title: 'One Last Kiss', artist: 'Utada Hikaru')]);
      expect(wrapper.filterRelevantIndicesAsList('utada hikaru'), [4]);
      expect(withSort.filterSplitByRelevance('utada hikaru').bestScore, withMain.filterSplitByRelevance('utada hikaru').bestScore);
    });

    test('main fields still match', () {
      expect(wrapper.filterIndicesAsList('夜に駆ける'), [2]);
      expect(wrapper.filterIndicesAsList('beatles'), [3]);
    });

    test('a sort tag never adds up over a field that already matched', () {
      final withSort = wrapperOf([
        trackOf(
          '/d.mp3',
          title: 'Help',
          artist: 'Beatles',
          sortInfo: FTagsSortInfo.orNull(artist: 'Beatles Band'),
        ),
      ]);
      final withoutSort = wrapperOf([trackOf('/d.mp3', title: 'Help', artist: 'Beatles')]);
      expect(withSort.filterSplitByRelevance('beatles').bestScore, withoutSort.filterSplitByRelevance('beatles').bestScore);
    });
  });

  group('keys', () {
    final artists = ['ちょこ', 'Chokolate Band', 'The Beatles'];
    final artistsSorts = {'ちょこ': 'Choko', 'The Beatles': 'Beatles, The'};
    final artistsWrapper = KeysSearchWrapper.init(
      artists,
      title: (a) => a,
      titleSort: (a) => artistsSorts[a],
      weights: (listensCounts: const [0, 0, 0], tracksCounts: const [2, 5, 9]),
      cleanup: true,
    );

    test('exact sort tag ranks above a prefix match', () {
      final r = artistsWrapper.filterRelevantFirst('choko');
      expect(r.results.take(2), ['ちょこ', 'Chokolate Band']);
    });

    test('main title still matches', () {
      expect(artistsWrapper.filter('beatles'), ['The Beatles']);
    });

    final albums = [
      (album: '初恋', albumArtist: '宇多田ヒカル'),
      (album: 'Fantôme', albumArtist: '宇多田ヒカル'),
      (album: 'Pinkerton', albumArtist: 'Weezer'),
    ];
    final albumsSorts = {albums[0]: 'Hatsukoi'};
    final albumArtistsSorts = {albums[0]: 'Utada Hikaru', albums[1]: 'Utada Hikaru'};
    final albumsWrapper = KeysSearchWrapper.init(
      albums,
      title: (a) => a.album,
      subtitle: (a) => a.albumArtist,
      titleSort: (a) => albumsSorts[a],
      subtitleSort: (a) => albumArtistsSorts[a],
      weights: (listensCounts: const [0, 0, 0], tracksCounts: const [14, 12, 10]),
      cleanup: true,
    );

    test('album and album artist sort tags', () {
      expect(albumsWrapper.filter('hatsukoi'), [albums[0]]);
      expect(albumsWrapper.filter('utada').toSet(), {albums[0], albums[1]});
    });
  });
}
