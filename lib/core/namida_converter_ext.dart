import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/folders_page.dart';
import 'package:namida/ui/pages/genres_page.dart';
import 'package:namida/ui/pages/homepage.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';
import 'package:namida/ui/pages/tracks_page.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/stats.dart';

extension LibraryTabToEnum on int {
  LibraryTab toEnum() => SettingsController.inst.libraryTabs.elementAt(this);
}

extension LibraryTabUtils on LibraryTab {
  MediaType toMediaType() {
    switch (this) {
      case LibraryTab.tracks:
        return MediaType.track;
      case LibraryTab.albums:
        return MediaType.album;
      case LibraryTab.artists:
        return MediaType.artist;
      case LibraryTab.genres:
        return MediaType.genre;
      case LibraryTab.folders:
        return MediaType.folder;
      default:
        return MediaType.track;
    }
  }

  int toInt() => SettingsController.inst.libraryTabs.indexOf(this);

  Widget toWidget([int? gridCount, bool animateTiles = true, bool enableHero = true]) {
    Widget page = const SizedBox();
    switch (this) {
      case LibraryTab.tracks:
        page = TracksPage(animateTiles: animateTiles);
        break;
      case LibraryTab.albums:
        page = AlbumsPage(
          countPerRow: gridCount ?? SettingsController.inst.albumGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.artists:
        page = ArtistsPage(
          countPerRow: gridCount ?? SettingsController.inst.artistGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.genres:
        page = GenresPage(
          countPerRow: gridCount ?? SettingsController.inst.genreGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.playlists:
        page = PlaylistsPage(
          countPerRow: gridCount ?? SettingsController.inst.playlistGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.folders:
        page = const FoldersPage();
        break;
      default:
        null;
    }

    return page;
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
    if (this == SortType.shuffle) {
      return Language.inst.SHUFFLE;
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
    if (this == GroupSortType.shuffle) {
      return Language.inst.SHUFFLE;
    }

    return '';
  }
}

extension YTVideoQuality on String {
  String settingLabeltoVideoLabel() {
    final val = split('p').first;
    String vl = '144';
    switch (val) {
      case '144':
        vl = '144';
        break;
      case '240':
        vl = '240';
        break;
      case '360':
        vl = '360';
        break;
      case '480':
        vl = '480';
        break;
      case '720':
        vl = '720';
        break;

      case '1080':
        vl = '1080';
        break;
      case '2k':
        vl = '1440';
        break;
      case '4k':
        vl = '2160';
        break;
      case '8k':
        vl = '4320';
        break;

      default:
        null;
    }

    return vl;
  }
}

extension VideoSource on VideoPlaybackSource {
  String toText() {
    String s = '';
    switch (this) {
      case VideoPlaybackSource.auto:
        s = Language.inst.AUTO;
        break;
      case VideoPlaybackSource.youtube:
        s = Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE;
        break;
      case VideoPlaybackSource.local:
        s = Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL;
        break;
      default:
        null;
    }
    return s;
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

  List<Selectable> toTracks([int? limit, int? dayOfHistory]) {
    final trs = <Selectable>[];
    void addThese(Iterable<Selectable> tracks) => trs.addAll(tracks.withLimit(limit));
    if (this == QueueSource.allTracks) {
      addThese(SearchSortController.inst.trackSearchList);
    }
    // onMediaTap should have handled it already.
    if (this == QueueSource.album) {
      addThese(SelectedTracksController.inst.currentAllTracks);
    }
    if (this == QueueSource.artist) {
      addThese(SelectedTracksController.inst.currentAllTracks);
    }
    if (this == QueueSource.genre) {
      addThese(SelectedTracksController.inst.currentAllTracks);
    }
    if (this == QueueSource.playlist) {
      addThese(SelectedTracksController.inst.currentAllTracks);
    }
    if (this == QueueSource.folder) {
      addThese(SelectedTracksController.inst.currentAllTracks);
    }
    if (this == QueueSource.search) {
      addThese(SearchSortController.inst.trackSearchTemp);
    }
    if (this == QueueSource.mostPlayed) {
      addThese(HistoryController.inst.mostPlayedTracks);
    }
    if (this == QueueSource.history) {
      dayOfHistory != null
          ? addThese(HistoryController.inst.historyMap.value[dayOfHistory] ?? [])
          : addThese(
              HistoryController.inst.historyTracks.withLimit(limit),
            );
    }
    if (this == QueueSource.favourites) {
      addThese(PlaylistController.inst.favouritesPlaylist.value.tracks);
    }
    if (this == QueueSource.playerQueue) {
      addThese(Player.inst.currentQueue);
    }
    if (this == QueueSource.queuePage) {
      addThese(SelectedTracksController.inst.currentAllTracks);
    }
    if (this == QueueSource.selectedTracks) {
      addThese(SelectedTracksController.inst.selectedTracks);
    }

    return trs;
  }
}

extension PlaylistToQueueSource on Playlist {
  QueueSource toQueueSource() {
    // if (name == k_PLAYLIST_NAME_MOST_PLAYED) {
    //   return QueueSource.mostPlayed;
    // }
    // if (name == k_PLAYLIST_NAME_HISTORY) {
    //   return QueueSource.history;
    // }
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

extension ThemeUtils on ThemeMode {
  IconData toIcon() {
    if (this == ThemeMode.light) {
      return Broken.sun_1;
    }
    if (this == ThemeMode.dark) {
      return Broken.moon;
    }
    return Broken.autobrightness;
  }
}

extension WidgetsPagess on Widget {
  NamidaRoute toNamidaRoute() {
    String name = '';
    RouteType route = RouteType.UNKNOWN;
    switch (runtimeType) {
      // ----- Pages -----
      case TracksPage:
        route = RouteType.PAGE_allTracks;
        break;
      case AlbumsPage:
        route = RouteType.PAGE_albums;
        break;
      case ArtistsPage:
        route = RouteType.PAGE_artists;
        break;
      case GenresPage:
        route = RouteType.PAGE_genres;
        break;
      case PlaylistsPage:
        route = RouteType.PAGE_playlists;
        break;
      case FoldersPage:
        route = RouteType.PAGE_folders;
        break;
      case QueuesPage:
        route = RouteType.PAGE_queue;
        break;

      // ----- Subpages -----
      case AlbumTracksPage:
        route = RouteType.SUBPAGE_albumTracks;
        name = (this as AlbumTracksPage).name;
        break;
      case ArtistTracksPage:
        route = RouteType.SUBPAGE_artistTracks;
        name = (this as ArtistTracksPage).name;
        break;
      case GenreTracksPage:
        route = RouteType.SUBPAGE_genreTracks;
        name = (this as GenreTracksPage).name;
        break;
      case NormalPlaylistTracksPage:
        route = RouteType.SUBPAGE_playlistTracks;
        name = (this as NormalPlaylistTracksPage).playlistName;
        break;
      case HistoryTracksPage:
        route = RouteType.SUBPAGE_historyTracks;
        name = k_PLAYLIST_NAME_HISTORY;
        break;
      case MostPlayedTracksPage:
        route = RouteType.SUBPAGE_mostPlayedTracks;
        name = k_PLAYLIST_NAME_MOST_PLAYED;
        break;
      case QueueTracksPage:
        route = RouteType.SUBPAGE_queueTracks;
        name = (this as QueueTracksPage).queue.date.toString();
        break;

      // ----- Search Results -----
      case AlbumSearchResultsPage:
        route = RouteType.SEARCH_albumResults;
        break;
      case ArtistSearchResultsPage:
        route = RouteType.SEARCH_artistResults;
        break;

      // ----- Settings -----
      case SettingsPage:
        route = RouteType.SETTINGS_page;
        break;
      case SettingsSubPage:
        route = RouteType.SETTINGS_subpage;
        name = (this as SettingsSubPage).title;
        break;
    }

    return NamidaRoute(route, name);
  }
}

extension RouteUtils on NamidaRoute {
  /// Mainly used for sending to [generalPopupDialog] and use these tracks to remove from playlist.
  List<TrackWithDate>? get tracksWithDateInside {
    switch (route) {
      case RouteType.SUBPAGE_playlistTracks:
        return PlaylistController.inst.getPlaylist(name)?.tracks;
      case RouteType.SUBPAGE_historyTracks:
        return HistoryController.inst.historyTracks;

      default:
        null;
    }
    return null;
  }

  List<Selectable> get tracksInside {
    final tr = <Selectable>[];
    switch (route) {
      case RouteType.PAGE_allTracks:
        tr.addAll(SearchSortController.inst.trackSearchList);
      case RouteType.PAGE_folders:
        tr.addAll(Folders.inst.currentTracks);
      case RouteType.SUBPAGE_albumTracks:
        tr.addAll(name.getAlbumTracks());
      case RouteType.SUBPAGE_artistTracks:
        tr.addAll(name.getArtistTracks());
      case RouteType.SUBPAGE_genreTracks:
        tr.addAll(name.getGenresTracks());
      case RouteType.SUBPAGE_queueTracks:
        tr.addAll(name.getQueue()?.tracks ?? []);
      case RouteType.SUBPAGE_playlistTracks:
        tr.addAll(PlaylistController.inst.getPlaylist(name)?.tracks ?? []);
      case RouteType.SUBPAGE_historyTracks:
        tr.addAll(HistoryController.inst.historyTracks);
      case RouteType.SUBPAGE_mostPlayedTracks:
        tr.addAll(HistoryController.inst.mostPlayedTracks);

      default:
        null;
    }
    return tr;
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks] & [RouteType.SUBPAGE_artistTracks].
  Track? get trackOfColor {
    if (route == RouteType.SUBPAGE_albumTracks) {
      return name.getAlbumTracks().trackOfImage;
    }
    if (route == RouteType.SUBPAGE_artistTracks) {
      return name.getArtistTracks().trackOfImage;
    }
    return null;
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks] & [RouteType.SUBPAGE_artistTracks].
  Future<void> updateColorScheme() async {
    // a delay to prevent navigation glitches
    await Future.delayed(const Duration(milliseconds: 500));

    Color? color;
    final trackToExtractFrom = trackOfColor;
    if (trackToExtractFrom != null) {
      color = await CurrentColor.inst.getTrackDelightnedColor(trackToExtractFrom);
    }
    CurrentColor.inst.updateCurrentColorSchemeOfSubPages(color);
  }

  Widget? toTitle() {
    Widget getTextWidget(String t) => Text(t);
    Widget? finalWidget;
    switch (route) {
      case RouteType.SETTINGS_page:
        finalWidget = getTextWidget(Language.inst.SETTINGS);
      case RouteType.SETTINGS_subpage:
        finalWidget = getTextWidget(name);
      case RouteType.SEARCH_albumResults:
        finalWidget = getTextWidget(Language.inst.ALBUMS);
      case RouteType.SEARCH_artistResults:
        finalWidget = getTextWidget(Language.inst.ARTISTS);
      case RouteType.PAGE_queue:
        finalWidget = Obx(() => getTextWidget("${Language.inst.QUEUES} • ${QueueController.inst.queuesMap.value.length}"));
      default:
        null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: finalWidget ?? const NamidaSearchBar(),
    );
  }

  List<Widget> toActions() {
    Widget getMoreIcon(void Function()? onPressed) {
      return NamidaAppBarIcon(
        icon: Broken.more_2,
        onPressed: onPressed,
      );
    }

    Widget getAnimatedCrossFade({required Widget child, required bool shouldShow}) {
      return AnimatedCrossFade(
        firstChild: child,
        secondChild: const SizedBox(),
        crossFadeState: shouldShow ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 500),
        reverseDuration: const Duration(milliseconds: 500),
        sizeCurve: Curves.easeOut,
        firstCurve: Curves.easeInOutQuart,
        secondCurve: Curves.easeInOutQuart,
      );
    }

    final shouldShowInitialActions = route != RouteType.PAGE_stats && route != RouteType.SETTINGS_page && route != RouteType.SETTINGS_subpage;
    final shouldShowJsonParse = route != RouteType.SETTINGS_page && route != RouteType.SETTINGS_subpage;

    final queue = route == RouteType.SUBPAGE_queueTracks ? name.getQueue() : null;

    return <Widget>[
      // -- Stats Icon
      getAnimatedCrossFade(
          child: NamidaAppBarIcon(
            icon: Broken.chart_21,
            onPressed: () {
              NamidaNavigator.inst.navigateTo(
                SettingsSubPage(
                  title: Language.inst.STATS,
                  child: const StatsSection(),
                ),
              );
            },
          ),
          shouldShow: shouldShowInitialActions),

      // -- Parsing Json Icon
      getAnimatedCrossFade(child: const ParsingJsonPercentage(size: 30.0), shouldShow: shouldShowJsonParse),

      // -- Settings Icon
      getAnimatedCrossFade(
        child: NamidaAppBarIcon(
          icon: Broken.setting_2,
          onPressed: () => NamidaNavigator.inst.navigateTo(const SettingsPage()),
        ),
        shouldShow: shouldShowInitialActions,
      ),

      getAnimatedCrossFade(
        child: NamidaRawLikeButton(
          padding: const EdgeInsets.symmetric(horizontal: 3.0),
          isLiked: queue?.isFav,
          onTap: (isLiked) async => await QueueController.inst.toggleFavButton(queue!),
        ),
        shouldShow: queue != null,
      ),

      getAnimatedCrossFade(
        child: getMoreIcon(() {
          switch (route) {
            case RouteType.SUBPAGE_albumTracks:
              NamidaDialogs.inst.showAlbumDialog(name);
            case RouteType.SUBPAGE_artistTracks:
              NamidaDialogs.inst.showArtistDialog(name);
            case RouteType.SUBPAGE_genreTracks:
              NamidaDialogs.inst.showGenreDialog(name);
            case RouteType.SUBPAGE_queueTracks:
              NamidaDialogs.inst.showQueueDialog(int.parse(name));

            default:
              null;
          }
        }),
        shouldShow:
            route == RouteType.SUBPAGE_albumTracks || route == RouteType.SUBPAGE_artistTracks || route == RouteType.SUBPAGE_genreTracks || route == RouteType.SUBPAGE_queueTracks,
      ),
      getAnimatedCrossFade(child: const HistoryJumpToDayIcon(), shouldShow: route == RouteType.SUBPAGE_historyTracks),

      // ---- Playlist Tracks ----
      getAnimatedCrossFade(
        child: Obx(
          () {
            final reorderable = PlaylistController.inst.canReorderTracks.value;
            return NamidaAppBarIcon(
              tooltip: reorderable ? Language.inst.DISABLE_REORDERING : Language.inst.ENABLE_REORDERING,
              icon: reorderable ? Broken.forward_item : Broken.lock_1,
              onPressed: () => PlaylistController.inst.canReorderTracks.value = !PlaylistController.inst.canReorderTracks.value,
            );
          },
        ),
        shouldShow: route == RouteType.SUBPAGE_playlistTracks,
      ),
      getAnimatedCrossFade(
        child: getMoreIcon(() {
          NamidaDialogs.inst.showPlaylistDialog(name);
        }),
        shouldShow: route == RouteType.SUBPAGE_playlistTracks || route == RouteType.SUBPAGE_historyTracks || route == RouteType.SUBPAGE_mostPlayedTracks,
      ),

      const SizedBox(width: 8.0),
    ];
  }

  LibraryTab? toLibraryTab() {
    LibraryTab? tab;
    switch (route) {
      case RouteType.PAGE_allTracks:
        tab = LibraryTab.tracks;
      case RouteType.PAGE_albums:
        tab = LibraryTab.albums;
      case RouteType.PAGE_artists:
        tab = LibraryTab.artists;
      case RouteType.PAGE_genres:
        tab = LibraryTab.genres;
      case RouteType.PAGE_folders:
        tab = LibraryTab.folders;
      case RouteType.PAGE_playlists:
        tab = LibraryTab.playlists;
      default:
        null;
    }
    return tab;
  }
}

extension TracksFromMaps on String {
  List<Track> getAlbumTracks() {
    return Indexer.inst.mainMapAlbums.value[this] ?? [];
  }

  List<Track> getArtistTracks() {
    return Indexer.inst.mainMapArtists.value[this] ?? [];
  }

  List<Track> getGenresTracks() {
    return Indexer.inst.mainMapGenres.value[this] ?? [];
  }

  Set<String> getArtistAlbums() {
    final tracks = getArtistTracks();
    final albums = <String>{};
    tracks.loop((t, i) {
      albums.add(t.album);
    });
    return albums;
  }

  Queue? getQueue() => QueueController.inst.queuesMap.value[int.tryParse(this)];
}

extension QueueFromMap on int {
  Queue? getQueue() => QueueController.inst.queuesMap.value[this];
}

extension TrackTileItemExtentExt on Iterable {
  List<double> toTrackItemExtents() => List.filled(length, Dimensions.inst.trackTileItemExtent);
}
