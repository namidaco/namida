// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:history_manager/history_manager.dart';
import 'package:namida/class/folder.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/faudiomodel.dart';
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
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
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
import 'package:namida/ui/pages/subpages/indexer_missing_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';
import 'package:namida/ui/pages/tracks_page.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_search_bar.dart';
import 'package:namida/ui/widgets/stats.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart' as ytplc;
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/youtube_home_view.dart';
import 'package:namida/youtube/pages/yt_history_page.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/youtube_playlists_view.dart';
import 'package:namida/youtube/yt_utils.dart';

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
      case LibraryTab.playlists:
        return MediaType.playlist;
      case LibraryTab.folders:
        return MediaType.folder;
      default:
        return null;
    }
  }

  int toInt() => settings.libraryTabs.value.indexOf(this);

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
      case LibraryTab.youtube:
        page = const YouTubeHomeView();
        break;
      default:
        null;
    }

    return page;
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

extension CacheGetterAudio on AudioOnlyStream {
  String cacheKey(String id) {
    final audio = this;
    // -- wont save english track, only saves non-english ones.
    final langCode = audio.language?.toLowerCase();
    final langName = audio.displayLanguage?.toLowerCase();
    final isNull = langCode == null || langName == null;
    final isEnglish = langCode == 'en' || langName == 'english';
    final languageText = isNull || isEnglish ? '' : '_${audio.language}_${audio.displayLanguage}';
    return "$id${languageText}_${audio.bitrate}.${audio.formatSuffix}";
  }

  String cachePath(String id, {String? directory}) {
    return p.join(directory ?? AppDirs.AUDIOS_CACHE, cacheKey(id));
  }

  File? getCachedFile(String? id, {String? directory}) {
    if (id == null) return null;
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
    return p.join(directory ?? AppDirs.VIDEOS_CACHE, cacheKey(id));
  }

  File? getCachedFile(String? id, {String? directory}) {
    if (id == null) return null;
    final path = cachePath(id, directory: directory);
    return File(path).existsSync() ? File(path) : null;
  }
}

extension StreamInfoUtils on StreamInfoItem {
  VideoInfo toVideoInfo() {
    return VideoInfo(
      id: id,
      url: url,
      name: name,
      uploaderName: uploaderName,
      uploaderUrl: uploaderUrl,
      uploaderAvatarUrl: uploaderAvatarUrl,
      date: date,
      isDateApproximation: isDateApproximation,
      description: null,
      duration: duration,
      viewCount: viewCount,
      likeCount: null,
      category: null,
      ageLimit: null,
      tags: null,
      thumbnailUrl: thumbnailUrl,
      isUploaderVerified: isUploaderVerified,
      textualUploadDate: textualUploadDate,
      uploaderSubscriberCount: -1,
      privacy: null,
      isShortFormContent: isShortFormContent,
    );
  }
}

extension MediaInfoToFAudioModel on MediaInfo? {
  FAudioModel? toFAudioModel() {
    final infoFull = this;
    final info = infoFull?.format?.tags;
    if (infoFull == null || info == null) return null;
    final trackNumberTotal = info.track?.split('/');
    final discNumberTotal = info.disc?.split('/');
    final audioStream = infoFull.streams?.firstWhereEff((e) => e.streamType == StreamType.audio);
    int? parsy(String? v) => v == null ? null : int.tryParse(v);
    final bitrate = parsy(infoFull.format?.bitRate); // 234292
    final bitrateThousands = bitrate == null ? null : bitrate / 1000; // 234
    return FAudioModel(
      tags: FTags(
        path: infoFull.path,
        artwork: FArtwork(),
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
        year: info.date,
        language: info.language,
        lyricist: info.lyricist,
        remixer: info.remixer,
        mood: info.mood,
        country: info.country,
      ),
      length: infoFull.format?.duration?.inSeconds,
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
        addThese(Player.inst.currentQueue.value.mapAs<Selectable>());
        break;
      case QueueSource.recentlyAdded:
        addThese(Indexer.inst.recentlyAddedTracks);
        break;
      default:
        addThese(SelectedTracksController.inst.getCurrentAllTracks());
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

  Future<void> executePlaylist(String playlistUrl, {YoutubePlaylist? playlist, required BuildContext? context}) async {
    final plInfo = playlist ?? await YoutubeController.inst.getPlaylistInfo(playlistUrl);
    if (plInfo == null) {
      snackyy(title: lang.ERROR, message: 'error retrieving playlist info, check your connection?');
      return;
    }
    final didFetch = await plInfo.fetchAllPlaylistStreams(context: context?.mounted == true ? context : null);
    if (!didFetch) {
      snackyy(title: lang.ERROR, message: 'error fetching playlist videos');
      return;
    }

    final streams = plInfo.streams;

    final playlistId = playlist?.id == null ? null : PlaylistID(id: playlist!.id!);
    Iterable<YoutubeID> getPlayables() => streams.map((e) => YoutubeID(id: e.id ?? '', playlistID: playlistId));

    switch (this) {
      case OnYoutubeLinkOpenAction.showDownload:
        plInfo.showPlaylistDownloadSheet(context: context?.mounted == true ? context : null);
      case OnYoutubeLinkOpenAction.addToPlaylist:
        showAddToPlaylistSheet(ids: streams.map((e) => e.id ?? ''), idsNamesLookup: {});
      case OnYoutubeLinkOpenAction.play:
        await Player.inst.playOrPause(0, getPlayables(), QueueSource.others);
      case OnYoutubeLinkOpenAction.playNext:
        await Player.inst.addToQueue(getPlayables(), insertNext: true);
      case OnYoutubeLinkOpenAction.playLast:
        await Player.inst.addToQueue(getPlayables(), insertNext: false);
      case OnYoutubeLinkOpenAction.playAfter:
        await Player.inst.addToQueue(getPlayables(), insertAfterLatest: true);
      case OnYoutubeLinkOpenAction.alwaysAsk:
        _showAskDialog(
          (action) => action.executePlaylist(playlistUrl, context: context, playlist: plInfo),
          playlistToOpen: plInfo,
          playlistToAddAs: plInfo,
        );

      default:
        null;
    }
  }

  Future<void> execute(Iterable<String> ids) async {
    Iterable<YoutubeID> getPlayables() => ids.map((e) => YoutubeID(id: e, playlistID: null));
    switch (this) {
      case OnYoutubeLinkOpenAction.showDownload:
        if (ids.length == 1) {
          showDownloadVideoBottomSheet(videoId: ids.first);
        } else {
          NamidaNavigator.inst.navigateTo(
            YTPlaylistDownloadPage(
              ids: ids.map((e) => YoutubeID(id: e, playlistID: null)).toList(),
              playlistName: 'External - ${DateTime.now().millisecondsSinceEpoch.dateAndClockFormattedOriginal}',
              infoLookup: const {},
            ),
          );
        }
      case OnYoutubeLinkOpenAction.addToPlaylist:
        showAddToPlaylistSheet(ids: ids, idsNamesLookup: {});
      case OnYoutubeLinkOpenAction.play:
        await Player.inst.playOrPause(0, getPlayables(), QueueSource.others);
      case OnYoutubeLinkOpenAction.playNext:
        await Player.inst.addToQueue(getPlayables(), insertNext: true);
      case OnYoutubeLinkOpenAction.playLast:
        await Player.inst.addToQueue(getPlayables(), insertNext: false);
      case OnYoutubeLinkOpenAction.playAfter:
        await Player.inst.addToQueue(getPlayables(), insertAfterLatest: true);
      case OnYoutubeLinkOpenAction.alwaysAsk:
        _showAskDialog((action) => action.execute(ids));

      default:
        null;
    }
  }

  void _showAskDialog(void Function(OnYoutubeLinkOpenAction action) onTap, {YoutubePlaylist? playlistToOpen, YoutubePlaylist? playlistToAddAs}) {
    String playlistNameToAddAs = playlistToAddAs?.name ?? '';
    String suffix = '';
    int suffixIndex = 1;
    while (ytplc.YoutubePlaylistController.inst.playlistsMap["$playlistNameToAddAs$suffix"] != null) {
      suffixIndex++;
      suffix = ' ($suffixIndex)';
    }
    playlistNameToAddAs += suffix;

    final didAddToPlaylist = false.obs;
    final isItemEnabled = <OnYoutubeLinkOpenAction, bool>{
      OnYoutubeLinkOpenAction.playNext: true,
      OnYoutubeLinkOpenAction.playAfter: true,
      OnYoutubeLinkOpenAction.playLast: true,
    }.obs;

    final playAfterVid = YTUtils.getPlayerAfterVideo();

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        didAddToPlaylist.close();
        isItemEnabled.close();
      },
      dialog: CustomBlurryDialog(
        title: lang.CHOOSE,
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.DONE,
            onPressed: NamidaNavigator.inst.closeDialog,
          )
        ],
        child: Column(
          children: [
            if (playlistToOpen != null)
              CustomListTile(
                icon: Broken.export_2,
                title: lang.OPEN,
                onTap: () {
                  NamidaNavigator.inst.navigateTo(YTHostedPlaylistSubpage(playlist: playlistToOpen));
                },
              ),
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
                  () => CustomListTile(
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
            if (playlistNameToAddAs != '')
              Obx(
                () => CustomListTile(
                  enabled: !didAddToPlaylist.valueR,
                  icon: Broken.add_square,
                  title: lang.ADD_AS_A_NEW_PLAYLIST,
                  subtitle: playlistNameToAddAs,
                  onTap: () {
                    didAddToPlaylist.value = true;
                    ytplc.YoutubePlaylistController.inst.addNewPlaylist(
                      playlistNameToAddAs,
                      videoIds: playlistToAddAs?.streams.map((e) => e.id ?? '') ?? [],
                    );
                  },
                ),
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

  Future<void> execute() async {
    switch (this) {
      case PerformanceMode.highPerformance:
        settings.save(
          enableBlurEffect: false,
          enableGlowEffect: false,
          enableMiniplayerParallaxEffect: false,
          artworkCacheHeightMultiplier: 0.8,
        );
      case PerformanceMode.balanced:
        settings.save(
          enableBlurEffect: false,
          enableGlowEffect: false,
          enableMiniplayerParallaxEffect: true,
          artworkCacheHeightMultiplier: 0.9,
        );
      case PerformanceMode.goodLooking:
        settings.save(
          enableBlurEffect: true,
          enableGlowEffect: true,
          enableMiniplayerParallaxEffect: true,
          artworkCacheHeightMultiplier: 1.0,
        );
      // case PerformanceMode.custom:
      default:
        null;
    }
  }
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
      // case InsertionSortingType.rating:
      //   tracks.sortByReverse((e) => e.track.stats.rating);
      case InsertionSortingType.random:
        videos.shuffle();

      default:
        null;
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
}

extension PlaylistAddDuplicateActionUtils on PlaylistAddDuplicateAction {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension YTSeekActionModeUtils on YTSeekActionMode {
  String toText() => _NamidaConverters.inst.getTitle(this);
}

extension WidgetsPagess on Widget {
  NamidaRoute toNamidaRoute() {
    String name = '';
    RouteType route = RouteType.UNKNOWN;
    switch (runtimeType) {
      // ----- Pages -----
      case const (TracksPage):
        route = RouteType.PAGE_allTracks;
        break;
      case const (AlbumsPage):
        route = RouteType.PAGE_albums;
        break;
      case const (ArtistsPage):
        route = RouteType.PAGE_artists;
        break;
      case const (GenresPage):
        route = RouteType.PAGE_genres;
        break;
      case const (PlaylistsPage):
        route = RouteType.PAGE_playlists;
        break;
      case const (FoldersPage):
        route = RouteType.PAGE_folders;
        break;
      case const (QueuesPage):
        route = RouteType.PAGE_queue;
        break;
      case const (AboutPage):
        route = RouteType.PAGE_about;
        break;

      // ----- Subpages -----
      case const (RecentlyAddedTracksPage):
        route = RouteType.SUBPAGE_recentlyAddedTracks;
        break;
      case const (AlbumTracksPage):
        route = RouteType.SUBPAGE_albumTracks;
        name = (this as AlbumTracksPage).albumIdentifier;
        break;
      case const (ArtistTracksPage):
        final page = (this as ArtistTracksPage);
        final type = page.type;
        route = type == MediaType.albumArtist
            ? RouteType.SUBPAGE_albumArtistTracks
            : type == MediaType.composer
                ? RouteType.SUBPAGE_composerTracks
                : RouteType.SUBPAGE_artistTracks;
        name = page.name;
        break;
      case const (GenreTracksPage):
        route = RouteType.SUBPAGE_genreTracks;
        name = (this as GenreTracksPage).name;
        break;
      case const (NormalPlaylistTracksPage):
        route = RouteType.SUBPAGE_playlistTracks;
        name = (this as NormalPlaylistTracksPage).playlistName;
        break;
      case const (HistoryTracksPage):
        route = RouteType.SUBPAGE_historyTracks;
        name = k_PLAYLIST_NAME_HISTORY;
        break;
      case const (MostPlayedTracksPage):
        route = RouteType.SUBPAGE_mostPlayedTracks;
        name = k_PLAYLIST_NAME_MOST_PLAYED;
        break;
      case const (QueueTracksPage):
        route = RouteType.SUBPAGE_queueTracks;
        name = (this as QueueTracksPage).queue.date.toString();
        break;
      case const (IndexerMissingTracksSubpage):
        route = RouteType.SUBPAGE_INDEXER_UPDATE_MISSING_TRACKS;
        break;

      // ----- Search Results -----
      case const (AlbumSearchResultsPage):
        route = RouteType.SEARCH_albumResults;
        break;
      case const (ArtistSearchResultsPage):
        route = RouteType.SEARCH_artistResults;
        break;

      // ----- Settings -----
      case const (SettingsPage):
        route = RouteType.SETTINGS_page;
        break;
      case const (SettingsSubPage):
        route = RouteType.SETTINGS_subpage;
        name = (this as SettingsSubPage).title;
        break;

      case const (YouTubeHomeView):
        route = RouteType.YOUTUBE_HOME;
        break;
      case const (YoutubePlaylistsView):
        route = RouteType.YOUTUBE_PLAYLISTS;
        break;
      case const (YTNormalPlaylistSubpage):
        route = RouteType.YOUTUBE_PLAYLIST_SUBPAGE;
        name = (this as YTNormalPlaylistSubpage).playlistName;
        break;
      case const (YTHostedPlaylistSubpage):
        route = RouteType.YOUTUBE_PLAYLIST_SUBPAGE_HOSTED;
        name = (this as YTHostedPlaylistSubpage).playlist.name ?? '';
        break;
      case const (YTPlaylistDownloadPage):
        route = RouteType.YOUTUBE_PLAYLIST_DOWNLOAD_SUBPAGE;
        name = (this as YTPlaylistDownloadPage).playlistName;
        break;
      case const (YoutubeHistoryPage):
        route = RouteType.YOUTUBE_HISTORY_SUBPAGE;
        break;
      case const (YTMostPlayedVideosPage):
        route = RouteType.YOUTUBE_MOST_PLAYED_SUBPAGE;
        break;
      case const (YTLikedVideosPage):
        route = RouteType.YOUTUBE_LIKED_SUBPAGE;
        break;
    }

    return NamidaRoute(route, name);
  }
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
          RouteType.PAGE_folders => Folders.inst.currentFolder.value?.tracks(),
          RouteType.SUBPAGE_albumTracks => name.getAlbumTracks(),
          RouteType.SUBPAGE_artistTracks => name.getArtistTracks(),
          RouteType.SUBPAGE_albumArtistTracks => name.getAlbumArtistTracks(),
          RouteType.SUBPAGE_composerTracks => name.getComposerTracks(),
          RouteType.SUBPAGE_genreTracks => name.getGenresTracks(),
          RouteType.SUBPAGE_queueTracks => name.getQueue()?.tracks,
          RouteType.SUBPAGE_playlistTracks => PlaylistController.inst.getPlaylist(name)?.tracks,
          RouteType.SUBPAGE_historyTracks => HistoryController.inst.historyTracks,
          RouteType.SUBPAGE_mostPlayedTracks => HistoryController.inst.currentMostPlayedTracks,
          RouteType.SUBPAGE_recentlyAddedTracks => Indexer.inst.recentlyAddedTracks,
          _ => [],
        } ??
        [];
  }

  /// Currently Supports only [RouteType.SUBPAGE_albumTracks], [RouteType.SUBPAGE_artistTracks],
  /// [RouteType.SUBPAGE_albumArtistTracks] & [RouteType.SUBPAGE_composerTracks].
  Track? get trackOfColor {
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
        finalWidget = ObxO(
          rx: QueueController.inst.queuesMap,
          builder: (qmap) => getTextWidget("${lang.QUEUES} • ${qmap.length}"),
        );
        break;
      default:
        null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: (route == RouteType.SETTINGS_page || route == RouteType.SETTINGS_subpage)
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

    final shouldShowInitialActions = route != RouteType.PAGE_stats && route != RouteType.SETTINGS_page && route != RouteType.SETTINGS_subpage;
    final shouldShowProgressPercentage = route != RouteType.SETTINGS_page && route != RouteType.SETTINGS_subpage;

    final queue = route == RouteType.SUBPAGE_queueTracks ? name.getQueue() : null;

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
        child: NamidaAppBarIcon(
          icon: Broken.sort,
          onPressed: () {
            NamidaOnTaps.inst.onSubPageTracksSortIconTap(sortingTracksMediaType!);
          },
        ),
        shouldShow: sortingTracksMediaType != null,
      ),

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

      getAnimatedCrossFade(child: HistoryJumpToDayIcon(controller: HistoryController.inst), shouldShow: route == RouteType.SUBPAGE_historyTracks),

      getAnimatedCrossFade(child: HistoryJumpToDayIcon(controller: YoutubeHistoryController.inst), shouldShow: route == RouteType.YOUTUBE_HISTORY_SUBPAGE),

      // ---- Playlist Tracks ----
      getAnimatedCrossFade(
        child: ObxO(
          rx: PlaylistController.inst.canReorderTracks,
          builder: (reorderable) => NamidaAppBarIcon(
            tooltip: reorderable ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
            icon: reorderable ? Broken.forward_item : Broken.lock_1,
            onPressed: () => PlaylistController.inst.canReorderTracks.value = !PlaylistController.inst.canReorderTracks.value,
          ),
        ),
        shouldShow: route == RouteType.SUBPAGE_playlistTracks,
      ),
      getAnimatedCrossFade(
        child: getMoreIcon(() {
          NamidaDialogs.inst.showPlaylistDialog(name);
        }),
        shouldShow: route == RouteType.SUBPAGE_playlistTracks || route == RouteType.SUBPAGE_historyTracks || route == RouteType.SUBPAGE_mostPlayedTracks,
      ),

      getAnimatedCrossFade(
        child: ObxO(
          rx: ytplc.YoutubePlaylistController.inst.canReorderVideos,
          builder: (reorderable) => NamidaAppBarIcon(
            tooltip: reorderable ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
            icon: reorderable ? Broken.forward_item : Broken.lock_1,
            onPressed: () => ytplc.YoutubePlaylistController.inst.canReorderVideos.value = !ytplc.YoutubePlaylistController.inst.canReorderVideos.value,
          ),
        ),
        shouldShow: route == RouteType.YOUTUBE_PLAYLIST_SUBPAGE,
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
      case RouteType.YOUTUBE_HOME:
        tab = LibraryTab.youtube;
        break;
      default:
        null;
    }
    return tab;
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
        YTHomePages.channels: lang.CHANNELS,
        YTHomePages.playlists: lang.PLAYLISTS,
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
      InsertionSortingType: {
        InsertionSortingType.listenCount: Broken.award,
        InsertionSortingType.random: Broken.format_circle,
        InsertionSortingType.rating: Broken.grammerly,
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
    };

    _ffmpegToTitle = {
      FFMPEGTagField.title: lang.TITLE,
      FFMPEGTagField.album: lang.ALBUM,
      FFMPEGTagField.artist: lang.ARTIST,
      FFMPEGTagField.albumArtist: lang.ALBUM_ARTIST,
      FFMPEGTagField.genre: lang.GENRE,
      FFMPEGTagField.mood: lang.MOOD,
      FFMPEGTagField.composer: lang.COMPOSER,
      FFMPEGTagField.synopsis: lang.SYNOPSIS,
      FFMPEGTagField.comment: lang.COMMENT,
      FFMPEGTagField.description: lang.DESCRIPTION,
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
    };
    _ffmpegToIcon = {
      FFMPEGTagField.title: Broken.music,
      FFMPEGTagField.album: Broken.music_dashboard,
      FFMPEGTagField.artist: Broken.microphone,
      FFMPEGTagField.albumArtist: Broken.user,
      FFMPEGTagField.genre: Broken.smileys,
      FFMPEGTagField.mood: Broken.happyemoji,
      FFMPEGTagField.composer: Broken.profile_2user,
      FFMPEGTagField.synopsis: Broken.text,
      FFMPEGTagField.comment: Broken.text_block,
      FFMPEGTagField.description: Broken.note_text,
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
