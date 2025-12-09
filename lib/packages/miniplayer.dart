// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:animated_background/animated_background.dart';

import 'package:namida/base/yt_video_like_manager.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/sponsor_block_button.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/youtube_miniplayer.dart';
import 'package:namida/youtube/yt_utils.dart';

class MiniPlayerParent extends StatelessWidget {
  final AnimationController animation;
  const MiniPlayerParent({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => Theme(
        data: AppThemes.inst.getAppTheme(CurrentColor.inst.miniplayerColor, !context.isDarkMode),
        child: Stack(
          children: [
            // -- MiniPlayer Wallpaper
            Positioned.fill(
              child: RepaintBoundary(
                child: FadeIgnoreTransition(
                  completelyKillWhenPossible: true,
                  opacity: NamidaMiniPlayerBase.clampedAnimationCP,
                  child: const Wallpaper(
                    gradient: false,
                    particleOpacity: 0.3,
                  ),
                ),
              ),
            ),

            // -- MiniPlayers
            RepaintBoundary(
              child: ObxO(
                rx: settings.mixedQueue,
                builder: (context, mixedQueue) => mixedQueue
                    ? const NamidaMiniPlayerMixed()
                    : ObxO(
                        rx: Player.inst.currentItem,
                        builder: (context, currentItem) => currentItem is YoutubeID
                            ? ObxO(
                                rx: settings.youtube.youtubeStyleMiniplayer,
                                builder: (context, youtubeStyleMiniplayer) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: youtubeStyleMiniplayer
                                      ? YoutubeMiniPlayer(key: YoutubeMiniplayerUiController.inst.ytMiniplayerKey) //
                                      : const NamidaMiniPlayerYoutubeID(key: Key('local_miniplayer_yt')),
                                ),
                              )
                            : currentItem is Selectable
                                ? const NamidaMiniPlayerTrack(key: Key('local_miniplayer'))
                                : const SizedBox(key: Key('empty_miniplayer')),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NamidaMiniPlayerMixed extends StatelessWidget {
  const NamidaMiniPlayerMixed({super.key});

  @override
  Widget build(BuildContext context) {
    final trackConfig = const NamidaMiniPlayerTrack().getMiniPlayerBase(context);
    final ytConfig = NamidaMiniPlayerYoutubeIDState().getMiniPlayerBase(context);

    return NamidaMiniPlayerBase(
      trackTileConfigs: trackConfig.trackTileConfigs,
      videoTileConfigs: trackConfig.videoTileConfigs,
      queueItemExtent: null,
      queueItemExtentBuilder: (item) {
        return item is Selectable ? trackConfig.queueItemExtent : ytConfig.queueItemExtent;
      },
      itemBuilder: (context, index, currentIndex, queue, trackTileProperties, videoTileProperties) {
        final item = queue[index];
        return item is Selectable
            ? trackConfig.itemBuilder(context, index, currentIndex, queue, trackTileProperties, videoTileProperties)
            : ytConfig.itemBuilder(context, index, currentIndex, queue, trackTileProperties, videoTileProperties);
      },
      getDurationMS: (currentItem) {
        return (currentItem is Selectable ? trackConfig.getDurationMS?.call(currentItem) : ytConfig.getDurationMS?.call(currentItem)) ?? 0;
      },
      itemsKeyword: (number, item) {
        return item is Selectable ? trackConfig.itemsKeyword(number, item) : ytConfig.itemsKeyword(number, item);
      },
      onAddItemsTap: (currentItem) {
        return currentItem is Selectable ? trackConfig.onAddItemsTap(currentItem) : ytConfig.onAddItemsTap(currentItem);
      },
      topText: (currentItem) {
        return currentItem is Selectable ? trackConfig.topText(currentItem) : ytConfig.topText(currentItem);
      },
      onTopTextTap: (currentItem) {
        return currentItem is Selectable ? trackConfig.onTopTextTap(currentItem) : ytConfig.onTopTextTap(currentItem);
      },
      onMenuOpen: (currentItem, details) {
        return currentItem is Selectable ? trackConfig.onMenuOpen(currentItem, details) : ytConfig.onMenuOpen(currentItem, details);
      },
      focusedMenuOptions: (item) => item is Selectable ? trackConfig.focusedMenuOptions(item) : ytConfig.focusedMenuOptions(item),
      imageBuilder: (item, brMultiplier) {
        return item is Selectable ? trackConfig.imageBuilder(item, brMultiplier) : ytConfig.imageBuilder(item, brMultiplier);
      },
      currentImageBuilder: (item, brMultiplier, maxHeight) {
        return item is Selectable ? trackConfig.currentImageBuilder(item, brMultiplier, maxHeight) : ytConfig.currentImageBuilder(item, brMultiplier, maxHeight);
      },
      textBuilder: (item) {
        return item is Selectable
            ? trackConfig.textBuilder(item) as MiniplayerInfoData<Track, SortType>
            : ytConfig.textBuilder(item as YoutubeID) as MiniplayerInfoData<String, YTSortType>;
      },
      canShowBuffering: (item) => item is Selectable ? trackConfig.canShowBuffering(item) : ytConfig.canShowBuffering(item),
    );
  }
}

class NamidaMiniPlayerTrack extends StatelessWidget {
  const NamidaMiniPlayerTrack({super.key});

  static void openMenu(TrackWithDate? trackWithDate, Track track) => NamidaDialogs.inst.showTrackDialog(
        track,
        source: QueueSource.playerQueue,
        heroTag: TrackTile.obtainHeroTag(trackWithDate, track, -1, true),
      );
  static void openInfoMenu(TrackWithDate? trackWithDate, Track track) => showTrackInfoDialog(
        track,
        true,
        heroTag: TrackTile.obtainHeroTag(trackWithDate, track, -1, true),
      );

  static MiniplayerInfoData<Track, SortType> textBuilder(Playable playable) {
    String firstLine = '';
    String secondLine = '';

    final track = (playable as Selectable).track;
    final trExt = track.toTrackExt();
    final title = trExt.title;
    final artist = trExt.originalArtist;
    if (settings.displayArtistBeforeTitle.value) {
      firstLine = artist.overflow;
      secondLine = title.overflow;
    } else {
      firstLine = title.overflow;
      secondLine = artist.overflow;
    }

    if (firstLine == '') {
      firstLine = secondLine;
      secondLine = '';
    }
    return MiniplayerInfoData(
      firstLine: firstLine,
      secondLine: secondLine,
      favouritePlaylist: PlaylistController.inst.favouritesPlaylist,
      itemToLike: track,
      onLikeTap: (isLiked) async => PlaylistController.inst.favouriteButtonOnPressed(track),
      onShowAddToPlaylistDialog: () => showAddToPlaylistDialog([track]),
      onMenuOpen: (_) => openMenu(playable.trackWithDate, track),
      onTextLongTap: () => openInfoMenu(playable.trackWithDate, track),
      likedIcon: Broken.heart_tick,
      normalIcon: Broken.heart,
    );
  }

  NamidaMiniPlayerBase getMiniPlayerBase(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return NamidaMiniPlayerBase<Track, SortType>(
      queueItemExtent: Dimensions.inst.trackTileItemExtent,
      trackTileConfigs: const TrackTilePropertiesConfigs(
        displayRightDragHandler: true,
        draggableThumbnail: true,
        horizontalGestures: false,
        queueSource: QueueSource.playerQueue,
      ),
      itemBuilder: (context, i, currentIndex, queue, properties, _) {
        final track = queue[i] as Selectable;
        final key = Key("${i}_${track.track.path}");
        return (
          TrackTile(
            properties: properties!,
            key: key,
            index: i,
            trackOrTwd: track,
            tracks: queue,
            cardColorOpacity: 0.5,
            fadeOpacity: i < currentIndex ? 0.3 : 0.0,
            onPlaying: () {
              // -- to improve performance, skipping process of checking new queues, etc..
              if (i == currentIndex) {
                Player.inst.togglePlayPause();
              } else {
                Player.inst.skipToQueueItem(i);
              }
            },
          ),
          key,
        );
      },
      getDurationMS: (currentItem) => (currentItem as Selectable).track.durationMS,
      itemsKeyword: (number, item) => number.displayTrackKeyword,
      onAddItemsTap: (currentItem) => TracksAddOnTap().onAddTracksTap(context),
      topText: (currentItem) => (currentItem as Selectable).track.album,
      onTopTextTap: (currentItem) => NamidaOnTaps.inst.onAlbumTap((currentItem as Selectable).track.albumIdentifier),
      onMenuOpen: (currentItem, _) => openMenu((currentItem as Selectable).trackWithDate, currentItem.track),
      focusedMenuOptions: (currentItem) => FocusedMenuOptions(
        onSearch: (item) {
          showSetYTLinkCommentDialog([(item as Selectable).track], CurrentColor.inst.miniplayerColor, autoOpenSearch: true);
        },
        onOpen: (currentItem) {
          if (settings.enableVideoPlayback.value) return true;

          NamidaNavigator.inst.navigateDialog(
            dialog: Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: kDialogMaxWidth),
                child: PlaybackSettings(isInDialog: true),
              ),
            ),
          );
          return false;
        },
        onPressed: (currentItem) => VideoController.inst.toggleVideoPlayback(),
        videoIconBuilder: (currentItem, size, color) => Obx(
          (context) => Icon(
            settings.enableVideoPlayback.valueR ? Broken.video : Broken.headphone,
            size: size,
            color: color,
          ),
        ),
        builder: (currentItem, fontSizeMultiplier, sizeMultiplier) {
          final onSecondary = theme.colorScheme.onSecondaryContainer;
          return Obx((context) {
            if (!settings.enableVideoPlayback.valueR) {
              return Text.rich(
                TextSpan(
                  text: lang.AUDIO,
                  style: textTheme.labelLarge?.copyWith(fontSize: fontSizeMultiplier(15.0), color: theme.colorScheme.onSecondaryContainer),
                  children: [
                    if (settings.displayAudioInfoMiniplayer.valueR)
                      TextSpan(
                        text: " • ${(currentItem as Selectable).track.audioInfoFormattedCompact}",
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: fontSizeMultiplier(11.0)),
                      )
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            }
            final currentVideo = VideoController.inst.currentVideo.valueR;
            final downloadedBytes = VideoController.inst.currentVideoConfig.currentDownloadedBytes.valueR;
            final videoTotalSize = currentVideo?.sizeInBytes ?? 0;
            final videoQuality = currentVideo?.resolution ?? 0;
            final videoFramerate = currentVideo?.framerateText(30);
            final markText = VideoController.inst.currentVideoConfig.isNoVideosAvailable.valueR ? 'x' : '?';
            final fallbackQualityLabel = currentVideo?.nameInCache?.splitLast('_');
            final qualityText = videoQuality == 0 ? fallbackQualityLabel ?? markText : '${videoQuality}p';
            final framerateText = videoFramerate ?? '';

            final videoBlockedBy = VideoController.inst.currentVideoConfig.videoBlockedByType.valueR;
            final videoBlockedByIcon = switch (videoBlockedBy) {
              VideoFetchBlockedBy.cachePriority => Broken.cpu,
              VideoFetchBlockedBy.noNetwork => Broken.global_refresh,
              VideoFetchBlockedBy.dataSaver => Broken.blur,
              VideoFetchBlockedBy.playbackSource => Broken.scroll,
              null => null,
            };

            return Text.rich(
              TextSpan(
                text: lang.VIDEO,
                style: textTheme.labelLarge?.copyWith(fontSize: fontSizeMultiplier(15.0), color: theme.colorScheme.onSecondaryContainer),
                children: [
                  if (videoBlockedByIcon != null) ...[
                    TextSpan(text: " • ", style: TextStyle(color: onSecondary, fontSize: fontSizeMultiplier(15.0))),
                    WidgetSpan(
                      child: Icon(
                        videoBlockedByIcon,
                        size: sizeMultiplier(14.0),
                        color: onSecondary,
                      ),
                    ),
                  ] else
                    TextSpan(
                      text: " • $qualityText$framerateText",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: fontSizeMultiplier(13.0),
                      ),
                    ),
                  // --
                  if (videoTotalSize > 0) ...[
                    TextSpan(text: " • ", style: TextStyle(color: theme.colorScheme.primary, fontSize: fontSizeMultiplier(14.0))),
                    TextSpan(
                      text: downloadedBytes == null ? videoTotalSize.fileSizeFormatted : "${downloadedBytes.fileSizeFormatted}/${videoTotalSize.fileSizeFormatted}",
                      style: TextStyle(color: onSecondary, fontSize: fontSizeMultiplier(10.0)),
                    ),
                  ],
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          });
        },
        currentId: (item) => (item as Selectable).track.youtubeID,
        loadQualities: (item) async => await VideoController.inst.fetchYTQualities((item as Selectable).track),
        localVideos: VideoController.inst.currentVideoConfig.currentPossibleLocalVideos,
        streams: VideoController.inst.currentVideoConfig.currentYTStreams,
        onLocalVideoTap: (item, video) async {
          VideoController.inst.playVideoCurrent(video: video, track: (item as Selectable).track);
        },
        onStreamVideoTap: (item, videoId, stream, cacheFile, streams) async {
          final cacheExists = cacheFile != null;
          if (!cacheExists) await VideoController.inst.getVideoFromYoutubeAndUpdate(videoId, stream: stream);
          VideoController.inst.playVideoCurrent(
            video: null,
            cacheIdAndPath: (videoId ?? '', cacheFile?.path ?? ''),
            track: (item as Selectable).track,
          );
        },
      ),
      imageBuilder: (item, brMultiplier) => _TrackImage(
        track: (item as Selectable).track,
        brMultiplier: brMultiplier,
      ),
      currentImageBuilder: (item, brMultiplier, maxHeight) => _AnimatingTrackImage(
        track: (item as Selectable).track,
        brMultiplier: brMultiplier,
        maxHeight: maxHeight,
      ),
      textBuilder: textBuilder,
      canShowBuffering: (currentItem) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return getMiniPlayerBase(context);
  }
}

class NamidaMiniPlayerYoutubeID extends StatefulWidget {
  const NamidaMiniPlayerYoutubeID({super.key});

  @override
  State<NamidaMiniPlayerYoutubeID> createState() => NamidaMiniPlayerYoutubeIDState();
}

class NamidaMiniPlayerYoutubeIDState extends State<NamidaMiniPlayerYoutubeID> {
  NamidaMiniPlayerYoutubeIDState();

  static final _videoLikeManager = YtVideoLikeManager(pageRx: YoutubeInfoController.current.currentVideoPage);
  static final _numberOfRepeats = 1.obs;

  @override
  void initState() {
    super.initState();
    _videoLikeManager.init();
    _numberOfRepeats.reInit();
  }

  @override
  void dispose() {
    _videoLikeManager.dispose();
    _numberOfRepeats.close();
    super.dispose();
  }

  static void openMenu(BuildContext context, YoutubeID video, TapUpDetails details) async {
    final vidpage = await YoutubeInfoController.video.fetchVideoPageCache(video.id);
    final vidstreams = await YoutubeInfoController.video.fetchVideoStreamsCache(video.id);
    final videoTitle = vidpage?.videoInfo?.title ?? vidstreams?.info?.title;
    final videoChannelId = vidpage?.channelInfo?.id ?? vidstreams?.info?.channelId;

    final menu = NamidaPopupWrapper(
      childrenDefault: () => YTUtils.getVideoCardMenuItemsForCurrentlyPlaying(
        queueSource: QueueSourceYoutubeID.playerQueue,
        numberOfRepeats: _numberOfRepeats,
        videoId: video.id,
        videoTitle: videoTitle,
        channelID: videoChannelId,
        displayGoToChannel: true,
        displayCopyUrl: true,
      ),
    );
    menu.showPopupMenu(context);
  }

  static void openInfoMenu(BuildContext context, YoutubeID video) {
    NamidaNavigator.inst.navigateDialog(
      dialog: VideoInfoDialog(
        videoId: video.id,
      ),
    );
  }

  static MiniplayerInfoData<String, YTSortType> textBuilder(BuildContext context, Playable playbale) {
    final video = playbale as YoutubeID;
    String firstLine = '';
    String secondLine = '';

    firstLine = YoutubeInfoController.utils.getVideoNameSync(video.id) ?? '';
    secondLine = YoutubeInfoController.utils.getVideoChannelNameSync(video.id) ?? '';
    if (firstLine == '') {
      firstLine = secondLine;
      secondLine = '';
    }

    return MiniplayerInfoData(
      firstLine: firstLine,
      secondLine: secondLine,
      favouritePlaylist: YoutubePlaylistController.inst.favouritesPlaylist,
      itemToLike: video.id,
      onLikeTap: (isLiked) async => YoutubePlaylistController.inst.favouriteButtonOnPressed(video.id),
      onShowAddToPlaylistDialog: () => showAddToPlaylistSheet(ids: [video.id], idsNamesLookup: {}),
      onMenuOpen: (d) => openMenu(context, video, d),
      onTextLongTap: () => openInfoMenu(context, video),
      likedIcon: Broken.like_filled,
      normalIcon: Broken.like_1,
      ytLikeManager: _videoLikeManager,
    );
  }

  NamidaMiniPlayerBase getMiniPlayerBase(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return NamidaMiniPlayerBase<String, YTSortType>(
      queueItemExtent: Dimensions.youtubeCardItemExtent,
      videoTileConfigs: const VideoTilePropertiesConfigs(
        openMenuOnLongPress: false,
        displayTimeAgo: false,
        draggingEnabled: true,
        draggableThumbnail: true,
        horizontalGestures: false,
        queueSource: QueueSourceYoutubeID.playerQueue,
        showMoreIcon: true,
      ),
      itemBuilder: (context, i, currentIndex, queue, _, properties) {
        final video = queue[i] as YoutubeID;
        final key = Key("${i}_${video.id}");
        return (
          YTHistoryVideoCard(
            properties: properties!,
            key: key,
            videos: queue,
            index: i,
            day: null,
            thumbnailHeight: Dimensions.youtubeThumbnailHeight,
            cardColorOpacity: 0.5,
            fadeOpacity: i < currentIndex ? 0.3 : 0.0,
            preferFetchNewInfo: true,
          ),
          key,
        );
      },
      getDurationMS: null,
      itemsKeyword: (number, item) => number.displayVideoKeyword,
      onAddItemsTap: (currentItem) => TracksAddOnTap().onAddVideosTap(context),
      topText: (currentItem) =>
          YoutubeInfoController.current.currentVideoPage.value?.channelInfo?.title ??
          YoutubeInfoController.current.currentYTStreams.value?.info?.channelName ??
          YoutubeInfoController.utils.getVideoChannelNameSync((currentItem as YoutubeID).id) ??
          '',
      onTopTextTap: (currentItem) async {
        final pageChannel = YoutubeInfoController.current.currentVideoPage.value?.channelInfo;
        final channelId = pageChannel?.id ??
            YoutubeInfoController.current.currentYTStreams.value?.info?.channelId ?? //
            await YoutubeInfoController.utils.getVideoChannelID((currentItem as YoutubeID).id);
        if (channelId != null) YTChannelSubpage(channelID: channelId, channel: pageChannel).navigate();
      },
      onMenuOpen: (currentItem, d) => openMenu(context, (currentItem as YoutubeID), d),
      focusedMenuOptions: (currentItem) => FocusedMenuOptions(
        onSearch: null,
        onOpen: (currentItem) => true,
        onPressed: (currentItem) => Player.inst.setAudioOnlyPlayback(!settings.youtube.isAudioOnlyMode.value),
        videoIconBuilder: (currentItem, size, color) => Obx(
          (context) => Icon(
            !settings.youtube.isAudioOnlyMode.valueR ? Broken.video : Broken.headphone,
            size: size,
            color: color,
          ),
        ),
        builder: (currentItem, fontSizeMultiplier, sizeMultiplier) {
          final onSecondary = theme.colorScheme.onSecondaryContainer;
          return Obx((context) {
            if (settings.youtube.isAudioOnlyMode.valueR) {
              List<TextSpan>? textChildren;
              if (settings.displayAudioInfoMiniplayer.valueR) {
                final audioStream = Player.inst.currentAudioStream.valueR;
                final formatName = audioStream?.codecInfo.codec;
                final bitrate = audioStream?.bitrate ?? Player.inst.currentCachedAudio.valueR?.bitrate;
                final bitrateText = bitrate == null ? null : "${bitrate ~/ 1000} kbps";
                final sampleRate = audioStream?.codecInfo.embeddedAudioInfo?.audioSampleRate;
                final sampleRateText = sampleRate == null ? null : "$sampleRate khz";
                final language = audioStream?.audioTrack?.langCode ?? Player.inst.currentCachedAudio.valueR?.langaugeCode;

                final finalText = <String?>[
                  formatName,
                  bitrateText,
                  sampleRateText,
                  language,
                ];

                if (finalText.isNotEmpty) {
                  textChildren = <TextSpan>[
                    TextSpan(
                      text: " • ${finalText.joinText(separator: ' • ')}",
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: fontSizeMultiplier(11.0)),
                    ),
                  ];
                }
              }
              return Text.rich(
                TextSpan(
                  text: lang.AUDIO,
                  style: textTheme.labelLarge?.copyWith(fontSize: fontSizeMultiplier(15.0), color: theme.colorScheme.onSecondaryContainer),
                  children: textChildren,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              );
            } else {
              final stream = Player.inst.currentVideoStream.valueR;
              final cached = Player.inst.currentCachedVideo.valueR;
              int? size = stream?.sizeInBytes;
              if (size == null || size == 0) {
                size = cached?.sizeInBytes;
              }
              final sizeFinal = size ?? 0;
              final qualityText = stream?.qualityLabel ?? (cached == null ? null : "${cached.resolution}p${cached.framerateText()}");
              return Text.rich(
                TextSpan(
                  text: lang.VIDEO,
                  style: textTheme.labelLarge?.copyWith(fontSize: fontSizeMultiplier(15.0), color: theme.colorScheme.onSecondaryContainer),
                  children: [
                    if (stream == null && cached == null && !ConnectivityController.inst.hasConnectionR) ...[
                      TextSpan(text: " • ", style: TextStyle(color: onSecondary, fontSize: fontSizeMultiplier(15.0))),
                      WidgetSpan(
                        child: Icon(
                          Broken.global_refresh,
                          size: sizeMultiplier(14.0),
                          color: onSecondary,
                        ),
                      ),
                    ] else
                      TextSpan(
                        text: " • ${qualityText ?? '?'}",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: fontSizeMultiplier(13.0),
                        ),
                      ),
                    // --
                    if (sizeFinal > 0) ...[
                      TextSpan(text: " • ", style: TextStyle(color: theme.colorScheme.primary, fontSize: fontSizeMultiplier(14.0))),
                      TextSpan(
                        text: sizeFinal.fileSizeFormatted,
                        style: TextStyle(color: onSecondary, fontSize: fontSizeMultiplier(10.0)),
                      ),
                    ],
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            }
          });
        },
        currentId: (item) => (item as YoutubeID).id,
        loadQualities: null,
        localVideos: YoutubeInfoController.current.currentCachedQualities,
        streams: YoutubeInfoController.current.currentYTStreams,
        onLocalVideoTap: (item, video) async {
          Player.inst.onItemPlayYoutubeIDSetQuality(
            stream: null,
            mainStreams: null,
            cachedFile: File(video.path),
            videoItem: video,
            useCache: true,
            videoId: Player.inst.currentVideo?.id ?? '',
          );
        },
        onStreamVideoTap: (item, videoId, stream, cacheFile, streams) async {
          Player.inst.onItemPlayYoutubeIDSetQuality(
            mainStreams: streams,
            stream: stream,
            cachedFile: null,
            useCache: true,
            videoId: (item as YoutubeID).id,
          );
        },
      ),
      imageBuilder: (item, brMultiplier) => _YoutubeIDImage(
        video: item as YoutubeID,
        brMultiplier: brMultiplier,
      ),
      currentImageBuilder: (item, brMultiplier, maxHeight) => _AnimatingYoutubeIDImage(
        video: item as YoutubeID,
        brMultiplier: brMultiplier,
        maxHeight: maxHeight,
      ),
      textBuilder: (item) => textBuilder(context, item),
      canShowBuffering: (currentItem) => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return getMiniPlayerBase(context);
  }
}

final _lrcAdditionalScale = 0.0.obs;

class _AnimatingTrackImage extends StatelessWidget {
  final Track track;
  final double Function(double borderRadius) brMultiplier;
  final double? maxHeight;

  const _AnimatingTrackImage({
    required this.track,
    required this.brMultiplier,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatingThumnailWidget(
      brMultiplier: brMultiplier,
      isLocal: true,
      maxHeight: maxHeight,
      fallback: _TrackImage(
        track: track,
        brMultiplier: brMultiplier,
      ),
    );
  }
}

class _AnimatingThumnailWidget extends StatelessWidget {
  final double Function(double borderRadius) brMultiplier;
  final bool isLocal;
  final Widget fallback;
  final double? maxHeight;

  const _AnimatingThumnailWidget({
    required this.brMultiplier,
    required this.isLocal,
    required this.fallback,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.animatingThumbnailInversed,
      builder: (context, isInversed) => ObxO(
        rx: settings.animatingThumbnailScaleMultiplier,
        builder: (context, userScaleMultiplier) => ObxO(
          rx: Player.inst.videoPlayerInfo,
          builder: (context, videoInfo) {
            final videoOrImage = Stack(
              alignment: Alignment.center,
              children: [
                videoInfo != null && videoInfo.isInitialized
                    ? AnimatedBuilder(
                        animation: NamidaMiniPlayerBase.clampedAnimationBCP,
                        child: DoubleTapDetector(
                          onDoubleTap: () => VideoController.inst.toggleFullScreenVideoView(isLocal: isLocal),
                          child: NamidaAspectRatio(
                            aspectRatio: videoInfo.aspectRatio,
                            child: Texture(textureId: videoInfo.textureId),
                          ),
                        ),
                        builder: (context, child) => BorderRadiusClip(
                          borderRadius: BorderRadius.circular(6.0.multipliedRadius + (brMultiplier(8.0.multipliedRadius) * NamidaMiniPlayerBase.clampedAnimationBCP.value)),
                          child: child!,
                        ),
                      )
                    : fallback,
                if (!isLocal)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: ObxO(
                      rx: settings.youtube.sponsorBlockSettings,
                      builder: (context, sponsorblock) => sponsorblock.enabled
                          ? Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Padding(
                                padding: EdgeInsetsDirectional.only(bottom: 16.0),
                                child: SkipSponsorButton(
                                  itemsColor: Colors.white.withAlpha(200),
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ),
              ],
            );

            return ObxO(
              rx: settings.enableLyrics,
              builder: (context, shoulShowLyricsView) {
                final animatedScaleChild = AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: shoulShowLyricsView
                      ? LyricsLRCParsedView(
                          key: Lyrics.inst.lrcViewKey,
                          videoOrImage: videoOrImage,
                          maxHeight: maxHeight, // limit height for when sizes are internally mutated
                        )
                      : KeyedSubtree(
                          key: const ValueKey('no_lyrics'),
                          child: videoOrImage,
                        ),
                );
                return ObxO(
                  rx: VideoController.inst.videoZoomAdditionalScale,
                  builder: (context, videoZoomAdditionalScale) {
                    final additionalScaleVideo = 0.02 * videoZoomAdditionalScale;
                    return ObxO(
                      rx: _lrcAdditionalScale,
                      builder: (context, lrcAdditionalScale) {
                        final additionalScaleLRC = 0.02 * lrcAdditionalScale;
                        return ObxO(
                          rx: Player.inst.nowPlayingPosition,
                          builder: (context, nowPlayingPosition) {
                            final animatingScale = MiniPlayerController.inst.animation.value == 0
                                ? WaveformController.inst.getCurrentAnimatingScaleMinimized(nowPlayingPosition)
                                : shoulShowLyricsView
                                    ? WaveformController.inst.getCurrentAnimatingScaleLyrics(nowPlayingPosition)
                                    : WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition);
                            final finalScale = additionalScaleLRC + additionalScaleVideo + animatingScale;
                            return AnimatedScale(
                              duration: const Duration(milliseconds: 100),
                              scale: (isInversed ? 1.22 - finalScale : 1.13 + finalScale) * userScaleMultiplier,
                              child: animatedScaleChild,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TrackImage extends StatelessWidget {
  final Track track;
  final double Function(double borderRadius) brMultiplier;

  const _TrackImage({
    required this.track,
    required this.brMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutWidthProvider(
      builder: (context, maxWidth) => ArtworkWidget(
        key: Key(track.pathToImage),
        track: track,
        path: track.pathToImage,
        thumbnailSize: maxWidth,
        compressed: MiniPlayerController.inst.animation.value == 0,
        borderRadius: 6.0 + brMultiplier(8.0.multipliedRadius) * (maxWidth * 0.004),
        fadeMilliSeconds: 0,
        forceSquared: settings.forceSquaredTrackThumbnail.value,
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(100),
            blurRadius: 24.0,
            offset: const Offset(0.0, 8.0),
          ),
        ],
        iconSize: maxWidth * 0.5,
        enableGlow: false,
      ),
    );
  }
}

class _YoutubeIDImage extends StatelessWidget {
  final YoutubeID video;
  final double Function(double borderRadius) brMultiplier;

  const _YoutubeIDImage({
    required this.video,
    required this.brMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutWidthProvider(
      builder: (context, maxWidth) => YoutubeThumbnail(
        type: ThumbnailType.video,
        key: Key(video.id),
        videoId: video.id,
        width: maxWidth,
        forceSquared: settings.forceSquaredTrackThumbnail.value,
        isImportantInCache: true,
        compressed: MiniPlayerController.inst.animation.value == 0,
        preferLowerRes: false,
        fadeMilliSeconds: 0,
        borderRadius: 6.0 + brMultiplier(8.0.multipliedRadius) * (maxWidth * 0.004),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(100),
            blurRadius: 24.0,
            offset: const Offset(0.0, 8.0),
          ),
        ],
        iconSize: maxWidth * 0.5,
        enableGlow: false,
      ),
    );
  }
}

class _AnimatingYoutubeIDImage extends StatelessWidget {
  final YoutubeID video;
  final double Function(double borderRadius) brMultiplier;
  final double? maxHeight;

  const _AnimatingYoutubeIDImage({
    required this.video,
    required this.brMultiplier,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatingThumnailWidget(
      brMultiplier: brMultiplier,
      isLocal: false,
      maxHeight: maxHeight,
      fallback: _YoutubeIDImage(
        video: video,
        brMultiplier: brMultiplier,
      ),
    );
  }
}

class Wallpaper extends StatefulWidget {
  const Wallpaper({
    super.key,
    this.child,
    this.particleOpacity = .1,
    this.gradient = true,
  });

  final Widget? child;
  final double particleOpacity;
  final bool gradient;

  @override
  State<Wallpaper> createState() => _WallpaperState();
}

class _WallpaperState extends State<Wallpaper> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (widget.gradient)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, -0.95),
                  radius: 1.0,
                  colors: [
                    theme.colorScheme.onSecondary.withValues(alpha: .3),
                    theme.colorScheme.onSecondary.withValues(alpha: .2),
                  ],
                ),
              ),
            ),
          if (settings.enableMiniplayerParticles.value)
            ObxO(
              rx: Player.inst.isPlaying,
              builder: (context, playing) => AnimatedOpacity(
                duration: const Duration(seconds: 1),
                opacity: playing ? 1 : 0,
                child: ObxO(
                  rx: Player.inst.nowPlayingPosition,
                  builder: (context, nowPlayingPosition) {
                    final scale = WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition);
                    final bpm = (2000 * scale).withMinimum(0);
                    return AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: 1.0 + scale * 1.5,
                      child: AnimatedBackground(
                        vsync: this,
                        behaviour: RandomParticleBehaviour(
                          options: ParticleOptions(
                            baseColor: theme.colorScheme.tertiary,
                            spawnMaxRadius: 4,
                            spawnMinRadius: 2,
                            spawnMaxSpeed: 60 + bpm * 2,
                            spawnMinSpeed: bpm,
                            maxOpacity: widget.particleOpacity,
                            minOpacity: 0,
                            particleCount: 50,
                          ),
                        ),
                        child: const SizedBox(),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
