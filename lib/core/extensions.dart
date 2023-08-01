// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';

extension SecondsLabel on int {
  String get secondsLabel {
    if (this == 0) {
      return "00:00";
    }
    String heyPad(int n) => n.toString().padLeft(2, "0");
    final minutes = this ~/ 60;
    final seconds = this % 60;
    final durinHour = this >= 3600 ? "${heyPad(this ~/ 3600)}:" : '';
    return "$durinHour${heyPad(minutes)}:${heyPad(seconds)}";
  }

  String get milliSecondsLabel => (this ~/ 1000).secondsLabel;
}

extension StringUtilsNull on String? {
  int? getIntValue() {
    final value = this;
    if (value == null) return null;
    int? res;
    res = int.tryParse(value);
    res ??= int.tryParse(value.cleanUpForComparison);

    return res;
  }

  double? getDoubleValue() {
    final value = this;
    if (value == null) return null;
    double? res;
    res = double.tryParse(value);
    return res;
  }
}

extension StringUtils on String {
  /// Trims a string and removes all extra white spaces.
  String trimAll() {
    // second time ensures removing extra ones if number of white spaces is odd, for ex:
    // 1. 'W...H' => 'W..H'
    // 2. 'W..H' => 'W.H'
    return replaceAll('  ', ' ')
      ..replaceAll('  ', ' ')
      ..trim();
  }

  String addQuotation() => "'$this'";
  String addDQuotation() => '"$this"';

  String get overflow => this != '' ? characters.replaceAll(Characters(''), Characters('\u{200B}')).toString() : '';

  String formatPath() {
    String formatted = replaceFirst('/storage/', '/').replaceFirst('/emulated/0', 'main');
    if (formatted[0] == '/') {
      formatted = formatted.substring(1);
    }
    return formatted;
  }

  String withoutLast(String splitBy) {
    final parts = split(splitBy);
    parts.removeLast();
    return parts.join(splitBy);
  }

  List<String> multiSplit(Iterable<String> delimiters, Iterable<String> blacklist) {
    if (blacklist.any((s) => contains(s))) {
      return [this];
    } else {
      return delimiters.isEmpty
          ? [this]
          : split(
              RegExp(delimiters.map(RegExp.escape).join('|'), caseSensitive: false),
            );
    }
  }

  String get cleanUpForComparison => toLowerCase()
      .replaceAll(RegExp(r'''[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\>\=\?\@\[\]\{\}\\\\\^\_\`\~\s\|\@\#\$\%\^\&\*\(\)\-\+\=\[\]\{\}\:\;\"\'\<\>\.\,\?\/\`\~\!\_\s]+'''), '');
}

extension Iterables<E> on Iterable<E> {
  Map<K, List<E>> groupBy<K>(K Function(E) keyFunction) => fold(
        <K, List<E>>{},
        (Map<K, List<E>> map, E element) => map..putIfAbsent(keyFunction(element), () => <E>[]).add(element),
      );
  Map<K, E> groupByToSingleValue<K>(K Function(E) keyFunction) => fold(
        <K, E>{},
        (Map<K, E> map, E element) => map..[keyFunction(element)] = element,
      );
}

extension TracksSelectableUtils on List<Selectable> {
  String get displayTrackKeyword => length.displayTrackKeyword;

  List<String> toImagePaths([int? limit = 4]) => withLimit(limit).map((e) => e.track.pathToImage).toList();
}

extension TracksWithDatesUtils on List<TrackWithDate> {
  int get totalDurationInS => fold(0, (previousValue, element) => previousValue + element.track.duration);
  String get totalDurationFormatted {
    return totalDurationInS.getTimeFormatted;
  }
}

extension TracksUtils on List<Track> {
  String get totalSizeFormatted {
    int size = 0;
    loop((t, index) {
      size += t.size;
    });
    return size.fileSizeFormatted;
  }

  int get totalDurationInS => fold(0, (previousValue, element) => previousValue + element.duration);

  String get totalDurationFormatted {
    return totalDurationInS.getTimeFormatted;
  }

  int get year {
    if (isEmpty) return 0;
    for (int i = length - 1; i >= 0; i--) {
      final y = this[i].year;
      if (y != 0) return y;
    }
    return 0;
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
}

extension MSSEUtils on int? {
  DateTime? get milliSecondsSinceEpoch => this == null ? null : DateTime.fromMillisecondsSinceEpoch(this!);
}

extension TotalTime on int {
  /// Converts milliSecondsSinceEpoch to DaysSinceEpoch.
  ///
  /// Note: using normal way of getting day doesnt give a shit about local time, this one works just fine.
  int toDaysSinceEpoch() => DateTime.fromMillisecondsSinceEpoch(this).difference(DateTime(1970)).inDays;

  String get getTimeFormatted {
    final totalSeconds = this;
    final durInSec = totalSeconds % 60;

    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }

    final totalMinutes = totalSeconds ~/ 60;
    final durInMin = totalMinutes % 60;
    final finalDurInMin = durInSec > 30 ? durInMin + 1 : durInMin;
    final totalHours = totalMinutes ~/ 60;

    final hoursText = totalHours == 0 ? "" : "${totalHours}h ";
    final minsText = durInMin == 0 ? "" : "${finalDurInMin}min";
    return "$hoursText$minsText";
  }
}

extension DisplayKeywords on int {
  String displayKeyword(String singular, String plural) {
    return '${formatDecimal()} ${this > 1 ? plural : singular}';
  }

  String get displayTrackKeyword => displayKeyword(Language.inst.TRACK, Language.inst.TRACKS);
  String get displayDayKeyword => displayKeyword(Language.inst.DAY, Language.inst.DAYS);
  String get displayAlbumKeyword => displayKeyword(Language.inst.ALBUM, Language.inst.ALBUMS);
  String get displayArtistKeyword => displayKeyword(Language.inst.ARTIST, Language.inst.ARTISTS);
  String get displayGenreKeyword => displayKeyword(Language.inst.GENRE, Language.inst.GENRES);
  String get displayFolderKeyword => displayKeyword(Language.inst.FOLDER, Language.inst.FOLDERS);
  String get displayPlaylistKeyword => displayKeyword(Language.inst.PLAYLIST, Language.inst.PLAYLISTS);
}

extension YearDateFormatted on int {
  String get yearFormatted {
    if (this == 0) {
      return '';
    }
    final formatDate = DateFormat(SettingsController.inst.dateTimeFormat.value);
    final yearFormatted = toString().length == 8 ? formatDate.format(DateTime.parse(toString())) : toString();

    return yearFormatted;
  }

  String formatTimeFromMSSE(String format) => DateFormat(format).format(DateTime.fromMillisecondsSinceEpoch(this));

  String get dateFormatted => formatTimeFromMSSE(SettingsController.inst.dateTimeFormat.value);

  String get dateFormattedOriginal => formatTimeFromMSSE('dd MMM yyyy');

  String get clockFormatted => formatTimeFromMSSE(SettingsController.inst.hourFormat12.value ? 'hh:mm aa' : 'HH:mm');

  /// this one gurantee that the format will return with the day included, even if the format in setting doesnt have day.
  /// if (valInSet.contains('d')) return userformat;
  /// else return dateFormattedOriginal ('dd MMM yyyy');
  String get dateAndClockFormattedOriginal {
    final valInSet = SettingsController.inst.dateTimeFormat.value;
    if (valInSet.contains('d')) {
      return dateAndClockFormatted;
    }
    return [dateFormattedOriginal, clockFormatted].join(' - ');
  }

  String get dateAndClockFormatted => [dateFormatted, clockFormatted].join(' - ');
}

extension BorderRadiusSetting on double {
  double get multipliedRadius {
    return this * SettingsController.inst.borderRadiusMultiplier.value;
  }
}

extension FontScaleSetting on double {
  double get multipliedFontScale {
    return this * SettingsController.inst.fontScaleFactor.value;
  }
}

extension TrackItemSubstring on TrackTileItem {
  String get label => convertToString;
}

extension Channels on String {
  String? get channelToLabel {
    final ch = int.tryParse(this);
    if (ch == 0) {
      return '';
    }
    if (ch == 1) {
      return 'mono';
    }
    if (ch == 2) {
      return 'stereo';
    }
    return this;
  }
}

extension FavouriteTrack on Track {
  bool get isFavourite {
    return PlaylistController.inst.favouritesPlaylist.value.tracks.firstWhereOrNull((element) => element.track == this) != null;
  }
}

extension FileSizeFormat on int {
  String get fileSizeFormatted {
    const decimals = 2;
    if (this <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    final i = (math.log(this) / math.log(1024)).floor();
    return '${(this / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

extension FileNameUtils on String {
  String get getFilename => p.basename(this);
  String get getFilenameWOExt => p.basenameWithoutExtension(this);
  String get getExtension => p.extension(this).substring(1);
  String get getDirectoryName => p.dirname(this);
  String get getDirectoryPath => withoutLast(Platform.pathSeparator);
}

extension EnumUtils on Enum {
  String get convertToString => toString().split('.').last;
}

extension PLNAME on String {
  String translatePlaylistName() => replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, Language.inst.AUTO_GENERATED)
      .replaceFirst(k_PLAYLIST_NAME_FAV, Language.inst.FAVOURITES)
      .replaceFirst(k_PLAYLIST_NAME_HISTORY, Language.inst.HISTORY)
      .replaceFirst(k_PLAYLIST_NAME_MOST_PLAYED, Language.inst.MOST_PLAYED);
}

extension TRACKPLAYMODE on TrackPlayMode {
  void toggleSetting() {
    if (SettingsController.inst.trackPlayMode.value.index + 1 == TrackPlayMode.values.length) {
      SettingsController.inst.save(trackPlayMode: TrackPlayMode.values[0]);
    } else {
      SettingsController.inst.save(trackPlayMode: TrackPlayMode.values[index + 1]);
    }
  }

  bool get shouldBeIndex0 => this == TrackPlayMode.selectedTrack || this == TrackPlayMode.trackAlbum || this == TrackPlayMode.trackArtist || this == TrackPlayMode.trackGenre;

  List<Track> getQueue(Track trackPre, {List<Track>? searchQueue}) {
    List<Track> queue = [];
    final track = trackPre.toTrackExt();
    if (this == TrackPlayMode.selectedTrack) {
      queue = [trackPre];
    }
    if (this == TrackPlayMode.searchResults) {
      queue = searchQueue ?? (SearchSortController.inst.trackSearchTemp.isNotEmpty ? SearchSortController.inst.trackSearchTemp : SearchSortController.inst.trackSearchList);
    }
    if (this == TrackPlayMode.trackAlbum) {
      queue = track.album.getAlbumTracks();
    }
    if (this == TrackPlayMode.trackArtist) {
      queue = track.artistsList.first.getArtistTracks();
    }
    if (this == TrackPlayMode.trackGenre) {
      queue = track.artistsList.first.getGenresTracks();
    }
    if (shouldBeIndex0) {
      queue.remove(trackPre);
      queue.insertSafe(0, trackPre);
    }
    return queue;
  }
}

extension PlayerRepeatModeUtils on RepeatMode {
  void toggleSetting() {
    if (SettingsController.inst.playerRepeatMode.value.index + 1 == RepeatMode.values.length) {
      SettingsController.inst.save(playerRepeatMode: RepeatMode.values[0]);
    } else {
      SettingsController.inst.save(playerRepeatMode: RepeatMode.values[index + 1]);
    }
  }
}

extension ConvertPathToTrack on String {
  Future<Track> toTrackOrExtract() async => toTrackOrNull() ?? await Indexer.inst.extractOneTrack(trackPath: this).then((value) => value!.toTrack());
  Track toTrack() => Track(this);
  Track? toTrackOrNull() => Indexer.inst.allTracksMappedByPath[toTrack()] == null ? null : toTrack();
  TrackExtended? toTrackExtOrNull() => Indexer.inst.allTracksMappedByPath[Track(this)];

  TrackExtended toTrackExt() {
    return toTrackExtOrNull() ?? kDummyExtendedTrack.copyWith(title: getFilenameWOExt, path: this);
  }
}

extension YTLinkToID on String {
  String get getYoutubeID {
    String videoId = '';
    if (length >= 11) {
      videoId = substring(length - 11);
    }
    return videoId;
  }
}

extension FORMATNUMBER on int? {
  String formatDecimalShort([bool full = false]) => (full ? NumberFormat('#,###,###') : NumberFormat.compact()).format(this);
  String formatDecimal() => NumberFormat('#,###,###').format(this);
}

extension TagFieldsUtils on TagField {
  bool get isNumeric => this == TagField.trackNumber || this == TagField.trackTotal || this == TagField.discNumber || this == TagField.discTotal || this == TagField.year;
}

extension WAKELOCKMODETEXT on WakelockMode {
  void toggleSetting() {
    if (SettingsController.inst.wakelockMode.value.index + 1 == WakelockMode.values.length) {
      SettingsController.inst.save(wakelockMode: WakelockMode.values[0]);
    } else {
      SettingsController.inst.save(wakelockMode: WakelockMode.values[index + 1]);
    }
  }
}

extension FileUtils<R> on File {
  Future<bool> existsAndValid([int minValidSize = 3]) async {
    final st = await stat();
    final doesExist = await exists();
    return (doesExist && st.size >= minValidSize);
  }

  bool existsAndValidSync([int minValidSize = 3]) {
    return existsSync() && statSync().size >= minValidSize;
  }

  /// returns [true] if deleted successfully. or [false] if failed.
  Future<bool> deleteIfExists() async {
    try {
      if (await exists()) {
        await delete();
        return true;
      }
    } catch (e) {
      printy(e, isError: true);
      return false;
    }
    return false;
  }

  Future<bool> tryDeleting() async {
    try {
      await delete();
      return true;
    } catch (e) {
      printy(e, isError: true);
      return false;
    }
  }

  /// returns [true] if deleted successfully.
  bool deleteIfExistsSync() {
    if (existsSync()) {
      deleteSync();
      return true;
    }
    return false;
  }

  /// Returns decoded [response] if executed successfully.
  ///
  /// Otherwise, executes [onError] and returns [null].
  ///
  /// has a built in try-catch.
  Future<dynamic> readAsJson({void Function()? onError}) async {
    try {
      await create(recursive: true);
      final content = await readAsString();
      if (content.isEmpty) return null;
      return jsonDecode(content);
    } catch (e) {
      printy(e, isError: true);
      if (onError != null) onError();
      return null;
    }
  }

  /// returns [true] if executed successfully.
  ///
  /// Otherwise, executes [onError] and returns [false].
  ///
  /// has a built in try-catch.
  Future<bool> readAsJsonAnd(Future<void> Function(R response) execute, {void Function()? onError}) async {
    final respone = await readAsJson(onError: onError);
    if (respone == null) return false;

    try {
      await execute(respone);
      return true;
    } catch (e) {
      if (onError != null) onError();
      printy(e, isError: true);
      return false;
    }
  }

  Future<bool> readAsJsonAndLoop(
    void Function(dynamic item, int index) execute, {
    void Function(List? responseList)? onListReady,
    void Function()? onError,
  }) async {
    final success = await readAsJsonAnd(
      (response) async {
        response as List?;
        if (onListReady != null) onListReady(response ?? []);

        (response)?.loop((e, index) {
          execute(e, index);
        });
      },
      onError: onError,
    );
    return success;
  }

  /// Automatically creates the file if it doesnt exist
  ///
  /// Has a built-in try-catch that returns [File] if wrote successfully, or [null] if failed.
  Future<File?> writeAsJson(Object? object) async {
    try {
      await create(recursive: true);
      const encoder = JsonEncoder.withIndent("  ");
      return (await writeAsString(encoder.convert(object)));
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }
}

extension NumberUtils<E extends num> on E {
  E withMinimum(E min) {
    if (this < min) return min;
    return this;
  }

  E withMaximum(E max) {
    if (this > max) return max;
    return this;
  }
}

extension IntUtils on int {
  int getRandomNumberBelow([int minimum = 0]) {
    return minimum + (math.Random().nextInt(this));
  }
}

extension MapExtNull<K, E> on Map<K, List<E>?> {
  void addForce(K key, E item) {
    if (keyExists(key)) {
      this[key]!.add(item);
    } else {
      this[key] = <E>[item];
    }
  }

  void insertForce(int index, K key, E item) {
    if (keyExists(key)) {
      this[key]!.insert(index, item);
    } else {
      this[key] = <E>[item];
    }
  }

  /// Same as [addNoDuplicates], but initializes new list in case list was null.
  /// i.e: entry doesnt exist in map.
  void addNoDuplicatesForce(K key, E item, {bool preventDuplicates = true}) {
    if (keyExists(key)) {
      this[key]!.addNoDuplicates(item, preventDuplicates: preventDuplicates);
    } else {
      this[key] = <E>[item];
    }
  }

  void addAllNoDuplicatesForce(K key, Iterable<E> items, {bool preventDuplicates = true}) {
    if (keyExists(key)) {
      this[key]!.addAllNoDuplicates(items, preventDuplicates: preventDuplicates);
    } else {
      this[key] = items.toList();
    }
  }
}

extension StuffUtils<T> on T {
  T toIf(T convertTo, T ifValueEquals) => this == ifValueEquals ? convertTo : this;
}

extension ListieExt<E, Id> on List<E> {
  /// Adds [item] to [this] if it doesn't exist,
  /// or removes [item] if it exists.
  void addOrRemove(E item) {
    final didRemove = remove(item);
    if (!didRemove) {
      add(item);
    }
  }

  /// Replaces All Items that fullfils [test] with [newElement] inside the list.
  void replaceWhere(bool Function(E e) test, E Function(E old) newElement, {void Function()? onMatch}) {
    loop((currentElement, index) {
      if (test(currentElement)) {
        this[index] = newElement(currentElement);
        if (onMatch != null) onMatch();
      }
    });
  }

  /// Replaces Single Item inside the list.
  void replaceSingleWhere(bool Function(E e) test, E Function(E old) newElement, {void Function()? onMatch}) {
    for (int i = 0; i <= length - 1; i++) {
      final currentElement = this[i];
      if (test(currentElement)) {
        this[i] = newElement(currentElement);
        if (onMatch != null) onMatch();
        break;
      }
    }
  }

  /// Replaces All Items that matches [oldElement] with [newElement] inside the list.
  void replaceItems(E oldElement, E newElement, {void Function()? onMatch}) {
    loop((currentElement, index) {
      if (currentElement == oldElement) {
        this[index] = newElement;
        if (onMatch != null) onMatch();
      }
    });
  }

  /// Replaces Single Item inside the list.
  void replaceItem(E oldElement, E newElement, {void Function()? onMatch}) {
    for (int i = 0; i <= length - 1; i++) {
      final currentElement = this[i];
      if (currentElement == oldElement) {
        this[i] = newElement;
        if (onMatch != null) onMatch();
        break;
      }
    }
  }

  E? getEnum(String? string) => firstWhereOrNull((element) => element.toString().split('.').last == string);
  void insertSafe(int index, E object) => insert(index.clamp(0, length), object);
  void insertAllSafe(int index, Iterable<E> objects) => insertAll(index.clamp(0, length), objects);

  void sortBy(Comparable Function(E e) key) => sort((a, b) => key(a).compareTo(key(b)));
  void sortByReverse(Comparable Function(E e) key) => sort((a, b) => key(b).compareTo(key(a)));

  void sortByAlt(Comparable Function(E e) key, Comparable Function(E e) alternative) => sort((a, b) {
        final compare = key(a).compareTo(key(b));
        if (compare == 0) {
          return alternative(a).compareTo(alternative(b));
        }
        return compare;
      });
  void sortByReverseAlt(Comparable Function(E e) key, Comparable Function(E e) alternative) => sort((a, b) {
        final compare = key(b).compareTo(key(a));
        if (compare == 0) {
          return alternative(b).compareTo(alternative(a));
        }
        return compare;
      });

  /// returns number of items removed.
  int removeWhereWithDifference(bool Function(E element) test) {
    final lengthBefore = length;
    removeWhere(test);
    final lengthAfter = length;
    return lengthBefore - lengthAfter;
  }

  bool isEqualTo(List<E> q2) {
    final q1 = this;
    if (q1.isEmpty && q2.isEmpty) {
      return true;
    }
    if (q1.length != q2.length) {
      return false;
    }
    final finalLength = q1.length > q2.length ? q2.length : q1.length;

    for (int i = 0; i < finalLength; i++) {
      if (q1[i] != q2[i]) {
        return false;
      }
    }
    return true;
  }

  /// returns number of items removed.
  int removeDuplicates([Id Function(E element)? id]) {
    final uniquedSet = <dynamic>{};
    final lengthBefore = length;
    retainWhere((e) => uniquedSet.add(id != null ? id(e) : e));
    final lengthAfter = length;
    return lengthBefore - lengthAfter;
  }

  List<E> uniqued([Id Function(E element)? id]) {
    final uniquedSet = <dynamic>{};
    final list = List<E>.from(this);
    list.retainWhere((e) => uniquedSet.add(id != null ? id(e) : e));
    return list;
  }

  List<T> mapped<T>(T Function(E e) toElement) {
    final list = <T>[];
    loop((el, index) {
      list.add(toElement(el));
    });
    return list;
  }

  List<T> mappedUniqued<T>(T Function(E e) toElement) {
    final list = mapped(toElement);
    list.removeDuplicates();
    return list;
  }

  List<T> mappedUniquedList<T>(Iterable<T> Function(E e) toElement) {
    final list = <T>[];
    loop((el, index) {
      list.addAll(toElement(el));
    });
    list.removeDuplicates();
    return list;
  }

  void addNoDuplicates(E item, {bool preventDuplicates = true}) {
    if (preventDuplicates && contains(item)) return;

    add(item);
  }

  void addAllNoDuplicates(Iterable<E> item, {bool preventDuplicates = true}) {
    addAll(item);
    if (preventDuplicates) {
      removeDuplicates();
    }
  }

  /// Efficient version of lastWhere()
  E? lastWhereEff(bool Function(E e) test, {E? fallback}) {
    for (int i = length - 1; i >= 0; i--) {
      final element = this[i];
      if (test(element)) {
        return element;
      }
    }
    return fallback;
  }

  /// Efficient version of firstWhere()
  E? firstWhereEff(bool Function(E e) test, {E? fallback}) {
    for (int i = 0; i < length; i++) {
      final element = this[i];
      if (test(element)) {
        return element;
      }
    }
    return fallback;
  }

  /// Efficient looping, uses normal for loop.
  ///
  /// Doesn't support keywork statements like [break], [continue], etc...
  void loop(void Function(E e, int index) function) async {
    for (int i = 0; i < length; i++) {
      final element = this[i];
      function(element, i);
    }
  }

  void retainWhereAdvanced(bool Function(E element, int index) test, {int? keepIndex}) {
    final indexesToRemove = <int>[];

    loop((element, index) {
      if (!test(element, index)) {
        indexesToRemove.add(index);
      }
    });

    indexesToRemove.remove(keepIndex);
    indexesToRemove.reverseLoop((indexToRemove, index) {
      removeAt(indexToRemove);
    });
  }

  Future<void> loopFuture(Future<void> Function(E e, int index) function) async {
    for (int i = 0; i < length; i++) {
      final element = this[i];
      await function(element, i);
    }
  }

  /// Efficent looping, uses normal for loop.
  ///
  /// Doesn't support keywork statements like [return], [break], [continue], etc...
  void reverseLoop(void Function(E e, int index) function) {
    for (int i = length - 1; i >= 0; i--) {
      final item = this[i];
      function(item, i);
    }
  }

  E? get firstOrNull => isEmpty ? null : this[0];
  E? get lastOrNull => isEmpty ? null : this[length - 1];
}

extension IterableUtils<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
  E? get lastOrNull => isEmpty ? null : last;

  Iterable<E> withLimit([int? limit]) => limit != null ? take(limit) : this;
}

extension WidgetsSeparator on Iterable<Widget> {
  Iterable<Widget> addSeparators({required Widget separator, int skipFirst = 0}) sync* {
    final iterator = this.iterator;
    int count = 0;

    while (iterator.moveNext()) {
      if (count < skipFirst) {
        yield iterator.current;
      } else {
        yield separator;
        yield iterator.current;
      }
      count++;
    }
  }
}

extension MapUtils<K, V> on Map<K, V> {
  /// [keyExists] : Less accurate but instant, O(1).
  /// Shouldn't be used if the value could be null.
  ///
  /// [containsKey] : Certain but not instant, O(keys.length).
  bool keyExists(K key) => this[key] != null;
}

extension CloseDialogIfTrue on bool {
  /// Closes dialog if [this == true].
  ///
  /// This is mainly created for [addToQueue] Function inside Player Class,
  /// where it should close the dialog only if there were tracks added.
  void closeDialog([int count = 1]) => executeIfTrue(() => NamidaNavigator.inst.closeDialog(count));

  void executeIfTrue<T>(T Function() execute) {
    if (this) execute();
  }
}

extension PrintFunction on dynamic {
  void printy(dynamic message, {bool isError = false, bool dumpshit = false}) {
    printo(message, isError: isError, classScope: this, dumpshit: dumpshit);
  }
}

/// logs the message only in Debug mode.
void printo(dynamic message, {bool isError = false, dynamic classScope, bool dumpshit = false}) {
  if (kDebugMode) {
    final className = classScope ?? '';
    final isClassNameLong = className.toString().split('').length > 50;
    final msgWithClass = "[$className]: ${isClassNameLong ? '\n' : ''} $message";
    final infoMsg = isError ? '' : 'Info: $msgWithClass';
    final errorMsg = isError ? 'Error: $msgWithClass' : '';
    final color = dumpshit ? '\x1B[37m' : '';
    dev.log('$color$infoMsg', error: errorMsg, name: 'Namida');
  }
}
