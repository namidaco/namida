// ignore_for_file: depend_on_referenced_packages

import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/folders_page.dart';
import 'package:namida/ui/pages/genres_page.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/pages/tracks_page.dart';

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

extension AllDirInDir on String {
  List<String> get getDirectoriesInside {
    final allFolders = Indexer.inst.groupedFoldersMap;
    return allFolders.keys.where((key) => key.startsWith(this)).toList();
  }
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

extension TracksUtils on List<Track> {
  int get totalDuration {
    int totalFinalDuration = 0;

    for (var t in this) {
      totalFinalDuration += t.duration ~/ 1000;
    }
    return totalFinalDuration;
  }

  String get totalDurationFormatted {
    return totalDuration.getTimeFormatted;
  }

  String get displayTrackKeyword {
    return '$length ${length == 1 ? Language.inst.TRACK : Language.inst.TRACKS}';
  }
}

extension TotalTime on int {
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
  String get displayAlbumKeyword {
    return '$this ${this == 1 ? Language.inst.ALBUM : Language.inst.ALBUMS}';
  }

  String get displayArtistKeyword {
    return '$this ${this == 1 ? Language.inst.ARTIST : Language.inst.ARTISTS}';
  }

  String get displayGenreKeyword {
    return '$this ${this == 1 ? Language.inst.GENRE : Language.inst.GENRES}';
  }

  String get displayPlaylistKeyword {
    return '$this ${this == 1 ? Language.inst.PLAYLIST : Language.inst.PLAYLISTS}';
  }

  String get displayFolderKeyword {
    return '$this ${this == 1 ? Language.inst.FOLDER : Language.inst.FOLDERS}';
  }
}

extension PlaylistUtils on List<Playlist> {
  String get displayPlaylistKeyword {
    return '$length ${length == 1 ? Language.inst.PLAYLIST : Language.inst.PLAYLISTS}';
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
    final formatDate = DateFormat(SettingsController.inst.dateTimeFormat.value);
    final dateFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(this));

    return dateFormatted;
  }

  String get clockFormatted {
    final formatClock = SettingsController.inst.hourFormat12.value ? DateFormat('hh:mm aa') : DateFormat('HH:mm');
    final clockFormatted = formatClock.format(DateTime.fromMillisecondsSinceEpoch(this));

    return clockFormatted;
  }
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

extension EmptyString on String {
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

extension FavouriteTrack on Track {
  bool get isFavourite {
    final favPlaylist = PlaylistController.inst.playlistList.firstWhere(
      (element) => element.id == kPlaylistFavourites,
    );
    return favPlaylist.tracks.map((e) => e.track).contains(this);
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
    // return SettingsController.inst.libraryTabs.toList().indexOf(toText);
    final libtabs = SettingsController.inst.libraryTabs.toList();
    if (this == LibraryTab.albums) {
      return libtabs.indexOf('albums');
    }
    if (this == LibraryTab.tracks) {
      return libtabs.indexOf('tracks');
    }
    if (this == LibraryTab.artists) {
      return libtabs.indexOf('artists');
    }
    if (this == LibraryTab.genres) {
      return libtabs.indexOf('genres');
    }
    if (this == LibraryTab.playlists) {
      return libtabs.indexOf('playlists');
    }
    if (this == LibraryTab.folders) {
      return libtabs.indexOf('folders');
    }
    return libtabs.indexOf('tracks');
  }
}

extension LibraryTabToEnum on int {
  LibraryTab get toEnum {
    final libtabs = SettingsController.inst.libraryTabs.toList();
    if (this == libtabs.indexOf('albums')) {
      return LibraryTab.albums;
    }
    if (this == libtabs.indexOf('tracks')) {
      return LibraryTab.tracks;
    }
    if (this == libtabs.indexOf('artists')) {
      return LibraryTab.artists;
    }
    if (this == libtabs.indexOf('genres')) {
      return LibraryTab.genres;
    }
    if (this == libtabs.indexOf('playlists')) {
      return LibraryTab.playlists;
    }
    if (this == libtabs.indexOf('folders')) {
      return LibraryTab.folders;
    }
    return LibraryTab.tracks;
  }
}

extension LibraryTabFromString on String {
  LibraryTab get toEnum {
    if (this == 'albums') {
      return LibraryTab.albums;
    }
    if (this == 'tracks') {
      return LibraryTab.tracks;
    }
    if (this == 'artists') {
      return LibraryTab.artists;
    }
    if (this == 'genres') {
      return LibraryTab.genres;
    }
    if (this == 'playlists') {
      return LibraryTab.playlists;
    }
    if (this == 'folders') {
      return LibraryTab.folders;
    }
    return LibraryTab.tracks;
  }
}

extension LibraryTabToWidget on LibraryTab {
  Widget get toWidget {
    if (this == LibraryTab.albums) {
      return AlbumsPage();
    }
    if (this == LibraryTab.tracks) {
      return TracksPage();
    }
    if (this == LibraryTab.artists) {
      return ArtistsPage();
    }
    if (this == LibraryTab.genres) {
      return GenresPage();
    }
    if (this == LibraryTab.playlists) {
      return PlaylistsPage();
    }
    if (this == LibraryTab.folders) {
      return FoldersPage();
    }
    return const SizedBox();
  }

  IconData get toIcon {
    if (this == LibraryTab.albums) {
      return Broken.music_dashboard;
    }
    if (this == LibraryTab.tracks) {
      return Broken.music_circle;
    }
    if (this == LibraryTab.artists) {
      return Broken.profile_2user;
    }
    if (this == LibraryTab.genres) {
      return Broken.smileys;
    }
    if (this == LibraryTab.playlists) {
      return Broken.music_library_2;
    }
    if (this == LibraryTab.folders) {
      return Broken.folder;
    }
    return Broken.music_circle;
  }

  String get toText {
    if (this == LibraryTab.albums) {
      return Language.inst.ALBUMS;
    }
    if (this == LibraryTab.tracks) {
      return Language.inst.TRACKS;
    }
    if (this == LibraryTab.artists) {
      return Language.inst.ARTISTS;
    }
    if (this == LibraryTab.genres) {
      return Language.inst.GENRES;
    }
    if (this == LibraryTab.playlists) {
      return Language.inst.PLAYLISTS;
    }
    if (this == LibraryTab.folders) {
      return Language.inst.FOLDERS;
    }
    return Language.inst.TRACKS;
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
    if (this == SortType.filename) {
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

extension GroupSortToText on GroupSortType {
  String get toText {
    if (this == GroupSortType.defaultSort) {
      return Language.inst.DEFAULT;
    }
    if (this == GroupSortType.title) {
      return Language.inst.TITLE;
    }
    if (this == GroupSortType.album) {
      return Language.inst.ALBUM;
    }
    if (this == GroupSortType.albumArtist) {
      return Language.inst.ALBUM_ARTIST;
    }
    if (this == GroupSortType.artistsList) {
      return Language.inst.ARTISTS;
    }
    if (this == GroupSortType.genresList) {
      return Language.inst.GENRES;
    }

    if (this == GroupSortType.composer) {
      return Language.inst.COMPOSER;
    }
    if (this == GroupSortType.dateModified) {
      return Language.inst.DATE_MODIFIED;
    }
    if (this == GroupSortType.duration) {
      return Language.inst.DURATION;
    }
    if (this == GroupSortType.numberOfTracks) {
      return Language.inst.NUMBER_OF_TRACKS;
    }
    if (this == GroupSortType.year) {
      return Language.inst.YEAR;
    }

    return '';
  }
}

extension YTVideoQuality on String {
  VideoQuality get toVideoQuality {
    if (this == '144p') {
      return VideoQuality.low144;
    }
    if (this == '240p') {
      return VideoQuality.low240;
    }
    if (this == '360p') {
      return VideoQuality.medium360;
    }
    if (this == '480p') {
      return VideoQuality.medium480;
    }
    if (this == '720p') {
      return VideoQuality.high720;
    }
    if (this == '1080p') {
      return VideoQuality.high1080;
    }
    if (this == '2k') {
      return VideoQuality.high1440;
    }
    if (this == '4k') {
      return VideoQuality.high2160;
    }
    if (this == '8k') {
      return VideoQuality.high4320;
    }
    return VideoQuality.low144;
  }
}

extension VideoSource on int {
  String get toText {
    if (this == 0) {
      return Language.inst.AUTO;
    }
    if (this == 1) {
      return Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL;
    }
    if (this == 2) {
      return Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE;
    }

    return '';
  }
}

extension FileNameUtils on String {
  String get getFilename => p.basename(this);
  String get getFilenameWOExt => p.basenameWithoutExtension(this);
  String get getExtension => p.extension(this).substring(1);
  String get getDirectoryName => p.dirname(this);
}

extension EnumUtils on Enum {
  String get convertToString => toString().split('.').last;
}

extension EnumListExtensions<T extends Object> on List<T> {
  T? getEnum(String? string) => firstWhereOrNull((element) => element.toString().split('.').last == string);
}

extension PLNAME on String {
  String get translatePlaylistName => replaceFirst('_AUTO_GENERATED_', Language.inst.AUTO_GENERATED)
      .replaceFirst('_FAVOURITES_', Language.inst.FAVOURITES)
      .replaceFirst('_HISTORY_', Language.inst.HISTORY)
      .replaceFirst('_MOST_PLAYED_', Language.inst.MOST_PLAYED);
}

extension TRACKPLAYMODE on TrackPlayMode {
  String get toText {
    if (this == TrackPlayMode.selectedTrack) {
      return Language.inst.TRACK_PLAY_MODE_SELECTED_ONLY;
    }
    if (this == TrackPlayMode.searchResults) {
      return Language.inst.TRACK_PLAY_MODE_SEARCH_RESULTS;
    }
    if (this == TrackPlayMode.trackAlbum) {
      return Language.inst.TRACK_PLAY_MODE_TRACK_ALBUM;
    }
    if (this == TrackPlayMode.trackArtist) {
      return Language.inst.TRACK_PLAY_MODE_TRACK_ARTIST;
    }
    if (this == TrackPlayMode.trackGenre) {
      return Language.inst.TRACK_PLAY_MODE_TRACK_GENRE;
    }

    return '';
  }

  void toggleSetting() {
    final index = TrackPlayMode.values.indexOf(this);
    if (SettingsController.inst.trackPlayMode.value.index + 1 == TrackPlayMode.values.length) {
      SettingsController.inst.save(trackPlayMode: TrackPlayMode.values[0]);
    } else {
      SettingsController.inst.save(trackPlayMode: TrackPlayMode.values[index + 1]);
    }
  }

  List<Track> getQueue(Track track) {
    List<Track> queue = [];
    if (this == TrackPlayMode.selectedTrack) {
      queue = [track];
    }
    if (this == TrackPlayMode.searchResults) {
      queue = Indexer.inst.trackSearchList.toList();
    }
    if (this == TrackPlayMode.trackAlbum) {
      queue = Indexer.inst.albumsMap.entries.firstWhere((element) => element.key == track.album).value.toList();
    }
    if (this == TrackPlayMode.trackArtist) {
      queue = Indexer.inst.groupedArtistsMap.entries.firstWhere((element) => element.key == track.artistsList.first).value.toList();
    }
    if (this == TrackPlayMode.trackGenre) {
      queue = Indexer.inst.groupedGenresMap.entries.firstWhere((element) => element.key == track.genresList.first).value.toList();
    }
    return queue;
  }
}

extension PlayerRepeatModeUtils on RepeatMode {
  String get toText {
    if (this == RepeatMode.none) {
      return Language.inst.REPEAT_MODE_NONE;
    }
    if (this == RepeatMode.one) {
      return Language.inst.REPEAT_MODE_ONE;
    }
    if (this == RepeatMode.all) {
      return Language.inst.REPEAT_MODE_ALL;
    }
    return '';
  }

  IconData get toIcon {
    if (this == RepeatMode.none) {
      return Broken.repeate_music;
    }
    if (this == RepeatMode.one) {
      return Broken.repeate_one;
    }
    if (this == RepeatMode.all) {
      return Broken.repeat;
    }

    return Broken.repeat;
  }

  void toggleSetting() {
    final index = RepeatMode.values.indexOf(this);
    if (SettingsController.inst.playerRepeatMode.value.index + 1 == RepeatMode.values.length) {
      SettingsController.inst.save(playerRepeatMode: RepeatMode.values[0]);
    } else {
      SettingsController.inst.save(playerRepeatMode: RepeatMode.values[index + 1]);
    }
  }
}

extension ConvertPathsToTracks on List<String> {
  List<Track> get toTracks {
    final matchingSet = HashSet<String>.from(this);
    final finalTracks = Indexer.inst.tracksInfoList.where((item) => matchingSet.contains(item.path));
    return finalTracks.sorted((a, b) => indexOf(a.path).compareTo(indexOf(b.path)));
  }
}

extension ConvertPathToTrack on String {
  Track get toTrack {
    return Indexer.inst.tracksInfoList.firstWhere((item) => item.path == this);
  }
}

//TODO: catches non utf char
extension CleanUp on String {
  String get cleanUpForComparison => toLowerCase().replaceAll(RegExp(r'[\W\s_]'), '');
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
