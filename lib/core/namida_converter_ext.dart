import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:history_manager/history_manager.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
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
import 'package:namida/ui/pages/about_page.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/folders_page.dart';
import 'package:namida/ui/pages/genres_page.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/pages/main_page.dart';
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
import 'package:namida/youtube/pages/youtube_page.dart';
import 'package:namida/youtube/widgets/yt_search_bar.dart';

extension LibraryTabToEnum on int {
  LibraryTab toEnum() => settings.libraryTabs.elementAt(this);
}

extension MediaTypeUtils on MediaType {
  LibraryTab? toLibraryTab() {
    switch (this) {
      case MediaType.track:
        return LibraryTab.tracks;
      case MediaType.album:
        return LibraryTab.albums;
      case MediaType.artist:
        return LibraryTab.artists;
      case MediaType.genre:
        return LibraryTab.genres;
      case MediaType.folder:
        return LibraryTab.folders;
      default:
        return null;
    }
  }
}

extension LibraryTabUtils on LibraryTab {
  MediaType? toMediaType() {
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
        return null;
    }
  }

  int toInt() => settings.libraryTabs.indexOf(this);

  Widget toWidget([int? gridCount, bool animateTiles = true, bool enableHero = true]) {
    Widget page = const SizedBox();
    switch (this) {
      case LibraryTab.tracks:
        page = TracksPage(animateTiles: animateTiles);
        break;
      case LibraryTab.albums:
        page = AlbumsPage(
          countPerRow: gridCount ?? settings.albumGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.artists:
        page = ArtistsPage(
          countPerRow: gridCount ?? settings.artistGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.genres:
        page = GenresPage(
          countPerRow: gridCount ?? settings.genreGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.playlists:
        page = PlaylistsPage(
          countPerRow: gridCount ?? settings.playlistGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        );
        break;
      case LibraryTab.folders:
        page = const FoldersPage();
        break;
      case LibraryTab.home:
        page = const HomePage();
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

  String videoLabelToSettingLabel() {
    final val = split('p').first;
    return <String, String>{
          '144': '144p',
          '240': '240p',
          '360': '360p',
          '480': '480p',
          '720': '720p',
          '1080': '1080p',
          '1440': '2k',
          '2160': '4k',
          '4320': '8k',
        }[val] ??
        '144';
  }
}

extension CacheGetterAudio on AudioOnlyStream {
  String cacheKey(String id) {
    final audio = this;
    return "${id}_${audio.bitrate}.${audio.formatSuffix}";
  }

  String cachePath(String id, {String? directory}) {
    final dir = Directory(directory ?? AppDirs.AUDIOS_CACHE);
    return "${dir.path}/${cacheKey(id)}";
  }

  File? getCachedFile(String id, {String? directory}) {
    final path = cachePath(id, directory: directory);
    return File(path).existsSync() ? File(path) : null;
  }
}

extension CacheGetterVideo on VideoOnlyStream {
  String cacheKey(String id, {String? directory}) {
    final video = this;
    return "${id}_${video.resolution}.${video.formatSuffix}";
  }

  String cachePath(String id, {String? directory}) {
    final dir = Directory(directory ?? AppDirs.VIDEOS_CACHE);
    return "${dir.path}/${cacheKey(id)}";
  }

  File? getCachedFile(String id, {String? directory}) {
    final path = cachePath(id, directory: directory);
    return File(path).existsSync() ? File(path) : null;
  }
}

extension VideoSource on VideoPlaybackSource {
  String toText() => _NamidaConverters.inst.getTitle(this);
  String? toSubtitle() => _NamidaConverters.inst.getSubtitle(this);
}

extension TrackItemSubstring on TrackTileItem {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension HomePageGetter on HomePageItems {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension QueueNameGetter on Queue {
  String toText() => homePageItem?.toText() ?? source.toText();
}

extension QUEUESOURCEtoTRACKS on QueueSource {
  String toText() => _NamidaConverters.inst.getTitle(this);

  List<Selectable> toTracks([int? limit, int? dayOfHistory]) {
    final trs = <Selectable>[];
    void addThese(Iterable<Selectable> tracks) => trs.addAll(tracks.withLimit(limit));
    switch (this) {
      case QueueSource.allTracks:
        addThese(SearchSortController.inst.trackSearchList);
        break;
      case QueueSource.search:
        addThese(SearchSortController.inst.trackSearchTemp);
        break;
      case QueueSource.mostPlayed:
        addThese(HistoryController.inst.currentMostPlayedTracks);
        break;
      case QueueSource.history:
        dayOfHistory != null
            ? addThese(HistoryController.inst.historyMap.value[dayOfHistory] ?? [])
            : addThese(
                HistoryController.inst.historyTracks.withLimit(limit),
              );
        break;
      case QueueSource.favourites:
        addThese(PlaylistController.inst.favouritesPlaylist.value.tracks);
        break;
      case QueueSource.queuePage:
        addThese(SelectedTracksController.inst.currentAllTracks);
        break;
      case QueueSource.selectedTracks:
        addThese(SelectedTracksController.inst.selectedTracks);
        break;
      case QueueSource.playerQueue:
        addThese(Player.inst.currentQueue);
        break;
      default:
        addThese(SelectedTracksController.inst.currentAllTracks);
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

extension NotificationTapActionTEXT on NotificationTapAction {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension LocalVideoMatchingTypeText on LocalVideoMatchingType {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TRACKPLAYMODE on TrackPlayMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TagFieldsUtilsC on TagField {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension FFMPEGTagFieldUtilsC on FFMPEGTagField {
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

extension QueueInsertionTypeToQI on QueueInsertionType {
  QueueInsertion toQueueInsertion() => settings.queueInsertion[this]!;

  /// NOTE: Modifies the original list.
  List<Selectable> shuffleOrSort(List<Selectable> tracks) {
    final sortBy = toQueueInsertion().sortBy;

    switch (sortBy) {
      case InsertionSortingType.listenCount:
        if (this == QueueInsertionType.algorithm) {
          // already sorted by repeated times inside [NamidaGenerator.generateRecommendedTrack].
        } else {
          tracks.sortByReverse((e) => HistoryController.inst.topTracksMapListens[e.track]?.length ?? 0);
        }
      case InsertionSortingType.rating:
        tracks.sortByReverse((e) => e.track.stats.rating);
      case InsertionSortingType.random:
        tracks.shuffle();

      default:
        null;
    }

    return tracks;
  }
}

extension InsertionSortingTypeTextIcon on InsertionSortingType {
  String toText() => _NamidaConverters.inst.getTitle(this);
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
      case AboutPage:
        route = RouteType.PAGE_about;
        break;

      // ----- Subpages -----
      case RecentlyAddedTracksPage:
        route = RouteType.SUBPAGE_recentlyAddedTracks;
        break;
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
      case YoutubePage:
        route = RouteType.YOUTUBE_HOME;
        break;
    }

    return NamidaRoute(route, name);
  }
}

extension RouteUtils on NamidaRoute {
  /// Mainly used for sending to [generalPopupDialog] and use these tracks to remove from playlist.
  Iterable<TrackWithDate>? get tracksWithDateInside {
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
        tr.addAll(HistoryController.inst.currentMostPlayedTracks);
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
        finalWidget = getTextWidget(lang.SETTINGS);
        break;
      case RouteType.SETTINGS_subpage:
        finalWidget = getTextWidget(name);
        break;
      case RouteType.SEARCH_albumResults:
        finalWidget = getTextWidget(lang.ALBUMS);
        break;
      case RouteType.SEARCH_artistResults:
        finalWidget = getTextWidget(lang.ARTISTS);
        break;
      case RouteType.PAGE_queue:
        finalWidget = Obx(() => getTextWidget("${lang.QUEUES} • ${QueueController.inst.queuesMap.value.length}"));
        break;
      case RouteType.YOUTUBE_HOME:
        finalWidget = const YoutubeSearchBar();
        break;
      default:
        null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: finalWidget ?? ScrollSearchController.inst.searchBarWidget,
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
      return child.animateEntrance(
        showWhen: shouldShow,
        durationMS: 400,
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
                  title: lang.STATS,
                  child: const StatsSection(),
                ),
              );
            },
          ),
          shouldShow: shouldShowInitialActions),

      // -- Parsing Json Icon
      getAnimatedCrossFade(child: const ParsingJsonPercentage(size: 30.0), shouldShow: shouldShowJsonParse),

      getAnimatedCrossFade(
        child: NamidaAppBarIcon(
          icon: Broken.activity,
          onPressed: () => JsonToHistoryParser.inst.showMissingEntriesDialog(),
        ),
        shouldShow: JsonToHistoryParser.inst.shouldShowMissingEntriesDialog,
      ),

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
              tooltip: reorderable ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
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
      case RouteType.PAGE_HOME:
        tab = LibraryTab.home;
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
  List<double>? toTrackItemExtents() => length == 0 ? null : List.filled(length, Dimensions.inst.trackTileItemExtent);
}

extension ThemeDefaultColors on BuildContext {
  Color defaultIconColor([Color? mainColor, Color? secondaryColor]) => Color.alphaBlend(
        (mainColor ?? CurrentColor.inst.color).withAlpha(120),
        secondaryColor ?? theme.colorScheme.onBackground,
      );
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

extension MostPlayedTimeRangeUtils on MostPlayedTimeRange {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension NamidaLanguageRefresher on NamidaLanguage {
  void refreshConverterMaps() => _NamidaConverters.inst.refillMaps();
}

extension LanguageUtils on Language {
  String getMinimumItemSubtitle([int minimum = 1]) => lang.MINIMUM_ONE_ITEM_SUBTITLE.replaceFirst('_NUM_', '$minimum');
}

void showMinimumItemsSnack([int minimum = 1]) {
  Get.snackbar(lang.MINIMUM_ONE_ITEM, lang.getMinimumItemSubtitle(minimum));
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
        InterruptionAction.doNothing: lang.DO_NOTHING,
        InterruptionAction.duckAudio: lang.DUCK_AUDIO,
        InterruptionAction.pause: lang.PAUSE_PLAYBACK,
      },
      InterruptionType: {
        InterruptionType.shouldPause: lang.SHOULD_PAUSE,
        InterruptionType.shouldDuck: lang.SHOULD_DUCK,
        InterruptionType.unknown: lang.OTHERS,
      },
      RepeatMode: {
        RepeatMode.none: lang.REPEAT_MODE_NONE,
        RepeatMode.one: lang.REPEAT_MODE_ONE,
        RepeatMode.all: lang.REPEAT_MODE_ALL,
        RepeatMode.forNtimes: lang.REPEAT_FOR_N_TIMES,
      },
      LibraryTab: {
        LibraryTab.albums: lang.ALBUMS,
        LibraryTab.tracks: lang.TRACKS,
        LibraryTab.artists: lang.ARTISTS,
        LibraryTab.genres: lang.GENRES,
        LibraryTab.playlists: lang.PLAYLISTS,
        LibraryTab.folders: lang.FOLDERS,
        LibraryTab.home: lang.HOME,
        LibraryTab.search: lang.SEARCH,
      },
      SortType: {
        SortType.title: lang.TITLE,
        SortType.album: lang.ALBUM,
        SortType.albumArtist: lang.ALBUM_ARTIST,
        SortType.artistsList: lang.ARTISTS,
        SortType.bitrate: lang.BITRATE,
        SortType.composer: lang.COMPOSER,
        SortType.dateAdded: lang.DATE_ADDED,
        SortType.dateModified: lang.DATE_MODIFIED,
        SortType.discNo: lang.DISC_NUMBER,
        SortType.filename: lang.FILE_NAME,
        SortType.duration: lang.DURATION,
        SortType.genresList: lang.GENRES,
        SortType.sampleRate: lang.SAMPLE_RATE,
        SortType.size: lang.SIZE,
        SortType.year: lang.YEAR,
        SortType.rating: lang.RATING,
        SortType.shuffle: lang.SHUFFLE,
      },
      GroupSortType: {
        GroupSortType.title: lang.TITLE,
        GroupSortType.album: lang.ALBUM,
        GroupSortType.albumArtist: lang.ALBUM_ARTIST,
        GroupSortType.artistsList: lang.ARTIST,
        GroupSortType.genresList: lang.GENRES,
        GroupSortType.composer: lang.COMPOSER,
        GroupSortType.dateModified: lang.DATE_MODIFIED,
        GroupSortType.duration: lang.DURATION,
        GroupSortType.numberOfTracks: lang.NUMBER_OF_TRACKS,
        GroupSortType.albumsCount: lang.ALBUMS_COUNT,
        GroupSortType.year: lang.YEAR,
        GroupSortType.creationDate: lang.DATE_CREATED,
        GroupSortType.modifiedDate: lang.DATE_MODIFIED,
        GroupSortType.shuffle: lang.SHUFFLE,
      },
      TrackTileItem: {
        TrackTileItem.none: lang.NONE,
        TrackTileItem.title: lang.TITLE,
        TrackTileItem.artists: lang.ARTISTS,
        TrackTileItem.album: lang.ALBUM,
        TrackTileItem.albumArtist: lang.ALBUM_ARTIST,
        TrackTileItem.genres: lang.GENRES,
        TrackTileItem.composer: lang.COMPOSER,
        TrackTileItem.year: lang.YEAR,
        TrackTileItem.bitrate: lang.BITRATE,
        TrackTileItem.channels: lang.CHANNELS,
        TrackTileItem.comment: lang.COMMENT,
        TrackTileItem.dateAdded: lang.DATE_ADDED,
        TrackTileItem.dateModified: lang.DATE_MODIFIED,
        TrackTileItem.dateModifiedClock: "${lang.DATE_MODIFIED} (${lang.CLOCK})",
        TrackTileItem.dateModifiedDate: "${lang.DATE_MODIFIED} (${lang.DATE})",
        TrackTileItem.discNumber: lang.DISC_NUMBER,
        TrackTileItem.trackNumber: lang.TRACK_NUMBER,
        TrackTileItem.duration: lang.DURATION,
        TrackTileItem.fileName: lang.FILE_NAME,
        TrackTileItem.fileNameWOExt: lang.FILE_NAME_WO_EXT,
        TrackTileItem.extension: lang.EXTENSION,
        TrackTileItem.folder: lang.FOLDER_NAME,
        TrackTileItem.format: lang.FORMAT,
        TrackTileItem.path: lang.PATH,
        TrackTileItem.sampleRate: lang.SAMPLE_RATE,
        TrackTileItem.size: lang.SIZE,
        TrackTileItem.rating: lang.RATING,
        TrackTileItem.moods: lang.MOODS,
        TrackTileItem.tags: lang.TAGS,
      },
      QueueSource: {
        QueueSource.allTracks: lang.TRACKS,
        QueueSource.album: lang.ALBUM,
        QueueSource.artist: lang.ARTIST,
        QueueSource.genre: lang.GENRE,
        QueueSource.playlist: lang.PLAYLIST,
        QueueSource.favourites: lang.FAVOURITES,
        QueueSource.history: lang.HISTORY,
        QueueSource.mostPlayed: lang.MOST_PLAYED,
        QueueSource.folder: lang.FOLDER,
        QueueSource.search: lang.SEARCH,
        QueueSource.playerQueue: lang.QUEUE,
        QueueSource.queuePage: lang.QUEUES,
        QueueSource.selectedTracks: lang.SELECTED_TRACKS,
        QueueSource.externalFile: lang.EXTERNAL_FILES,
        QueueSource.others: lang.OTHERS,
      },
      TagField: {
        TagField.title: lang.TITLE,
        TagField.album: lang.ALBUM,
        TagField.artist: lang.ARTIST,
        TagField.albumArtist: lang.ALBUM_ARTIST,
        TagField.genre: lang.GENRE,
        TagField.composer: lang.COMPOSER,
        TagField.comment: lang.COMMENT,
        TagField.lyrics: lang.LYRICS,
        TagField.trackNumber: lang.TRACK_NUMBER,
        TagField.discNumber: lang.DISC_NUMBER,
        TagField.year: lang.YEAR,
        TagField.remixer: lang.REMIXER,
        TagField.trackTotal: lang.TRACK_NUMBER_TOTAL,
        TagField.discTotal: lang.DISC_NUMBER_TOTAL,
        TagField.lyricist: lang.LYRICIST,
        TagField.language: lang.LANGUAGE,
        TagField.recordLabel: lang.RECORD_LABEL,
        TagField.country: lang.COUNTRY,
      },
      FFMPEGTagField: {
        FFMPEGTagField.title: lang.TITLE,
        FFMPEGTagField.album: lang.ALBUM,
        FFMPEGTagField.artist: lang.ARTIST,
        FFMPEGTagField.albumArtist: lang.ALBUM_ARTIST,
        FFMPEGTagField.genre: lang.GENRE,
        FFMPEGTagField.composer: lang.COMPOSER,
        FFMPEGTagField.synopsis: lang.SYNOPSIS,
        FFMPEGTagField.comment: lang.COMMENT,
        FFMPEGTagField.description: lang.DESCRIPTION,
        FFMPEGTagField.lyrics: lang.LYRICS,
        FFMPEGTagField.trackNumber: lang.TRACK_NUMBER,
        FFMPEGTagField.discNumber: lang.DISC_NUMBER,
        FFMPEGTagField.year: lang.YEAR,
        FFMPEGTagField.remixer: lang.REMIXER,
        FFMPEGTagField.lyricist: lang.LYRICIST,
        FFMPEGTagField.language: lang.LANGUAGE,
        FFMPEGTagField.recordLabel: lang.RECORD_LABEL,
        FFMPEGTagField.country: lang.COUNTRY,
      },
      VideoPlaybackSource: {
        VideoPlaybackSource.auto: lang.AUTO,
        VideoPlaybackSource.youtube: lang.VIDEO_PLAYBACK_SOURCE_YOUTUBE,
        VideoPlaybackSource.local: lang.VIDEO_PLAYBACK_SOURCE_LOCAL,
      },
      WakelockMode: {
        WakelockMode.none: lang.KEEP_SCREEN_AWAKE_NONE,
        WakelockMode.expanded: lang.KEEP_SCREEN_AWAKE_MINIPLAYER_EXPANDED,
        WakelockMode.expandedAndVideo: lang.KEEP_SCREEN_AWAKE_MINIPLAYER_EXPANDED_AND_VIDEO,
      },
      LocalVideoMatchingType: {
        LocalVideoMatchingType.auto: lang.AUTO,
        LocalVideoMatchingType.titleAndArtist: "${lang.TITLE} & ${lang.ARTIST}",
        LocalVideoMatchingType.filename: lang.FILE_NAME,
      },
      TrackPlayMode: {
        TrackPlayMode.selectedTrack: lang.TRACK_PLAY_MODE_SELECTED_ONLY,
        TrackPlayMode.searchResults: lang.TRACK_PLAY_MODE_SEARCH_RESULTS,
        TrackPlayMode.trackAlbum: lang.TRACK_PLAY_MODE_TRACK_ALBUM,
        TrackPlayMode.trackArtist: lang.TRACK_PLAY_MODE_TRACK_ARTIST,
        TrackPlayMode.trackGenre: lang.TRACK_PLAY_MODE_TRACK_GENRE,
      },
      InsertionSortingType: {
        InsertionSortingType.listenCount: lang.TOTAL_LISTENS,
        InsertionSortingType.random: lang.RANDOM,
        InsertionSortingType.rating: lang.RATING,
      },
      MostPlayedTimeRange: {
        MostPlayedTimeRange.custom: lang.CUSTOM,
        MostPlayedTimeRange.day: lang.DAY,
        MostPlayedTimeRange.day3: "3 ${lang.DAYS}",
        MostPlayedTimeRange.week: lang.WEEK,
        MostPlayedTimeRange.month: lang.MONTH,
        MostPlayedTimeRange.month3: "3 ${lang.MONTHS}",
        MostPlayedTimeRange.month6: "6 ${lang.MONTHS}",
        MostPlayedTimeRange.year: lang.YEAR,
        MostPlayedTimeRange.allTime: lang.ALL_TIME,
      },
      HomePageItems: {
        HomePageItems.mixes: lang.MIXES,
        HomePageItems.recentListens: lang.RECENT_LISTENS,
        HomePageItems.topRecentListens: lang.TOP_RECENTS,
        HomePageItems.lostMemories: lang.LOST_MEMORIES,
        HomePageItems.recentlyAdded: lang.RECENTLY_ADDED,
        HomePageItems.recentAlbums: lang.RECENT_ALBUMS,
        HomePageItems.recentArtists: lang.RECENT_ARTISTS,
        HomePageItems.topRecentAlbums: lang.TOP_RECENT_ALBUMS,
        HomePageItems.topRecentArtists: lang.TOP_RECENT_ARTISTS,
      },
      NotificationTapAction: {
        NotificationTapAction.openApp: lang.OPEN_APP,
        NotificationTapAction.openMiniplayer: lang.OPEN_MINIPLAYER,
        NotificationTapAction.openQueue: lang.OPEN_QUEUE,
      }
    };

    // ====================================================
    // ====================== Subtitle ====================
    // ====================================================
    final toSubtitle = <Type, Map<Enum, String?>>{
      InterruptionType: {
        InterruptionType.shouldPause: lang.SHOULD_PAUSE_NOTE,
        InterruptionType.shouldDuck: lang.SHOULD_DUCK_NOTE,
        InterruptionType.unknown: null,
      },
      VideoPlaybackSource: {
        VideoPlaybackSource.auto: lang.VIDEO_PLAYBACK_SOURCE_AUTO_SUBTITLE,
        VideoPlaybackSource.youtube: lang.VIDEO_PLAYBACK_SOURCE_YOUTUBE_SUBTITLE,
        VideoPlaybackSource.local: lang.VIDEO_PLAYBACK_SOURCE_LOCAL_SUBTITLE,
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
        LibraryTab.home: Broken.home_2,
        LibraryTab.search: Broken.search_normal_1,
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
      },
      FFMPEGTagField: {
        FFMPEGTagField.title: Broken.music,
        FFMPEGTagField.album: Broken.music_dashboard,
        FFMPEGTagField.artist: Broken.microphone,
        FFMPEGTagField.albumArtist: Broken.user,
        FFMPEGTagField.genre: Broken.smileys,
        FFMPEGTagField.composer: Broken.profile_2user,
        FFMPEGTagField.synopsis: Broken.text,
        FFMPEGTagField.comment: Broken.text_block,
        FFMPEGTagField.description: Broken.note_text,
        FFMPEGTagField.lyrics: Broken.message_text,
        FFMPEGTagField.trackNumber: Broken.hashtag,
        FFMPEGTagField.discNumber: Broken.hashtag,
        FFMPEGTagField.year: Broken.calendar,
        FFMPEGTagField.remixer: Broken.radio,
        FFMPEGTagField.lyricist: Broken.pen_add,
        FFMPEGTagField.language: Broken.language_circle,
        FFMPEGTagField.recordLabel: Broken.ticket,
        FFMPEGTagField.country: Broken.house,
      },
      InsertionSortingType: {
        InsertionSortingType.listenCount: Broken.award,
        InsertionSortingType.random: Broken.format_circle,
        InsertionSortingType.rating: Broken.grammerly,
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
