// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dart_extensions/dart_extensions.dart';
import 'package:lrc/lrc.dart';

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
import 'package:namida/packages/lyrics_parser/parser_smart.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

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
  int get totalDurationInS => fold(0, (previousValue, element) => previousValue + element.track.duration);
  String get totalDurationFormatted {
    return totalDurationInS.formattedTime;
  }
}

extension TracksUtils on List<Track> {
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

  int get totalDurationInS => fold(0, (previousValue, element) => previousValue + element.duration);

  String get totalDurationFormatted {
    return totalDurationInS.formattedTime;
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
}

extension YearDateFormatted on int {
  String get formattedTime => getTimeFormatted(hourChar: 'h', minutesChar: 'min', separator: ' ');

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
    return PlaylistController.inst.favouritesPlaylist.value.tracks.firstWhereEff((element) => element.track == this) != null;
  }

  bool get isFavouriteR {
    // ignore: avoid_rx_value_getter_outside_obx
    return PlaylistController.inst.favouritesPlaylist.valueR.tracks.firstWhereEff((element) => element.track == this) != null;
  }
}

extension PLNAME on String {
  String translatePlaylistName({bool liked = false}) => replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, lang.AUTO_GENERATED)
      .replaceFirst(k_PLAYLIST_NAME_FAV, liked ? lang.LIKED : lang.FAVOURITES)
      .replaceFirst(k_PLAYLIST_NAME_HISTORY, lang.HISTORY)
      .replaceFirst(k_PLAYLIST_NAME_MOST_PLAYED, lang.MOST_PLAYED);
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

extension ConvertPathToTrack on String {
  Future<TrackExtended?> removeTrackThenExtract({bool onlyIfNewFileExists = true}) async {
    if (onlyIfNewFileExists && !await File(this).exists()) return null;
    Indexer.inst.allTracksMappedByPath.value.remove(Track(this));
    return await Indexer.inst.extractTrackInfo(
      trackPath: this,
      onMinDurTrigger: () => null,
      onMinSizeTrigger: () => null,
    );
  }

  Future<TrackExtended?> toTrackExtOrExtract() async {
    final initial = toTrackExtOrNull();
    if (initial != null) return initial;
    return await Indexer.inst.extractTrackInfo(
      trackPath: this,
      onMinDurTrigger: () => null,
      onMinSizeTrigger: () => null,
    );
  }

  Track toTrack() => Track(this);
  Track? toTrackOrNull() => Indexer.inst.allTracksMappedByPath[toTrack()] == null ? null : toTrack();
  TrackExtended? toTrackExtOrNull() => Indexer.inst.allTracksMappedByPath[Track(this)];

  TrackExtended toTrackExt() {
    return toTrackExtOrNull() ?? kDummyExtendedTrack.copyWith(title: getFilenameWOExt, path: this);
  }
}

extension YTLinkToID on String {
  String get getYoutubeID {
    final match = NamidaLinkRegex.youtubeIdRegex.firstMatch(this);
    final idAndMore = match?.group(5);
    final id = idAndMore?.length == 11 ? idAndMore : null;
    return id ?? '';
  }
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
      final artist = match2.group(1)?.trim();
      final title = match2.group(2)?.trim();
      if (artist != null && title != null) {
        final a = artist.startsWith('「') ? artist.replaceRange(0, 1, '') : artist;
        return (a, title);
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
      r'\s*\((?!remix|featured|ft\.|feat\.|featuring)(?!.*Remix)[^)]*\)|\s*\[(?!remix|featured|ft\.|feat\.|featuring)(?!.*Remix)[^\]]*\]',
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
      return toLrc();
    } catch (_) {
      try {
        final res = LRCParserSmart(this).parseLines();
        final lines = res
            .map(
              (e) => LrcLine(
                timestamp: e.timeStamp ?? Duration.zero,
                lyrics: e.mainText ?? '',
                type: LrcTypes.simple,
              ),
            )
            .toList();
        return Lrc(lyrics: lines);
      } catch (_) {}
    }
    return null;
  }
}

extension TagFieldsUtils on TagField {
  bool get isNumeric => this == TagField.trackNumber || this == TagField.trackTotal || this == TagField.discNumber || this == TagField.discTotal || this == TagField.year;
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

extension ThreadOpener<M, R> on ComputeCallback<M, R> {
  /// Executes function on a separate thread using compute().
  /// Must be `static` or `global` function.
  Future<R> thready(M parameter) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
    } catch (_) {}
    return await compute(this, parameter);
  }
}

extension FunctionsExecuter<T> on Iterable<Future<T>?> {
  Future<List<T>> execute() async {
    return await Future.wait(whereType<Future<T>>());
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
  Future<int?> fileSize() async {
    try {
      return await length();
    } catch (e) {
      return null;
    }
  }

  int? fileSizeSync() {
    try {
      return lengthSync();
    } catch (e) {
      return null;
    }
  }

  String? fileSizeFormatted() {
    return fileSizeSync()?.fileSizeFormatted;
  }

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

final _minimumDateMicro = DateTime(1970).microsecondsSinceEpoch + 1;

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
    return await executeDelayed(Duration(milliseconds: durationMS));
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
    while (latestIndex > 0 && path[latestIndex] == until) {
      latestIndex--;
    }

    while (latestIndex > 0) {
      final char = path[latestIndex];
      if (char == until) break;
      extension = char + extension;
      latestIndex--;
    }
    return extension;
  }
}
