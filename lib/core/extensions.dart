// ignore_for_file: depend_on_referenced_packages

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
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
    final String twoDigitMinutes = "${twoDigits(inMinutes.remainder(60))}:";
    final String twoDigitSeconds = twoDigits(inSeconds.remainder(60));
    final String durinHour = inHours > 0 ? "${twoDigits(inHours)}:" : '';
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
    final allFolders = Indexer.inst.groupedFoldersList;
    final allInside = allFolders.map((element) => element.path).where((key) => key.startsWith(this)).toList();
    allInside.remove(this);
    return allInside;
  }
}

extension UtilExtensions on String {
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
  int get totalDuration {
    int totalFinalDuration = 0;

    for (final t in this) {
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
    return this[length - 1].pathToImage;
  }

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
  String displayKeyword(String singular, String plural) {
    return '$this ${this > 1 ? plural : singular}';
  }

  String get displayAlbumKeyword => displayKeyword(Language.inst.ALBUM, Language.inst.ALBUMS);
  String get displayArtistKeyword => displayKeyword(Language.inst.ARTIST, Language.inst.ARTISTS);
  String get displayGenreKeyword => displayKeyword(Language.inst.GENRE, Language.inst.GENRES);
  String get displayFolderKeyword => displayKeyword(Language.inst.FOLDER, Language.inst.FOLDERS);
  String get displayPlaylistKeyword => displayKeyword(Language.inst.PLAYLIST, Language.inst.PLAYLISTS);
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

  String get dateFormatted => DateFormat(SettingsController.inst.dateTimeFormat.value).format(DateTime.fromMillisecondsSinceEpoch(this));

  String get dateFormattedOriginal => DateFormat('dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(this));

  String get clockFormatted => (SettingsController.inst.hourFormat12.value ? DateFormat('hh:mm aa') : DateFormat('HH:mm')).format(DateTime.fromMillisecondsSinceEpoch(this));

  String get dateAndClockFormattedOriginal => DateFormat('dd MMM yyyy - hh:mm aa').format(DateTime.fromMillisecondsSinceEpoch(this));
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
    return namidaFavouritePlaylist.tracks.firstWhereOrNull((element) => element.track.path == path) != null;
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
      return const TracksPage();
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
  String get getDirectoryPath {
    final pieces = split('/');
    pieces.removeLast();
    return pieces.join('/');
  }
}

extension EnumUtils on Enum {
  String get convertToString => toString().split('.').last;
}

extension EnumListExtensions<T extends Object> on List<T> {
  T? getEnum(String? string) => firstWhereOrNull((element) => element.toString().split('.').last == string);
}

extension PLNAME on String {
  String translatePlaylistName() => replaceFirst(k_PLAYLIST_NAME_AUTO_GENERATED, Language.inst.AUTO_GENERATED)
      .replaceFirst(k_PLAYLIST_NAME_FAV, Language.inst.FAVOURITES)
      .replaceFirst(k_PLAYLIST_NAME_HISTORY, Language.inst.HISTORY)
      .replaceFirst(k_PLAYLIST_NAME_MOST_PLAYED, Language.inst.MOST_PLAYED);
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

  bool get shouldBeIndex0 => this == TrackPlayMode.selectedTrack || this == TrackPlayMode.trackAlbum || this == TrackPlayMode.trackArtist || this == TrackPlayMode.trackGenre;

  List<Track> getQueue(Track track, {List<Track>? searchQueue}) {
    List<Track> queue = [];
    if (this == TrackPlayMode.selectedTrack) {
      queue = [track];
    }
    if (this == TrackPlayMode.searchResults) {
      queue = searchQueue ?? (Indexer.inst.trackSearchTemp.isNotEmpty ? Indexer.inst.trackSearchTemp.toList() : Indexer.inst.trackSearchList.toList());
    }
    if (this == TrackPlayMode.trackAlbum) {
      queue = Indexer.inst.albumsList.firstWhere((al) => al.name == track.album).tracks;
    }
    if (this == TrackPlayMode.trackArtist) {
      queue = Indexer.inst.groupedArtistsList.firstWhere((element) => element.name == track.artistsList.first).tracks;
    }
    if (this == TrackPlayMode.trackGenre) {
      queue = Indexer.inst.groupedGenresList.firstWhere((element) => element.name == track.genresList.first).tracks;
    }
    if (shouldBeIndex0) {
      queue.remove(track);
      queue.insertSafe(0, track);
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
    if (this == RepeatMode.forNtimes) {
      return Language.inst.REPEAT_FOR_N_TIMES;
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
    if (this == RepeatMode.forNtimes) {
      return Broken.status;
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

extension PlaylistToQueueSource on Playlist {
  QueueSource toQueueSource() {
    if (name == k_PLAYLIST_NAME_MOST_PLAYED) {
      return QueueSource.mostPlayed;
    }
    if (name == k_PLAYLIST_NAME_HISTORY) {
      return QueueSource.history;
    }
    if (name == k_PLAYLIST_NAME_FAV) {
      return QueueSource.favourites;
    }
    return QueueSource.playlist;
  }
}

extension QUEUESOURCEtoTRACKS on QueueSource {
  String toText() {
    String s = '';
    if (this == QueueSource.allTracks) {
      s = Language.inst.TRACKS;
    }
    // onMediaTap should have handled it already.
    if (this == QueueSource.album) {
      s = Language.inst.ALBUM;
    }
    if (this == QueueSource.artist) {
      s = Language.inst.ARTIST;
    }
    if (this == QueueSource.genre) {
      s = Language.inst.GENRE;
    }
    if (this == QueueSource.playlist) {
      s = Language.inst.PLAYLIST;
    }
    if (this == QueueSource.favourites) {
      s = Language.inst.FAVOURITES;
    }
    if (this == QueueSource.history) {
      s = Language.inst.HISTORY;
    }
    if (this == QueueSource.mostPlayed) {
      s = Language.inst.MOST_PLAYED;
    }
    if (this == QueueSource.folder) {
      s = Language.inst.FOLDER;
    }
    if (this == QueueSource.search) {
      s = Language.inst.SEARCH;
    }

    if (this == QueueSource.playerQueue) {
      s = Language.inst.QUEUE;
    }
    if (this == QueueSource.queuePage) {
      s = Language.inst.QUEUES;
    }
    if (this == QueueSource.selectedTracks) {
      s = Language.inst.SELECTED_TRACKS;
    }
    if (this == QueueSource.externalFile) {
      s = Language.inst.EXTERNAL_FILES;
    }
    return s;
  }

  List<Track> toTracks() {
    final trs = <Track>[];
    if (this == QueueSource.allTracks) {
      trs.addAll(Indexer.inst.trackSearchList.toList());
    }
    // onMediaTap should have handled it already.
    if (this == QueueSource.album) {
      trs.addAll(SelectedTracksController.inst.currentAllTracks.toList());
    }
    if (this == QueueSource.artist) {
      trs.addAll(SelectedTracksController.inst.currentAllTracks.toList());
    }
    if (this == QueueSource.genre) {
      trs.addAll(SelectedTracksController.inst.currentAllTracks.toList());
    }
    if (this == QueueSource.playlist) {
      trs.addAll(SelectedTracksController.inst.currentAllTracks.toList());
    }
    if (this == QueueSource.folder) {
      trs.addAll(SelectedTracksController.inst.currentAllTracks.toList());
    }
    if (this == QueueSource.search) {
      trs.addAll(Indexer.inst.trackSearchTemp.toList());
    }
    if (this == QueueSource.mostPlayed) {
      trs.addAll(namidaMostPlayedPlaylist.tracks.map((e) => e.track).toList());
    }
    if (this == QueueSource.history) {
      trs.addAll(namidaHistoryPlaylist.tracks.map((e) => e.track).toList());
    }
    if (this == QueueSource.favourites) {
      trs.addAll(namidaFavouritePlaylist.tracks.map((e) => e.track).toList());
    }
    if (this == QueueSource.playerQueue) {
      trs.addAll(Player.inst.currentQueue.toList());
    }
    if (this == QueueSource.queuePage) {
      trs.addAll(SelectedTracksController.inst.currentAllTracks.toList());
    }
    if (this == QueueSource.selectedTracks) {
      trs.addAll(SelectedTracksController.inst.selectedTracks.toList());
    }

    return trs;
  }
}

extension ConvertPathsToTracks on List<String> {
  List<Track> toTracks() {
    // final matchingSet = HashSet<String>.from(this);
    // final finalTracks = allTracksInLibrary.where((item) => matchingSet.contains(item.path));
    final finalTracks = map((e) => e.toTrack()).toList();
    return finalTracks.sorted((a, b) => indexOf(a.path).compareTo(indexOf(b.path)));
  }
}

extension ConvertPathToTrack on String {
  Track toTrack() {
    return Indexer.inst.allTracksMappedByPath[this] ??
        Track(
          getFilenameWOExt,
          '',
          [],
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
          TrackStats('', 0, [], []),
        );
  }
}

extension CleanUp on String {
  String get cleanUpForComparison => toLowerCase()
      .replaceAll(RegExp(r'''[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\>\=\?\@\[\]\{\}\\\\\^\_\`\~\s\|\@\#\$\%\^\&\*\(\)\-\+\=\[\]\{\}\:\;\"\'\<\>\.\,\?\/\`\~\!\_\s]+'''), '');
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

extension SafeListInsertion<T> on List<T> {
  void insertSafe(int index, T object) => insert(index.clamp(0, length), object);
  void insertAllSafe(int index, Iterable<T> objects) => insertAll(index.clamp(0, length), objects);
}

extension TagFieldsUtils on TagField {
  bool get isNumeric => this == TagField.trackNumber || this == TagField.trackTotal || this == TagField.discNumber || this == TagField.discTotal || this == TagField.year;

  String toText() {
    if (this == TagField.title) {
      return Language.inst.TITLE;
    }
    if (this == TagField.album) {
      return Language.inst.ALBUM;
    }
    if (this == TagField.artist) {
      return Language.inst.ARTIST;
    }
    if (this == TagField.albumArtist) {
      return Language.inst.ALBUM_ARTIST;
    }
    if (this == TagField.genre) {
      return Language.inst.GENRE;
    }
    if (this == TagField.composer) {
      return Language.inst.COMPOSER;
    }
    if (this == TagField.comment) {
      return Language.inst.COMMENT;
    }
    if (this == TagField.lyrics) {
      return Language.inst.LYRICS;
    }
    if (this == TagField.trackNumber) {
      return Language.inst.TRACK_NUMBER;
    }
    if (this == TagField.discNumber) {
      return Language.inst.DISC_NUMBER;
    }
    if (this == TagField.year) {
      return Language.inst.YEAR;
    }
    if (this == TagField.remixer) {
      return Language.inst.REMIXER;
    }
    if (this == TagField.trackTotal) {
      return Language.inst.TRACK_NUMBER_TOTAL;
    }
    if (this == TagField.discTotal) {
      return Language.inst.DISC_NUMBER_TOTAL;
    }
    if (this == TagField.lyricist) {
      return Language.inst.LYRICIST;
    }
    if (this == TagField.language) {
      return Language.inst.LANGUAGE;
    }
    if (this == TagField.recordLabel) {
      return Language.inst.RECORD_LABEL;
    }
    if (this == TagField.country) {
      return Language.inst.COUNTRY;
    }
    return '';
  }

  IconData toIcon() {
    if (this == TagField.title) {
      return Broken.music;
    }
    if (this == TagField.album) {
      return Broken.music_dashboard;
    }
    if (this == TagField.artist) {
      return Broken.microphone;
    }
    if (this == TagField.albumArtist) {
      return Broken.user;
    }
    if (this == TagField.genre) {
      return Broken.smileys;
    }
    if (this == TagField.composer) {
      return Broken.profile_2user;
    }
    if (this == TagField.comment) {
      return Broken.text_block;
    }
    if (this == TagField.lyrics) {
      return Broken.message_text;
    }
    if (this == TagField.trackNumber) {
      return Broken.hashtag;
    }
    if (this == TagField.discNumber) {
      return Broken.hashtag;
    }
    if (this == TagField.year) {
      return Broken.calendar;
    }
    if (this == TagField.remixer) {
      return Broken.radio;
    }
    if (this == TagField.trackTotal) {
      return Broken.hashtag;
    }
    if (this == TagField.discTotal) {
      return Broken.hashtag;
    }
    if (this == TagField.lyricist) {
      return Broken.pen_add;
    }
    if (this == TagField.language) {
      return Broken.language_circle;
    }
    if (this == TagField.recordLabel) {
      return Broken.ticket;
    }
    if (this == TagField.country) {
      return Broken.house;
    }
    return Broken.activity;
  }
}

extension WAKELOCKMODETEXT on WakelockMode {
  String toText() {
    if (this == WakelockMode.none) {
      return Language.inst.KEEP_SCREEN_AWAKE_NONE;
    }
    if (this == WakelockMode.expanded) {
      return Language.inst.KEEP_SCREEN_AWAKE_MINIPLAYER_EXPANDED;
    }
    if (this == WakelockMode.expandedAndVideo) {
      return Language.inst.KEEP_SCREEN_AWAKE_MINIPLAYER_EXPANDED_AND_VIDEO;
    }
    return '';
  }

  void toggleSetting() {
    final index = WakelockMode.values.indexOf(this);
    if (SettingsController.inst.wakelockMode.value.index + 1 == WakelockMode.values.length) {
      SettingsController.inst.save(wakelockMode: WakelockMode.values[0]);
    } else {
      SettingsController.inst.save(wakelockMode: WakelockMode.values[index + 1]);
    }
  }
}
