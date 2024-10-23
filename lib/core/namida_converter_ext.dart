import 'dart:io';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:path/path.dart' as p;
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/extensions.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/media_info.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
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
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/folders_page.dart';
import 'package:namida/ui/pages/genres_page.dart';
import 'package:namida/ui/pages/home_page.dart';
import 'package:namida/ui/pages/playlists_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/tracks_page.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_search_bar.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart' as ytplc;
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/pages/youtube_home_view.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';

extension MediaTypeUtils on MediaType {
  LibraryTab toLibraryTab() {
    return switch (this) {
      MediaType.track => LibraryTab.tracks,
      MediaType.album => LibraryTab.albums,
      MediaType.artist || MediaType.albumArtist || MediaType.composer => LibraryTab.artists,
      MediaType.genre => LibraryTab.genres,
      MediaType.folder => LibraryTab.folders,
      MediaType.folderVideo => LibraryTab.foldersVideos,
      MediaType.playlist => LibraryTab.playlists,
    };
  }
}

extension LibraryTabUtils on LibraryTab {
  MediaType? toMediaType() {
    return switch (this) {
      LibraryTab.tracks => MediaType.track,
      LibraryTab.albums => MediaType.album,
      LibraryTab.artists => MediaType.artist,
      LibraryTab.genres => MediaType.genre,
      LibraryTab.playlists => MediaType.playlist,
      LibraryTab.folders => MediaType.folder,
      LibraryTab.foldersVideos => MediaType.folderVideo,
      LibraryTab.home => null,
      LibraryTab.search => null,
      LibraryTab.youtube => null,
    };
  }

  int toInt() => settings.libraryTabs.value.indexOf(this);

  NamidaRouteWidget toWidget([int? gridCount, bool animateTiles = true, bool enableHero = true]) {
    return switch (this) {
      LibraryTab.tracks => TracksPage(animateTiles: animateTiles),
      LibraryTab.albums => AlbumsPage(
          countPerRow: gridCount ?? settings.albumGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        ),
      LibraryTab.artists => ArtistsPage(
          countPerRow: gridCount ?? settings.artistGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        ),
      LibraryTab.genres => GenresPage(
          countPerRow: gridCount ?? settings.genreGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        ),
      LibraryTab.playlists => PlaylistsPage(
          countPerRow: gridCount ?? settings.playlistGridCount.value,
          animateTiles: animateTiles,
          enableHero: enableHero,
        ),
      LibraryTab.folders => FoldersPage.tracks(),
      LibraryTab.foldersVideos => FoldersPage.videos(),
      LibraryTab.home => const HomePage(),
      LibraryTab.youtube => const YouTubeHomeView(),
      LibraryTab.search => const NamidaDummyPage(),
    };
  }

  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension MediaTypeToText on MediaType {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension AlbumIdentifierToText on AlbumIdentifier {
  String toText() => _NamidaConverters.inst.getTitle(this);
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

extension CacheGetterAudio on AudioStream {
  String cacheKey(String id) {
    final audio = this;
    // -- wont save english track, only saves non-english ones.
    String languageText = '';

    final audioTrack = audio.audioTrack;
    if (audioTrack != null) {
      final langCode = audioTrack.langCode?.toLowerCase();
      final langName = audioTrack.displayName?.toLowerCase();

      if (langCode == 'en' && audioTrack.isDefault == true) {
        // -- is original english
        // -- isDefault check is required cuz there can be more than 1 english audio
      } else {
        languageText = '_${langCode}_$langName';
      }
    }

    return "$id${languageText}_${audio.bitrate}.${audio.codecInfo.container}";
  }

  String cachePath(String id) {
    return p.join(AppDirs.AUDIOS_CACHE, cacheKey(id));
  }

  File? getCachedFile(String? id) {
    if (id == null) return null;
    final path = cachePath(id);
    return File(path).existsSync() ? File(path) : null;
  }
}

extension CacheGetterVideo on VideoStream {
  String cacheKey(String id) {
    final video = this;
    var codecIdentifier = codecInfo.codecIdentifierIfCustom();
    var suffix = codecIdentifier != null ? '-$codecIdentifier' : '';
    return "${id}_${video.qualityLabel}$suffix.${video.codecInfo.container}";
  }

  String cachePath(String id) {
    return p.join(AppDirs.VIDEOS_CACHE, cacheKey(id));
  }

  String cachePathTemp(String id) {
    return p.join(AppDirs.VIDEOS_CACHE_TEMP, cacheKey(id));
  }

  File? getCachedFile(String? id) {
    if (id == null) return null;
    final path = cachePath(id);
    return File(path).existsSync() ? File(path) : null;
  }
}

extension MediaInfoToFAudioModel on MediaInfo {
  FAudioModel toFAudioModel({required FArtwork? artwork}) {
    final infoFull = this;
    final info = infoFull.format?.tags;
    if (info == null) return FAudioModel.dummy(path, artwork);
    final trackNumberTotal = info.track?.split('/');
    final discNumberTotal = info.disc?.split('/');
    final audioStream = infoFull.streams?.firstWhereEff((e) => e.streamType == StreamType.audio);
    int? parsy(String? v) => v == null ? null : int.tryParse(v);
    final bitrate = parsy(infoFull.format?.bitRate); // 234292
    final bitrateThousands = bitrate == null ? null : bitrate / 1000; // 234
    return FAudioModel(
      tags: FTags(
        path: infoFull.path,
        artwork: artwork ?? FArtwork(),
        title: info.title,
        album: info.album,
        albumArtist: info.albumArtist,
        artist: info.artist,
        composer: info.composer,
        genre: info.genre,
        trackNumber: trackNumberTotal?.first ?? info.track,
        trackTotal: info.trackTotal ?? (trackNumberTotal?.length == 2 ? trackNumberTotal?.last : null),
        discNumber: discNumberTotal?.first ?? info.disc,
        discTotal: info.discTotal ?? (discNumberTotal?.length == 2 ? discNumberTotal?.last : null),
        lyrics: info.lyrics,
        comment: info.comment,
        description: info.description,
        synopsis: info.synopsis,
        year: info.date,
        language: info.language,
        lyricist: info.lyricist,
        remixer: info.remixer,
        mood: info.mood,
        country: info.country,
        recordLabel: info.label,
        gainData: info.gainData,
      ),
      durationMS: infoFull.format?.duration?.inMilliseconds,
      bitRate: bitrateThousands?.round(),
      channels: audioStream?.channels == null
          ? null
          : {
                0: null,
                1: 'mono',
                2: 'stereo',
              }[audioStream?.channels] ??
              'unknown',
      format: infoFull.format?.formatName,
      sampleRate: parsy(audioStream?.sampleRate),
    );
  }
}

extension VideoSource on VideoPlaybackSource {
  String toText() => _NamidaConverters.inst.getTitle(this);
  String? toSubtitle() => _NamidaConverters.inst.getSubtitle(this);
}

extension LyricsSourceUtils on LyricsSource {
  String toText() => _NamidaConverters.inst.getTitle(this);
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
        addThese(SearchSortController.inst.trackSearchList.value);
        break;
      case QueueSource.search:
        addThese(SearchSortController.inst.trackSearchTemp.value);
        break;
      case QueueSource.mostPlayed:
        addThese(HistoryController.inst.currentMostPlayedTracks);
        break;
      case QueueSource.history:
        dayOfHistory != null ? addThese(HistoryController.inst.historyMap.value[dayOfHistory] ?? []) : addThese(HistoryController.inst.historyTracks);
        break;
      case QueueSource.favourites:
        addThese(PlaylistController.inst.favouritesPlaylist.value.tracks);
        break;
      case QueueSource.queuePage:
        addThese(SelectedTracksController.inst.getCurrentAllTracks());
        break;
      case QueueSource.selectedTracks:
        addThese(SelectedTracksController.inst.selectedTracks.value);
        break;
      case QueueSource.playerQueue:
        addThese(Player.inst.currentQueue.value.whereType<Selectable>());
        break;
      case QueueSource.recentlyAdded:
        addThese(Indexer.inst.recentlyAddedTracksSorted());
        break;
      default:
        addThese(SelectedTracksController.inst.getCurrentAllTracks());
    }

    return trs;
  }
}

extension PlaylistToQueueSource on LocalPlaylist {
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

extension OnTrackTileSwapActionsUtils on OnTrackTileSwapActions {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TRACKPLAYMODE on TrackPlayMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TagFieldsUtilsC on TagField {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension FFMPEGTagFieldUtilsC on String {
  String ffmpegTagToText() => _NamidaConverters.inst.ffmpegTagFieldName(this);
  IconData ffmpegTagToIcon() => _NamidaConverters.inst.ffmpegTagFieldIcon(this);
}

extension PlayerRepeatModeUtils on RepeatMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension KillAppModeUtils on KillAppMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension FABTypeUtils on FABType {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension SetMusicAsActionUtils on SetMusicAsAction {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension TrackSearchFilterUtils on TrackSearchFilter {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension OnYoutubeLinkOpenActionUtils on OnYoutubeLinkOpenAction {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);

  Future<bool> execute(Iterable<String> ids) async {
    Iterable<YoutubeID> getPlayables() => ids.map((e) => YoutubeID(id: e, playlistID: null));
    switch (this) {
      case OnYoutubeLinkOpenAction.showDownload:
        if (ids.length == 1) {
          showDownloadVideoBottomSheet(videoId: ids.first, originalIndex: null, totalLength: null, playlistId: null, streamInfoItem: null);
        } else {
          final ptitle = 'External - ${DateTime.now().millisecondsSinceEpoch.dateAndClockFormattedOriginal}';
          YTPlaylistDownloadPage(
            ids: ids.map((e) => YoutubeID(id: e, playlistID: null)).toList(),
            playlistName: ptitle,
            infoLookup: const {},
            playlistInfo: PlaylistBasicInfo(
              id: '',
              title: ptitle,
              videosCountText: ids.length.toString(),
              videosCount: ids.length,
              thumbnails: [],
            ),
          ).navigate();
        }
        return true;
      case OnYoutubeLinkOpenAction.addToPlaylist:
        showAddToPlaylistSheet(ids: ids, idsNamesLookup: {});
        return true;
      case OnYoutubeLinkOpenAction.play:
        await Player.inst.playOrPause(0, getPlayables(), QueueSource.others);
        return true;
      case OnYoutubeLinkOpenAction.playNext:
        return Player.inst.addToQueue(getPlayables(), insertNext: true);
      case OnYoutubeLinkOpenAction.playLast:
        return Player.inst.addToQueue(getPlayables(), insertNext: false);
      case OnYoutubeLinkOpenAction.playAfter:
        return Player.inst.addToQueue(getPlayables(), insertAfterLatest: true);
      case OnYoutubeLinkOpenAction.alwaysAsk:
        final videoNamesSubtitle = ids
                .map((id) => YoutubeInfoController.utils.getVideoName(id) ?? id) //
                .take(3)
                .join(', ') +
            (ids.length > 3 ? '... + ${ids.length - 3}' : '');
        _showAskDialog((action) => action.execute(ids), title: videoNamesSubtitle);
        return true;
    }
  }

  void _showAskDialog(void Function(OnYoutubeLinkOpenAction action) onTap, {String? title}) {
    final isItemEnabled = <OnYoutubeLinkOpenAction, bool>{
      OnYoutubeLinkOpenAction.playNext: true,
      OnYoutubeLinkOpenAction.playAfter: true,
      OnYoutubeLinkOpenAction.playLast: true,
    }.obs;

    final playAfterVid = YTUtils.getPlayerAfterVideo();

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        isItemEnabled.close();
      },
      dialogBuilder: (theme) => CustomBlurryDialog(
        title: lang.CHOOSE,
        titleWidgetInPadding: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.CHOOSE,
              style: theme.textTheme.displayLarge,
            ),
            if (title != null && title.isNotEmpty)
              Text(
                title,
                style: theme.textTheme.displaySmall,
              ),
          ],
        ),
        normalTitleStyle: true,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          children: [
            ...[
              OnYoutubeLinkOpenAction.showDownload,
              OnYoutubeLinkOpenAction.play,
              OnYoutubeLinkOpenAction.playNext,
              if (playAfterVid != null) OnYoutubeLinkOpenAction.playAfter,
              OnYoutubeLinkOpenAction.playLast,
              OnYoutubeLinkOpenAction.addToPlaylist,
            ].map(
              (e) {
                final isPlayAfter = e == OnYoutubeLinkOpenAction.playAfter && playAfterVid != null;
                final extraTitle = isPlayAfter ? ": ${playAfterVid.diff.displayVideoKeyword}" : "";
                String? subtitle = isPlayAfter ? playAfterVid.name : null;
                if (subtitle == '') subtitle = null;
                return Obx(
                  (context) => CustomListTile(
                    enabled: isItemEnabled[e] ?? true,
                    icon: e.toIcon(),
                    title: e.toText() + extraTitle,
                    subtitle: subtitle,
                    visualDensity: null,
                    onTap: () {
                      onTap(e);
                      if (isItemEnabled[e] != null) {
                        isItemEnabled[e] = false; // only disable existing item
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension PerformanceModeUtils on PerformanceMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);

  Future<void> executeAndSave() async {
    switch (this) {
      case PerformanceMode.highPerformance:
        settings.save(
          performanceMode: PerformanceMode.highPerformance,
          enableBlurEffect: false,
          enableGlowEffect: false,
          enableMiniplayerParallaxEffect: false,
          artworkCacheHeightMultiplier: 0.8,
          autoColor: false,
          animatedTheme: false,
        );
      case PerformanceMode.balanced:
        settings.save(
          performanceMode: PerformanceMode.balanced,
          enableBlurEffect: false,
          enableGlowEffect: false,
          enableMiniplayerParallaxEffect: true,
          artworkCacheHeightMultiplier: 0.9,
          autoColor: true,
          animatedTheme: false,
        );
      case PerformanceMode.goodLooking:
        settings.save(
          performanceMode: PerformanceMode.goodLooking,
          enableBlurEffect: true,
          enableGlowEffect: true,
          enableMiniplayerParallaxEffect: true,
          artworkCacheHeightMultiplier: 1.0,
          autoColor: true,
          animatedTheme: true,
        );
      case PerformanceMode.custom:
        settings.save(
          performanceMode: PerformanceMode.custom,
        );
      default:
        null;
    }
  }
}

extension ThemeUtils on ThemeMode {
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension QueueInsertionTypeToQI on QueueInsertionType {
  QueueInsertion toQueueInsertion() => settings.queueInsertion.value[this] ?? const QueueInsertion(numberOfTracks: 0, insertNext: true, sortBy: InsertionSortingType.none);

  /// NOTE: Modifies the original list.
  List<Selectable> shuffleOrSort(List<Selectable> tracks) {
    final sortBy = toQueueInsertion().sortBy;

    switch (sortBy) {
      case InsertionSortingType.listenCount:
        if (this == QueueInsertionType.algorithm) {
          // already sorted by repeated times inside [NamidaGenerator.generateRecommendedTrack].
        } else {
          tracks.sortByReverse((e) => HistoryController.inst.topTracksMapListens.value[e.track]?.length ?? 0);
        }
      case InsertionSortingType.rating:
        tracks.sortByReverse((e) => e.track.effectiveRating);
      case InsertionSortingType.random:
        tracks.shuffle();
      case InsertionSortingType.none: // do nothing
    }

    return tracks;
  }

  /// NOTE: Modifies the original list.
  List<YoutubeID> shuffleOrSortYT(List<YoutubeID> videos) {
    final sortBy = toQueueInsertion().sortBy;

    switch (sortBy) {
      case InsertionSortingType.listenCount:
        if (this == QueueInsertionType.algorithm) {
          // already sorted by repeated times inside [NamidaGenerator.generateRecommendedTrack].
        } else {
          videos.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.length ?? 0);
        }
      case InsertionSortingType.random:
        videos.shuffle();

      case InsertionSortingType.rating: // no ratings yet
      case InsertionSortingType.none: // do nothing
    }

    return videos;
  }
}

extension InsertionSortingTypeTextIcon on InsertionSortingType {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension YTHomePagesUils on YTHomePages {
  String toText() => _NamidaConverters.inst.getTitle(this);
  IconData toIcon() => _NamidaConverters.inst.getIcon(this);
}

extension PlaylistAddDuplicateActionUtils on PlaylistAddDuplicateAction {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension YTSeekActionModeUtils on YTSeekActionMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension CommentsSortTypeUtils on CommentsSortType {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension ChannelNotificationsUtils on ChannelNotifications {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension YTVisibleShortPlacesUtils on YTVisibleShortPlaces {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension YTVisibleMixesPlacesUtils on YTVisibleMixesPlaces {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension PlaylistPrivacyUtils on PlaylistPrivacy {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension RouteUtils on NamidaRoute {
  List<Selectable> tracksListInside() {
    final iter = tracksInside();
    return iter is List ? iter as List<Selectable> : iter.toList();
  }

  bool hasTracksInside() => tracksInside().isNotEmpty;

  /// NOTE: any modification done to this will be reflected in the original list.
  Iterable<Selectable> tracksInside() {
    return switch (route) {
          RouteType.PAGE_allTracks => SearchSortController.inst.trackSearchList.value,
          RouteType.PAGE_folders => Folders.tracks.currentFolder.value?.tracks(),
          RouteType.PAGE_folders_videos => Folders.videos.currentFolder.value?.tracks(),
          RouteType.SUBPAGE_albumTracks => name?.getAlbumTracks(),
          RouteType.SUBPAGE_artistTracks => name?.getArtistTracks(),
          RouteType.SUBPAGE_albumArtistTracks => name?.getAlbumArtistTracks(),
          RouteType.SUBPAGE_composerTracks => name?.getComposerTracks(),
          RouteType.SUBPAGE_genreTracks => name?.getGenresTracks(),
          RouteType.SUBPAGE_queueTracks => name?.getQueue()?.tracks,
          RouteType.SUBPAGE_playlistTracks => name == null ? null : PlaylistController.inst.getPlaylist(name!)?.tracks,
          RouteType.SUBPAGE_historyTracks => HistoryController.inst.historyTracks,
          // RouteType.SUBPAGE_mostPlayedTracks => HistoryController.inst.currentMostPlayedTracks,
          RouteType.SUBPAGE_recentlyAddedTracks => Indexer.inst.recentlyAddedTracksSorted(),
          _ => [],
        } ??
        [];
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks], [RouteType.SUBPAGE_artistTracks],
  /// [RouteType.SUBPAGE_albumArtistTracks] & [RouteType.SUBPAGE_composerTracks].
  Track? get trackOfColor {
    final name = this.name;
    if (name == null) return null;
    if (route == RouteType.SUBPAGE_albumTracks) return name.getAlbumTracks().trackOfImage;
    if (route == RouteType.SUBPAGE_artistTracks) return name.getArtistTracks().trackOfImage;
    if (route == RouteType.SUBPAGE_albumArtistTracks) return name.getAlbumArtistTracks().trackOfImage;
    if (route == RouteType.SUBPAGE_composerTracks) return name.getComposerTracks().trackOfImage;
    return null;
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks], [RouteType.SUBPAGE_artistTracks],
  /// [RouteType.SUBPAGE_albumArtistTracks] & [RouteType.SUBPAGE_composerTracks].
  Future<void> updateColorScheme() async {
    // a delay to prevent navigation glitches
    await Future.delayed(const Duration(milliseconds: 500));

    Color? color;
    final trackToExtractFrom = trackOfColor;
    if (trackToExtractFrom != null) {
      color = await CurrentColor.inst.getTrackDelightnedColor(trackToExtractFrom, useIsolate: true);
    }
    CurrentColor.inst.updateCurrentColorSchemeOfSubPages(color);
  }

  Widget? toTitle(BuildContext context) {
    Widget getTextWidget(String t) => Text(t, style: context.textTheme.titleLarge);
    Widget? finalWidget;
    bool displaySettingSearch = false;
    switch (route) {
      case RouteType.SETTINGS_page:
        displaySettingSearch = true;
        finalWidget = getTextWidget(lang.SETTINGS);
        break;
      case RouteType.SETTINGS_subpage:
        displaySettingSearch = true;
        finalWidget = getTextWidget(name ?? '');
        break;
      case RouteType.SEARCH_albumResults:
        finalWidget = getTextWidget(lang.ALBUMS);
        break;
      case RouteType.SEARCH_artistResults:
        finalWidget = getTextWidget(lang.ARTISTS);
        break;
      case RouteType.PAGE_queue:
        finalWidget = ObxO(
          rx: QueueController.inst.queuesMap,
          builder: (context, qmap) => getTextWidget("${lang.QUEUES} • ${qmap.length}"),
        );
        break;
      default:
        null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: displaySettingSearch //
          ? NamidaSettingSearchBar(closedChild: finalWidget)
          : finalWidget ?? ScrollSearchController.inst.searchBarWidget,
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

    final shouldShowInitialActions = route != RouteType.PAGE_stats &&
        route != RouteType.SETTINGS_page &&
        route != RouteType.SETTINGS_subpage &&
        route != RouteType.YOUTUBE_USER_MANAGE_ACCOUNT_SUBPAGE &&
        route != RouteType.YOUTUBE_USER_MANAGE_SUBSCRIPTION_SUBPAGE;
    final shouldShowProgressPercentage = route != RouteType.SETTINGS_page && route != RouteType.SETTINGS_subpage;

    final name = this.name;

    final queue = route == RouteType.SUBPAGE_queueTracks ? name?.getQueue() : null;

    MediaType? sortingTracksMediaType;
    switch (route) {
      case RouteType.SUBPAGE_albumTracks:
        sortingTracksMediaType = MediaType.album;
        break;
      case RouteType.SUBPAGE_artistTracks:
      case RouteType.SUBPAGE_albumArtistTracks:
      case RouteType.SUBPAGE_composerTracks:
        sortingTracksMediaType = MediaType.artist;
        break;
      case RouteType.SUBPAGE_genreTracks:
        sortingTracksMediaType = MediaType.genre;
        break;
      // -- sorting icon is displayed in folder page itself
      // case RouteType.PAGE_folders:
      //   sortingTracksMediaType = MediaType.folder;
      //   break;

      default:
        null;
    }

    return <Widget>[
      getAnimatedCrossFade(
        child: NamidaAppBarIcon(
          icon: Broken.trush_square,
          onPressed: () => NamidaOnTaps.inst.onQueuesClearIconTap(),
        ),
        shouldShow: route == RouteType.PAGE_queue,
      ),

      // -- Parsing Json Icon
      getAnimatedCrossFade(child: const ParsingJsonPercentage(size: 30.0), shouldShow: shouldShowProgressPercentage),

      // -- Indexer Icon
      getAnimatedCrossFade(child: const IndexingPercentage(size: 30.0), shouldShow: shouldShowProgressPercentage),

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
          onPressed: const SettingsPage().navigate,
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
        child: NamidaAppBarIcon(
          icon: Broken.sort,
          onPressed: () {
            NamidaOnTaps.inst.onSubPageTracksSortIconTap(sortingTracksMediaType!);
          },
        ),
        shouldShow: sortingTracksMediaType != null,
      ),

      if (name != null)
        getAnimatedCrossFade(
          child: getMoreIcon(() {
            switch (route) {
              case RouteType.SUBPAGE_albumTracks:
                NamidaDialogs.inst.showAlbumDialog(name);
                break;
              case RouteType.SUBPAGE_artistTracks:
                NamidaDialogs.inst.showArtistDialog(name, MediaType.artist);
                break;
              case RouteType.SUBPAGE_albumArtistTracks:
                NamidaDialogs.inst.showArtistDialog(name, MediaType.albumArtist);
                break;
              case RouteType.SUBPAGE_composerTracks:
                NamidaDialogs.inst.showArtistDialog(name, MediaType.composer);
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
          shouldShow: route == RouteType.SUBPAGE_albumTracks ||
              route == RouteType.SUBPAGE_artistTracks ||
              route == RouteType.SUBPAGE_albumArtistTracks ||
              route == RouteType.SUBPAGE_composerTracks ||
              route == RouteType.SUBPAGE_genreTracks ||
              route == RouteType.SUBPAGE_queueTracks,
        ),

      getAnimatedCrossFade(
        child: HistoryJumpToDayIcon(
          controller: HistoryController.inst,
          itemExtentAndDayHeaderExtent: () => (
            itemExtent: Dimensions.inst.trackTileItemExtent,
            dayHeaderExtent: kHistoryDayHeaderHeightWithPadding,
          ),
        ),
        shouldShow: route == RouteType.SUBPAGE_historyTracks,
      ),

      getAnimatedCrossFade(
        child: HistoryJumpToDayIcon(
          controller: YoutubeHistoryController.inst,
          itemExtentAndDayHeaderExtent: () => (
            itemExtent: Dimensions.youtubeCardItemExtent,
            dayHeaderExtent: kYoutubeHistoryDayHeaderHeightWithPadding,
          ),
        ),
        shouldShow: route == RouteType.YOUTUBE_HISTORY_SUBPAGE,
      ),

      // ---- Playlist Tracks ----
      getAnimatedCrossFade(
        child: ObxO(
          key: UniqueKey(), // i have no f idea why this happens.. namida ghosts are here again
          rx: PlaylistController.inst.canReorderTracks,
          builder: (context, reorderable) => NamidaAppBarIcon(
            tooltip: () => PlaylistController.inst.canReorderTracks.value ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
            icon: reorderable ? Broken.forward_item : Broken.lock_1,
            onPressed: () => PlaylistController.inst.canReorderTracks.value = !PlaylistController.inst.canReorderTracks.value,
          ),
        ),
        shouldShow: route == RouteType.SUBPAGE_playlistTracks,
      ),
      if (name != null)
        getAnimatedCrossFade(
          child: getMoreIcon(() {
            NamidaDialogs.inst.showPlaylistDialog(name);
          }),
          shouldShow: route == RouteType.SUBPAGE_playlistTracks || route == RouteType.SUBPAGE_historyTracks || route == RouteType.SUBPAGE_mostPlayedTracks,
        ),

      getAnimatedCrossFade(
        child: ObxO(
          rx: ytplc.YoutubePlaylistController.inst.canReorderVideos,
          builder: (context, reorderable) => NamidaAppBarIcon(
            tooltip: () => ytplc.YoutubePlaylistController.inst.canReorderVideos.value ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
            icon: reorderable ? Broken.forward_item : Broken.lock_1,
            onPressed: () => ytplc.YoutubePlaylistController.inst.canReorderVideos.value = !ytplc.YoutubePlaylistController.inst.canReorderVideos.value,
          ),
        ),
        shouldShow: route == RouteType.YOUTUBE_PLAYLIST_SUBPAGE,
      ),
      const SizedBox(width: 8.0),
    ];
  }
}

extension TracksFromMaps on String {
  List<Track> getAlbumTracks() => Indexer.inst.mainMapAlbums.value[this] ?? [];

  List<Track> getArtistTracks() => Indexer.inst.mainMapArtists.value[this] ?? [];
  List<Track> getArtistTracksFor(MediaType type) {
    return switch (type) {
      MediaType.artist => Indexer.inst.mainMapArtists.value[this] ?? [],
      MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists.value[this] ?? [],
      MediaType.composer => Indexer.inst.mainMapComposer.value[this] ?? [],
      _ => Indexer.inst.mainMapArtists.value[this] ?? [],
    };
  }

  List<Track> getAlbumArtistTracks() => Indexer.inst.mainMapAlbumArtists.value[this] ?? [];
  List<Track> getComposerTracks() => Indexer.inst.mainMapComposer.value[this] ?? [];
  List<Track> getGenresTracks() => Indexer.inst.mainMapGenres.value[this] ?? [];

  Queue? getQueue() => QueueController.inst.queuesMap.value[int.tryParse(this)];
}

extension QueueFromMap on int {
  Queue? getQueue() => QueueController.inst.queuesMap.value[this];
}

extension ThemeDefaultColors on BuildContext {
  Color defaultIconColor([Color? mainColor, Color? secondaryColor]) => Color.alphaBlend(
        (mainColor ?? CurrentColor.inst.color).withAlpha(120),
        secondaryColor ?? theme.colorScheme.onSurface,
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
  snackyy(title: lang.MINIMUM_ONE_ITEM, message: lang.getMinimumItemSubtitle(minimum));
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
    _toTitle = <Type, Map<Enum, String>>{
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
        LibraryTab.foldersVideos: lang.VIDEOS,
        LibraryTab.home: lang.HOME,
        LibraryTab.search: lang.SEARCH,
        LibraryTab.youtube: lang.YOUTUBE,
      },
      MediaType: {
        MediaType.album: lang.ALBUMS,
        MediaType.track: lang.TRACKS,
        MediaType.artist: lang.ARTISTS,
        MediaType.albumArtist: lang.ALBUM_ARTISTS,
        MediaType.composer: lang.COMPOSER,
        MediaType.genre: lang.GENRES,
        MediaType.playlist: lang.PLAYLISTS,
        MediaType.folder: lang.FOLDERS,
        MediaType.folderVideo: lang.VIDEOS,
      },
      AlbumIdentifier: {
        AlbumIdentifier.albumName: lang.NAME,
        AlbumIdentifier.albumArtist: lang.ALBUM_ARTIST,
        AlbumIdentifier.year: lang.YEAR,
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
        SortType.trackNo: lang.TRACK_NUMBER,
        SortType.filename: lang.FILE_NAME,
        SortType.duration: lang.DURATION,
        SortType.genresList: lang.GENRES,
        SortType.sampleRate: lang.SAMPLE_RATE,
        SortType.size: lang.SIZE,
        SortType.year: lang.YEAR,
        SortType.rating: lang.RATING,
        SortType.shuffle: lang.SHUFFLE,
        SortType.mostPlayed: lang.MOST_PLAYED,
        SortType.latestPlayed: lang.RECENT_LISTENS,
      },
      GroupSortType: {
        GroupSortType.title: lang.TITLE,
        GroupSortType.album: lang.ALBUM,
        GroupSortType.albumArtist: lang.ALBUM_ARTIST,
        GroupSortType.artistsList: lang.ARTIST,
        GroupSortType.genresList: lang.GENRES,
        GroupSortType.composer: lang.COMPOSER,
        GroupSortType.label: lang.RECORD_LABEL,
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
        TrackTileItem.listenCount: lang.TOTAL_LISTENS,
        TrackTileItem.latestListenDate: lang.RECENT_LISTENS,
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
        QueueSource.folderVideos: lang.VIDEOS,
        QueueSource.search: lang.SEARCH,
        QueueSource.playerQueue: lang.QUEUE,
        QueueSource.queuePage: lang.QUEUES,
        QueueSource.selectedTracks: lang.SELECTED_TRACKS,
        QueueSource.externalFile: lang.EXTERNAL_FILES,
        QueueSource.recentlyAdded: lang.RECENTLY_ADDED,
        QueueSource.homePageItem: '',
        QueueSource.others: lang.OTHERS,
      },
      TagField: {
        TagField.title: lang.TITLE,
        TagField.album: lang.ALBUM,
        TagField.artist: lang.ARTIST,
        TagField.albumArtist: lang.ALBUM_ARTIST,
        TagField.genre: lang.GENRE,
        TagField.mood: lang.MOOD,
        TagField.composer: lang.COMPOSER,
        TagField.comment: lang.COMMENT,
        TagField.description: lang.DESCRIPTION,
        TagField.synopsis: lang.SYNOPSIS,
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
        TagField.rating: lang.RATING,
        TagField.tags: lang.TAGS,
      },
      VideoPlaybackSource: {
        VideoPlaybackSource.auto: lang.AUTO,
        VideoPlaybackSource.youtube: lang.VIDEO_PLAYBACK_SOURCE_YOUTUBE,
        VideoPlaybackSource.local: lang.VIDEO_PLAYBACK_SOURCE_LOCAL,
      },
      LyricsSource: {
        LyricsSource.auto: lang.AUTO,
        LyricsSource.local: lang.LOCAL,
        LyricsSource.internet: lang.DATABASE,
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
      OnTrackTileSwapActions: {
        OnTrackTileSwapActions.none: lang.NONE,
        OnTrackTileSwapActions.playnext: lang.PLAY_NEXT,
        OnTrackTileSwapActions.playlast: lang.PLAY_LAST,
        OnTrackTileSwapActions.playafter: lang.PLAY_AFTER,
        OnTrackTileSwapActions.addtoplaylist: lang.ADD_TO_PLAYLIST,
      },
      InsertionSortingType: {
        InsertionSortingType.listenCount: lang.TOTAL_LISTENS,
        InsertionSortingType.random: lang.RANDOM,
        InsertionSortingType.rating: lang.RATING,
        InsertionSortingType.none: lang.DEFAULT,
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
      },
      OnYoutubeLinkOpenAction: {
        OnYoutubeLinkOpenAction.showDownload: lang.DOWNLOAD,
        OnYoutubeLinkOpenAction.play: lang.PLAY,
        OnYoutubeLinkOpenAction.playNext: lang.PLAY_NEXT,
        OnYoutubeLinkOpenAction.playAfter: lang.PLAY_AFTER,
        OnYoutubeLinkOpenAction.playLast: lang.PLAY_LAST,
        OnYoutubeLinkOpenAction.addToPlaylist: lang.ADD_TO_PLAYLIST,
        OnYoutubeLinkOpenAction.alwaysAsk: lang.ALWAYS_ASK,
      },
      PerformanceMode: {
        PerformanceMode.highPerformance: lang.HIGH_PERFORMANCE,
        PerformanceMode.balanced: lang.BALANCED,
        PerformanceMode.goodLooking: lang.GOOD_LOOKING,
        PerformanceMode.custom: lang.CUSTOM,
      },
      KillAppMode: {
        KillAppMode.never: lang.NEVER,
        KillAppMode.ifNotPlaying: lang.IF_NOT_PLAYING,
        KillAppMode.always: lang.ALWAYS,
      },
      FABType: {
        FABType.none: lang.NONE,
        FABType.search: lang.SEARCH,
        FABType.shuffle: lang.SHUFFLE,
        FABType.play: lang.PLAY,
      },
      YTHomePages: {
        YTHomePages.home: lang.HOME,
        YTHomePages.notifications: lang.NOTIFICATIONS,
        YTHomePages.channels: lang.CHANNELS,
        YTHomePages.playlists: lang.PLAYLISTS,
        YTHomePages.userplaylists: '${lang.PLAYLISTS} (${lang.YOUTUBE})',
        YTHomePages.downloads: lang.DOWNLOADS,
      },
      TrackSearchFilter: {
        TrackSearchFilter.filename: lang.FILE_NAME,
        TrackSearchFilter.title: lang.TITLE,
        TrackSearchFilter.album: lang.ALBUM,
        TrackSearchFilter.artist: lang.ARTIST,
        TrackSearchFilter.albumartist: lang.ALBUM_ARTIST,
        TrackSearchFilter.genre: lang.GENRE,
        TrackSearchFilter.composer: lang.COMPOSER,
        TrackSearchFilter.comment: lang.COMMENT,
        TrackSearchFilter.year: lang.YEAR,
      },
      SetMusicAsAction: {
        SetMusicAsAction.ringtone: lang.RINGTONE,
        SetMusicAsAction.notification: lang.NOTIFICATION,
        SetMusicAsAction.alarm: lang.ALARM,
      },
      PlaylistAddDuplicateAction: {
        PlaylistAddDuplicateAction.justAddEverything: lang.ADD_ALL,
        PlaylistAddDuplicateAction.addAllAndRemoveOldOnes: lang.ADD_ALL_AND_REMOVE_OLD_ONES,
        PlaylistAddDuplicateAction.addOnlyMissing: lang.ADD_ONLY_MISSING,
      },
      YTSeekActionMode: {
        YTSeekActionMode.none: lang.NONE,
        YTSeekActionMode.minimizedMiniplayer: lang.MINIMIZED_MINIPLAYER,
        YTSeekActionMode.expandedMiniplayer: lang.EXPANDED_MINIPLAYER,
        YTSeekActionMode.all: lang.ALL,
      },
      CommentsSortType: {
        CommentsSortType.top: lang.TOP,
        CommentsSortType.newest: lang.NEWEST,
      },
      ChannelNotifications: {
        ChannelNotifications.all: lang.ALL,
        ChannelNotifications.personalized: lang.PERSONALIZED,
        ChannelNotifications.none: lang.NONE,
      },
      YTVisibleShortPlaces: {
        YTVisibleShortPlaces.homeFeed: lang.HOME,
        YTVisibleShortPlaces.relatedVideos: lang.RELATED_VIDEOS,
        YTVisibleShortPlaces.history: lang.HISTORY,
        YTVisibleShortPlaces.search: lang.SEARCH,
      },
      YTVisibleMixesPlaces: {
        YTVisibleMixesPlaces.homeFeed: lang.HOME,
        YTVisibleMixesPlaces.relatedVideos: lang.RELATED_VIDEOS,
        YTVisibleMixesPlaces.search: lang.SEARCH,
      },
      PlaylistPrivacy: {
        PlaylistPrivacy.public: lang.PUBLIC,
        PlaylistPrivacy.unlisted: lang.UNLISTED,
        PlaylistPrivacy.private: lang.PRIVATE,
      },
    };

    // ====================================================
    // ====================== Subtitle ====================
    // ====================================================
    _toSubtitle = <Type, Map<Enum, String?>>{
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
    _toIcon = <Type, Map<Enum, IconData>>{
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
        LibraryTab.foldersVideos: Broken.video_play,
        LibraryTab.home: Broken.home_2,
        LibraryTab.search: Broken.search_normal_1,
        LibraryTab.youtube: Broken.video_square,
      },
      TagField: {
        TagField.title: Broken.music,
        TagField.album: Broken.music_dashboard,
        TagField.artist: Broken.microphone,
        TagField.albumArtist: Broken.user,
        TagField.genre: Broken.smileys,
        TagField.mood: Broken.happyemoji,
        TagField.composer: Broken.profile_2user,
        TagField.comment: Broken.text_block,
        TagField.description: Broken.note_text,
        TagField.synopsis: Broken.text,
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
        TagField.rating: Broken.grammerly,
        TagField.tags: Broken.ticket_discount,
      },
      InsertionSortingType: {
        InsertionSortingType.listenCount: Broken.award,
        InsertionSortingType.random: Broken.format_circle,
        InsertionSortingType.rating: Broken.grammerly,
        InsertionSortingType.none: Broken.cd,
      },
      OnYoutubeLinkOpenAction: {
        OnYoutubeLinkOpenAction.showDownload: Broken.import,
        OnYoutubeLinkOpenAction.play: Broken.play,
        OnYoutubeLinkOpenAction.playNext: Broken.next,
        OnYoutubeLinkOpenAction.playAfter: Broken.hierarchy_square,
        OnYoutubeLinkOpenAction.playLast: Broken.play_cricle,
        OnYoutubeLinkOpenAction.addToPlaylist: Broken.music_library_2,
        OnYoutubeLinkOpenAction.alwaysAsk: Broken.message_question,
      },
      PerformanceMode: {
        PerformanceMode.highPerformance: Broken.activity,
        PerformanceMode.balanced: Broken.cd,
        PerformanceMode.goodLooking: Broken.buy_crypto,
        PerformanceMode.custom: Broken.candle,
      },
      FABType: {
        FABType.none: Broken.status,
        FABType.search: Broken.search_normal,
        FABType.shuffle: Broken.shuffle,
        FABType.play: Broken.play_cricle,
      },
      YTHomePages: {
        YTHomePages.home: Broken.home_1,
        YTHomePages.notifications: Broken.notification_bing,
        YTHomePages.channels: Broken.profile_2user,
        YTHomePages.playlists: Broken.music_library_2,
        YTHomePages.userplaylists: Broken.music_dashboard,
        YTHomePages.downloads: Broken.import,
      },
    };

    _ffmpegToTitle = {
      FFMPEGTagField.title: lang.TITLE,
      FFMPEGTagField.album: lang.ALBUM,
      FFMPEGTagField.artist: lang.ARTIST,
      FFMPEGTagField.albumArtist: lang.ALBUM_ARTIST,
      FFMPEGTagField.genre: lang.GENRE,
      FFMPEGTagField.mood: lang.MOOD,
      FFMPEGTagField.composer: lang.COMPOSER,
      FFMPEGTagField.comment: lang.COMMENT,
      FFMPEGTagField.description: lang.DESCRIPTION,
      FFMPEGTagField.synopsis: lang.SYNOPSIS,
      FFMPEGTagField.lyrics: lang.LYRICS,
      FFMPEGTagField.trackNumber: lang.TRACK_NUMBER,
      FFMPEGTagField.discNumber: lang.DISC_NUMBER,
      FFMPEGTagField.trackTotal: lang.TRACK_NUMBER_TOTAL,
      FFMPEGTagField.discTotal: lang.DISC_NUMBER_TOTAL,
      FFMPEGTagField.year: lang.YEAR,
      FFMPEGTagField.remixer: lang.REMIXER,
      FFMPEGTagField.lyricist: lang.LYRICIST,
      FFMPEGTagField.language: lang.LANGUAGE,
      FFMPEGTagField.recordLabel: lang.RECORD_LABEL,
      FFMPEGTagField.country: lang.COUNTRY,
      FFMPEGTagField.rating: lang.RATING,
      FFMPEGTagField.tags: lang.TAGS,
    };
    _ffmpegToIcon = {
      FFMPEGTagField.title: Broken.music,
      FFMPEGTagField.album: Broken.music_dashboard,
      FFMPEGTagField.artist: Broken.microphone,
      FFMPEGTagField.albumArtist: Broken.user,
      FFMPEGTagField.genre: Broken.smileys,
      FFMPEGTagField.mood: Broken.happyemoji,
      FFMPEGTagField.composer: Broken.profile_2user,
      FFMPEGTagField.comment: Broken.text_block,
      FFMPEGTagField.description: Broken.note_text,
      FFMPEGTagField.synopsis: Broken.text,
      FFMPEGTagField.lyrics: Broken.message_text,
      FFMPEGTagField.trackNumber: Broken.hashtag,
      FFMPEGTagField.discNumber: Broken.hashtag,
      FFMPEGTagField.trackTotal: Broken.hashtag,
      FFMPEGTagField.discTotal: Broken.hashtag,
      FFMPEGTagField.year: Broken.calendar,
      FFMPEGTagField.remixer: Broken.radio,
      FFMPEGTagField.lyricist: Broken.pen_add,
      FFMPEGTagField.language: Broken.language_circle,
      FFMPEGTagField.recordLabel: Broken.ticket,
      FFMPEGTagField.country: Broken.house,
      FFMPEGTagField.rating: Broken.grammerly,
      FFMPEGTagField.tags: Broken.ticket_discount,
    };
  }

  var _toTitle = <Type, Map<Enum, String>>{};
  var _toSubtitle = <Type, Map<Enum, String?>>{};
  var _toIcon = <Type, Map<Enum, IconData>>{};

  var _ffmpegToTitle = <String, String>{};
  var _ffmpegToIcon = <String, IconData>{};

  String getTitle(Enum enumValue) {
    return _toTitle[enumValue.runtimeType]![enumValue]!;
  }

  String? getSubtitle(Enum enumValue) {
    return _toSubtitle[enumValue.runtimeType]?[enumValue];
  }

  IconData getIcon(Enum enumValue) {
    return _toIcon[enumValue.runtimeType]![enumValue]!;
  }

  String ffmpegTagFieldName(String tag) {
    return _ffmpegToTitle[tag]!;
  }

  IconData ffmpegTagFieldIcon(String tag) {
    return _ffmpegToIcon[tag]!;
  }
}
