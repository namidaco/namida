// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/language.dart';

void main() {
  late Directory dir;

  final specs =
      <
        ({
          String name,
          List<String> genres,
          List<String> artists,
          String album,
          String albumArtist,
          List<String> composers,
          List<String> styles,
          String folder,
          int seconds,
        })
      >[
        (name: 'a01', genres: ['Jazz'], artists: ['A1'], album: 'AlbX', albumArtist: 'AA1', composers: ['C1'], styles: ['S1'], folder: 'f1', seconds: 60),
        (name: 'a02', genres: ['Rock'], artists: ['A2'], album: 'AlbY', albumArtist: 'AA2', composers: ['C2'], styles: ['S2'], folder: 'f2', seconds: 120),
        (name: 'a03', genres: ['Jazz', 'Rock'], artists: ['A1', 'A2'], album: 'AlbX', albumArtist: 'AA1', composers: ['C1', 'C2'], styles: ['S1'], folder: 'f1', seconds: 600),
        (name: 'a04', genres: ['Rap'], artists: ['A3'], album: 'AlbZ', albumArtist: 'AA3', composers: ['C3'], styles: ['S3'], folder: 'f3', seconds: 60),
        (name: 'a05', genres: ['Jazz'], artists: ['A3'], album: 'AlbZ', albumArtist: 'AA3', composers: [], styles: [], folder: 'f3', seconds: 60),
        (name: 'a06', genres: [], artists: [UnknownTags.ARTIST], album: '', albumArtist: '', composers: [], styles: [], folder: 'f4', seconds: 60),
        (name: 'a07', genres: [UnknownTags.GENRE], artists: ['A2'], album: 'AlbY', albumArtist: 'AA2', composers: ['C2'], styles: ['S2'], folder: 'f2', seconds: 60),
        (name: 'a08', genres: ['Rock'], artists: ['A2'], album: 'AlbY', albumArtist: 'AA2', composers: ['C2'], styles: ['S2'], folder: 'f2', seconds: 60),
      ];

  final tracks = <String, Track>{};
  final namesByTrack = <Track, String>{};

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_smart_limit_scope_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));

    for (final s in specs) {
      final folderPath = '${dir.path}${Platform.pathSeparator}${s.folder}';
      Directory(folderPath).createSync(recursive: true);
      final path = '$folderPath${Platform.pathSeparator}${s.name}.mp3';
      final track = Track.explicit(path);
      tracks[s.name] = track;
      namesByTrack[track] = s.name;
      Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
        path: path,
        title: s.name,
        artistsList: s.artists,
        originalArtist: s.artists.join(', '),
        genresList: s.genres,
        originalGenre: s.genres.join(', '),
        stylesList: s.styles,
        originalStyle: s.styles.join(', '),
        composer: s.composers.join(', '),
        composersList: s.composers,
        albumArtist: s.albumArtist,
        albumsList: [s.album],
        originalAlbum: s.album,
        albumsIdentifiersWrappers: AlbumIdentifierWrapper.fromAlbums(
          albums: [s.album],
          albumArtist: s.albumArtist,
          year: '',
          mbAlbumId: '',
          mbAlbumArtistId: '',
        ),
        durationMS: s.seconds * 1000,
        size: s.seconds * 1000,
        generatePathHash: false,
      );
    }
    final allTracks = tracks.values.toList();
    Indexer.inst.tracksInfoList.value = allTracks;
    Indexer.inst.mainMapsGroup.fillAll(allTracks, (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  const byTitle = SortChain([SortEntry(SortType.title)]);

  List<Track> tracksOf(List<String> names) => names.map((e) => tracks[e]!).toList();
  List<Track> allTracks() => tracks.values.toList();

  SmartPlaylistLimit limitOf({
    int amount = 100,
    SmartPlaylistLimitUnit unit = SmartPlaylistLimitUnit.tracks,
    SortChain<SortType> sorting = byTitle,
    SmartPlaylistNumberScope? scope,
    int scopeAmount = 1,
  }) => SmartPlaylistLimit(
    amount: amount,
    unit: unit,
    sorting: sorting,
    fromScope: scope == null ? null : SmartPlaylistLimitScope(scope: scope, amount: scopeAmount),
  );

  List<String> select(SmartPlaylistLimit limit, [List<Track>? among]) {
    final result = limit.select(among ?? allTracks());
    expect(limit.selectCount(among ?? allTracks()), result.length, reason: 'selectCount should match select');
    return result.map((tr) => namesByTrack[tr]!).toList();
  }

  group('without a scope', () {
    test('keeps the old behavior', () {
      expect(select(limitOf(amount: 3)), ['a01', 'a02', 'a03']);
      expect(select(limitOf(amount: 100)), ['a01', 'a02', 'a03', 'a04', 'a05', 'a06', 'a07', 'a08']);
      expect(select(limitOf(amount: 4, unit: SmartPlaylistLimitUnit.minutes)), ['a01', 'a02', 'a04']);
    });
  });

  group('from genres', () {
    test('1 genre keeps the tracks of the first track genre', () {
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre)), ['a01', 'a03', 'a05']);
    });

    test('2 genres keeps the tracks of the first 2 genres met', () {
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 2)), ['a01', 'a02', 'a03', 'a05', 'a08']);
    });

    test('the track amount applies after the genre is picked', () {
      expect(select(limitOf(amount: 2, scope: SmartPlaylistNumberScope.genre)), ['a01', 'a03']);
      expect(select(limitOf(amount: 1, scope: SmartPlaylistNumberScope.genre, scopeAmount: 2)), ['a01']);
    });

    test('more genres than exist keeps every tagged track, untagged ones are left out', () {
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 99)), ['a01', 'a02', 'a03', 'a04', 'a05', 'a08']);
    });

    test('a first track with several genres picks them in tag order while there is room', () {
      final among = tracksOf(['a08', 'a05', 'a04', 'a03']);
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre), among), ['a03', 'a05']);
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 2), among), ['a03', 'a05', 'a08']);
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 3), among), ['a03', 'a04', 'a05', 'a08']);
    });

    test('a track kept by a picked genre does not pick its other genres', () {
      final among = tracksOf(['a01', 'a03', 'a04', 'a08']);
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 2), among), ['a01', 'a03', 'a04']);
    });

    test('untagged tracks never pick a genre', () {
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre), tracksOf(['a06', 'a07', 'a08'])), ['a08']);
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre), tracksOf(['a06', 'a07'])), isEmpty);
    });

    test('no tracks gives nothing', () {
      expect(select(limitOf(scope: SmartPlaylistNumberScope.genre), []), isEmpty);
      expect(select(limitOf(unit: SmartPlaylistLimitUnit.minutes, scope: SmartPlaylistNumberScope.genre), []), isEmpty);
    });

    test('the order decides the genre', () {
      const byTitleReversed = SortChain([SortEntry(SortType.title)], reverse: true);
      expect(select(limitOf(sorting: byTitleReversed, scope: SmartPlaylistNumberScope.genre)), ['a08', 'a03', 'a02']);
    });
  });

  group('with a duration budget', () {
    test('tracks of other genres are skipped without using the budget', () {
      expect(select(limitOf(amount: 5, unit: SmartPlaylistLimitUnit.minutes, scope: SmartPlaylistNumberScope.genre)), ['a01', 'a05']);
    });

    test('a track too long for the budget does not pick its genre', () {
      const longestFirst = SortChain([SortEntry(SortType.duration)], reverse: true);
      final limit = limitOf(
        amount: 5,
        unit: SmartPlaylistLimitUnit.minutes,
        sorting: longestFirst,
        scope: SmartPlaylistNumberScope.genre,
      );
      final picked = select(limit);
      expect(picked.first, 'a02');
      expect(picked.toSet(), {'a02', 'a08'});
    });
  });

  group('every scope', () {
    final expectedFirstPicks = <SmartPlaylistNumberScope, Set<String>>{
      SmartPlaylistNumberScope.album: {'a01', 'a03'},
      SmartPlaylistNumberScope.artist: {'a01', 'a03'},
      SmartPlaylistNumberScope.albumArtist: {'a01', 'a03'},
      SmartPlaylistNumberScope.composer: {'a01', 'a03'},
      SmartPlaylistNumberScope.genre: {'a01', 'a03', 'a05'},
      SmartPlaylistNumberScope.style: {'a01', 'a03'},
      SmartPlaylistNumberScope.folder: {'a01', 'a03'},
      SmartPlaylistNumberScope.track: {'a01'},
    };
    for (final scope in SmartPlaylistNumberScope.values) {
      test('1 ${scope.name} keeps the tracks sharing the first one', () {
        expect(select(limitOf(scope: scope)).toSet(), expectedFirstPicks[scope]);
      });
    }

    test('untagged values are skipped for every tag scope', () {
      const byTitleReversed = SortChain([SortEntry(SortType.title)], reverse: true);
      final unknownFirst = tracksOf(['a04', 'a06']);
      final tagScopes = [
        SmartPlaylistNumberScope.album,
        SmartPlaylistNumberScope.artist,
        SmartPlaylistNumberScope.albumArtist,
        SmartPlaylistNumberScope.composer,
        SmartPlaylistNumberScope.genre,
        SmartPlaylistNumberScope.style,
      ];
      for (final scope in tagScopes) {
        expect(select(limitOf(sorting: byTitleReversed, scope: scope), unknownFirst), ['a04'], reason: scope.name);
      }
      expect(select(limitOf(sorting: byTitleReversed, scope: SmartPlaylistNumberScope.folder), unknownFirst), ['a06'], reason: 'folders are never unknown');
    });

    test('2 artists, the first track with 2 artists fills both', () {
      final among = tracksOf(['a03', 'a04', 'a05', 'a08']);
      expect(select(limitOf(scope: SmartPlaylistNumberScope.artist, scopeAmount: 2), among), ['a03', 'a08']);
    });

    test('2 folders', () {
      expect(select(limitOf(scope: SmartPlaylistNumberScope.folder, scopeAmount: 2)), ['a01', 'a02', 'a03', 'a07', 'a08']);
    });
  });

  group('inside a smart playlist', () {
    final everything = SmartPlaylistRuleNumber(
      data: 0,
      data2: null,
      filter: SmartPlaylistRuleFilterNumber.isGreaterThan,
      source: SmartPlaylistRuleFilterNumberSource.durationMS,
      enableCleanup: true,
    );

    SmartPlaylist playlistOf(SmartPlaylistLimit limit, {SortChain<SortType> sorting = const SortChain([])}) => SmartPlaylist(
      name: 'test',
      creationDate: DateTime(2026),
      joiner: SmartJoiner.and,
      sorting: sorting,
      moods: const [],
      ruleGroups: [
        SmartPlaylistRuleGroup.create(rules: [everything]),
      ],
      limit: limit,
    );

    List<String> namesOf(List<Track> result) => result.map((tr) => namesByTrack[tr]!).toList();

    test('resolve and its count agree', () {
      final pl = playlistOf(limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 2));
      final resolved = namesOf(pl.resolve());
      expect(resolved, ['a01', 'a02', 'a03', 'a05', 'a08']);
      expect(pl.resolveCount(), resolved.length);
    });

    test('the playlist sorting applies after the limit', () {
      const byTitleReversed = SortChain([SortEntry(SortType.title)], reverse: true);
      final pl = playlistOf(limitOf(scope: SmartPlaylistNumberScope.genre), sorting: byTitleReversed);
      expect(namesOf(pl.resolve()), ['a05', 'a03', 'a01']);
    });

    test('random (daily) picks one genre and keeps it between resolves', () {
      const daily = SortChain([SortEntry(SortType.shuffleDaily)]);
      final pl = playlistOf(limitOf(sorting: daily, scope: SmartPlaylistNumberScope.genre));
      final first = pl.resolve();
      final second = pl.resolve();
      expect(namesOf(first), namesOf(second));
      expect(first, isNotEmpty);
      final sharedGenres = first.map((tr) => tr.toTrackExt().genresList.toSet()).reduce((a, b) => a.intersection(b));
      expect(sharedGenres, isNotEmpty);
      final pickedGenre = sharedGenres.first;
      final allOfGenre = allTracks().where((tr) => tr.toTrackExt().genresList.contains(pickedGenre)).toSet();
      expect(first.toSet(), allOfGenre);
    });

    test('each resolve starts with no picked values', () {
      final limit = limitOf(scope: SmartPlaylistNumberScope.genre);
      expect(select(limit), select(limit));
      expect(select(limit, tracksOf(['a02', 'a08'])), ['a02', 'a08']);
    });
  });

  group('saving', () {
    test('saved and read back', () {
      final limit = limitOf(amount: 50, scope: SmartPlaylistNumberScope.artist, scopeAmount: 3);
      final map = limit.toMap();
      expect(map['from'], {'scope': 'artist', 'amount': 3});
      final restored = SmartPlaylistLimit.fromMapNullable(map)!;
      expect(restored.fromScope?.scope, SmartPlaylistNumberScope.artist);
      expect(restored.fromScope?.amount, 3);
      expect(restored.toMap(), map);
    });

    test('inside a saved smart playlist', () {
      final pl = SmartPlaylist(
        name: 'x',
        creationDate: DateTime(2026),
        joiner: SmartJoiner.and,
        sorting: const SortChain([]),
        moods: const [],
        ruleGroups: const [],
        limit: limitOf(scope: SmartPlaylistNumberScope.genre, scopeAmount: 2),
      );
      final restored = SmartPlaylist.fromMap(pl.toMap());
      expect(restored.limit?.toMap(), pl.limit?.toMap());
      expect(restored.copyWith(moods: ['m']).limit?.fromScope?.amount, 2);
    });

    test('no scope saves no key, older limits load without one', () {
      final limit = limitOf();
      expect(limit.toMap().containsKey('from'), false);
      expect(SmartPlaylistLimit.fromMapNullable({'amount': 5, 'unit': 'tracks'})?.fromScope, null);
    });

    test('broken values load as no scope, the limit itself is kept', () {
      final brokenValues = <dynamic>[
        'genre',
        1,
        [],
        {},
        {'scope': 'nope', 'amount': 1},
        {'scope': 'genre'},
        {'scope': 'genre', 'amount': 0},
        {'scope': 'genre', 'amount': -2},
        {'scope': 'genre', 'amount': '1'},
        {'scope': 'genre', 'amount': 1.5},
        {'amount': 1},
      ];
      for (final broken in brokenValues) {
        final limit = SmartPlaylistLimit.fromMapNullable({'amount': 5, 'unit': 'tracks', 'from': broken});
        expect(limit, isNotNull, reason: '$broken');
        expect(limit!.amount, 5, reason: '$broken');
        expect(limit.fromScope, null, reason: '$broken');
      }
    });

    test('copyWith keeps the scope', () {
      final limit = limitOf(scope: SmartPlaylistNumberScope.album, scopeAmount: 4);
      final copy = limit.copyWith(amount: 7, unit: SmartPlaylistLimitUnit.hours, sorting: const SortChain([SortEntry(SortType.mostPlayed)]));
      expect(copy.fromScope?.scope, SmartPlaylistNumberScope.album);
      expect(copy.fromScope?.amount, 4);
      expect(copy.amount, 7);
    });
  });

  group('text', () {
    test('shows the scope with its count', () {
      expect(limitOf(amount: 50, scope: SmartPlaylistNumberScope.genre).toText(), contains('1 Genre'));
      expect(limitOf(amount: 50, scope: SmartPlaylistNumberScope.genre, scopeAmount: 2).toText(), contains('2 Genres'));
      expect(limitOf(amount: 50, scope: SmartPlaylistNumberScope.albumArtist, scopeAmount: 3).toText(), contains('3 Album Artists'));
      expect(limitOf(amount: 50).toText().split(' • ').length, 2);
      expect(limitOf(amount: 50, scope: SmartPlaylistNumberScope.genre).toText().split(' • ').length, 3);
    });
  });
}
