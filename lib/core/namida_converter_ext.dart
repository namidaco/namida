import 'package:flutter/material.dart';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
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

extension LibraryTabToInt on LibraryTab {
  int toInt() {
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
  LibraryTab toEnum() {
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
  LibraryTab toEnum() {
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
  Widget toWidget() {
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

  IconData toIcon() {
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

  String toText() {
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
  String toText() {
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
    if (this == SortType.rating) {
      return Language.inst.RATING;
    }

    return '';
  }
}

extension GroupSortToText on GroupSortType {
  String toText() {
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
      return Language.inst.ARTIST;
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
    if (this == GroupSortType.albumsCount) {
      return Language.inst.ALBUMS_COUNT;
    }
    if (this == GroupSortType.year) {
      return Language.inst.YEAR;
    }
    if (this == GroupSortType.creationDate) {
      return Language.inst.DATE_CREATED;
    }
    if (this == GroupSortType.modifiedDate) {
      return Language.inst.DATE_MODIFIED;
    }

    return '';
  }
}

extension YTVideoQuality on String {
  VideoQuality toVideoQuality() {
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
  String toText() {
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

extension TrackItemSubstring on TrackTileItem {
  String toText() {
    String t = '';
    if (this == TrackTileItem.none) {
      t = Language.inst.NONE;
    }
    if (this == TrackTileItem.title) {
      t = Language.inst.TITLE;
    }
    if (this == TrackTileItem.artists) {
      t = Language.inst.ARTISTS;
    }
    if (this == TrackTileItem.album) {
      t = Language.inst.ALBUM;
    }

    if (this == TrackTileItem.albumArtist) {
      t = Language.inst.ALBUM_ARTIST;
    }
    if (this == TrackTileItem.genres) {
      t = Language.inst.GENRES;
    }

    if (this == TrackTileItem.composer) {
      t = Language.inst.COMPOSER;
    }
    if (this == TrackTileItem.year) {
      t = Language.inst.YEAR;
    }

    if (this == TrackTileItem.bitrate) {
      t = Language.inst.BITRATE;
    }
    if (this == TrackTileItem.channels) {
      t = Language.inst.CHANNELS;
    }

    if (this == TrackTileItem.comment) {
      t = Language.inst.COMMENT;
    }
    if (this == TrackTileItem.dateAdded) {
      t = Language.inst.DATE_ADDED;
    }

    if (this == TrackTileItem.dateModified) {
      t = Language.inst.DATE_MODIFIED;
    }
    if (this == TrackTileItem.dateModifiedClock) {
      t = "${Language.inst.DATE_MODIFIED} (${Language.inst.CLOCK})";
    }
    if (this == TrackTileItem.dateModifiedDate) {
      t = "${Language.inst.DATE_MODIFIED} (${Language.inst.DATE})";
    }
    if (this == TrackTileItem.discNumber) {
      t = Language.inst.DISC_NUMBER;
    }
    if (this == TrackTileItem.trackNumber) {
      t = Language.inst.TRACK_NUMBER;
    }
    if (this == TrackTileItem.duration) {
      t = Language.inst.DURATION;
    }
    if (this == TrackTileItem.fileName) {
      t = Language.inst.FILE_NAME;
    }
    if (this == TrackTileItem.fileNameWOExt) {
      t = Language.inst.FILE_NAME_WO_EXT;
    }
    if (this == TrackTileItem.extension) {
      t = Language.inst.EXTENSION;
    }
    if (this == TrackTileItem.folder) {
      t = Language.inst.FOLDER_NAME;
    }

    if (this == TrackTileItem.format) {
      t = Language.inst.FORMAT;
    }
    if (this == TrackTileItem.path) {
      t = Language.inst.PATH;
    }

    if (this == TrackTileItem.sampleRate) {
      t = Language.inst.SAMPLE_RATE;
    }
    if (this == TrackTileItem.size) {
      t = Language.inst.SIZE;
    }

    if (this == TrackTileItem.rating) {
      t = Language.inst.RATING;
    }
    if (this == TrackTileItem.moods) {
      t = Language.inst.MOODS;
    }
    if (this == TrackTileItem.tags) {
      t = Language.inst.TAGS;
    }

    return t;
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
      trs.addAll(PlaylistController.inst.topTracksMapListens.keys);
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
}

extension TRACKPLAYMODE on TrackPlayMode {
  String toText() {
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
}

extension TagFieldsUtilsC on TagField {
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

extension PlayerRepeatModeUtils on RepeatMode {
  String toText() {
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

  IconData toIcon() {
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
}
