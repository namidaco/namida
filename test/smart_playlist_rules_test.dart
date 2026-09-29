// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

void main() {
  late Directory dir;
  final now = DateTime.now().millisecondsSinceEpoch;
  const dayMS = Duration.millisecondsPerDay;

  final specs = <({String name, String title, List<String> artists, String album, int seconds, double rating, int dateAdded, List<int> listens})>[
    (
      name: 't1',
      title: 'Abba song',
      artists: ['Alpha'],
      album: 'X',
      seconds: 60,
      rating: 0.9,
      dateAdded: now - 150 * dayMS,
      listens: List.generate(10, (i) => now - (10 - i) * dayMS),
    ),
    (name: 't2', title: 'Coldplay tune', artists: ['Alpha'], album: 'X', seconds: 120, rating: 0.8, dateAdded: 0, listens: []),
    (
      name: 't3',
      title: 'Delta',
      artists: ['Beta'],
      album: 'Y',
      seconds: 180,
      rating: 0.0,
      dateAdded: now - 300 * dayMS,
      listens: [now - 30 * dayMS, now - 20 * dayMS, now - 10 * dayMS],
    ),
    (name: 't4', title: 'Bravo', artists: ['Beta', 'Alpha'], album: 'Y', seconds: 240, rating: 0.5, dateAdded: 0, listens: [now - dayMS]),
    (name: 't5', title: '', artists: ['Gamma'], album: 'Z', seconds: 300, rating: 0.7, dateAdded: 0, listens: [now - 2 * dayMS, now - dayMS]),
  ];
  final tracks = <String, Track>{};
  final namesByTrack = <Track, String>{};

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_smart_rules_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';

    for (final s in specs) {
      final path = '${dir.path}${Platform.pathSeparator}${s.name}.mp3';
      final track = Track.explicit(path);
      tracks[s.name] = track;
      namesByTrack[track] = s.name;
      Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
        path: path,
        title: s.title,
        artistsList: s.artists,
        originalArtist: s.artists.join(', '),
        albumsList: [s.album],
        originalAlbum: s.album,
        albumsIdentifiersWrappers: AlbumIdentifierWrapper.fromAlbums(albums: [s.album], albumArtist: '', year: '', mbAlbumId: '', mbAlbumArtistId: ''),
        durationMS: s.seconds * 1000,
        size: s.seconds * 1000,
        rating: s.rating,
        dateAdded: s.dateAdded,
        generatePathHash: false,
      );
      for (final listen in s.listens) {
        HistoryController.inst.topTracksMapListens.value.addElement(track, listen);
      }
    }
    final allTracks = tracks.values.toList();
    Indexer.inst.tracksInfoList.value = allTracks;
    Indexer.inst.mainMapsGroup.fillAll(allTracks, (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Set<String> namesOf(Iterable<Track> result) => result.map((tr) => namesByTrack[tr]!).toSet();

  SmartPlaylist playlistOf(SmartPlaylistRuleBase rule, {SmartPlaylistLimit? limit}) => SmartPlaylist(
    name: 'test',
    creationDate: DateTime.now(),
    joiner: SmartJoiner.and,
    sorts: const [],
    sortReverse: false,
    moods: const [],
    ruleGroups: [
      SmartPlaylistRuleGroup.create(rules: [rule]),
    ],
    limit: limit,
  );

  Set<String> resolve(SmartPlaylistRuleBase rule) => namesOf(playlistOf(rule).resolve());

  SmartPlaylistRuleText textRule(SmartPlaylistRuleFilterText filter, String a, [String? b]) => SmartPlaylistRuleText(
    data: [SmartPlaylistTextDataTokenLiteral(a)],
    data2: b == null ? null : [SmartPlaylistTextDataTokenLiteral(b)],
    filter: filter,
    source: SmartPlaylistRuleFilterTextSource.title,
    enableCleanup: true,
  );

  SmartPlaylistRuleNumber numberRule(
    SmartPlaylistRuleFilterNumberSource source,
    SmartPlaylistRuleFilterNumber filter,
    int value, {
    SmartPlaylistNumberScope scope = SmartPlaylistNumberScope.track,
    SmartPlaylistNumberAggregate aggregate = SmartPlaylistNumberAggregate.sum,
  }) => SmartPlaylistRuleNumber(
    data: value,
    data2: null,
    filter: filter,
    source: source,
    enableCleanup: false,
    scope: scope,
    aggregate: aggregate,
  );

  group('alphabetical text filters', () {
    test('between includes everything starting with the upper bound', () {
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isInBetween, 'A', 'C')), {'t1', 't2', 't4'});
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isInBetween, 'C', 'A')), {'t1', 't2', 't4'});
    });
    test('before/after exclude the bound group and empty values', () {
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isBefore, 'C')), {'t1', 't4'});
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isAfter, 'C')), {'t3'});
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isOutside, 'A', 'C')), {'t3'});
    });
  });

  group('number scopes', () {
    test('artist total tracks', () {
      final rule = numberRule(SmartPlaylistRuleFilterNumberSource.tracksCount, SmartPlaylistRuleFilterNumber.isGreaterThan, 2, scope: SmartPlaylistNumberScope.artist);
      expect(resolve(rule), {'t1', 't2', 't4'});
    });
    test('negative filter matches only when no artist matches', () {
      final rule = numberRule(SmartPlaylistRuleFilterNumberSource.tracksCount, SmartPlaylistRuleFilterNumber.isNotSame, 3, scope: SmartPlaylistNumberScope.artist);
      expect(resolve(rule), {'t3', 't5'});
    });
    test('artist listens sum', () {
      final rule = numberRule(SmartPlaylistRuleFilterNumberSource.totalListens, SmartPlaylistRuleFilterNumber.isSmallerThan, 5, scope: SmartPlaylistNumberScope.artist);
      expect(resolve(rule), {'t3', 't4', 't5'});
    });
    test('album average rating skips unrated tracks', () {
      final rule = numberRule(
        SmartPlaylistRuleFilterNumberSource.rating,
        SmartPlaylistRuleFilterNumber.isGreaterThanOrEq,
        80,
        scope: SmartPlaylistNumberScope.album,
        aggregate: SmartPlaylistNumberAggregate.average,
      );
      expect(resolve(rule), {'t1', 't2'});
    });
    test('never played tracks have 0 listens', () {
      expect(resolve(numberRule(SmartPlaylistRuleFilterNumberSource.totalListens, SmartPlaylistRuleFilterNumber.isSame, 0)), {'t2'});
    });
    test('listens per month', () {
      expect(resolve(numberRule(SmartPlaylistRuleFilterNumberSource.listenRate, SmartPlaylistRuleFilterNumber.isGreaterThan, 1)), {'t1', 't5'});
    });
    test('scoped rules survive a json round trip', () {
      final rule = numberRule(
        SmartPlaylistRuleFilterNumberSource.rating,
        SmartPlaylistRuleFilterNumber.isGreaterThan,
        50,
        scope: SmartPlaylistNumberScope.genre,
        aggregate: SmartPlaylistNumberAggregate.maximum,
      );
      expect(SmartPlaylistRuleBase.fromMap(rule.toMap()), rule);
      final text = textRule(SmartPlaylistRuleFilterText.isInBetween, 'a', 'b');
      expect(SmartPlaylistRuleBase.fromMap(text.toMap()), text);
    });
    test('calculation defaults per source', () {
      final ratingMap = numberRule(SmartPlaylistRuleFilterNumberSource.rating, SmartPlaylistRuleFilterNumber.isGreaterThan, 50, scope: SmartPlaylistNumberScope.album).toMap()
        ..remove('aggregate');
      final rating = SmartPlaylistRuleBase.fromMap(ratingMap) as SmartPlaylistRuleNumber;
      expect(rating.aggregate, SmartPlaylistNumberAggregate.average);
      final listens = SmartPlaylistRuleBase.buildFrom(
        type: SmartPlaylistFilterType.number,
        filter: SmartPlaylistRuleFilterNumber.isGreaterThan,
        source: SmartPlaylistRuleFilterNumberSource.totalListens,
        enableCleanup: false,
        clockOnly: false,
        relativeDuration: null,
      );
      expect((listens as SmartPlaylistRuleNumber).aggregate, SmartPlaylistNumberAggregate.sum);
    });
  });

  group('limit', () {
    final everything = numberRule(SmartPlaylistRuleFilterNumberSource.durationMS, SmartPlaylistRuleFilterNumber.isGreaterThan, 0);

    test('top tracks by most played', () {
      final limit = const SmartPlaylistLimit(amount: 2, unit: SmartPlaylistLimitUnit.tracks, sorts: [SortType.mostPlayed], sortReverse: false);
      final pl = playlistOf(everything, limit: limit);
      expect(pl.resolve().map((tr) => namesByTrack[tr]).toList(), ['t1', 't3']);
      expect(pl.resolveCount(), 2);
    });
    test('duration budget skips tracks that dont fit', () {
      final limit = const SmartPlaylistLimit(amount: 5, unit: SmartPlaylistLimitUnit.minutes, sorts: [SortType.mostPlayed], sortReverse: false);
      final pl = playlistOf(everything, limit: limit);
      expect(namesOf(pl.resolve()), {'t1', 't3'});
      expect(SmartPlaylist.fromMap(pl.toMap()).limit?.toMap(), limit.toMap());
    });
  });
}
