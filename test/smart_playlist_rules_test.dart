// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/language.dart';

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
    Language.inst.update(language: NamidaLanguage.fromCode('en'));

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

  /// not added to the library list, so only tests resolving among them see them.
  Track addTrack(String name, {String title = '', List<String> artists = const [], List<String> genres = const [], int dateAdded = 0, int year = 0, List<int> listens = const []}) {
    final path = '${dir.path}${Platform.pathSeparator}$name.mp3';
    final track = Track.explicit(path);
    namesByTrack[track] = name;
    Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
      path: path,
      title: title,
      artistsList: artists,
      genresList: genres,
      dateAdded: dateAdded,
      year: year,
      generatePathHash: false,
    );
    for (final listen in listens) {
      HistoryController.inst.topTracksMapListens.value.addElement(track, listen);
    }
    return track;
  }

  SmartPlaylist playlistOfGroups(List<SmartPlaylistRuleGroup> groups, {SmartJoiner joiner = SmartJoiner.and, SmartPlaylistLimit? limit}) => SmartPlaylist(
    name: 'test',
    creationDate: DateTime.now(),
    joiner: joiner,
    sorts: const [],
    sortReverse: false,
    moods: const [],
    ruleGroups: groups,
    limit: limit,
  );

  SmartPlaylist playlistOf(SmartPlaylistRuleBase rule, {SmartPlaylistLimit? limit}) => playlistOfGroups(
    [
      SmartPlaylistRuleGroup.create(rules: [rule]),
    ],
    limit: limit,
  );

  Set<String> resolve(SmartPlaylistRuleBase rule) => namesOf(playlistOf(rule).resolve());

  Set<String> resolveAmong(SmartPlaylistRuleBase rule, List<Track> tracks) => namesOf(playlistOf(rule).resolveIterableUnSorted(tracks));

  SmartPlaylistRuleText textRule(
    SmartPlaylistRuleFilterText filter,
    String? data, {
    String? data2,
    SmartPlaylistRuleFilterTextSource source = SmartPlaylistRuleFilterTextSource.title,
    bool enableCleanup = true,
  }) => SmartPlaylistRuleText(
    data: data == null ? null : [SmartPlaylistTextDataTokenLiteral(data)],
    data2: data2 == null ? null : [SmartPlaylistTextDataTokenLiteral(data2)],
    filter: filter,
    source: source,
    enableCleanup: enableCleanup,
  );

  SmartPlaylistRuleText tokensRule(SmartPlaylistRuleFilterText filter, List<SmartPlaylistTextDataToken> tokens, {bool enableCleanup = true}) => SmartPlaylistRuleText(
    data: tokens,
    data2: null,
    filter: filter,
    source: SmartPlaylistRuleFilterTextSource.title,
    enableCleanup: enableCleanup,
  );

  SmartPlaylistRuleDateTime dateRule(
    SmartPlaylistRuleFilterDateTime filter,
    SmartPlaylistRuleFilterDateTimeSource source, {
    DateTime? data,
    DateTime? data2,
    bool clockOnly = false,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleDateTime(
    data: data,
    data2: data2,
    filter: filter,
    source: source,
    enableCleanup: false,
    clockOnly: clockOnly,
    relativeDuration: relativeDuration,
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
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isInBetween, 'A', data2: 'C')), {'t1', 't2', 't4'});
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isInBetween, 'C', data2: 'A')), {'t1', 't2', 't4'});
    });
    test('before/after exclude the bound group and empty values', () {
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isBefore, 'C')), {'t1', 't4'});
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isAfter, 'C')), {'t3'});
      expect(resolve(textRule(SmartPlaylistRuleFilterText.isOutside, 'A', data2: 'C')), {'t3'});
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
      final text = textRule(SmartPlaylistRuleFilterText.isInBetween, 'a', data2: 'b');
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

  group('date filters', () {
    final d1 = DateTime(2024, 1, 1);
    final d2 = DateTime(2024, 6, 1);
    late List<Track> addedTracks;
    late List<Track> listenedTracks;
    late List<Track> clockTracks;

    setUpAll(() {
      addedTracks = [
        addTrack('added_d1', dateAdded: d1.millisecondsSinceEpoch),
        addTrack('added_d2', dateAdded: d2.millisecondsSinceEpoch),
        addTrack('added_mid', dateAdded: DateTime(2024, 3, 15).millisecondsSinceEpoch),
        addTrack('added_before', dateAdded: d1.millisecondsSinceEpoch - 1000),
        addTrack('added_after', dateAdded: d2.millisecondsSinceEpoch + 1000),
        addTrack('added_unknown'),
      ];
      listenedTracks = [
        addTrack('listen_never'),
        addTrack('listen_mixed', listens: [now - 30 * dayMS, now - dayMS]),
        addTrack('listen_old', listens: [now - 30 * dayMS]),
        addTrack('listen_recent', listens: [now - dayMS]),
      ];
      clockTracks = [
        addTrack('clock_2330', listens: [DateTime(2024, 1, 15, 23, 30).millisecondsSinceEpoch]),
        addTrack('clock_0100', listens: [DateTime(2024, 1, 16, 1).millisecondsSinceEpoch]),
        addTrack('clock_1200', listens: [DateTime(2024, 1, 16, 12).millisecondsSinceEpoch]),
        addTrack('clock_2200', listens: [DateTime(2024, 1, 16, 22).millisecondsSinceEpoch]),
        addTrack('clock_0200', listens: [DateTime(2024, 1, 17, 2).millisecondsSinceEpoch]),
        addTrack('clock_0000', listens: [DateTime(2024, 1, 18).millisecondsSinceEpoch]),
      ];
    });

    test('between and before/after include the exact bounds, outside excludes them', () {
      expect(resolveAmong(dateRule(.isInBetween, .dateAdded, data: d1, data2: d2), addedTracks), {'added_d1', 'added_d2', 'added_mid'});
      expect(resolveAmong(dateRule(.isOutside, .dateAdded, data: d1, data2: d2), addedTracks), {'added_before', 'added_after'});
      expect(resolveAmong(dateRule(.isBefore, .dateAdded, data: d1), addedTracks), {'added_before', 'added_d1'});
      expect(resolveAmong(dateRule(.isAfter, .dateAdded, data: d2), addedTracks), {'added_d2', 'added_after'});
      expect(resolveAmong(dateRule(.missing, .dateAdded), addedTracks), {'added_unknown'});
    });

    Set<String> withinThreeDays(SmartPlaylistRuleFilterDateTime filter, SmartPlaylistRuleFilterDateTimeSource source) {
      final rule = dateRule(filter, source, relativeDuration: const SmartPlaylistRelativeDuration(amount: 3, unit: .days));
      return resolveAmong(rule, listenedTracks);
    }

    test('within last excludes never played tracks, not within last includes them', () {
      expect(withinThreeDays(.isWithinLast, .lastListen), {'listen_mixed', 'listen_recent'});
      expect(withinThreeDays(.isNotWithinLast, .lastListen), {'listen_never', 'listen_old'});
    });

    test('a clock only flag left over from a clock range does not break relative filters', () {
      final rule = dateRule(.isWithinLast, .lastListen, clockOnly: true, relativeDuration: const SmartPlaylistRelativeDuration(amount: 3, unit: .days));
      expect(resolveAmong(rule, listenedTracks), {'listen_mixed', 'listen_recent'});
      expect(resolveAmong(rule.copyWith(filter: .isNotWithinLast), listenedTracks), {'listen_never', 'listen_old'});
    });

    test('listen sources check any, all, first or last listen', () {
      expect(withinThreeDays(.isWithinLast, .anyListen), {'listen_mixed', 'listen_recent'});
      expect(withinThreeDays(.isWithinLast, .allListens), {'listen_recent'});
      expect(withinThreeDays(.isWithinLast, .firstListen), {'listen_recent'});
      expect(withinThreeDays(.isNotWithinLast, .anyListen), {'listen_never', 'listen_mixed', 'listen_old'});
    });

    test('clock range crossing midnight, outside is its exact complement', () {
      final between = dateRule(.isInBetween, .lastListen, data: DateTime(0, 1, 1, 22), data2: DateTime(0, 1, 1, 2), clockOnly: true);
      final outside = between.copyWith(filter: .isOutside);
      expect(resolveAmong(between, clockTracks), {'clock_2330', 'clock_0100', 'clock_2200', 'clock_0200', 'clock_0000'});
      expect(resolveAmong(outside, clockTracks), {'clock_1200'});
    });

    test('midnight is a valid clock bound', () {
      final empty = dateRule(.isInBetween, .lastListen, clockOnly: true);
      final rule = empty.copyWith(datas: (empty.textToData('00:00:00'), empty.textToData2('06:00:00')));
      expect(rule.validate(), isNull);
      expect(resolveAmong(rule, clockTracks), {'clock_0100', 'clock_0200', 'clock_0000'});
      final withoutEnd = empty.copyWith(datas: (empty.textToData('00:00:00'), null));
      expect(withoutEnd.validate(), lang.emptyValue);
    });

    test('month and year boundaries clamp the day to the target month', () {
      const oneMonth = SmartPlaylistRelativeDuration(amount: 1, unit: .months);
      expect(oneMonth.getBoundary(DateTime(2026, 3, 31, 15)), DateTime(2026, 2, 28));
      expect(oneMonth.getBoundary(DateTime(2024, 3, 31)), DateTime(2024, 2, 29));
      expect(oneMonth.getBoundary(DateTime(2026, 1, 15)), DateTime(2025, 12, 15));
      expect(const SmartPlaylistRelativeDuration(amount: 14, unit: .months).getBoundary(DateTime(2026, 5, 31)), DateTime(2025, 3, 31));
      expect(const SmartPlaylistRelativeDuration(amount: 1, unit: .years).getBoundary(DateTime(2024, 2, 29)), DateTime(2023, 2, 28));
    });

    test('a relative month boundary matches neither side when hit exactly', () {
      const oneMonth = SmartPlaylistRelativeDuration(amount: 1, unit: .months);
      final boundaryMS = oneMonth.getBoundary(DateTime.now()).millisecondsSinceEpoch;
      final tracks = [
        addTrack('month_before', listens: [boundaryMS - 1]),
        addTrack('month_exact', listens: [boundaryMS]),
        addTrack('month_after', listens: [boundaryMS + 1]),
      ];
      final within = dateRule(.isWithinLast, .lastListen, relativeDuration: oneMonth);
      expect(resolveAmong(within, tracks), {'month_after'});
      expect(resolveAmong(within.copyWith(filter: .isNotWithinLast), tracks), {'month_before'});
    });

    test('dates with sub millisecond parts compare exactly', () {
      final listenMS = DateTime.utc(2024, 1, 15, 12).millisecondsSinceEpoch;
      final tracks = [
        addTrack('subms_at', listens: [listenMS]),
        addTrack('subms_next', listens: [listenMS + 1]),
      ];
      final halfAfter = DateTime.fromMicrosecondsSinceEpoch(listenMS * 1000 + 500);
      expect(resolveAmong(dateRule(.isAfter, .lastListen, data: halfAfter), tracks), {'subms_next'});
      expect(resolveAmong(dateRule(.isBefore, .lastListen, data: halfAfter), tracks), {'subms_at'});
      expect(resolveAmong(dateRule(.isSame, .lastListen, data: halfAfter), tracks), isEmpty);
      expect(resolveAmong(dateRule(.isInBetween, .lastListen, data: DateTime.fromMillisecondsSinceEpoch(listenMS), data2: halfAfter), tracks), {'subms_at'});
    });

    test('any and all listens are decided by the oldest or newest listen', () {
      final d = DateTime.utc(2024, 1, 15, 12);
      final dMS = d.millisecondsSinceEpoch;
      final tracks = [
        addTrack('edges_before', listens: [dMS - 2 * dayMS, dMS - dayMS]),
        addTrack('edges_around', listens: [dMS - dayMS, dMS, dMS + dayMS]),
        addTrack('edges_after', listens: [dMS + dayMS, dMS + 2 * dayMS]),
      ];
      expect(resolveAmong(dateRule(.isAfter, .anyListen, data: d), tracks), {'edges_around', 'edges_after'});
      expect(resolveAmong(dateRule(.isAfter, .allListens, data: d), tracks), {'edges_after'});
      expect(resolveAmong(dateRule(.isBefore, .anyListen, data: d), tracks), {'edges_before', 'edges_around'});
      expect(resolveAmong(dateRule(.isBefore, .allListens, data: d), tracks), {'edges_before'});
    });

    test('any and all listens with unknown or pre 1970 dates check every listen', () {
      final tracks = [
        addTrack('odd_unknown_recent', listens: [0, now - dayMS]),
        addTrack('odd_pre1970_recent', listens: [-5000, now - dayMS]),
        addTrack('odd_pre1970_unknown', listens: [-5000, 0]),
      ];
      Set<String> withinThreeDays(SmartPlaylistRuleFilterDateTime filter, SmartPlaylistRuleFilterDateTimeSource source) {
        final rule = dateRule(filter, source, relativeDuration: const SmartPlaylistRelativeDuration(amount: 3, unit: .days));
        return resolveAmong(rule, tracks);
      }

      expect(withinThreeDays(.isWithinLast, .anyListen), {'odd_unknown_recent', 'odd_pre1970_recent'});
      expect(withinThreeDays(.isWithinLast, .allListens), isEmpty);
      expect(withinThreeDays(.isNotWithinLast, .anyListen), {'odd_unknown_recent', 'odd_pre1970_recent', 'odd_pre1970_unknown'});
      expect(withinThreeDays(.isNotWithinLast, .allListens), {'odd_pre1970_unknown'});
      final beforeEpoch = DateTime.fromMillisecondsSinceEpoch(-10000);
      expect(resolveAmong(dateRule(.isAfter, .allListens, data: beforeEpoch), tracks), {'odd_pre1970_recent'});
      expect(resolveAmong(dateRule(.isBefore, .anyListen, data: DateTime.fromMillisecondsSinceEpoch(-1000)), tracks), {'odd_pre1970_recent', 'odd_pre1970_unknown'});
    });

    test('year rules match every track sharing a year', () {
      final tracks = [
        addTrack('year_1999', year: 1999),
        addTrack('year_2005_a', year: 2005),
        addTrack('year_2005_b', year: 2005),
        addTrack('year_full_date', year: 20240115),
        addTrack('year_unknown'),
      ];
      expect(resolveAmong(dateRule(.isAfter, .year, data: DateTime(2000)), tracks), {'year_2005_a', 'year_2005_b', 'year_full_date'});
      expect(resolveAmong(dateRule(.isInBetween, .year, data: DateTime(2005), data2: DateTime(2024, 1, 15)), tracks), {'year_2005_a', 'year_2005_b', 'year_full_date'});
      expect(resolveAmong(dateRule(.missing, .year), tracks), {'year_unknown'});
    });
  });

  group('text filters', () {
    late List<Track> genreTracks;
    late List<Track> regexTracks;
    late List<Track> tokenTracks;

    setUpAll(() {
      genreTracks = [
        addTrack('genre_multi', genres: ['Rock', 'Pop']),
        addTrack('genre_empty'),
      ];
      regexTracks = [
        addTrack('regex_live', title: 'Song (Live)'),
        addTrack('regex_plain', title: 'Song Live'),
        addTrack('regex_feat', title: 'X feat. Y'),
        addTrack('regex_feat_nodot', title: 'X feat Y'),
        addTrack('regex_accent', title: 'Beyoncé - Halo', artists: ['Beyoncé', 'Jay-Z']),
      ];
      tokenTracks = [
        addTrack('token_alpha', title: 'Alpha - Intro', artists: ['Alpha']),
        addTrack('token_beta', title: 'Beta - Intro', artists: ['Alpha']),
        addTrack('token_intro', title: 'Intro - Alpha', artists: ['Alpha']),
        addTrack('token_mr_big', title: 'Mr. Big - Live', artists: ['Mr. Big']),
        addTrack('token_mrx_big', title: 'MrX Big', artists: ['Mr. Big']),
      ];
    });

    test('multi value sources match when any value does, negations only when none does', () {
      expect(resolve(textRule(.isSame, 'Alpha', source: .artist)), {'t1', 't2', 't4'});
      expect(resolve(textRule(.isNotSame, 'Alpha', source: .artist)), {'t3', 't5'});
      Set<String> genres(SmartPlaylistRuleFilterText filter, [String? data]) => resolveAmong(textRule(filter, data, source: .genre), genreTracks);
      expect(genres(.isSame, 'pop'), {'genre_multi'});
      expect(genres(.isNotSame, 'pop'), {'genre_empty'});
      expect(genres(.contains, 'ro'), {'genre_multi'});
      expect(genres(.notContains, 'ro'), {'genre_empty'});
      expect(genres(.missing), {'genre_empty'});
      expect(genres(.exists), {'genre_multi'});
    });

    test('regex matches the raw or the cleaned text, not matching only when neither does', () {
      Set<String> regex(SmartPlaylistRuleFilterText filter, String pattern, {bool enableCleanup = true}) =>
          resolveAmong(textRule(filter, pattern, enableCleanup: enableCleanup), regexTracks);
      expect(regex(.regexMatch, r'\(live\)'), {'regex_live'});
      expect(regex(.regexMatch, r'feat\.'), {'regex_feat'});
      expect(regex(.regexMatch, 'beyonce'), {'regex_accent'});
      expect(regex(.regexMatch, r'^song live$'), {'regex_live', 'regex_plain'});
      expect(regex(.regexNotMatch, r'\(live\)'), {'regex_plain', 'regex_feat', 'regex_feat_nodot', 'regex_accent'});
      expect(regex(.regexNotMatch, 'beyonce'), {'regex_live', 'regex_plain', 'regex_feat', 'regex_feat_nodot'});
      expect(regex(.regexMatch, r'\(live\)', enableCleanup: false), isEmpty);
      expect(regex(.regexMatch, r'\(Live\)', enableCleanup: false), {'regex_live'});
      expect(regex(.regexMatch, 'beyonce', enableCleanup: false), isEmpty);

      Set<String> artistRegex(SmartPlaylistRuleFilterText filter, String pattern) => resolveAmong(textRule(filter, pattern, source: .artist), regexTracks);
      expect(artistRegex(.regexMatch, r'^beyonce$'), {'regex_accent'});
      expect(artistRegex(.regexMatch, r'^jay-z$'), {'regex_accent'});
      expect(artistRegex(.regexNotMatch, r'^beyonce$'), {'regex_live', 'regex_plain', 'regex_feat', 'regex_feat_nodot'});
    });

    test('source tokens resolve per track, escaped inside regex while literals stay regex', () {
      const artist = SmartPlaylistTextDataTokenSource(.artist);
      const startAnchor = SmartPlaylistTextDataTokenLiteral('^');
      expect(resolveAmong(tokensRule(.contains, [artist]), tokenTracks), {'token_alpha', 'token_intro', 'token_mr_big'});
      expect(resolveAmong(tokensRule(.regexMatch, [artist]), tokenTracks), {'token_alpha', 'token_intro', 'token_mr_big'});
      expect(resolveAmong(tokensRule(.regexMatch, [artist], enableCleanup: false), tokenTracks), {'token_alpha', 'token_intro', 'token_mr_big'});
      expect(resolveAmong(tokensRule(.regexMatch, [startAnchor, artist]), tokenTracks), {'token_alpha', 'token_mr_big'});
    });

    test('regex rules resolving to the same pattern keep their own case sensitivity', () {
      const artist = SmartPlaylistTextDataTokenSource(.artist);
      final lowerCaseTitleTrack = addTrack('token_lower', title: 'alpha - outro', artists: ['Alpha']);
      final tracks = [lowerCaseTitleTrack, ...tokenTracks];
      final group = SmartPlaylistRuleGroup.create(
        rules: [
          tokensRule(.regexMatch, [artist]),
          tokensRule(.regexMatch, [artist], enableCleanup: false),
        ],
      );
      expect(namesOf(playlistOfGroups([group]).resolveIterableUnSorted(tracks)), {'token_alpha', 'token_intro', 'token_mr_big'});
    });
  });

  group('joiners', () {
    test('listens in range count only listens inside the sibling range', () {
      final range = dateRule(.isInBetween, .rangeOnly, data: DateTime.fromMillisecondsSinceEpoch(now - 15 * dayMS), data2: DateTime.fromMillisecondsSinceEpoch(now));
      final count = numberRule(SmartPlaylistRuleFilterNumberSource.totalListensInRange, SmartPlaylistRuleFilterNumber.isGreaterThan, 2);
      final pl = playlistOfGroups([
        SmartPlaylistRuleGroup.create(rules: [count, range]),
      ]);
      expect(namesOf(pl.resolve()), {'t1'});
    });

    test('groups joined with or match either group, with and both groups', () {
      final groups = [
        SmartPlaylistRuleGroup.create(rules: [textRule(.contains, 'abba')]),
        SmartPlaylistRuleGroup.create(rules: [textRule(.isSame, 'Gamma', source: .artist)]),
      ];
      expect(namesOf(playlistOfGroups(groups, joiner: .or).resolve()), {'t1', 't5'});
      expect(namesOf(playlistOfGroups(groups).resolve()), isEmpty);
    });
  });

  group('json', () {
    test('rules survive a round trip', () {
      final rules = <SmartPlaylistRuleBase>[
        dateRule(.isInBetween, .anyListen, data: DateTime(0, 1, 1, 22), data2: DateTime(0, 1, 1, 2), clockOnly: true),
        dateRule(.isWithinLast, .lastListen, relativeDuration: const SmartPlaylistRelativeDuration(amount: 2, unit: .months)),
        SmartPlaylistRuleBoolean(filter: .isUnknown, source: .isLossless, enableCleanup: false),
        SmartPlaylistRuleText(
          data: const [SmartPlaylistTextDataTokenLiteral('feat '), SmartPlaylistTextDataTokenSource(.artist)],
          data2: const [SmartPlaylistTextDataTokenLiteral('z')],
          filter: .isInBetween,
          source: .title,
          enableCleanup: true,
        ),
      ];
      for (final rule in rules) {
        final json = jsonDecode(jsonEncode(rule.toMap()));
        expect(SmartPlaylistRuleBase.fromMap(json), rule);
      }
    });

    test('legacy single sort and plain text data are read', () {
      final pl = SmartPlaylist.fromMap({
        'name': 'legacy',
        'creationDate': 0,
        'joiner': 'and',
        'sort': 'title',
        'sortReverse': false,
        'moods': [],
        'ruleGroups': [
          {
            'joiner': 'and',
            'rules': [
              {'type': 'text', 'filter': 'contains', 'source': 'title', 'data': 'abba', 'enableCleanup': true},
              {
                'type': 'text',
                'filter': 'contains',
                'source': 'title',
                'data': ['Ab', 'ba'],
              },
            ],
          },
        ],
      });
      expect(pl.sorts, [SortType.title]);
      expect(pl.modifiedDate, 0);
      final rules = pl.ruleGroups.single.rules.cast<SmartPlaylistRuleText>();
      expect(rules[0].data, [const SmartPlaylistTextDataTokenLiteral('abba')]);
      expect(rules[1].data, [const SmartPlaylistTextDataTokenLiteral('Ab'), const SmartPlaylistTextDataTokenLiteral('ba')]);
      expect(namesOf(pl.resolve()), {'t1'});
    });

    test('unknown sorts and rules are skipped, keeping the known ones', () {
      final pl = SmartPlaylist.fromMap({
        'name': 'newer',
        'creationDate': 0,
        'joiner': 'and',
        'sorts': ['title', 'futureSort'],
        'sortReverse': false,
        'moods': [],
        'ruleGroups': [
          {
            'joiner': 'and',
            'rules': [
              {'type': 'futureType', 'filter': 'contains', 'source': 'title'},
              {'type': 'text', 'filter': 'futureFilter', 'source': 'title', 'data': 'a'},
              {'type': 'text', 'filter': 'contains', 'source': 'title', 'data': 'abba'},
            ],
          },
        ],
        'limit': {
          'amount': 5,
          'unit': 'tracks',
          'sorts': ['futureSort', 'mostPlayed'],
        },
      });
      expect(pl.sorts, [SortType.title]);
      expect(pl.limit?.sorts, [SortType.mostPlayed]);
      expect(pl.ruleGroups.single.rules, hasLength(1));
      expect(pl.toMap()['sorts'], ['title']);
    });
  });
}
