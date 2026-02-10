import 'dart:async';
import 'dart:io';
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
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/lyrics_parser/parser_smart.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

export 'package:dart_extensions/dart_extensions.dart';

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

extension TracksWithDatesUtils on List<TrackWithDate> {
  int get totalDurationInMS => fold(0, (previousValue, element) => previousValue + element.track.durationMS);
  String get totalDurationFormatted {
    return (totalDurationInMS ~/ 1000).secondsFormatted;
  }

  int getTotalListenCount() {
    int total = 0;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final twd = this[i];
      final e = twd.track;
      final c = HistoryController.inst.topTracksMapListens.value[e]?.length ?? 0;
      total += c;
    }
    return total;
  }

  int? getFirstListen() {
    int? generalFirstListen;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final twd = this[i];
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
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final twd = this[i];
      final e = twd.track;
      final lastListen = HistoryController.inst.topTracksMapListens.value[e]?.lastOrNull;
      if (lastListen != null && (generalLastListen == null || lastListen > generalLastListen)) {
        generalLastListen = lastListen;
      }
    }
    return generalLastListen;
  }
}

extension TracksUtils on List<Track> {
  int getTotalListenCount() {
    int total = 0;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final e = this[i];
      final c = HistoryController.inst.topTracksMapListens.value[e]?.length ?? 0;
      total += c;
    }
    return total;
  }

  int? getFirstListen() {
    int? generalFirstListen;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final e = this[i];
      final firstListen = HistoryController.inst.topTracksMapListens.value[e]?.firstOrNull;
      if (firstListen != null && (generalFirstListen == null || firstListen < generalFirstListen)) {
        generalFirstListen = firstListen;
      }
    }
    return generalFirstListen;
  }

  int? getLatestListen() {
    int? generalLastListen;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final e = this[i];
      final lastListen = HistoryController.inst.topTracksMapListens.value[e]?.lastOrNull;
      if (lastListen != null && (generalLastListen == null || lastListen > generalLastListen)) {
        generalLastListen = lastListen;
      }
    }
    return generalLastListen;
  }

  Set<String> toUniqueAlbums() {
    final tracks = this;
    final albums = <String>{};
    tracks.loop((t) => albums.add(t.albumIdentifier));
    return albums;
  }

  String get totalSizeFormatted {
    int size = 0;
    loop((t) => size += t.size);
    return size.fileSizeFormatted;
  }

  int get totalDurationInMS => fold(0, (previousValue, element) => previousValue + element.durationMS);

  String get totalDurationFormatted {
    return (totalDurationInMS ~/ 1000).secondsFormatted;
  }

  int get year {
    if (isEmpty) return 0;
    for (int i = length - 1; i >= 0; i--) {
      final y = this[i].year;
      if (y != 0) return y;
    }
    return 0;
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

  String get album {
    if (isEmpty) return '';
    for (int i = length - 1; i >= 0; i--) {
      final a = this[i].album;
      if (a != '') return a;
    }
    return '';
  }

  String get albumArtist {
    if (isEmpty) return '';
    for (int i = length - 1; i >= 0; i--) {
      final aa = this[i].albumArtist;
      if (aa != '') return aa;
    }
    return '';
  }

  String get composer {
    if (isEmpty) return '';
    for (int i = length - 1; i >= 0; i--) {
      final aa = this[i].composer;
      if (aa != '') return aa;
    }
    return '';
  }

  String get recordLabel {
    if (isEmpty) return '';
    for (int i = length - 1; i >= 0; i--) {
      final aa = this[i].label;
      if (aa != '') return aa;
    }
    return '';
  }
}

extension StringListJoiner on Iterable<String?> {
  String joinText({String separator = ' • '}) {
    return where((element) => element != null && element != '').join(separator);
  }
}

extension ListieListieUtils<T> on List<T> {
  T get random {
    final index = math.Random().nextInt(length);
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

    for (var i = totalLength - sampleCount; i < totalLength; i++) {
      final t = random.nextInt(i + 1);
      final indexToSelect = selectedIndices.contains(t) ? i : t;
      final item = list[indexToSelect];
      if (test(item)) {
        selectedIndices.add(indexToSelect);
        selectedItems.add(item);
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

extension ListieFutureUtils<T> on List<T> {
  Stream<T> whereAsync(FutureOr<bool> Function(T element) test) async* {
    for (var i = 0; i < length; i++) {
      var e = this[i];
      if (await test(e)) yield e;
    }
  }

  Future<T?> firstWhereEffAsync(FutureOr<bool> Function(T element) test, {T? fallback}) async {
    for (var i = 0; i < length; i++) {
      var e = this[i];
      if (await test(e)) return e;
    }
    return fallback;
  }

  Future<bool> anyAsync(FutureOr<bool> Function(T element) test, {T? fallback}) async {
    for (var i = 0; i < length; i++) {
      var e = this[i];
      if (await test(e)) return true;
    }
    return false;
  }

  Stream<E> mapAsync<E>(FutureOr<E> Function(T element) converter) async* {
    for (var i = 0; i < length; i++) {
      var e = this[i];
      yield await converter(e);
    }
  }

  Future<void> loopAsync(FutureOr<dynamic> Function(T element) fn) async {
    for (var i = 0; i < length; i++) {
      await fn(this[i]);
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
    final length = this.length;
    for (int i = 0; i < length; i++) {
      yield toElement(this[i], i);
    }
  }
}

extension IterablieUtils<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(E e, int index) toElement) sync* {
    int index = 0;
    for (final item in this) {
      yield toElement(item, index);
    }
  }
}

extension DisplayKeywords on int {
  String get displayTrackKeyword => displayKeyword(lang.TRACK, lang.TRACKS);
  String get displayDayKeyword => displayKeyword(lang.DAY, lang.DAYS);
  String get displayAlbumKeyword => displayKeyword(lang.ALBUM, lang.ALBUMS);
  String get displayArtistKeyword => displayKeyword(lang.ARTIST, lang.ARTISTS);
  String get displayGenreKeyword => displayKeyword(lang.GENRE, lang.GENRES);
  String get displayFilesKeyword => displayKeyword(lang.FILE, lang.FILES);
  String get displayFolderKeyword => displayKeyword(lang.FOLDER, lang.FOLDERS);
  String get displayPlaylistKeyword => displayKeyword(lang.PLAYLIST, lang.PLAYLISTS);
  String get displayVideoKeyword => displayKeyword(lang.VIDEO, lang.VIDEOS);
  String get displayViewsKeyword => displayKeyword(lang.VIEW, lang.VIEWS);
  String get displayViewsKeywordShort => displayKeywordShort(lang.VIEW, lang.VIEWS);
  String get displaySubscribersKeywordShort => displayKeywordShort(lang.SUBSCRIBER, lang.SUBSCRIBERS);
}

extension YearDateFormatted on int {
  String get secondsFormatted => getSecondsFormatted(hourChar: 'h', minutesChar: 'min', separator: ' ');

  String get yearFormatted => getYearFormatted(settings.dateTimeFormat.value); // non reactive

  String get dateFormatted => formatTimeFromMSSE(settings.dateTimeFormat.value); // non reactive

  String get dateFormattedOriginal {
    final valInSetting = settings.dateTimeFormat.value;
    return getDateFormatted(format: valInSetting.contains('d') ? settings.dateTimeFormat.value : 'dd MMM yyyy');
  }

  String dateFormattedOriginalNoYears(DateTime diffDate) {
    final valInSettingMain = settings.dateTimeFormat.value;
    String valInSettingNew = valInSettingMain.contains('d') ? valInSettingMain : 'dd MMM yyyy';

    bool lessThan1Year(Duration d) => d.inDays.abs() < 364;
    final thisDate = DateTime.fromMillisecondsSinceEpoch(this);
    final diffFromNow = thisDate.difference(DateTime.now());
    final diffDur = thisDate.difference(diffDate);
    if (lessThan1Year(diffDur) && lessThan1Year(diffFromNow)) {
      valInSettingNew = valInSettingNew.replaceAll('y', '').replaceAll('Y', '');
    }
    return getDateFormatted(format: valInSettingNew);
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
    if (ch == null) return '';
    if (ch == 0) return '';
    if (ch == 1) return 'mono';
    if (ch == 2) return 'stereo';
    return this;
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
    if (name == k_PLAYLIST_NAME_FAV) return lang.FAVOURITES;
    if (name == k_PLAYLIST_NAME_HISTORY) return lang.HISTORY;
    if (name == k_PLAYLIST_NAME_MOST_PLAYED) return lang.MOST_PLAYED;
    return name.replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, lang.AUTO_GENERATED);
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
  bool get shouldBeIndex0 => this == TrackPlayMode.selectedTrack || this == TrackPlayMode.trackAlbum || this == TrackPlayMode.trackArtist || this == TrackPlayMode.trackGenre;

  List<Track> generateQueue(Track trackPre, {List<Track>? searchQueue}) {
    final track = trackPre.toTrackExt();
    final queue = switch (this) {
          TrackPlayMode.selectedTrack => [trackPre],
          TrackPlayMode.searchResults => searchQueue ??
              (SearchSortController.inst.trackSearchTemp.value.isNotEmpty ? SearchSortController.inst.trackSearchTemp.value : SearchSortController.inst.trackSearchList.value),
          TrackPlayMode.trackAlbum => track.albumIdentifier.getAlbumTracks(),
          TrackPlayMode.trackArtist => track.artistsList.firstOrNull?.getArtistTracks(),
          TrackPlayMode.trackGenre => track.artistsList.firstOrNull?.getGenresTracks(),
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
  /// (artist, title)
  (String?, String?) splitArtistAndTitle() {
    final input = this;
    if (input == '') return (null, null);
    final regexCareForSpaces = RegExp(
      r'^(.*?)(?:\s+-\s+|\s+\|\s+|\s+by\s+|\s+["「]|-\||-\s+|」)(.*?)(?:"|」)?$',
      caseSensitive: false,
    );
    final match2 = regexCareForSpaces.firstMatch(input);
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
    final regex = RegExp(
      r'\s*\((?!remix|featured|features|ft\.|feat\.|featuring)(?!.*Remix)[^)]*\)|\s*\[(?!remix|featured|features|ft\.|feat\.|featuring)(?!.*Remix)[^\]]*\]',
      caseSensitive: false,
    );
    String res = replaceAll(regex, '').trimAll();
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
            ),
          );
        }

        return Lrc(lyrics: lines);
      }
    } catch (_) {}
    return null;
  }

  bool isValidLRC() {
    bool valid = false;
    try {
      valid = LrcParser.isValid(this) || TtmlParser.isValid(this);
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
    Curve firstCurve = Curves.linear,
    Curve secondCurve = Curves.linear,
    Curve sizeCurve = Curves.linear,
    Curve? allCurves,
  }) {
    return NamidaAnimatedSwitcher(
      firstChild: this,
      secondChild: const SizedBox(),
      showFirst: showWhen,
      durationMS: durationMS,
      reverseDurationMS: reverseDurationMS,
      firstCurve: firstCurve,
      secondCurve: secondCurve,
      sizeCurve: sizeCurve,
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
      final params = {
        'dirPath': path,
        'recursive': recursive,
        'followLinks': followLinks,
      };
      return await compute(_listAllIsolate, params);
    } catch (e) {
      printy(e, isError: true);
      return [];
    }
  }

  Future<int?> getTotalSize({bool recursive = false, bool followLinks = true}) async {
    try {
      final params = {
        'dirPath': path,
        'recursive': recursive,
        'followLinks': followLinks,
      };
      return await compute(_getDirSizeIsolate, params);
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }
}

List<FileSystemEntity> _listAllIsolate(Map params) {
  final dirPath = params['dirPath'] as String;
  final recursive = params['recursive'] as bool;
  final followLinks = params['followLinks'] as bool;
  return Directory(dirPath).listSync(recursive: recursive, followLinks: followLinks);
}

int _getDirSizeIsolate(Map params) {
  final dirPath = params['dirPath'] as String;
  final recursive = params['recursive'] as bool;
  final followLinks = params['followLinks'] as bool;
  int size = 0;
  Directory(dirPath).listSync(recursive: recursive, followLinks: followLinks).loop((e) {
    size += (e is File ? File(e.path).fileSizeSync() ?? 0 : 0);
  });
  return size;
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

final _minimumDateMicro = DateTime(1980).microsecondsSinceEpoch + 1;

extension FileStatsUtils on FileStat {
  DateTime get creationDate {
    int? finalDateMicro;
    void tryAssign(int micros) {
      if (micros > _minimumDateMicro && (finalDateMicro == null || micros < finalDateMicro!)) finalDateMicro = micros;
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
      final diff = offset - this.positions.last.pixels;

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
    String extension = ''; // represents the latest part
    final path = this;
    int latestIndex = path.length - 1;

    // -- skipping separator at the end.
    while (latestIndex >= 0 && path[latestIndex] == until) {
      latestIndex--;
    }

    while (latestIndex >= 0) {
      final char = path[latestIndex];
      if (char == until) break;
      extension = char + extension;
      latestIndex--;
    }
    return extension;
  }

  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }

  String ignoreCommonPrefixes() {
    var text = this;
    while (true) {
      final before = text;

      for (final prefix in settings.commonPrefixes.value) {
        if (text.startsWith(prefix)) {
          text = text.substring(prefix.length);
        }
      }

      if (text == before) {
        break;
      }
    }
    return text;
  }

  String toFastHashKey() {
    final s = this;
    int hash = 0;
    for (int i = 0; i < s.length; i++) {
      hash += s.codeUnitAt(i);
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
}

extension ClamperExtInt on int {
  int clampInt(int min, int max) {
    assert(min <= max && !max.isNaN && !min.isNaN);
    var x = this;
    if (x < min) return min;
    if (x > max) return max;
    if (x.isNaN) return max;
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
  bool isLight(Brightness? platformBrightness) {
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

extension DirectoryIndexServerUtils on Iterable<DirectoryIndexServer> {
  String toBodyText({bool? Function(DirectoryIndexServer d)? stillExistsCallback}) {
    return this.map((e) {
      final type = e.type.toText();
      final title = [type, e.username ?? '?'].joinText(separator: ' - ');
      final stillExists = stillExistsCallback?.call(e) ?? true;
      final removedText = stillExists ? '' : ' (${lang.REMOVED})';
      return "$title$removedText:\n${e.source}";
    }).join('\n\n');
  }
}
