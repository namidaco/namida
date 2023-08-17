// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:dart_extensions/dart_extensions.dart';

export 'package:dart_extensions/dart_extensions.dart';

extension TracksSelectableUtils on List<Selectable> {
  String get displayTrackKeyword => length.displayTrackKeyword;

  List<String> toImagePaths([int? limit = 4]) => withLimit(limit).map((e) => e.track.pathToImage).toList();
}

extension TracksWithDatesUtils on List<TrackWithDate> {
  int get totalDurationInS => fold(0, (previousValue, element) => previousValue + element.track.duration);
  String get totalDurationFormatted {
    return totalDurationInS.formattedTime;
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

extension DisplayKeywords on int {
  String get displayTrackKeyword => displayKeyword(Language.inst.TRACK, Language.inst.TRACKS);
  String get displayDayKeyword => displayKeyword(Language.inst.DAY, Language.inst.DAYS);
  String get displayAlbumKeyword => displayKeyword(Language.inst.ALBUM, Language.inst.ALBUMS);
  String get displayArtistKeyword => displayKeyword(Language.inst.ARTIST, Language.inst.ARTISTS);
  String get displayGenreKeyword => displayKeyword(Language.inst.GENRE, Language.inst.GENRES);
  String get displayFolderKeyword => displayKeyword(Language.inst.FOLDER, Language.inst.FOLDERS);
  String get displayPlaylistKeyword => displayKeyword(Language.inst.PLAYLIST, Language.inst.PLAYLISTS);
}

extension YearDateFormatted on int {
  String get formattedTime => getTimeFormatted(hourChar: 'h', minutesChar: 'min', separator: ' ');

  String get yearFormatted => getYearFormatted(SettingsController.inst.dateTimeFormat.value);

  String get dateFormatted => formatTimeFromMSSE(SettingsController.inst.dateTimeFormat.value);

  String get dateFormattedOriginal {
    final valInSetting = SettingsController.inst.dateTimeFormat.value;
    return getDateFormatted(format: valInSetting.contains('d') ? SettingsController.inst.dateTimeFormat.value : 'dd MMM yyyy');
  }

  String dateFormattedOriginalNoYears(DateTime diffDate) {
    final valInSettingMain = SettingsController.inst.dateTimeFormat.value;
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

  String get clockFormatted => getClockFormatted(SettingsController.inst.hourFormat12.value);

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
    return PlaylistController.inst.favouritesPlaylist.value.tracks.firstWhereEff((element) => element.track == this) != null;
  }
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

extension CloseDialogIfTrue on bool {
  /// Closes dialog if [this == true].
  ///
  /// This is mainly created for [addToQueue] Function inside Player Class,
  /// where it should close the dialog only if there were tracks added.
  void closeDialog([int count = 1]) => executeIfTrue(() => NamidaNavigator.inst.closeDialog(count));
}

extension ThreadOpener<M, R> on ComputeCallback<M, R> {
  /// Executes function on a separate thread using compute().
  /// Must be `static` or `global` function.
  Future<R> thready(M parameter) async {
    WidgetsFlutterBinding.ensureInitialized();
    return await compute(this, parameter);
  }
}
