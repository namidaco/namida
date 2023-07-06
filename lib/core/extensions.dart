// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';

extension DurationLabel on Duration {
  String get label {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = "${twoDigits(inMinutes.remainder(60))}:";
    final String twoDigitSeconds = twoDigits(inSeconds.remainder(60));
    final String durinHour = inHours > 0 ? "${twoDigits(inHours)}:" : '';
    return "$durinHour$twoDigitMinutes$twoDigitSeconds";
  }
}

extension StringUtils on String {
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

extension TracksUtils on List<Track> {
  String get totalSizeFormatted {
    int size = 0;
    loop((t, index) {
      size += t.size;
    });
    return size.fileSizeFormatted;
  }

  int get totalDurationInS {
    int totalFinalDurationInMs = 0;
    loop((t, index) {
      totalFinalDurationInMs += t.duration;
    });

    return totalFinalDurationInMs ~/ 1000;
  }

  String get totalDurationFormatted {
    return totalDurationInS.getTimeFormatted;
  }

  String get displayTrackKeyword {
    return '$length ${length == 1 ? Language.inst.TRACK : Language.inst.TRACKS}';
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

  int get indexOfImage => length - 1;

  Track get firstTrackWithImage {
    if (isEmpty) return kDummyTrack;
    return this[length - 1];
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
  /// Converts milliSecondsSinceEpoch to DaysSinceEpoch
  int toDaysSinceEpoch() {
    const msinday = 86400000;
    return (this / msinday).floor();
  }

  String get getTimeFormatted {
    final durInSec = Duration(seconds: this).inSeconds.remainder(60);

    if (Duration(seconds: this).inSeconds < 60) {
      return '${Duration(seconds: this).inSeconds}s';
    }

    final durInMin = Duration(seconds: this).inMinutes.remainder(60);
    final finalDurInMin = durInSec > 30 ? durInMin + 1 : durInMin;
    final durInHour = Duration(seconds: this).inHours;
    return "${durInHour == 0 ? "" : "${durInHour}h "}${durInMin == 0 ? "" : "${finalDurInMin}min"}";
  }
}

extension DisplayKeywords on int {
  String displayKeyword(String singular, String plural) {
    return '$this ${this > 1 ? plural : singular}';
  }

  String get displayTrackKeyword => displayKeyword(Language.inst.TRACK, Language.inst.TRACKS);
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
    final i = (log(this) / log(1024)).floor();
    return '${(this / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
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
    final index = TrackPlayMode.values.indexOf(this);
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
      queue = searchQueue ??
          (SearchSortController.inst.trackSearchTemp.isNotEmpty ? SearchSortController.inst.trackSearchTemp.toList() : SearchSortController.inst.trackSearchList.toList());
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
    final index = RepeatMode.values.indexOf(this);
    if (SettingsController.inst.playerRepeatMode.value.index + 1 == RepeatMode.values.length) {
      SettingsController.inst.save(playerRepeatMode: RepeatMode.values[0]);
    } else {
      SettingsController.inst.save(playerRepeatMode: RepeatMode.values[index + 1]);
    }
  }
}

extension ConvertPathToTrack on String {
  Track toTrack() => Track(this);
  Track? toTrackOrNull() => Indexer.inst.allTracksMappedByPath[toTrack()] == null ? null : toTrack();
  TrackExtended? toTrackExtOrNull() => Indexer.inst.allTracksMappedByPath[Track(this)];

  TrackExtended toTrackExt() {
    return toTrackExtOrNull() ??
        TrackExtended(
          getFilenameWOExt,
          '',
          [],
          '',
          '',
          '',
          [],
          '',
          0,
          0,
          0,
          0,
          0,
          0,
          this,
          '',
          0,
          0,
          '',
          '',
          0,
          '',
          '',
        );
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
  String formatDecimal([bool full = false]) => (full ? NumberFormat('#,###,###') : NumberFormat.compact()).format(this);
}

extension TagFieldsUtils on TagField {
  bool get isNumeric => this == TagField.trackNumber || this == TagField.trackTotal || this == TagField.discNumber || this == TagField.discTotal || this == TagField.year;
}

extension WAKELOCKMODETEXT on WakelockMode {
  void toggleSetting() {
    final index = WakelockMode.values.indexOf(this);
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
      debugPrint(e.toString());
      return false;
    }
    return false;
  }

  Future<bool> tryDeleting() async {
    try {
      await delete();
      return true;
    } catch (e) {
      debugPrint(e.toString());
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
      final content = await readAsString();
      if (content.isEmpty) return null;
      return jsonDecode(content);
    } catch (e) {
      debugPrint(e.toString());
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
      debugPrint(e.toString());
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
  Future<File?> writeAsJson(Object? object, {Object? Function(Object? nonEncodable)? toEncodable}) async {
    try {
      await create(recursive: true);
      const encoder = JsonEncoder.withIndent("  ");
      return (await writeAsString(encoder.convert(object)));
    } catch (e) {
      debugPrint('$e');
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
    return minimum + (Random().nextInt(this));
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

extension ListieExt<E, Id> on List<E> {
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

  List<E> uniqued(Id Function(E element)? id) {
    final uniquedSet = <dynamic>{};
    final list = List<E>.from(this);
    list.retainWhere((e) => uniquedSet.add(id != null ? id(e) : e));
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
