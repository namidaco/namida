import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:dart_extensions/dart_extensions.dart';
import 'package:lrc/lrc.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/lyrics_parser/parser_smart.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

export 'package:dart_extensions/dart_extensions.dart';
export 'package:youtipie/youtipie.dart' show YTStringUtils;

extension TracksSelectableUtils on Iterable<Selectable> {
  String get displayTrackKeyword => length.displayTrackKeyword;

  List<Track> toImageTracks([int? limit = 4]) {
    final l = <Track>[];
    String previousArtwork = '';
    bool sameArtwork = true;
    try {
      for (final Selectable p in withLimit(limit)) {
        final currentArtwork = p.track.pathToImage;
        if (sameArtwork && previousArtwork != '' && currentArtwork != previousArtwork) {
          sameArtwork = false;
        }
        l.add(p.track);
        previousArtwork = currentArtwork;
      }
    } catch (_) {}
    if (l.isEmpty) return [];
    if (sameArtwork) return [l.first];
    return l;
  }

  List<String> toImagePaths([int? limit = 4]) {
    return toImageTracks(limit).map((e) => e.pathToImage).toList();
  }
}

extension TracksWithDatesUtilsIterable on Iterable<Selectable> {
  int get totalDurationInMS => fold(0, (previousValue, element) => previousValue + element.track.durationMS);
  String get totalDurationFormatted {
    return (totalDurationInMS ~/ 1000).secondsFormatted;
  }
}

extension TracksWithDatesUtils on List<Selectable> {
  int getTotalListenCount() {
    int total = 0;
    for (final twd in this) {
      final e = twd.track;
      final c = HistoryController.inst.topTracksMapListens.value[e]?.length ?? 0;
      total += c;
    }
    return total;
  }

  int? getFirstListen() {
    int? generalFirstListen;
    for (final twd in this) {
      final e = twd.track;
      final firstListen = HistoryController.inst.topTracksMapListens.value[e]?.firstOrNull;
      if (firstListen != null && (generalFirstListen == null || firstListen < generalFirstListen)) {
        generalFirstListen = firstListen;
      }
    }
    return generalFirstListen;
  }

  int? getLatestListen() {
    int? generalLastListen;
    for (final twd in this) {
      final e = twd.track;
      final lastListen = HistoryController.inst.topTracksMapListens.value[e]?.lastOrNull;
      if (lastListen != null && (generalLastListen == null || lastListen > generalLastListen)) {
        generalLastListen = lastListen;
      }
    }
    return generalLastListen;
  }

  int? getDateAddedEffective() {
    if (isEmpty) return null;
    int best = first.track.dateAdded;

    for (final e in this) {
      final track = e.track;
      final dateAdded = track.dateAdded;
      if (dateAdded < best && dateAdded > _minimumFileDateMilli) best = dateAdded;
    }

    return best;
  }

  int? getDateModifiedEffective() {
    if (isEmpty) return null;
    int best = first.track.dateModified;

    for (final e in this) {
      final track = e.track;
      final dateModified = track.dateModified;
      best = dateModified > best ? dateModified : best;
    }

    return best;
  }

  String get totalSizeFormatted {
    int size = 0;
    for (final s in this) {
      size += s.track.size;
    }
    return size.fileSizeFormatted;
  }

  double getAverageBpm() {
    if (isEmpty) return 0.0;

    int totalBPM = 0;
    for (final s in this) {
      totalBPM += s.track.bpm ?? 0;
    }
    return totalBPM / this.length;
  }

  String getAverageBpmFormatted() {
    final avgBpm = this.getAverageBpm();
    if (avgBpm <= 0) return '';
    return '$avgBpm BPM';
  }
}

extension TracksUtils on List<Track> {
  Set<AlbumIdentifierWrapper> toUniqueAlbums() {
    final tracks = this;
    final albums = <AlbumIdentifierWrapper>{};
    for (var t in tracks) {
      t.albumsIdentifiersModified.forEach(albums.add);
    }
    return albums;
  }

  int get yearOldest {
    int oldest = 0;
    int oldestAsyyyyMMdd = 0;
    for (int i = 0; i < length; i++) {
      final y = this[i].year;
      if (y == 0) continue;
      final asyyyyMMdd = y < 10000 ? y * 10000 + 101 : y;
      if (oldest == 0 || asyyyyMMdd < oldestAsyyyyMMdd) {
        oldest = y;
        oldestAsyyyyMMdd = asyyyyMMdd;
      }
    }
    return oldest;
  }

  String get yearPreferyyyyMMdd {
    if (isEmpty) return '';
    for (int i = length - 1; i >= 0; i--) {
      final y = this[i].yearPreferyyyyMMdd;
      if (y != '') return y;
    }
    return '';
  }

  /// should be upgraded to check if image file exist, but performance...
  String get pathToImage {
    if (isEmpty) return '';
    return this[indexOfImage].pathToImage;
  }

  Track? get trackOfImage {
    if (isEmpty) return null;
    return this[indexOfImage];
  }

  int get indexOfImage => 0;

  Track get firstTrackWithImage {
    if (isEmpty) return kDummyTrack;
    return this[indexOfImage];
  }

  String _firstNonEmpty(String Function(Track e) resolver) {
    if (isEmpty) return '';
    for (final item in this) {
      final p = resolver(item);
      if (p.isNotEmpty) return p;
    }
    return '';
  }

  String get originalAlbum => _firstNonEmpty((e) => e.originalAlbum);

  String get albumArtist {
    if (isEmpty) return '';

    // -- set this to null to mark as invalid
    List<String>? cumulativeArtists = this[0].artistsList;
    // -- lists are borrowed from tracks, copy before the first in-place intersection
    bool cumulativeOwned = false;
    for (var i = 0; i < length; i++) {
      final e = this[i];
      final aa = e.albumArtist;
      if (aa.isNotEmpty) return aa;

      if (cumulativeArtists != null) {
        final currentArtists = this[i].artistsList;
        if (currentArtists.length == 1) {
          // -- just some performance optimizations (benchmarks 30us -> 2us)
          final singleArtistCurrent = currentArtists[0];
          if (cumulativeArtists.length == 1) {
            if (singleArtistCurrent != cumulativeArtists[0]) {
              cumulativeArtists = null;
            }
          } else {
            if (cumulativeArtists.contains(singleArtistCurrent)) {
              cumulativeArtists = currentArtists;
              cumulativeOwned = false;
            } else {
              cumulativeArtists = null;
            }
          }
        } else {
          if (!cumulativeOwned) {
            cumulativeArtists = List<String>.of(cumulativeArtists, growable: true);
            cumulativeOwned = true;
          }
          cumulativeArtists.retainWhere(currentArtists.contains);
          if (cumulativeArtists.isEmpty) {
            cumulativeArtists = null;
          }
        }
      }
    }

    // -- return common artists as an album artist if all tracks has the same one.
    return cumulativeArtists?.join(', ') ?? '';
  }

  String get originalArtist => _firstNonEmpty((e) => e.originalArtist);
  String get originalGenre => _firstNonEmpty((e) => e.originalGenre);
  String get composer => _firstNonEmpty((e) => e.composer);
  String get recordLabel => _firstNonEmpty((e) => e.label);
  String get releaseType => _firstNonEmpty((e) => e.releaseType);

  String get albumSort => _firstNonEmpty((e) => e.sortInfo?.album ?? '');
  String get albumArtistSort => _firstNonEmpty((e) => e.sortInfo?.albumArtist ?? '');
  String get artistSort => _firstNonEmpty((e) => e.sortInfo?.artist ?? '');
  String get composerSort => _firstNonEmpty((e) => e.sortInfo?.composer ?? '');
}

extension StringListJoiner on Iterable<String?> {
  String joinText({String separator = ' • '}) {
    return where((element) => element != null && element != '').join(separator);
  }
}

final _sharedRandom = math.Random();

extension ListieListieUtils<T> on List<T> {
  T get random {
    final index = _sharedRandom.nextInt(length);
    return this[index];
  }

  List<T> getRandomSample(int sampleCount, [math.Random? random]) {
    final list = this;
    if (list.isEmpty) return list;

    final totalLength = list.length;

    random ??= math.Random();

    if (sampleCount >= totalLength) {
      final copy = List<T>.from(list);
      copy.shuffle(random);
      return copy;
    }

    final selectedIndices = <int>{};
    final selectedItems = <T>[];

    for (var i = totalLength - sampleCount; i < totalLength; i++) {
      final t = random.nextInt(i + 1);
      final indexToSelect = selectedIndices.contains(t) ? i : t;
      final item = list[indexToSelect];
      selectedIndices.add(indexToSelect);
      selectedItems.add(item);
    }

    return selectedItems;
  }

  List<T> getRandomSampleWhere(int sampleCount, bool Function(T item) test, [math.Random? random]) {
    final list = this;
    if (list.isEmpty) return list;

    final totalLength = list.length;

    random ??= math.Random();

    if (sampleCount >= totalLength) {
      final copy = List<T>.from(list.where(test));
      copy.shuffle(random);
      return copy;
    }

    final selectedIndices = <int>{};
    final selectedItems = <T>[];

    int attempts = 0;
    final maxAttempts = totalLength;

    for (var i = totalLength - sampleCount; i < totalLength && attempts < maxAttempts;) {
      final t = random.nextInt(i + 1);
      final indexToSelect = selectedIndices.contains(t) ? i : t;
      final item = list[indexToSelect];
      attempts++;
      if (test(item)) {
        selectedIndices.add(indexToSelect);
        selectedItems.add(item);
        i++;
      }
    }

    return selectedItems;
  }

  List<List<T>> split([int parts = 2]) {
    final mainList = this;
    if (parts > mainList.length) parts = mainList.length;
    final finalParts = List.generate(parts, (_) => <T>[]);
    for (int partIndex = 0; partIndex < parts; partIndex++) {
      for (int i = partIndex; i < mainList.length; i += parts) {
        finalParts[partIndex].add(mainList[i]);
      }
    }
    return finalParts;
  }
}

/// Decorate-sort-undecorate (schwartzian transform).
///
/// [sortBy] & friends from `dart_extensions` evaluate the key extractor on *every* comparison,
/// i.e `2 * n * log(n)` times. these evaluate it exactly `n` times, which matters a lot when
/// the key costs an allocation (`toLowerCase()`, `join()`, `ignoreCommonPrefixes()`) or a lookup
/// over a sublist (`getTotalListenCount()`, `getDateAddedEffective()`).
///
/// by claude
extension ListiePrecomputedSortUtils<E> on List<E> {
  /// below this the extra lists cost more than the saved key evaluations.
  static const _minLengthToPrecompute = 16;

  void sortByPrecomputed(Comparable Function(E e) key, {bool reverse = false}) {
    final length = this.length;
    if (length < 2) return;
    if (length < _minLengthToPrecompute) {
      sort(reverse ? (a, b) => key(b).compareTo(key(a)) : (a, b) => key(a).compareTo(key(b)));
      return;
    }
    final keys = List<Comparable>.generate(length, (i) => key(this[i]), growable: false);
    _applySortedOrder(_sortedIndicesOf(length, (a, b) => keys[a].compareTo(keys[b]), reverse));
  }

  void sortByAltsPrecomputed(List<Comparable Function(E e)> alternatives, {bool reverse = false}) {
    final alternativesLength = alternatives.length;
    if (alternativesLength == 0) return;
    if (alternativesLength == 1) return sortByPrecomputed(alternatives[0], reverse: reverse);

    final length = this.length;
    if (length < 2) return;
    if (length < _minLengthToPrecompute) {
      int compareItems(E a, E b) {
        for (int i = 0; i < alternativesLength; i++) {
          final compare = alternatives[i](a).compareTo(alternatives[i](b));
          if (compare != 0) return compare;
        }
        return 0;
      }

      sort(reverse ? (a, b) => compareItems(b, a) : compareItems);
      return;
    }

    final keys = List<List<Comparable>>.generate(
      alternativesLength,
      (alternativeIndex) {
        final key = alternatives[alternativeIndex];
        return List<Comparable>.generate(length, (i) => key(this[i]), growable: false);
      },
      growable: false,
    );

    _applySortedOrder(
      _sortedIndicesOf(length, (a, b) {
        for (int i = 0; i < alternativesLength; i++) {
          final key = keys[i];
          final compare = key[a].compareTo(key[b]);
          if (compare != 0) return compare;
        }
        return 0;
      }, reverse),
    );
  }

  /// Returns a new sorted list, keeping items that compare equal in their original order.
  ///
  /// [sort] & friends are not stable, which ruins lists where a lot of items share the same key,
  /// ex. youtube dates parsed from `2 months ago` texts, where a whole month collapses into one value.
  List<E> sortedByPrecomputed(Comparable Function(E e) key, {bool reverse = false}) {
    final length = this.length;
    if (length < 2) return List<E>.of(this, growable: false);

    final keys = List<Comparable>.generate(length, (i) => key(this[i]), growable: false);
    final indices = List<int>.generate(length, (i) => i, growable: false);
    indices.sort(
      reverse
          ? (a, b) {
              final compare = keys[b].compareTo(keys[a]);
              return compare != 0 ? compare : a - b;
            }
          : (a, b) {
              final compare = keys[a].compareTo(keys[b]);
              return compare != 0 ? compare : a - b;
            },
    );
    return List<E>.generate(length, (i) => this[indices[i]], growable: false);
  }

  static List<int> _sortedIndicesOf(int length, int Function(int a, int b) compare, bool reverse) {
    final indices = List<int>.generate(length, (i) => i, growable: false);
    indices.sort(reverse ? (a, b) => compare(b, a) : compare);
    return indices;
  }

  void _applySortedOrder(List<int> indices) {
    final length = indices.length;
    final sorted = List<E>.generate(length, (i) => this[indices[i]], growable: false);
    this.setRange(0, length, sorted);
  }
}

extension ListieEqualityUtils<T1> on List<T1>? {
  bool didChangeFrom<T2>(List<T2>? other, {bool ordered = false}) {
    final equality = ordered ? DeepCollectionEquality() : DeepCollectionEquality.unordered();
    final didChange = !equality.equals(this, other);
    return didChange;
  }
}

/// Fan-out helpers for independent async work.
///
/// A plain `for (...) await ...` loop pays the full latency of every item in series, while a bare
/// `Future.wait` over a long list puts every item in flight at once, which for file io means
/// thousands of open handles. these keep at most [concurrency] running.
///
/// by claude
extension IterableConcurrentUtils<E> on Iterable<E> {
  static const _defaultConcurrency = 16;

  /// Results are returned in the original order, regardless of completion order.
  Future<List<R>> mapConcurrent<R>(Future<R> Function(E item) action, {int concurrency = _defaultConcurrency}) async {
    final items = this is List<E> ? this as List<E> : toList();
    final length = items.length;
    if (length == 0) return <R>[];
    if (length == 1) return <R>[await action(items[0])];

    final results = List<R?>.filled(length, null);
    int next = 0;

    Future<void> worker() async {
      while (true) {
        // -- single threaded event loop, nothing can interleave between the read & the increment.
        final index = next++;
        if (index >= length) return;
        results[index] = await action(items[index]);
      }
    }

    final workersCount = concurrency < length ? concurrency : length;
    await Future.wait(List.generate(workersCount, (_) => worker(), growable: false));
    return List<R>.generate(length, (i) => results[i] as R, growable: false);
  }

  Future<void> loopConcurrent(Future<void> Function(E item) action, {int concurrency = _defaultConcurrency}) async {
    final items = this is List<E> ? this as List<E> : toList();
    final length = items.length;
    if (length == 0) return;
    if (length == 1) return await action(items[0]);

    int next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= length) return;
        await action(items[index]);
      }
    }

    final workersCount = concurrency < length ? concurrency : length;
    await Future.wait(List.generate(workersCount, (_) => worker(), growable: false));
  }
}

extension ListieFutureUtils<T> on List<T> {
  Stream<T> whereAsync(FutureOr<bool> Function(T element) test) async* {
    for (final e in this) {
      if (await test(e)) yield e;
    }
  }

  Future<T?> firstWhereEffAsync(FutureOr<bool> Function(T element) test, {T? fallback}) async {
    for (final e in this) {
      if (await test(e)) return e;
    }
    return fallback;
  }

  Future<bool> anyAsync(FutureOr<bool> Function(T element) test, {T? fallback}) async {
    for (final e in this) {
      if (await test(e)) return true;
    }
    return false;
  }

  Stream<E> mapAsync<E>(FutureOr<E> Function(T element) converter) async* {
    for (final e in this) {
      yield await converter(e);
    }
  }

  Future<void> loopAsync(FutureOr<dynamic> Function(T element) fn) async {
    for (final e in this) {
      await fn(e);
    }
  }
}

extension IterableFutureUtils<T> on Iterable<T> {
  Stream<E> mapAsync<E>(FutureOr<E> Function(T element) converter) async* {
    for (final e in this) {
      yield await converter(e);
    }
  }
}

extension IterablieListieUtils<E> on List<E> {
  Iterable<T> mapIndexed<T>(T Function(E e, int index) toElement) sync* {
    int index = 0;
    for (final item in this) {
      yield toElement(item, index);
      index++;
    }
  }
}

extension DisplayKeywords on int {
  String get displayTrackKeyword => lang.countTracks(count: this);
  String get displayDayKeyword => lang.countDays(count: this);
  String get displayAlbumKeyword => lang.countAlbums(count: this);
  String get displayArtistKeyword => lang.countArtists(count: this);
  String get displayGenreKeyword => lang.countGenres(count: this);
  String get displayStyleKeyword => lang.countStyles(count: this);
  String get displayFilesKeyword => lang.countFiles(count: this);
  String get displayFolderKeyword => lang.countFolders(count: this);
  String get displayPlaylistKeyword => lang.countPlaylists(count: this);
  String get displayVideoKeyword => lang.countVideos(count: this);
  String get displayViewsKeyword => lang.countViews(count: this);
  String get displaySubscribersKeyword => lang.countSubscribers(count: this);
  String get displayMonthKeyword => lang.countMonths(count: this);

  String get displayViewsKeywordShort => lang.countViewsShort(count: this);
  String get displaySubscribersKeywordShort => lang.countSubscribersShort(count: this);
}

extension DateTimeFormattersInt on int {
  String get secondsFormatted => getSecondsFormatted(hourChar: 'h', minutesChar: 'min', separator: ' ');
  String get yearFormatted => getYearFormatted(settings.dateTimeFormat.value);
  String get dateFormatted => DateTime.fromMillisecondsSinceEpoch(this).dateFormatted;
  String get dateFormattedOriginal => DateTime.fromMillisecondsSinceEpoch(this).dateFormattedOriginal;
  String dateFormattedOriginalNoYears(DateTime diffDate) => DateTimeFormatters(DateTime.fromMillisecondsSinceEpoch(this)).dateFormattedOriginalNoYears(diffDate);
  String get clockFormatted => DateTime.fromMillisecondsSinceEpoch(this).clockFormatted;
  String get dateAndClockFormattedOriginal => DateTime.fromMillisecondsSinceEpoch(this).dateAndClockFormattedOriginal;
  String get dateAndClockFormatted => DateTime.fromMillisecondsSinceEpoch(this).dateAndClockFormatted;
}

extension DateTimeFormatters on DateTime {
  String get yearFormatted => getYearFormatted(settings.dateTimeFormat.value); // non reactive

  String get dateFormatted => formatTimeFromDate(settings.dateTimeFormat.value); // non reactive

  String get dateFormattedOriginal {
    final valInSetting = settings.dateTimeFormat.value;
    return getDateFormatted(valInSetting.contains('d') ? settings.dateTimeFormat.value : 'dd MMM yyyy');
  }

  String dateFormattedOriginalNoYears(DateTime diffDate) {
    final valInSettingMain = settings.dateTimeFormat.value;
    String valInSettingNew = valInSettingMain.contains('d') ? valInSettingMain : 'dd MMM yyyy';

    final thisDate = this;
    if (thisDate.year == diffDate.year && thisDate.year == DateTime.now().year) {
      valInSettingNew = valInSettingNew.replaceAll('y', '').replaceAll('Y', '');
    }
    return getDateFormatted(valInSettingNew);
  }

  String get clockFormatted => getClockFormatted(settings.hourFormat12.value);

  /// this one gurantee that the format will return with the day included, even if the format in setting doesnt have day.
  /// if (valInSet.contains('d')) return userformat;
  /// else return dateFormattedOriginal ('dd MMM yyyy');
  String get dateAndClockFormattedOriginal {
    final valInSet = settings.dateTimeFormat.value;
    if (valInSet.contains('d')) {
      return dateAndClockFormatted;
    }
    return [dateFormattedOriginal, clockFormatted].join(' - ');
  }

  String get dateAndClockFormatted => [dateFormatted, clockFormatted].join(' - ');
}

extension BorderRadiusSetting on double {
  double get multipliedRadius {
    return this * settings.borderRadiusMultiplier.value;
  }
}

extension TrackItemSubstring on TrackTileItem {
  String get label => name;
}

extension Channels on String {
  String get channelToLabel {
    final ch = int.tryParse(this);
    final resolved = switch (ch) {
      null => '',
      0 => '',
      1 => 'mono',
      2 => 'stereo',
      _ => null,
    };
    return resolved ?? this;
  }
}

extension FavouriteTrack on Track {
  bool get isFavourite => PlaylistController.inst.favouritesPlaylist.isSubItemFavourite(this);
}

extension FavouriteYoutubeID on YoutubeID {
  bool get isFavourite => YoutubePlaylistController.inst.favouritesPlaylist.isItemFavourite(this);
}

extension PLNAME on String {
  String translatePlaylistName() {
    final name = this;
    if (name == k_PLAYLIST_NAME_FAV) return lang.favourites;
    if (name == k_PLAYLIST_NAME_HISTORY) return lang.history;
    if (name == k_PLAYLIST_NAME_MOST_PLAYED) return lang.mostPlayed;
    return name.replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, lang.autoGenerated);
  }

  bool isDefaultPlaylistName() {
    final name = this;
    if (name == k_PLAYLIST_NAME_FAV || name == k_PLAYLIST_NAME_HISTORY || name == k_PLAYLIST_NAME_MOST_PLAYED) return true;
    return false;
  }

  String emptyIfHasDefaultPlaylistName() {
    return isDefaultPlaylistName() ? '' : this;
  }
}

extension EnumUtils<E extends Enum> on E {
  E nextElement(List<E> enumsList) {
    final newIndex = (index + 1) % enumsList.length;
    final val = enumsList[newIndex];
    return val;
  }
}

extension TRACKPLAYMODE on TrackPlayMode {
  List<Track> generateQueue(Track trackPre, {List<Track>? searchQueue}) {
    final track = trackPre.toTrackExt();
    final queue =
        switch (this) {
          TrackPlayMode.selectedTrack => [trackPre],
          TrackPlayMode.searchResults =>
            searchQueue ??
                (SearchSortController.inst.trackSearchTemp.value.isNotEmpty ? SearchSortController.inst.trackSearchTemp.value : SearchSortController.inst.trackSearchList.value),
          TrackPlayMode.trackAlbum => track.albumsIdentifiersModified.firstOrNull?.getAlbumTracks(),
          TrackPlayMode.trackArtist => track.artistsList.firstOrNull?.getArtistTracks(),
          TrackPlayMode.trackGenre => track.genresList.firstOrNull?.getGenresTracks(),
          TrackPlayMode.trackStyle => track.stylesList.firstOrNull?.getStylesTracks(),
        } ??
        [trackPre];

    final newQueue = List<Track>.from(queue);
    if (shouldBeIndex0) {
      newQueue.remove(trackPre);
      newQueue.insertSafe(0, trackPre);
    }
    return newQueue;
  }
}

extension YTLinkToID on String {
  String get getYoutubeID => NamidaLinkUtils.extractYoutubeId(this) ?? '';
}

extension TitleAndArtistUtils on String {
  static final _artistTitleSplitRegex = RegExp(
    r'^(.*?)(?:\s+-\s+|\s+\|\s+|\s+by\s+|\s+["「]|-\||-\s+|」)(.*?)(?:"|」)?$',
    caseSensitive: false,
  );

  static final _keepFeatKeywordsOnlyRegex = RegExp(
    r'\s*\((?!remix|featured|features|ft\.|feat\.|featuring)(?!.*Remix)[^)]*\)|\s*\[(?!remix|featured|features|ft\.|feat\.|featuring)(?!.*Remix)[^\]]*\]',
    caseSensitive: false,
  );

  /// (artist, title)
  (String?, String?) splitArtistAndTitle() {
    final input = this;
    if (input == '') return (null, null);
    final match2 = _artistTitleSplitRegex.firstMatch(input);
    if (match2 != null) {
      String? artist = match2.group(1)?.trim();
      String? title = match2.group(2)?.trim();
      if (artist != null && title != null) {
        if (artist.startsWith('「')) artist = artist.replaceRange(0, 1, '');
        if (title.startsWith('"')) title = title.replaceRange(0, 1, '');
        return (artist, title);
      }
    }
    // final regexDoesntCareAboutSpaces = RegExp(
    //   r'^(.*?)(?:\s?-\s?|\s?\|\s?|\s?by\s|\s?["「])(.*?)(?:"|」)?$',
    //   caseSensitive: false,
    // );
    // final match = regexDoesntCareAboutSpaces.firstMatch(input);
    // if (match != null) {
    //   final artist = match.group(1)?.trim();
    //   final title = match.group(2)?.trim();
    //   if (artist != null && title != null) {
    //     final a = artist.startsWith('「') ? artist.replaceRange(0, 1, '') : artist;
    //     return (a, title);
    //   }
    // }
    return (null, null);
  }

  String keepFeatKeywordsOnly() {
    if (this == '') return '';
    String res = replaceAll(_keepFeatKeywordsOnlyRegex, '').trimAll();
    while (res.trim().endsWith(' -')) {
      res = res.substring(0, res.length - 2);
    }
    return res.trim();
  }
}

extension LRCParsingUtils on String {
  Lrc? parseLRC() {
    try {
      final lrc = LrcParser.parse(this);
      if (lrc.lyrics.isNotEmpty) return lrc;
    } catch (_) {}
    try {
      final ttmlAsLrc = TtmlParser.parse(this);
      if (ttmlAsLrc.lyrics.isNotEmpty) return ttmlAsLrc;
    } catch (_) {}
    try {
      final subtitleAsLrc = SubtitleParser.parse(this);
      if (subtitleAsLrc.lyrics.isNotEmpty) return subtitleAsLrc;
    } catch (_) {}
    try {
      final res = LRCParserSmart(this).parseLines();
      if (res.isNotEmpty) {
        final lines = <LrcLine>[];
        for (final e in res) {
          lines.add(
            LrcLine(
              timestamp: e.timeStamp ?? Duration.zero,
              lyrics: e.mainText ?? '',
              originalIndex: res.length,
              readableText: e.mainText ?? '',
              person: null,
              parts: null,
              type: LrcTypes.simple,
              isRTL: LrcParser.isLrcLineRTL(e.mainText ?? ''),
            ),
          );
        }

        return Lrc(
          lyrics: lines,
        );
      }
    } catch (_) {}
    return null;
  }

  bool isValidLRC() {
    bool valid = false;
    try {
      valid = LrcParser.isValid(this) || TtmlParser.isValid(this) || SubtitleParser.isValid(this);
    } catch (_) {}
    if (!valid) {
      try {
        final res = LRCParserSmart(this).parseLines();
        valid = res.isNotEmpty;
      } catch (_) {}
    }
    return valid;
  }
}

extension TagFieldsUtils on TagField {
  bool get isNumeric =>
      this == TagField.trackNumber || this == TagField.trackTotal || this == TagField.discNumber || this == TagField.discTotal || this == TagField.year || this == TagField.rating;
}

extension WidgetsUtils on Widget {
  Widget animateEntrance({
    required bool showWhen,
    int durationMS = 400,
    int? reverseDurationMS,
    Curve? allCurves,
  }) {
    return NamidaAnimatedSwitcher(
      firstChild: this,
      secondChild: const SizedBox(),
      showFirst: showWhen,
      durationMS: durationMS,
      reverseDurationMS: reverseDurationMS,
      allCurves: allCurves,
    );
  }

  Widget toSliver() => SliverToBoxAdapter(child: this);
}

extension CloseDialogIfTrueFuture on FutureOr<bool> {
  /// Closes dialog if [this == true].
  ///
  /// This is mainly created for [addToQueue] Function inside Player Class,
  /// where it should close the dialog only if there were tracks added.
  void closeDialog([int count = 1]) async {
    final res = await this;
    res.executeIfTrue(() => NamidaNavigator.inst.closeDialog(count));
  }
}

extension FutureIterabletUtils on Iterable<Future<void>> {
  Future<void> executeAllAndSilentReportErrors() async {
    await Future.wait(this.map((e) => e.catchError(logger.report)));
  }
}

extension FutureIterableNullUtils on Iterable<Future<void>?> {
  Future<void> executeAllAndSilentReportErrors() async {
    final newList = <Future<dynamic>>[];
    for (final f in this) {
      if (f != null) newList.add(f.catchError(logger.report));
    }
    await Future.wait(newList);
  }
}

extension IsolateOpener<M, R> on ComputeCallback<M, R> {
  /// Executes function on a separate isolate using compute().
  /// Must be `static` or `global` function.
  Future<R> thready(M parameter) async {
    return await compute(this, parameter);
  }
}

extension FunctionsExecuter<T> on Iterable<Future<T>?> {
  Future<List<T>> execute() async {
    return await Future.wait(whereType<Future<T>>());
  }
}

extension IterableExtensions<E> on Iterable<E> {
  E? firstWhereEff(bool Function(E e) test, {E? fallback}) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return fallback;
  }

  List<E> getRandomSample(int count) {
    return sample(count);
  }

  bool hasSingleItem() {
    Iterator it = iterator;
    if (!it.moveNext()) return false; // empty
    if (it.moveNext()) return false; // more than 1
    return true;
  }

  Future<bool> anyAsync(FutureOr<bool> Function(E element) test, {E? fallback}) async {
    for (var e in this) {
      if (await test(e)) return true;
    }
    return false;
  }

  List<E> takeUnique(int count) {
    final uniqueSet = <E>{};
    final finalList = <E>[];
    for (final e in this) {
      if (uniqueSet.add(e)) {
        finalList.add(e);
        if (finalList.length >= count) break;
      }
    }
    return finalList;
  }
}

extension DEWidgetsSeparator on Iterable<Widget> {
  /// Inserts [separator] between the items.
  ///
  /// [skipFirst] skips adding separators for the first [skipFirst] items.
  Iterable<Widget> addSeparators({required Widget separator, int skipFirst = 0}) sync* {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return;
    yield iterator.current;

    int remainingToSkip = skipFirst;
    while (iterator.moveNext()) {
      if (remainingToSkip > 0) {
        remainingToSkip--;
      } else {
        yield separator;
      }
      yield iterator.current;
    }
  }
}

extension DirectoryUtils on Directory {
  List<FileSystemEntity> listSyncSafe({bool recursive = false, bool followLinks = true}) {
    try {
      return listSync(recursive: recursive, followLinks: followLinks);
    } catch (e) {
      return [];
    }
  }

  Future<List<FileSystemEntity>> listAllIsolate({bool recursive = false, bool followLinks = true}) async {
    try {
      return await Isolate.run(
        () => this.listSync(
          recursive: recursive,
          followLinks: followLinks,
        ),
      );
    } catch (e) {
      printy(e, isError: true);
      return [];
    }
  }

  Future<int?> getTotalSize({bool recursive = false, bool followLinks = true}) async {
    try {
      return await Isolate.run(
        () {
          int size = 0;
          final files = this.listSync(recursive: recursive, followLinks: followLinks);
          for (var e in files) {
            size += (e is File ? File(e.path).fileSizeSync() ?? 0 : 0);
          }
          return size;
        },
      );
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }
}

extension FileUtils on File {
  Future<void> setLastAccessedTry(DateTime time) async {
    try {
      await setLastAccessed(time);
    } catch (_) {}
  }

  /// [goodBytesIfCopied] is checked to delete the old file if renaming failed.
  File? moveSync(String newPath, {bool Function(int newFileLength)? goodBytesIfCopied}) {
    File? newFile;
    final file = this;
    try {
      newFile = file.renameSync(newPath);
    } catch (_) {
      try {
        newFile = file.copySync(newPath);
        if (newFile.existsSync()) {
          if (goodBytesIfCopied != null) {
            if (goodBytesIfCopied(newFile.lengthSync())) {
              file.deleteSync();
            }
          } else {
            file.deleteSync();
          }
        }
      } catch (_) {}
    }
    return newFile;
  }

  /// [goodBytesIfCopied] is checked to delete the old file if renaming failed.
  Future<File?> move(String newPath, {FutureOr<bool> Function(int newFileLength)? goodBytesIfCopied}) async {
    File? newFile;
    final file = this;
    try {
      newFile = await file.rename(newPath);
    } catch (_) {
      try {
        newFile = await file.copy(newPath);
        if (await newFile.exists()) {
          if (goodBytesIfCopied != null) {
            if (await goodBytesIfCopied(await newFile.length())) {
              await file.delete();
            }
          } else {
            await file.delete();
          }
        }
      } catch (_) {}
    }
    return newFile;
  }
}

final _minimumFileDateMicro = DateTime(1980).microsecondsSinceEpoch + 1;
final _minimumFileDateMilli = DateTime(1980).millisecondsSinceEpoch + 1;

extension FileStatsUtils on FileStat {
  DateTime get creationDate {
    int? finalDateMicro;
    void tryAssign(int micros) {
      if (micros > _minimumFileDateMicro && (finalDateMicro == null || micros < finalDateMicro!)) finalDateMicro = micros;
    }

    tryAssign(modified.microsecondsSinceEpoch);
    tryAssign(changed.microsecondsSinceEpoch);
    tryAssign(accessed.microsecondsSinceEpoch);

    return finalDateMicro != null ? DateTime.fromMicrosecondsSinceEpoch(finalDateMicro!) : DateTime(1970);
  }
}

extension CompleterCompleter<T> on Completer<T> {
  void completeIfWasnt([FutureOr<T>? value]) {
    if (isCompleted == false) complete(value);
  }

  void completeErrorIfWasnt(Object error, [StackTrace? stackTrace]) {
    if (isCompleted == false) completeError(error, stackTrace);
  }
}

extension ScrollerPerf on ScrollController {
  /// Animates a scrollview to a certain [offset] after jumping closer for faster performance
  ///
  /// The final distance to animate is defined by [jumpitator]
  Future<void> animateToEff(
    double offset, {
    required Duration duration,
    required Curve curve,
    final double jumpitator = 800.0,
  }) async {
    try {
      await this.positions.last.animateToEff(
        offset,
        duration: duration,
        curve: curve,
        jumpitator: jumpitator,
      );
    } catch (_) {}
  }
}

extension ScrollPositionPerf on ScrollPosition {
  /// Animates a scrollview to a certain [offset] after jumping closer for faster performance
  ///
  /// The final distance to animate is defined by [jumpitator]
  Future<void> animateToEff(
    double offset, {
    required Duration duration,
    required Curve curve,
    final double jumpitator = 800.0,
  }) async {
    try {
      final diff = offset - this.pixels;

      if (diff > jumpitator) {
        // -- is now above the target, so we jump offset-jumpitator
        jumpTo(offset - jumpitator);
      } else if (diff < -jumpitator) {
        // -- is now under the target, so we jump offset+jumpitator
        jumpTo(offset + jumpitator);
      }
    } catch (_) {}

    await animateTo(offset, duration: duration, curve: curve);
  }
}

extension NavigatorUtils on BuildContext {
  void safePop({bool rootNavigator = false}) {
    final context = this;
    if (context.mounted) Navigator.of(context, rootNavigator: rootNavigator).pop();
  }
}

extension DisposingScrollUtils on ScrollController {
  Future<void> disposeAfterAnimation({int durationMS = 2000, void Function()? also}) async {
    void fn() {
      dispose();
      if (also != null) also();
    }

    await fn.executeDelayed(Duration(milliseconds: durationMS));
  }
}

extension DisposingUtils on TextEditingController {
  Future<void> disposeAfterAnimation({int durationMS = 2000, void Function()? also}) async {
    void fn() {
      dispose();
      if (also != null) also();
    }

    await fn.executeDelayed(Duration(milliseconds: durationMS));
  }
}

extension ExecuteDelayedUtils<T> on T Function() {
  Future<T> executeDelayed(Duration dur) async {
    return await Future.delayed(dur, this);
  }

  Future<T> executeAfterDelay({int durationMS = 2000}) async {
    return await this.executeDelayed(Duration(milliseconds: durationMS));
  }

  T? ignoreError() {
    try {
      return this();
    } catch (_) {
      return null;
    }
  }
}

extension ExecuteDelayedMinUtils<T> on Future<T> {
  Future<T> executeWithMinDelay({int delayMS = 200}) async {
    late final T v;
    await Future.wait([
      then((c) => v = c),
      Future.delayed(Duration(milliseconds: delayMS)),
    ]);
    return v;
  }

  Future<T?> ignoreError() async {
    try {
      return await this;
    } catch (_) {}
    return null;
  }
}

extension GlobalKeyExtensions on GlobalKey {
  RenderBox? findRenderBox() {
    return this.currentContext?.findRenderObject() as RenderBox?;
  }

  Size? calulateSize() {
    final renderBox = this.findRenderBox();
    return renderBox?.size;
  }

  void calulateSizeAfterBuild(Function(Size? size) onAvailable) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onAvailable(calulateSize()));
  }
}

extension StatefulWUtils<T extends StatefulWidget> on State<T> {
  void refreshState([void Function()? fn]) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() {
        if (fn != null) fn();
      });
    } else {
      if (fn != null) fn();
    }
  }
}

extension StringPathUtils on String {
  /// keeps reverse collecting string until [until] is matched.
  /// useful to exract extensions or filenames.
  String pathReverseSplitter(String until) {
    final path = this;
    int end = path.length;

    // -- skipping separator at the end.
    while (end > 0 && path[end - 1] == until) {
      end--;
    }
    if (end == 0) return '';

    final start = path.lastIndexOf(until, end - 1) + 1;
    return path.substring(start, end);
  }

  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }

  /// walks an offset instead of re-slicing: this is called once per item while sorting the
  /// whole library, and the overwhelmingly common case is "no prefix", which now allocates nothing.
  String ignoreCommonPrefixes() {
    final prefixes = settings.commonPrefixes.value;
    final prefixesLength = prefixes.length;
    if (prefixesLength == 0) return this;

    int start = 0;
    bool stripped = true;
    while (stripped) {
      stripped = false;
      for (int i = 0; i < prefixesLength; i++) {
        final prefix = prefixes[i];
        // -- an empty prefix would always match & never advance.
        if (prefix.isNotEmpty && startsWith(prefix, start)) {
          start += prefix.length;
          stripped = true;
        }
      }
    }
    return start == 0 ? this : substring(start);
  }

  String toFastHashKey() {
    final s = this;
    int hash = 0;
    for (final c in s.codeUnits) {
      hash += c;
      hash += (hash << 10);
      hash ^= (hash >> 6);
    }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    final number = hash & 0x7FFFFFFF;
    return number.toString();
  }
}

extension ColorExtensions on Color {
  int get intValue => toARGB32();
  Color withOpacityExt(double opacity) => Color.from(
    alpha: opacity,
    red: r,
    green: g,
    blue: b,
    colorSpace: colorSpace,
  );
}

extension ClamperExtInt on int {
  int clampInt(int min, int max) {
    assert(min <= max);
    final x = this;
    if (x < min) return min;
    if (x > max) return max;
    // if (x.isNaN) return max; // -- isNaN is only for double
    return x;
  }
}

extension ClamperExtDouble on double {
  double clampDouble(double min, double max) {
    assert(min <= max && !max.isNaN && !min.isNaN);
    var x = this;
    if (x < min) return min;
    if (x > max) return max;
    if (x.isNaN) return max;
    return x;
  }
}

extension ThemeModeExtensions on ThemeMode {
  bool checkIsLight(Brightness? platformBrightness) {
    final mode = this;
    final useDarkTheme = mode == ThemeMode.dark || (mode == ThemeMode.system && platformBrightness == Brightness.dark);
    final isLight = !useDarkTheme;
    return isLight;
  }
}

extension DirectoryIndexUtils on List<DirectoryIndex> {
  Iterable<DirectoryIndexServer> allServers() {
    return whereType<DirectoryIndexServer>();
  }

  bool hasServer() {
    return allServers().isNotEmpty;
  }
}

extension DirectoryIndexServerUtils on DirectoryIndex {
  Widget toWidget({
    String? title,
    String? subtitle,
    Widget Function(BuildContext context)? subtitleBuilder,
    required ThemeData theme,
    bool? Function(DirectoryIndex d)? stillExistsCallback,
  }) {
    final e = this;

    final type = e.type;
    if (title == null) {
      final typeText = e.type.toText();
      title = [typeText, e.username ?? '?'].joinText(separator: ' - ');
    }

    final stillExists = stillExistsCallback?.call(e) ?? true;
    final mainColorScheme = stillExists ? type.toColor(theme) : Colors.red;
    return NamidaCoolBox(
      colorScheme: mainColorScheme,
      extraVPadding: true,
      extraBorder: !stillExists,
      builder: (context) {
        final assetImagePath = type.toAssetImage();
        Widget? assetWidget = assetImagePath == null
            ? null
            : Image.asset(
                assetImagePath,
                height: 18.0,
              );
        assetWidget ??= Icon(
          type.toIcon(),
          size: 18.0,
        );
        return Row(
          mainAxisSize: .max,
          children: [
            assetWidget,
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    title ?? '',
                    style: context.theme.textTheme.displayMedium,
                  ),
                  subtitleBuilder?.call(context) ??
                      Text(
                        subtitle ?? e.toSourceInfo(),
                        style: context.theme.textTheme.displaySmall,
                      ),
                ],
              ),
            ),
            if (!stillExists) ...[
              const SizedBox(width: 12.0),
              Icon(
                Broken.trash,
                size: 20.0,
              ),
            ],
          ],
        );
      },
    );
  }
}
