import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/lang.dart';
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

  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension SortToText on SortType {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension GroupSortToText on GroupSortType {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension YTVideoQuality on String {
  String settingLabeltoVideoLabel() {
    final val = split('p').first;
    return <String, String>{
          '144': '144',
          '240': '240',
          '360': '360',
          '480': '480',
          '720': '720',
          '1080': '1080',
          '2k': '1440',
          '4k': '2160',
          '8k': '4320',
        }[val] ??
        '144';
  }
}

extension VideoSource on VideoPlaybackSource {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TrackItemSubstring on TrackTileItem {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension QUEUESOURCEtoTRACKS on QueueSource {
  String toText() => _NamidaConverters.inst.getTitle(this);

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
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TRACKPLAYMODE on TrackPlayMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TagFieldsUtilsC on TagField {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension PlayerRepeatModeUtils on RepeatMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension ThemeUtils on ThemeMode {
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
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
        break;
      case RouteType.PAGE_folders:
        tr.addAll(Folders.inst.currentTracks);
        break;
      case RouteType.SUBPAGE_albumTracks:
        tr.addAll(name.getAlbumTracks());
        break;
      case RouteType.SUBPAGE_artistTracks:
        tr.addAll(name.getArtistTracks());
        break;
      case RouteType.SUBPAGE_genreTracks:
        tr.addAll(name.getGenresTracks());
        break;
      case RouteType.SUBPAGE_queueTracks:
        tr.addAll(name.getQueue()?.tracks ?? []);
        break;
      case RouteType.SUBPAGE_playlistTracks:
        tr.addAll(PlaylistController.inst.getPlaylist(name)?.tracks ?? []);
        break;
      case RouteType.SUBPAGE_historyTracks:
        tr.addAll(HistoryController.inst.historyTracks);
        break;
      case RouteType.SUBPAGE_mostPlayedTracks:
        tr.addAll(HistoryController.inst.mostPlayedTracks);
        break;

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
        break;
      case RouteType.SETTINGS_subpage:
        finalWidget = getTextWidget(name);
        break;
      case RouteType.SEARCH_albumResults:
        finalWidget = getTextWidget(Language.inst.ALBUMS);
        break;
      case RouteType.SEARCH_artistResults:
        finalWidget = getTextWidget(Language.inst.ARTISTS);
        break;
      case RouteType.PAGE_queue:
        finalWidget = Obx(() => getTextWidget("${Language.inst.QUEUES} • ${QueueController.inst.queuesMap.value.length}"));
        break;
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
              break;
            case RouteType.SUBPAGE_artistTracks:
              NamidaDialogs.inst.showArtistDialog(name);
              break;
            case RouteType.SUBPAGE_genreTracks:
              NamidaDialogs.inst.showGenreDialog(name);
              break;
            case RouteType.SUBPAGE_queueTracks:
              NamidaDialogs.inst.showQueueDialog(int.parse(name));
              break;

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
        break;
      case RouteType.PAGE_albums:
        tab = LibraryTab.albums;
        break;
      case RouteType.PAGE_artists:
        tab = LibraryTab.artists;
        break;
      case RouteType.PAGE_genres:
        tab = LibraryTab.genres;
        break;
      case RouteType.PAGE_folders:
        tab = LibraryTab.folders;
        break;
      case RouteType.PAGE_playlists:
        tab = LibraryTab.playlists;
        break;
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

extension ThemeDefaultColors on BuildContext {
  Color defaultIconColor([Color? mainColor]) => Color.alphaBlend((mainColor ?? CurrentColor.inst.color).withAlpha(100), theme.colorScheme.onBackground);
}

extension InterruptionMediaUtils on InterruptionType {
  String toText() => _NamidaConverters.inst.getTitle(this);
  String? toSubtitle() => _NamidaConverters.inst.getSubtitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension InterruptionActionUtils on InterruptionAction {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension NamidaLanguageRefresher on NamidaLanguage {
  void refreshConverterMaps() => _NamidaConverters.inst.refillMaps();
}

class _NamidaConverters {
  static _NamidaConverters get inst => _instance;
  static final _NamidaConverters _instance = _NamidaConverters._internal();
  _NamidaConverters._internal() {
    refillMaps();
  }

  void refillMaps() {
    // =================================================
    // ====================== Title ====================
    // =================================================
    final toTitle = <Type, Map<Enum, String>>{
      InterruptionAction: {
        InterruptionAction.doNothing: Language.inst.DO_NOTHING,
        InterruptionAction.duckAudio: Language.inst.DUCK_AUDIO,
        InterruptionAction.pause: Language.inst.PAUSE_PLAYBACK,
      },
      InterruptionType: {
        InterruptionType.shouldPause: Language.inst.SHOULD_PAUSE,
        InterruptionType.shouldDuck: Language.inst.SHOULD_DUCK,
        InterruptionType.unknown: Language.inst.OTHERS,
      },
      RepeatMode: {
        RepeatMode.none: Language.inst.REPEAT_MODE_NONE,
        RepeatMode.one: Language.inst.REPEAT_MODE_ONE,
        RepeatMode.all: Language.inst.REPEAT_MODE_ALL,
        RepeatMode.forNtimes: Language.inst.REPEAT_FOR_N_TIMES,
      },
      LibraryTab: {
        LibraryTab.albums: Language.inst.ALBUMS,
        LibraryTab.tracks: Language.inst.TRACKS,
        LibraryTab.artists: Language.inst.ARTISTS,
        LibraryTab.genres: Language.inst.GENRES,
        LibraryTab.playlists: Language.inst.PLAYLISTS,
        LibraryTab.folders: Language.inst.FOLDERS,
      },
      SortType: {
        SortType.title: Language.inst.TITLE,
        SortType.album: Language.inst.ALBUM,
        SortType.albumArtist: Language.inst.ALBUM_ARTIST,
        SortType.artistsList: Language.inst.ARTISTS,
        SortType.bitrate: Language.inst.BITRATE,
        SortType.composer: Language.inst.COMPOSER,
        SortType.dateAdded: Language.inst.DATE_ADDED,
        SortType.dateModified: Language.inst.DATE_MODIFIED,
        SortType.discNo: Language.inst.DISC_NUMBER,
        SortType.filename: Language.inst.FILE_NAME,
        SortType.duration: Language.inst.DURATION,
        SortType.genresList: Language.inst.GENRES,
        SortType.sampleRate: Language.inst.SAMPLE_RATE,
        SortType.size: Language.inst.SIZE,
        SortType.year: Language.inst.YEAR,
        SortType.rating: Language.inst.RATING,
        SortType.shuffle: Language.inst.SHUFFLE,
      },
      GroupSortType: {
        GroupSortType.title: Language.inst.TITLE,
        GroupSortType.album: Language.inst.ALBUM,
        GroupSortType.albumArtist: Language.inst.ALBUM_ARTIST,
        GroupSortType.artistsList: Language.inst.ARTIST,
        GroupSortType.genresList: Language.inst.GENRES,
        GroupSortType.composer: Language.inst.COMPOSER,
        GroupSortType.dateModified: Language.inst.DATE_MODIFIED,
        GroupSortType.duration: Language.inst.DURATION,
        GroupSortType.numberOfTracks: Language.inst.NUMBER_OF_TRACKS,
        GroupSortType.albumsCount: Language.inst.ALBUMS_COUNT,
        GroupSortType.year: Language.inst.YEAR,
        GroupSortType.creationDate: Language.inst.DATE_CREATED,
        GroupSortType.modifiedDate: Language.inst.DATE_MODIFIED,
        GroupSortType.shuffle: Language.inst.SHUFFLE,
      },
      TrackTileItem: {
        TrackTileItem.none: Language.inst.NONE,
        TrackTileItem.title: Language.inst.TITLE,
        TrackTileItem.artists: Language.inst.ARTISTS,
        TrackTileItem.album: Language.inst.ALBUM,
        TrackTileItem.albumArtist: Language.inst.ALBUM_ARTIST,
        TrackTileItem.genres: Language.inst.GENRES,
        TrackTileItem.composer: Language.inst.COMPOSER,
        TrackTileItem.year: Language.inst.YEAR,
        TrackTileItem.bitrate: Language.inst.BITRATE,
        TrackTileItem.channels: Language.inst.CHANNELS,
        TrackTileItem.comment: Language.inst.COMMENT,
        TrackTileItem.dateAdded: Language.inst.DATE_ADDED,
        TrackTileItem.dateModified: Language.inst.DATE_MODIFIED,
        TrackTileItem.dateModifiedClock: "${Language.inst.DATE_MODIFIED} (${Language.inst.CLOCK})",
        TrackTileItem.dateModifiedDate: "${Language.inst.DATE_MODIFIED} (${Language.inst.DATE})",
        TrackTileItem.discNumber: Language.inst.DISC_NUMBER,
        TrackTileItem.trackNumber: Language.inst.TRACK_NUMBER,
        TrackTileItem.duration: Language.inst.DURATION,
        TrackTileItem.fileName: Language.inst.FILE_NAME,
        TrackTileItem.fileNameWOExt: Language.inst.FILE_NAME_WO_EXT,
        TrackTileItem.extension: Language.inst.EXTENSION,
        TrackTileItem.folder: Language.inst.FOLDER_NAME,
        TrackTileItem.format: Language.inst.FORMAT,
        TrackTileItem.path: Language.inst.PATH,
        TrackTileItem.sampleRate: Language.inst.SAMPLE_RATE,
        TrackTileItem.size: Language.inst.SIZE,
        TrackTileItem.rating: Language.inst.RATING,
        TrackTileItem.moods: Language.inst.MOODS,
        TrackTileItem.tags: Language.inst.TAGS,
      },
      QueueSource: {
        QueueSource.allTracks: Language.inst.TRACKS,
        QueueSource.album: Language.inst.ALBUM,
        QueueSource.artist: Language.inst.ARTIST,
        QueueSource.genre: Language.inst.GENRE,
        QueueSource.playlist: Language.inst.PLAYLIST,
        QueueSource.favourites: Language.inst.FAVOURITES,
        QueueSource.history: Language.inst.HISTORY,
        QueueSource.mostPlayed: Language.inst.MOST_PLAYED,
        QueueSource.folder: Language.inst.FOLDER,
        QueueSource.search: Language.inst.SEARCH,
        QueueSource.playerQueue: Language.inst.QUEUE,
        QueueSource.queuePage: Language.inst.QUEUES,
        QueueSource.selectedTracks: Language.inst.SELECTED_TRACKS,
        QueueSource.externalFile: Language.inst.EXTERNAL_FILES,
      },
      TagField: {
        TagField.title: Language.inst.TITLE,
        TagField.album: Language.inst.ALBUM,
        TagField.artist: Language.inst.ARTIST,
        TagField.albumArtist: Language.inst.ALBUM_ARTIST,
        TagField.genre: Language.inst.GENRE,
        TagField.composer: Language.inst.COMPOSER,
        TagField.comment: Language.inst.COMMENT,
        TagField.lyrics: Language.inst.LYRICS,
        TagField.trackNumber: Language.inst.TRACK_NUMBER,
        TagField.discNumber: Language.inst.DISC_NUMBER,
        TagField.year: Language.inst.YEAR,
        TagField.remixer: Language.inst.REMIXER,
        TagField.trackTotal: Language.inst.TRACK_NUMBER_TOTAL,
        TagField.discTotal: Language.inst.DISC_NUMBER_TOTAL,
        TagField.lyricist: Language.inst.LYRICIST,
        TagField.language: Language.inst.LANGUAGE,
        TagField.recordLabel: Language.inst.RECORD_LABEL,
        TagField.country: Language.inst.COUNTRY,
      },
      VideoPlaybackSource: {
        VideoPlaybackSource.auto: Language.inst.AUTO,
        VideoPlaybackSource.youtube: Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE,
        VideoPlaybackSource.local: Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL,
      },
      WakelockMode: {
        WakelockMode.none: Language.inst.KEEP_SCREEN_AWAKE_NONE,
        WakelockMode.expanded: Language.inst.KEEP_SCREEN_AWAKE_MINIPLAYER_EXPANDED,
        WakelockMode.expandedAndVideo: Language.inst.KEEP_SCREEN_AWAKE_MINIPLAYER_EXPANDED_AND_VIDEO,
      },
      TrackPlayMode: {
        TrackPlayMode.selectedTrack: Language.inst.TRACK_PLAY_MODE_SELECTED_ONLY,
        TrackPlayMode.searchResults: Language.inst.TRACK_PLAY_MODE_SEARCH_RESULTS,
        TrackPlayMode.trackAlbum: Language.inst.TRACK_PLAY_MODE_TRACK_ALBUM,
        TrackPlayMode.trackArtist: Language.inst.TRACK_PLAY_MODE_TRACK_ARTIST,
        TrackPlayMode.trackGenre: Language.inst.TRACK_PLAY_MODE_TRACK_GENRE,
      }
    };

    // ====================================================
    // ====================== Subtitle ====================
    // ====================================================
    final toSubtitle = <Type, Map<Enum, String?>>{
      InterruptionType: {
        InterruptionType.shouldPause: Language.inst.SHOULD_PAUSE_NOTE,
        InterruptionType.shouldDuck: Language.inst.SHOULD_DUCK_NOTE,
        InterruptionType.unknown: null,
      }
    };

    // =================================================
    // ====================== Icons ====================
    // =================================================
    final toIcon = <Type, Map<Enum, IconData>>{
      InterruptionAction: {
        InterruptionAction.doNothing: Broken.minus_cirlce,
        InterruptionAction.duckAudio: Broken.volume_low_1,
        InterruptionAction.pause: Broken.pause_circle,
      },
      InterruptionType: {
        InterruptionType.shouldPause: Broken.pause_circle,
        InterruptionType.shouldDuck: Broken.volume_low_1,
        InterruptionType.unknown: Broken.status,
      },
      RepeatMode: {
        RepeatMode.none: Broken.repeate_music,
        RepeatMode.one: Broken.repeate_one,
        RepeatMode.all: Broken.repeat,
        RepeatMode.forNtimes: Broken.status,
      },
      ThemeMode: {
        ThemeMode.light: Broken.sun_1,
        ThemeMode.dark: Broken.moon,
        ThemeMode.system: Broken.autobrightness,
      },
      LibraryTab: {
        LibraryTab.albums: Broken.music_dashboard,
        LibraryTab.tracks: Broken.music_circle,
        LibraryTab.artists: Broken.profile_2user,
        LibraryTab.genres: Broken.smileys,
        LibraryTab.playlists: Broken.music_library_2,
        LibraryTab.folders: Broken.folder,
      },
      TagField: {
        TagField.title: Broken.music,
        TagField.album: Broken.music_dashboard,
        TagField.artist: Broken.microphone,
        TagField.albumArtist: Broken.user,
        TagField.genre: Broken.smileys,
        TagField.composer: Broken.profile_2user,
        TagField.comment: Broken.text_block,
        TagField.lyrics: Broken.message_text,
        TagField.trackNumber: Broken.hashtag,
        TagField.discNumber: Broken.hashtag,
        TagField.year: Broken.calendar,
        TagField.remixer: Broken.radio,
        TagField.trackTotal: Broken.hashtag,
        TagField.discTotal: Broken.hashtag,
        TagField.lyricist: Broken.pen_add,
        TagField.language: Broken.language_circle,
        TagField.recordLabel: Broken.ticket,
        TagField.country: Broken.house,
      }
    };
    _toTitle
      ..clear()
      ..addAll(toTitle);
    _toSubtitle
      ..clear()
      ..addAll(toSubtitle);
    _toIcon
      ..clear()
      ..addAll(toIcon);
  }

  final _toTitle = <Type, Map<Enum, String>>{};
  final _toSubtitle = <Type, Map<Enum, String?>>{};
  final _toIcon = <Type, Map<Enum, IconData>>{};

  String getTitle(Enum enumValue) {
    return _toTitle[enumValue.runtimeType]![enumValue]!;
  }

  String? getSubtitle(Enum enumValue) {
    return _toSubtitle[enumValue.runtimeType]?[enumValue];
  }

  IconData getIcon(Enum enumValue) {
    return _toIcon[enumValue.runtimeType]![enumValue]!;
  }
}
