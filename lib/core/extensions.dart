import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/strings.dart';

extension DurationLabel on Duration {
  String get label {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = "${twoDigits(inMinutes.remainder(60))}:";
    String twoDigitSeconds = twoDigits(inSeconds.remainder(60));
    String durinHour = inHours > 0 ? "${twoDigits(inHours)}:" : '';
    return "$durinHour$twoDigitMinutes$twoDigitSeconds";
  }
}

extension StringOverflow on String {
  String get overflow => this != '' ? characters.replaceAll(Characters(''), Characters('\u{200B}')).toString() : '';
}

extension PathFormat on String {
  String get formatPath => replaceFirst('/0', '').replaceFirst('/storage/', '').replaceFirst('emulated/', '');
}

extension UtilExtensions on String {
  List<String> multiSplit(Iterable<String> delimeters) => delimeters.isEmpty
      ? [this]
      : split(
          RegExp(delimeters.map(RegExp.escape).join('|')),
        );
}

extension Iterables<E> on Iterable<E> {
  Map<K, List<E>> groupBy<K>(K Function(E) keyFunction) => fold(
        <K, List<E>>{},
        (Map<K, List<E>> map, E element) => map..putIfAbsent(keyFunction(element), () => <E>[]).add(element),
      );
}

extension TracksDuration on List<Track> {
  int get totalDuration {
    int totalFinalDuration = 0;

    for (var t in this) {
      totalFinalDuration += t.duration ~/ 1000;
    }
    return totalFinalDuration;
  }

  String get totalDurationFormatted {
    int totalDurationFinal = totalDuration;
    String formattedTotalTracksDuration =
        "${Duration(seconds: totalDurationFinal).inHours == 0 ? "" : "${Duration(seconds: totalDurationFinal).inHours} h "}${Duration(seconds: totalDurationFinal).inMinutes.remainder(60) == 0 ? "" : "${Duration(seconds: totalDurationFinal).inMinutes.remainder(60) + 1} min"}";
    return formattedTotalTracksDuration;
  }

  // String get displayTrackKeyword {
  //   return '$length Track${length == 1 ? "" : "s"}';
  // }

  String get displayTrackKeyword {
    return '$length ${length == 1 ? Language.inst.TRACK : Language.inst.TRACKS}';
  }

  String get displayAlbumKeyword {
    return '$length ${length == 1 ? Language.inst.ALBUM : Language.inst.ALBUMS}';
  }
}

///
extension ArtistAlbums on String {
  Map<String?, Set<Track>> get artistAlbums {
    return Indexer.inst.getAlbumsForArtist(this);
  }
}

extension YearDateFormatted on int {
  String get yearFormatted {
    if (this == 0) {
      return '';
    }
    final formatDate = DateFormat('${SettingsController.inst.dateTimeFormat}');
    final yearFormatted = toString().length == 8 ? formatDate.format(DateTime.parse(toString())) : toString();

    return yearFormatted;
  }

  String get dateFormatted {
    //TODO: Date Format
    final formatDate = DateFormat('dd MMM yyyy');
    final dateFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(this));

    return dateFormatted;
  }
}

extension BorderRadiusSetting on double {
  double get multipliedRadius {
    return this * SettingsController.inst.borderRadiusMultiplier.value;
  }
}

extension TrackItemSubstring on TrackTileItem {
  String get label => toString().substring(14);
}

extension hh on String {
  String? get isValueEmpty {
    if (this == '') {
      return null;
    }
    return this;
  }
}

extension Channels on String {
  String? get channelToLabel {
    final ch = int.tryParse(this) ?? 3;
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

extension FileSizeFormat on int {
  String get fileSizeFormatted {
    const decimals = 2;
    if (this <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(this) / log(1024)).floor();
    return '${(this / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

extension LibraryTabToInt on LibraryTab {
  int get toInt {
    if (this == LibraryTab.albums) {
      return 0;
    }
    if (this == LibraryTab.tracks) {
      return 1;
    }
    if (this == LibraryTab.artists) {
      return 2;
    }
    if (this == LibraryTab.genres) {
      return 3;
    }
    if (this == LibraryTab.folders) {
      return 4;
    }
    return 1;
  }
}

extension LibraryTabToEnum on int {
  LibraryTab get toEnum {
    if (this == 0) {
      return LibraryTab.albums;
    }
    if (this == 1) {
      return LibraryTab.tracks;
    }
    if (this == 2) {
      return LibraryTab.artists;
    }
    if (this == 3) {
      return LibraryTab.genres;
    }
    if (this == 4) {
      return LibraryTab.folders;
    }
    return LibraryTab.tracks;
  }
}

extension SortToText on SortType {
  String get toText {
    if (this == SortType.title) {
      return Language.inst.TITLE;
    }
    if (this == SortType.album) {
      return Language.inst.ALBUM;
    }
    if (this == SortType.albumArtist) {
      return Language.inst.ALBUM_ARTIST;
    }
    if (this == SortType.artistsList) {
      return Language.inst.ARTISTS;
    }
    if (this == SortType.bitrate) {
      return Language.inst.BITRATE;
    }
    if (this == SortType.composer) {
      return Language.inst.COMPOSER;
    }
    if (this == SortType.dateAdded) {
      return Language.inst.DATE_ADDED;
    }
    if (this == SortType.dateModified) {
      return Language.inst.DATE_MODIFIED;
    }
    if (this == SortType.discNo) {
      return Language.inst.DISC_NUMBER;
    }
    if (this == SortType.displayName) {
      return Language.inst.FILE_NAME;
    }
    if (this == SortType.duration) {
      return Language.inst.DURATION;
    }
    if (this == SortType.genresList) {
      return Language.inst.GENRES;
    }
    if (this == SortType.sampleRate) {
      return Language.inst.SAMPLE_RATE;
    }
    if (this == SortType.size) {
      return Language.inst.SIZE;
    }
    if (this == SortType.year) {
      return Language.inst.YEAR;
    }

    return '';
  }
}
