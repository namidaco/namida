import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nampack/core/main_utils.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/class/comments/comment_info_item.dart';
import 'package:youtipie/class/comments/comment_info_item_base.dart';
import 'package:youtipie/class/result_wrapper/comment_reply_result.dart';
import 'package:youtipie/class/result_wrapper/comment_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/url_utils.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/storage_cache_manager.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_download_options.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/user/youtube_account_manage_page.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_history_page.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'yt_utils.comments.dart';

class YTUtils {
  const YTUtils();

  static const comments = _YTUtilsCommentActions();

  static void expandMiniplayer() {
    final st = MiniPlayerController.inst.ytMiniplayerKey.currentState;
    if (st != null) st.animateToState(true);

    // if the miniplayer wasnt already active, we wait till the queue get filled (i.e. miniplayer gets a state)
    // it would be better if we had a callback instead of waiting 300ms.
    // since awaiting [playOrPause] would take quite long.
    if (st == null) {
      Future.delayed(
        const Duration(milliseconds: 300),
        () => MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(true),
      );
    }

    YoutubeMiniplayerUiController.inst.resetGlowUnderVideo();
  }

  static List<Widget> getVideoCacheStatusIcons({
    required String videoId,
    required BuildContext context,
    Color? iconsColor,
    List<int> overrideListens = const [],
    bool displayCacheIcons = true,
    double? fontMultiplier,
  }) {
    iconsColor ??= context.theme.iconTheme.color;
    final listens = overrideListens.isNotEmpty ? overrideListens : YoutubeHistoryController.inst.topTracksMapListens.value[videoId] ?? [];
    return [
      if (listens.isNotEmpty)
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            onTap: () => showVideoListensDialog(videoId),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0), // extra hittest margin
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                  color: context.theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                  child: Text(
                    listens.length.formatDecimal(),
                    style: fontMultiplier != null
                        ? context.textTheme.displaySmall?.copyWith(fontSize: (context.textTheme.displaySmall?.fontSize ?? 12.0) * fontMultiplier)
                        : context.textTheme.displaySmall,
                  ),
                ),
              ),
            ),
          ),
        ),
      if (displayCacheIcons) ...[
        Tooltip(
          message: lang.VIDEO_CACHE,
          child: Icon(
            Broken.video,
            size: 15.0,
            color: iconsColor?.withValues(
              alpha: VideoController.inst.hasNVCachedFromID(videoId) ? 0.6 : 0.1,
            ),
          ),
        ),
        const SizedBox(width: 4.0),
        Tooltip(
          message: lang.AUDIO_CACHE,
          child: Icon(
            Broken.audio_square,
            size: 15.0,
            color: iconsColor?.withValues(
              alpha: AudioCacheController.inst.audioCacheMap[videoId]?.isNotEmpty == true || Indexer.inst.allTracksMappedByYTID[videoId]?.isNotEmpty == true ? 0.6 : 0.1,
            ),
          ),
        ),
      ],
    ];
  }

  static _getPlayAllTile({required QueueSourceYoutubeID queueSource, required Iterable<YoutubeID> videos, required bool showPlayAllReverse}) {
    return NamidaPopupItem(
      icon: Broken.play_circle,
      title: lang.PLAY_ALL,
      onTap: () => Player.inst.playOrPause(0, videos, queueSource),
      trailing: showPlayAllReverse
          ? IconButton(
              style: ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              tooltip: "${lang.PLAY_ALL} (${lang.REVERSE_ORDER})",
              icon: StackedIcon(
                baseIcon: Broken.play_cricle,
                secondaryIcon: Broken.arrow_swap,
                iconSize: 20.0,
                secondaryIconSize: 10.0,
              ),
              iconSize: 20.0,
              onPressed: () {
                NamidaNavigator.inst.popMenu();
                Player.inst.playOrPause(0, videos.toList().reversed, queueSource);
              },
            )
          : null,
    );
  }

  static Future<List<NamidaPopupItem>> getVideosMenuItems({
    required QueueSourceYoutubeID queueSource,
    required BuildContext context,
    required List<YoutubeID> videos,
    required String playlistName,
    YoutubePlaylist? playlistToRemove,
    bool showPlayAllReverse = true,
  }) async {
    final playAfterVid = await getPlayerAfterVideo();

    final setPriorityChipController = SetVideosPriorityChipController();
    final setPriorityChip = SetVideosPriorityChip(
      controller: setPriorityChipController,
      smaller: true,
      totalCount: videos.length,
      videosId: videos.map((e) => e.id),
      countToText: (count) => count.displayVideoKeyword,
      onChanged: (_) {},
    );

    return [
      NamidaPopupItem(
        icon: Broken.music_library_2,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () {
          showAddToPlaylistSheet(ids: videos.map((e) => e.id), idsNamesLookup: {});
        },
      ),
      NamidaPopupItem(
        icon: Broken.share,
        title: lang.SHARE,
        onTap: videos.shareVideos,
      ),
      if (videos.length > 1)
        YTUtils._getPlayAllTile(queueSource: queueSource, videos: videos, showPlayAllReverse: showPlayAllReverse)
      else
        NamidaPopupItem(
          icon: Broken.play,
          title: lang.PLAY,
          onTap: () => Player.inst.playOrPause(0, videos, queueSource),
        ),
      if (videos.length > 1)
        NamidaPopupItem(
          icon: Broken.shuffle,
          title: lang.SHUFFLE,
          onTap: () => Player.inst.playOrPause(0, videos, queueSource, shuffle: true),
        ),
      NamidaPopupItem(
        icon: Broken.next,
        title: lang.PLAY_NEXT,
        onTap: () => Player.inst.addToQueue(videos, insertNext: true),
      ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: '${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}',
          subtitle: playAfterVid.name,
          oneLinedSub: true,
          onTap: () {
            Player.inst.addToQueue(videos, insertAfterLatest: true);
          },
        ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.PLAY_LAST,
        onTap: () => Player.inst.addToQueue(videos, insertNext: false),
      ),
      if (playlistName != '')
        NamidaPopupItem(
          icon: Broken.trash,
          title: lang.REMOVE_FROM_PLAYLIST,
          subtitle: playlistName.translatePlaylistName(),
          onTap: () => YTUtils.onRemoveVideosFromPlaylist(k_PLAYLIST_NAME_HISTORY, videos),
        ),
      if (playlistToRemove != null)
        NamidaPopupItem(
          icon: Broken.trash,
          title: lang.DELETE_PLAYLIST,
          onTap: () => playlistToRemove.promptDelete(name: playlistToRemove.name),
        ),
      NamidaPopupItem(
        icon: Broken.bill,
        title: lang.PRIORITY,
        trailing: setPriorityChip,
        onTap: setPriorityChipController.showMenu,
      ),
    ];
  }

  static Future<List<NamidaPopupItem>> getVideoCardMenuItemsForCurrentlyPlaying({
    required QueueSourceYoutubeID queueSource,
    required Rx<int> numberOfRepeats,
    required String videoId,
    required String? videoTitle,
    required String? channelID,
    required bool displayGoToChannel,
    required bool displayCopyUrl,
  }) async {
    final currentItem = Player.inst.currentItem.value;
    NamidaPopupItem? repeatForWidget;
    final defaultItems = await YTUtils.getVideoCardMenuItems(
      queueSource: queueSource,
      downloadIndex: null,
      totalLength: null,
      streamInfoItem: null,
      videoId: videoId,
      channelID: channelID,
      displayGoToChannel: displayGoToChannel,
      playlistID: null,
      idsNamesLookup: {videoId: videoTitle},
      copyUrl: displayCopyUrl,
      clearTile: false,
      displayShareUrl: false,
      showFavouritesTile: true,
    );
    if (currentItem is YoutubeID && videoId == currentItem.id) {
      repeatForWidget = NamidaPopupItem(
        icon: Broken.cd,
        title: '',
        titleBuilder: (style) => Obx(
          (context) => Text(
            lang.REPEAT_FOR_N_TIMES.replaceFirst('_NUM_', numberOfRepeats.valueR.toString()),
            style: style,
          ),
        ),
        onTap: () {
          settings.player.save(repeatMode: RepeatMode.forNtimes);
          Player.inst.updateNumberOfRepeats(numberOfRepeats.value);
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NamidaIconButton(
              icon: Broken.minus_cirlce,
              onPressed: () => numberOfRepeats.value = (numberOfRepeats.value - 1).clampInt(1, 20),
              iconSize: 20.0,
            ),
            NamidaIconButton(
              icon: Broken.add_circle,
              onPressed: () => numberOfRepeats.value = (numberOfRepeats.value + 1).clampInt(1, 20),
              iconSize: 20.0,
            ),
          ],
        ),
      );
    }
    final clearItem = NamidaPopupItem(
      icon: Broken.broom,
      title: lang.CLEAR,
      trailing: SetVideosPriorityChip(
        smaller: true,
        totalCount: 1,
        videosId: [videoId],
        countToText: (count) => count.displayTrackKeyword,
        onChanged: (_) {},
      ),
      onTap: () {
        const YTUtils().showVideoClearDialog(videoId);
      },
    );

    final items = <NamidaPopupItem>[];
    items.addAll(defaultItems);
    if (repeatForWidget != null) items.add(repeatForWidget);
    items.add(clearItem);
    return items;
  }

  static void showCopyItemsDialog(String videoId) async {
    final videoLink = YTUrlUtils.buildVideoUrl(videoId);
    String? videoLinkTimeStamp;
    final title = await YoutubeInfoController.utils.getVideoName(videoId) ?? '';
    final channelTitle = await YoutubeInfoController.utils.getVideoChannelName(videoId) ?? '';

    if (videoId == Player.inst.currentVideo?.id) {
      int currentSeconds = Player.inst.nowPlayingPosition.value ~/ 1000;
      if (currentSeconds > 0) {
        videoLinkTimeStamp = YTUrlUtils.buildVideoUrl(videoId, timestampSeconds: currentSeconds);
      }
    }

    void copy(String text) {
      Clipboard.setData(ClipboardData(text: text));
      snackyy(
        title: lang.COPIED_TO_CLIPBOARD,
        message: text.replaceAll('\n', ' '),
        maxLinesMessage: 2,
        leftBarIndicatorColor: CurrentColor.inst.miniplayerColor,
        top: false,
      );
      NamidaNavigator.inst.closeDialog();
    }

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.COPY,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomListTile(
              title: lang.TITLE,
              subtitle: title,
              onTap: () => copy(title),
            ),
            CustomListTile(
              title: lang.CHANNEL,
              subtitle: channelTitle,
              onTap: () => copy(channelTitle),
            ),
            CustomListTile(
              title: "${lang.CHANNEL} + ${lang.TITLE}",
              subtitle: '$channelTitle $title',
              onTap: () => copy('$channelTitle $title'),
            ),
            CustomListTile(
              title: lang.LINK,
              subtitle: videoLink,
              onTap: () => copy(videoLink),
            ),
            if (videoLinkTimeStamp != null)
              CustomListTile(
                title: "${lang.LINK} + ${lang.SECONDS}",
                subtitle: videoLinkTimeStamp,
                onTap: () => copy(videoLinkTimeStamp!),
              ),
            CustomListTile(
              title: lang.VIDEO,
              subtitle: videoId,
              onTap: () => copy(videoId),
            ),
          ],
        ),
      ),
    );
  }

  static NamidaPopupItem getVideoCopyItemsPopupItem(String videoId) {
    return NamidaPopupItem(
      icon: Broken.copy,
      title: lang.COPY,
      onTap: () {
        final videoLink = YTUrlUtils.buildVideoUrl(videoId);
        final text = videoLink;
        Clipboard.setData(ClipboardData(text: text));
        snackyy(
          title: lang.COPIED_TO_CLIPBOARD,
          message: text,
          maxLinesMessage: 2,
          leftBarIndicatorColor: CurrentColor.inst.color,
          top: false,
        );
      },
      onLongPress: () => YTUtils.showCopyItemsDialog(videoId),
      titleBuilder: (style) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              lang.COPY,
              style: style,
            ),
          ),
          const SizedBox(width: 4.0),
          NamidaIconButton(
            disableColor: true,
            icon: Broken.share,
            iconSize: 18.0,
            onPressed: () {
              final videoLink = YTUrlUtils.buildVideoUrl(videoId);
              SharePlus.instance.share(ShareParams(uri: Uri.parse(videoLink)));
            },
          )
        ],
      ),
    );
  }

  static Future<String?> copyThumbnailToStorage(String videoId) async {
    if (!await requestManageStoragePermission()) {
      return null;
    }

    final imgFile = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
      id: videoId,
      type: ThumbnailType.video,
    );

    if (imgFile != null) {
      final saveDirPath = await EditDeleteController.inst.saveImageToStorage(imgFile);
      return saveDirPath;
    }
    return null;
  }

  static Future<List<NamidaPopupItem>> getVideoCardMenuItems({
    required QueueSourceYoutubeID queueSource,
    required int? downloadIndex,
    required int? totalLength,
    required StreamInfoItem? streamInfoItem,
    String? playlistId,
    PlaylistBasicInfo Function()? playlistInfo,
    required String videoId,
    required String? channelID,
    bool displayGoToChannel = true,
    required PlaylistID? playlistID,
    required Map<String, String?> idsNamesLookup,
    String playlistName = '',
    YoutubeID? videoYTID,
    bool copyUrl = false,
    List<NamidaPopupItem>? moreMenuChildren,
    bool isInFullScreen = false,
    bool clearTile = true,
    bool displayShareUrl = true,
    bool showInfoTile = true,
    bool showFavouritesTile = false,
    Iterable<YoutubeID>? videosToPlayAll,
  }) async {
    final playAfterVid = await getPlayerAfterVideo();
    final currentVideo = Player.inst.currentVideo;
    final isCurrentlyPlaying = currentVideo != null && videoId == currentVideo.id;
    if (displayGoToChannel && (channelID == null || channelID.isEmpty)) channelID = await YoutubeInfoController.utils.getVideoChannelID(videoId);

    NamidaPopupItem? favouriteItem;
    if (showFavouritesTile) {
      final isFavourite = YoutubePlaylistController.inst.favouritesPlaylist.isSubItemFavourite(videoId);
      favouriteItem = NamidaPopupItem(
        icon: isFavourite ? Broken.heart_tick : Broken.heart,
        title: lang.FAVOURITES,
        onTap: () => YoutubePlaylistController.inst.favouriteButtonOnPressed(videoId),
      );
    }
    return [
      if (showInfoTile)
        NamidaPopupItem(
          icon: Broken.info_circle,
          title: lang.INFO,
          onTap: () {
            NamidaNavigator.inst.navigateDialog(
              dialog: VideoInfoDialog(
                videoId: videoId,
              ),
            );
          },
        ),
      if (favouriteItem != null) favouriteItem,
      NamidaPopupItem(
        icon: Broken.music_library_2,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () {
          showAddToPlaylistSheet(ids: [videoId], idsNamesLookup: idsNamesLookup);
        },
      ),
      NamidaPopupItem(
        icon: Broken.import,
        title: lang.DOWNLOAD,
        onTap: () {
          final plInfo = playlistInfo?.call();
          showDownloadVideoBottomSheet(
            videoId: videoId,
            originalIndex: downloadIndex,
            playlistId: plInfo?.id ?? playlistId,
            playlistInfo: plInfo,
            totalLength: totalLength,
            streamInfoItem: streamInfoItem,
            initialGroupName: playlistName.emptyIfHasDefaultPlaylistName(),
          );
        },
      ),
      if (displayShareUrl) getVideoCopyItemsPopupItem(videoId),
      if (copyUrl)
        NamidaPopupItem(
          icon: Broken.copy,
          title: lang.COPY,
          onTap: () => const YTUtils().copyCurrentVideoUrl(videoId, withTimestamp: false),
        ),
      if (channelID != null && channelID.isNotEmpty)
        NamidaPopupItem(
          icon: Broken.user,
          title: lang.GO_TO_CHANNEL,
          onTap: () {
            if (isInFullScreen) NamidaNavigator.inst.exitFullScreen();
            YTChannelSubpage(channelID: channelID!).navigate();
          },
        ),
      if (videosToPlayAll != null && videosToPlayAll.length > 1) YTUtils._getPlayAllTile(queueSource: queueSource, videos: videosToPlayAll, showPlayAllReverse: true),
      isCurrentlyPlaying
          ? NamidaPopupItem(
              icon: Broken.pause,
              title: lang.STOP_AFTER_THIS_VIDEO,
              enabled: Player.inst.sleepTimerConfig.value.sleepAfterItems != 1,
              onTap: () {
                Player.inst.updateSleepTimerValues(enableSleepAfterItems: true, sleepAfterItems: 1);
              },
            )
          : NamidaPopupItem(
              icon: Broken.play,
              title: lang.PLAY,
              onTap: () {
                Player.inst.playOrPause(0, [YoutubeID(id: videoId, playlistID: playlistID)], QueueSource.others);
              },
            ),
      NamidaPopupItem(
        icon: Broken.next,
        title: lang.PLAY_NEXT,
        onTap: () {
          Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertNext: true, showSnackBar: false);
        },
      ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: '${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}',
          subtitle: playAfterVid.name,
          oneLinedSub: true,
          onTap: () {
            Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertAfterLatest: true, showSnackBar: false);
          },
        ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.PLAY_LAST,
        onTap: () {
          Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertNext: false, showSnackBar: false);
        },
      ),
      if (playlistName != '' && videoYTID != null)
        NamidaPopupItem(
          icon: Broken.box_remove,
          title: lang.REMOVE_FROM_PLAYLIST,
          subtitle: playlistName.translatePlaylistName(),
          onTap: () => YTUtils.onRemoveVideosFromPlaylist(playlistName, [videoYTID]),
        ),
      if (clearTile)
        NamidaPopupItem(
          icon: Broken.broom,
          title: lang.CLEAR,
          trailing: SetVideosPriorityChip(
            smaller: true,
            totalCount: 1,
            videosId: [videoId],
            countToText: (count) => count.displayTrackKeyword,
            onChanged: (_) {},
          ),
          onTap: () {
            const YTUtils().showVideoClearDialog(videoId);
          },
        ),
      if (moreMenuChildren != null) ...moreMenuChildren,
    ];
  }

  static Future<({YoutubeID video, int diff, String name})?> getPlayerAfterVideo() async {
    final player = Player.inst;
    if (player.currentItem.value is YoutubeID && player.latestInsertedIndex > player.currentIndex.value) {
      try {
        final playAfterVideo = player.currentQueue.value[player.latestInsertedIndex] as YoutubeID;
        final diff = player.latestInsertedIndex - player.currentIndex.value;
        final name = await YoutubeInfoController.utils.getVideoName(playAfterVideo.id) ?? '';
        return (video: playAfterVideo, diff: diff, name: name);
      } catch (_) {}
    }
    return null;
  }

  static Map<String, String> getDefaultTagsFieldsBuilders(bool autoExtract) {
    return {
      if (autoExtract)
        FFMPEGTagField.title: YoutubeController.filenameBuilder.buildParamForFilename('title')
      else
        FFMPEGTagField.title: YoutubeController.filenameBuilder.buildParamForFilename('fulltitle'),
      if (autoExtract)
        FFMPEGTagField.artist: YoutubeController.filenameBuilder.buildParamForFilename('artist')
      else
        FFMPEGTagField.artist: YoutubeController.filenameBuilder.buildParamForFilename('channel'),
      if (autoExtract) FFMPEGTagField.album: YoutubeController.filenameBuilder.buildParamForFilename('channel'),
      if (autoExtract) FFMPEGTagField.genre: YoutubeController.filenameBuilder.buildParamForFilename('genre'),
      FFMPEGTagField.title: YoutubeController.filenameBuilder.buildParamForFilename('title'),
      FFMPEGTagField.artist: YoutubeController.filenameBuilder.buildParamForFilename('artist'),
      FFMPEGTagField.album: YoutubeController.filenameBuilder.buildParamForFilename('channel'),
      FFMPEGTagField.comment: YoutubeController.filenameBuilder.buildParamForFilename('video_url'),
      FFMPEGTagField.year: YoutubeController.filenameBuilder.buildParamForFilename('upload_date'),
      FFMPEGTagField.trackNumber: YoutubeController.filenameBuilder.buildParamForFilename('playlist_autonumber'),
      FFMPEGTagField.trackTotal: YoutubeController.filenameBuilder.buildParamForFilename('playlist_count'),
      // FFMPEGTagField.synopsis: YoutubeController.filenameBuilder.buildParamForFilename('description'),
      FFMPEGTagField.description: YoutubeController.filenameBuilder.buildParamForFilename('description'),
    };
  }

  static Future<Map<String, String?>> getMetadataInitialMap(
    String id,
    StreamInfoItem? streamInfoItem,
    VideoStream? videoStream,
    AudioStream? audioStream,
    VideoStreamsResult? streams,
    PlaylistBasicInfo? playlistInfo,
    String? playlistId,
    int? originalIndex,
    int? totalLength, {
    bool autoExtract = true,
    Map<String, String?>? initialBuilding,
  }) async {
    if (playlistInfo == null && playlistId != null && playlistId.isNotEmpty) {
      final plInfo = await YoutubeInfoController.playlist.fetchPlaylist(playlistId: playlistId).catchError((_) => null);
      playlistInfo = plInfo?.info;
    }
    final videoPage = await YoutubeInfoController.video.fetchVideoPage(id).catchError((_) => null);
    final streamInfo = await YoutubeInfoController.utils.buildOrUseVideoStreamInfo(id, streams);

    final infoMap = <String, String?>{};

    if (initialBuilding != null) {
      for (final ib in initialBuilding.entries) {
        final userText = ib.value;
        if (userText != null) {
          infoMap[ib.key] = YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
                  userText, id, streamInfo, videoPage, streamInfoItem, playlistInfo, videoStream, audioStream, originalIndex, totalLength,
                  fallback: '') ??
              userText;
        }
      }
    }

    final defaultInfoSett = settings.youtube.initialDefaultMetadataTags;
    for (final di in defaultInfoSett.entries) {
      final defaultText = di.value;
      infoMap[di.key] ??= YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
              defaultText, id, streamInfo, videoPage, streamInfoItem, playlistInfo, videoStream, audioStream, originalIndex, totalLength,
              fallback: '') ??
          defaultText;
    }

    final defaultInfo = getDefaultTagsFieldsBuilders(autoExtract);
    for (final di in defaultInfo.entries) {
      final defaultText = di.value;
      infoMap[di.key] ??= YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
              defaultText, id, streamInfo, videoPage, streamInfoItem, playlistInfo, videoStream, audioStream, originalIndex, totalLength,
              fallback: '') ??
          '';
    }

    return infoMap;
  }

  static Future<bool> writeAudioMetadata({
    required String videoId,
    required File audioFile,
    required File? thumbnailFile,
    required Map<String, String?> tagsMap,
  }) async {
    final thumbnail = thumbnailFile ?? await ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: videoId, type: ThumbnailType.video);
    if (thumbnail != null) {
      await NamidaFFMPEG.inst.editAudioThumbnail(audioPath: audioFile.path, thumbnailPath: thumbnail.path);
    }
    return await NamidaFFMPEG.inst.editMetadata(
      path: audioFile.path,
      tagsMap: tagsMap,
    );
  }

  static Future<void> onYoutubeHistoryPlaylistTap({int? initialListen}) async {
    bool shouldNavigate = true;
    if (initialListen != null) {
      shouldNavigate = NamidaOnTaps.jumpToListen(
        YoutubeHistoryController.inst,
        initialListen,
        Dimensions.youtubeCardItemExtent,
        kYoutubeHistoryDayHeaderHeightWithPadding,
      );
    }
    if (shouldNavigate) await YoutubeHistoryPage().navigate();
  }

  static Future<void> onYoutubeLikedPlaylistTap() {
    return const YTLikedVideosPage().navigate();
  }

  static Future<void> onYoutubeMostPlayedPlaylistTap() {
    return const YTMostPlayedVideosPage().navigate();
  }

  static Future<void> onRemoveVideosFromPlaylist(String name, List<YoutubeID> videosToDelete) async {
    void showSnacky({required void Function() whatDoYouWant}) {
      snackyy(
        title: lang.UNDO_CHANGES,
        message: lang.UNDO_CHANGES_DELETED_TRACK,
        displayDuration: SnackDisplayDuration.long,
        button: (lang.UNDO, whatDoYouWant),
      );
    }

    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;

    if (isHistory) {
      final tempList = List<YoutubeID>.from(videosToDelete);
      await YoutubeHistoryController.inst.removeTracksFromHistory(tempList);
      showSnacky(
        whatDoYouWant: () async {
          await YoutubeHistoryController.inst.addTracksToHistory(tempList);
          YoutubeHistoryController.inst.sortHistoryTracks(tempList.mapped((e) => e.dateAddedMS.toDaysSince1970()));
        },
      );
    } else {
      final playlist = YoutubePlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;

      final Map<YoutubeID, int> twdAndIndexes = {};
      videosToDelete.loop((twd) {
        final index = playlist.tracks.indexOf(twd);
        if (index > -1) twdAndIndexes[twd] = index;
      });

      await YoutubePlaylistController.inst.removeTracksFromPlaylist(playlist, twdAndIndexes.values.toList());
      showSnacky(
        whatDoYouWant: () async {
          YoutubePlaylistController.inst.insertTracksInPlaylistWithEachIndex(
            playlist,
            twdAndIndexes,
          );
        },
      );
    }
  }

  void showVideoClearDialog(
    String videoId, {
    final void Function(Map<String, bool> pathsDeleted)? afterDeleting,
    List<NamidaClearDialogExpansionTile<dynamic>> Function(RxMap<String, bool> pathsToDelete, Rx<int> totalSizeToDelete, Rx<bool> allSelected)? extraTiles,
  }) async {
    final pathsToDelete = <String, bool>{}.obs;
    final allSelected = false.obs;
    final totalSizeToDelete = 0.obs;

    final deleteTempAudio = false.obs;
    final deleteTempVideo = false.obs;
    final tempFilesSizeAudio = <File, int>{}.obs;
    final tempFilesSizeVideo = <File, int>{}.obs;

    final extraTilesBuilt = extraTiles?.call(pathsToDelete, totalSizeToDelete, allSelected);
    final videosCached = await VideoController.inst.getNVFromID(videoId);
    final audiosCached = await AudioCacheController.inst.audioCacheMap[videoId]?.whereAsync((element) => element.file.exists()).toList() ?? [];

    final fileSizeLookup = <String, int>{};
    final fileTypeLookup = <String, int>{};

    int videosSize = 0;
    int audiosSize = 0;

    final int length = audiosCached.length;
    for (int i = 0; i < length; i++) {
      final e = audiosCached[i];
      final s = await e.file.fileSize() ?? 0;
      audiosSize += s;
      fileSizeLookup[e.file.path] = s;
      fileTypeLookup[e.file.path] = 0;
    }

    videosCached.loop((e) {
      final s = e.sizeInBytes;
      videosSize += s;
      fileSizeLookup[e.path] = s;
      fileTypeLookup[e.path] = 1;
    });

    extraTilesBuilt?.loop((e) => e.items.loop((item) {
          final data = e.itemBuilder(item);
          final s = e.itemSize(item);
          fileSizeLookup[data.path] = s;
          fileTypeLookup[data.path] = 2;
        }));

    const cm = StorageCacheManager();
    cm.getTempAudiosForID(videoId).then((value) => tempFilesSizeAudio.value = value);
    cm.getTempVideosForID(videoId).then((value) => tempFilesSizeVideo.value = value);

    void reEvaluateTotalSize() {
      int newVal = 0;
      for (final k in pathsToDelete.keys) {
        if (pathsToDelete[k] == true) newVal += fileSizeLookup[k] ?? 0;
      }
      if (deleteTempAudio.value) {
        for (final v in tempFilesSizeAudio.values) {
          newVal += v;
        }
      }
      if (deleteTempVideo.value) {
        for (final v in tempFilesSizeVideo.values) {
          newVal += v;
        }
      }
      totalSizeToDelete.value = newVal;
    }

    Future<void> deleteItems(Iterable<String> paths) async {
      for (final path in paths) {
        final type = fileTypeLookup[path];
        await File(path).tryDeleting(); // always delete even if not in fileTypeLookup, for temp files
        if (type == 1) {
          VideoController.inst.removeNVFromCacheMap(videoId, path);
        } else if (type == 0) {
          AudioCacheController.inst.removeFromCacheMap(videoId, path);
        }
      }
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        pathsToDelete.close();
        allSelected.close();
        totalSizeToDelete.close();
        deleteTempAudio.close();
        deleteTempVideo.close();
        tempFilesSizeAudio.close();
        tempFilesSizeVideo.close();
      },
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        icon: Broken.broom,
        title: lang.CLEAR,
        trailingWidgets: [
          Obx(
            (context) => Checkbox.adaptive(
              splashRadius: 28.0,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0.multipliedRadius),
              ),
              value: allSelected.valueR,
              onChanged: (_) {
                final newVal = allSelected.toggle();
                if (newVal == true) {
                  audiosCached.loop((e) => pathsToDelete[e.file.path] = true);
                  videosCached.loop((e) => pathsToDelete[e.path] = true);
                  extraTilesBuilt?.loop((e) => e.items.loop((item) => pathsToDelete[e.itemBuilder(item).path] = true));
                  deleteTempAudio.value = true;
                  deleteTempVideo.value = true;
                } else {
                  pathsToDelete.clear();
                  deleteTempAudio.value = false;
                  deleteTempVideo.value = false;
                }
                reEvaluateTotalSize();
              },
            ),
          ),
        ],
        actions: [
          const CancelButton(),
          Obx(
            (context) => NamidaButton(
              enabled: deleteTempAudio.valueR || deleteTempVideo.valueR || pathsToDelete.values.any((element) => element),
              text: "${lang.DELETE} (${totalSizeToDelete.valueR.fileSizeFormatted})",
              onPressed: () async {
                await Future.wait([
                  deleteItems(pathsToDelete.keys.where((element) => pathsToDelete[element] == true)),
                  if (deleteTempAudio.value) deleteItems(tempFilesSizeAudio.keys.map((e) => e.path)),
                  if (deleteTempVideo.value) deleteItems(tempFilesSizeVideo.keys.map((e) => e.path)),
                ]);
                afterDeleting?.call(pathsToDelete.value);
                Player.inst.recheckCachedVideos(videoId);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ),
        ],
        child: Column(
          children: [
            NamidaClearDialogExpansionTile(
              title: lang.VIDEO_CACHE,
              subtitle: videosSize.fileSizeFormatted,
              icon: Broken.video,
              items: videosCached,
              itemSize: (item) => item.sizeInBytes,
              tempFilesDelete: deleteTempVideo,
              tempFilesSize: tempFilesSizeVideo,
              itemBuilder: (v) {
                return (
                  title: "${v.resolution}p • ${v.framerate}fps ",
                  subtitle: v.sizeInBytes.fileSizeFormatted,
                  path: v.path,
                );
              },
              pathsToDelete: pathsToDelete,
              totalSizeToDelete: totalSizeToDelete,
              allSelected: allSelected,
            ),
            NamidaClearDialogExpansionTile(
              title: lang.AUDIO_CACHE,
              subtitle: audiosSize.fileSizeFormatted,
              icon: Broken.musicnote,
              items: audiosCached,
              itemSize: (item) => fileSizeLookup[item.file.path] ?? item.file.fileSizeSync() ?? 0,
              tempFilesDelete: deleteTempAudio,
              tempFilesSize: tempFilesSizeAudio,
              itemBuilder: (a) {
                final bitrateText = a.bitrate == null ? null : "${a.bitrate! ~/ 1000}kb/s";
                final langText = a.langaugeName == null ? '' : " • ${a.langaugeName}";
                return (
                  title: "${bitrateText ?? lang.AUDIO}$langText",
                  subtitle: a.file.fileSizeFormatted() ?? '',
                  path: a.file.path,
                );
              },
              pathsToDelete: pathsToDelete,
              totalSizeToDelete: totalSizeToDelete,
              allSelected: allSelected,
            ),
            ...?extraTilesBuilt,
          ],
        ),
      ),
    );
  }

  static void showFilenameBuilderOutputSheet({
    required String groupName,
    required bool showEditTags,
    required void Function(String text) onChanged,
  }) async {
    final controller = TextEditingController(text: settings.youtube.downloadFilenameBuilder.value);
    await showNamidaBottomSheetWithTextField(
      title: lang.OUTPUT,
      textfieldConfig: BottomSheetTextFieldConfigWC(
        controller: controller,
        hintText: '',
        labelText: lang.FILE_NAME,
        validator: (value) {
          if (value == null) return lang.PLEASE_ENTER_A_NAME;
          final file = FileParts.join(AppDirs.YOUTUBE_DOWNLOADS, groupName, value);
          if (file.existsSync()) {
            return "${lang.FILE_ALREADY_EXISTS}, ${lang.DOWNLOADING_WILL_OVERRIDE_IT} (${file.fileSizeFormatted() ?? 0})";
          }
          if (!YoutubeController.filenameBuilder.isBuildingDefaultFilenameSafe(value)) {
            return YoutubeController.filenameBuilder.encodedParamsThatShouldExistInFilename.join(' - ');
          }
          return null;
        },
      ),
      buttonText: lang.SAVE,
      onButtonTap: (text) {
        onChanged(text);
        settings.youtube.save(downloadFilenameBuilder: text);
        return true;
      },
      extraPreItemsBuilder: !showEditTags
          ? null
          : (formState) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: CustomListTile(
                  icon: Broken.edit,
                  title: lang.EDIT_TAGS,
                  onTap: () async {
                    await showVideoDownloadOptionsSheet(
                      videoTitle: null,
                      videoUploader: null,
                      tagMaps: settings.youtube.initialDefaultMetadataTags,
                      tagMapsForFillingInfoOnly: YTUtils.getDefaultTagsFieldsBuilders(settings.youtube.autoExtractVideoTagsFromInfo.value),
                      supportTagging: true,
                      showSpecificFileOptions: false, onDownloadFilenameChanged: (filename) {}, // not visible
                      onDownloadGroupNameChanged: (newGroupName) {}, // not visible
                      preWidget: (controllerFn, onChangedFn) => Padding(
                        padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                        child: YTDownloadFilenameBuilderRow(
                          controller: null,
                          controllerCallback: controllerFn,
                          onChanged: onChangedFn,
                        ),
                      ),
                      initialGroupName: groupName,
                    );
                    settings.youtube.save();
                  },
                ),
              );
            },
      extraItemsBuilder: (formState) {
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
          child: YTDownloadFilenameBuilderRow(
            controller: controller,
          ),
        );
      },
    );
    controller.disposeAfterAnimation();
  }

  void copyCurrentVideoUrl(String videoId, {required bool withTimestamp}) {
    if (videoId != '') {
      int? timeStampSeconds = withTimestamp ? Player.inst.nowPlayingPosition.value ~/ 1000 : null;
      timeStampSeconds = timeStampSeconds.toIf(null, 0);
      String finalUrl = YTUrlUtils.buildVideoUrl(videoId, timestampSeconds: timeStampSeconds);
      Clipboard.setData(ClipboardData(text: finalUrl));
      snackyy(
        title: lang.COPIED_TO_CLIPBOARD,
        message: finalUrl,
        top: false,
        maxLinesMessage: 2,
        leftBarIndicatorColor: CurrentColor.inst.miniplayerColor,
      );
    }
  }
}
