// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Selectable;

import 'package:just_audio/just_audio.dart' show VideoInfoData;
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/youtipie.dart' show CodecInfoUtils;

import 'package:namida/base/audio_handler.dart';
import 'package:namida/base/yt_video_like_manager.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_output_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/party/party_controller.dart';
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
import 'package:namida/ui/dialogs/chapters_sheet.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/effects/effects.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
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
  final Animation<double> animation;
  const MiniPlayerParent({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => Theme(
        data: AppThemes.inst.getAppTheme(CurrentColor.inst.miniplayerColor, !context.isDarkMode),
        child: const _MiniPlayerParentBody(),
      ),
    );
  }
}

class _MiniPlayerParentBody extends StatelessWidget {
  const _MiniPlayerParentBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // -- MiniPlayer Wallpaper
        Positioned.fill(
          child: RepaintBoundary(
            child: FadeIgnoreTransition(
              completelyKillWhenPossible: true,
              opacity: NamidaMiniPlayerBase.clampedAnimationCP,
              child: const Wallpaper(
                gradient: false,
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
                    rx: PartyController.inst.forcesMixedQueue,
                    builder: (context, partyMixedQueue) => partyMixedQueue ? const NamidaMiniPlayerMixed() : const _NamidaMiniPlayerByCurrentItem(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NamidaMiniPlayerByCurrentItem extends StatelessWidget {
  const _NamidaMiniPlayerByCurrentItem();

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.currentItem,
      builder: (context, currentItem) => currentItem is YoutubeID
          ? ObxO(
              rx: settings.youtube.youtubeStyleMiniplayer,
              builder: (context, youtubeStyleMiniplayer) => CustomAnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: youtubeStyleMiniplayer
                    ? YoutubeMiniPlayer(key: YoutubeMiniplayerUiController.inst.ytMiniplayerKey) //
                    : const NamidaMiniPlayerYoutubeID(key: Key('local_miniplayer_yt')),
              ),
            )
          : currentItem is Selectable
          ? const NamidaMiniPlayerTrack(key: Key('local_miniplayer'))
          : const SizedBox(key: Key('empty_miniplayer')),
    );
  }
}

class NamidaMiniPlayerMixed extends StatelessWidget {
  const NamidaMiniPlayerMixed({super.key});

  @override
  Widget build(BuildContext context) {
    final trackConfig = NamidaMiniPlayerTrack.getMiniPlayerBase(context);
    final ytConfig = NamidaMiniPlayerYoutubeID.getMiniPlayerBase(context);

    return NamidaMiniPlayerBase(
      trackTileConfigs: trackConfig.trackTileConfigs,
      videoTileConfigs: ytConfig.videoTileConfigs,
      queueItemExtent: null,
      queueItemExtentBuilder: (item) {
        return item is Selectable ? trackConfig.queueItemExtent : ytConfig.queueItemExtent;
      },
      itemBuilder: (context, index, queue, trackTileProperties, videoTileProperties) {
        final item = queue[index];
        return item is Selectable
            ? trackConfig.itemBuilder(context, index, queue, trackTileProperties, videoTileProperties)
            : ytConfig.itemBuilder(context, index, queue, trackTileProperties, videoTileProperties);
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
      imageBuilder: (item) {
        return item is Selectable ? trackConfig.imageBuilder(item) : ytConfig.imageBuilder(item);
      },
      currentImageBuilder: (item, lyricsMaxSize) {
        return item is Selectable ? trackConfig.currentImageBuilder(item, lyricsMaxSize) : ytConfig.currentImageBuilder(item, lyricsMaxSize);
      },
      textBuilder: (item) {
        return item is Selectable
            ? trackConfig.textBuilder(item) as MiniplayerInfoData<Track, SortType>
            : ytConfig.textBuilder(item as YoutubeID) as MiniplayerInfoData<String, YTSortType>;
      },
      textRefreshRx: ytConfig.textRefreshRx,
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
    );
  }

  static FocusedMenuOptions buildFocusedMenuOptions(BuildContext context) {
    final theme = context.theme;
    // ignore: unused_local_variable
    final textTheme = theme.textTheme;
    return FocusedMenuOptions(
      onSearch: (item) {
        final tr = (item as Selectable).track;
        showSetYTLinkCommentDialog(tr, CurrentColor.inst.miniplayerColor, autoOpenSearch: true);
      },
      onPressed: (currentItem) => VideoController.inst.toggleVideoPlayback(),
      videoIconBuilder: (currentItem, size, color) => Obx(
        (context) => Icon(
          settings.enableVideoPlayback.valueR ? Broken.video : Broken.headphone,
          size: size,
          color: color,
        ),
      ),
      builder: (currentItem) {
        final onSecondary = theme.colorScheme.onSecondaryContainer;
        return Obx((context) {
          if (!settings.enableVideoPlayback.valueR) {
            final trExt = (currentItem as Selectable).track.toTrackExt();
            var text = " • ${trExt.audioInfoFormattedCompact}";
            final bits = trExt.bits;
            final isLossless = trExt.isLossless;

            final bitsTextParts = [
              if (bits >= 24) 'Hi-Res',
              if (isLossless == true) 'Lossless',
            ];
            final bitsText = bitsTextParts.join(' ');
            final isBitPerfect = AudioOutputController.inst.isBitPerfectActiveR();
            final badgeIcon = isBitPerfect ? Broken.flash : Broken.wind_2;

            return Text.rich(
              TextSpan(
                text: lang.audio,
                style: textTheme.labelLarge?.copyWith(fontSize: 15.0, color: theme.colorScheme.onSecondaryContainer),
                children: [
                  if (settings.displayAudioInfoMiniplayer.valueR)
                    TextSpan(
                      text: text,
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 11.0),
                      children: bits > 0
                          ? [
                              const WidgetSpan(
                                child: SizedBox(width: 4.0),
                              ),
                              WidgetSpan(
                                child: NamidaPopupWrapper(
                                  contentDecoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                    border: Border.all(
                                      color: CurrentColor.inst.miniplayerColor,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color.alphaBlend(theme.scaffoldBackgroundColor.withOpacityExt(0.8), CurrentColor.inst.miniplayerColor).withOpacityExt(1.0),
                                        Color.alphaBlend(theme.scaffoldBackgroundColor.withOpacityExt(0.5), CurrentColor.inst.miniplayerColor).withOpacityExt(1.0),
                                      ],
                                    ),
                                  ),
                                  children: () => [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            badgeIcon,
                                            size: 32.0,
                                          ),
                                          const SizedBox(height: 12.0),
                                          if (isBitPerfect) ...[
                                            Text(
                                              lang.bitPerfect,
                                              style: textTheme.displayLarge,
                                            ),
                                            const SizedBox(height: 6.0),
                                          ],
                                          if (bitsText.isNotEmpty) ...[
                                            Text(
                                              bitsText,
                                              style: textTheme.displayLarge,
                                            ),
                                            const SizedBox(height: 6.0),
                                          ],
                                          Text(
                                            trExt.audioInfoFormattedAlt,
                                            style: textTheme.displayMedium,
                                          ),
                                          const SizedBox(height: 12.0),
                                          NamidaInkWell(
                                            borderRadius: 8.0,
                                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                            bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
                                            onTap: () {
                                              NamidaNavigator.inst.popMenu();
                                              NamidaOnTaps.inst.openAudioPath();
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Broken.routing_2,
                                                  size: 16.0,
                                                ),
                                                const SizedBox(width: 6.0),
                                                Text(
                                                  lang.signalPath,
                                                  style: textTheme.displaySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: NamidaInkWell(
                                    borderRadius: 4.0,
                                    bgColor: theme.cardColor.withAlpha(60),
                                    padding: const EdgeInsetsGeometry.symmetric(horizontal: 4.0, vertical: 1.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          badgeIcon,
                                          size: 12.0,
                                        ),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          [
                                            '$bits-bit',
                                            ...bitsTextParts,
                                          ].join(' '),
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 11.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          : null,
                    ),
                  WidgetSpan(
                    child: CurrentChapterBadge(
                      item: currentItem,
                    ),
                  ),
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
          late final markText = VideoController.inst.currentVideoConfig.isNoVideosAvailable.valueR
              ? 'x'
              : (currentItem as Selectable).track is Video
              ? '✓'
              : '?';
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
              text: lang.video,
              style: textTheme.labelLarge?.copyWith(fontSize: 15.0, color: theme.colorScheme.onSecondaryContainer),
              children: [
                if (videoBlockedByIcon != null) ...[
                  TextSpan(
                    text: " • ",
                    style: TextStyle(color: onSecondary, fontSize: 15.0),
                  ),
                  WidgetSpan(
                    child: Icon(
                      videoBlockedByIcon,
                      size: 14.0,
                      color: onSecondary,
                    ),
                  ),
                ] else
                  TextSpan(
                    text: " • $qualityText$framerateText",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 13.0,
                    ),
                  ),
                // --
                if (videoTotalSize > 0) ...[
                  TextSpan(
                    text: " • ",
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 14.0),
                  ),
                  TextSpan(
                    text: downloadedBytes == null ? videoTotalSize.fileSizeFormatted : "${downloadedBytes.fileSizeFormatted}/${videoTotalSize.fileSizeFormatted}",
                    style: TextStyle(color: onSecondary, fontSize: 10.0),
                  ),
                ],
                WidgetSpan(
                  child: CurrentChapterBadge(
                    item: currentItem,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        });
      },
      currentId: (item) => (item as Selectable).track.youtubeID,
      loadQualities: (item) => VideoController.inst.fetchYTQualitiesForCurrent((item as Selectable).track),
      localVideos: VideoController.inst.currentVideoConfig.currentPossibleLocalVideos,
      streams: VideoController.inst.currentVideoConfig.currentYTStreams,
      isStreamSelected: VideoController.inst.isStreamCurrentlySelectedR,
      downloadingStream: VideoController.inst.currentVideoConfig.currentDownloadingStream,
      downloadedBytes: VideoController.inst.currentVideoConfig.currentDownloadedBytes,
      onLocalVideoTap: (item, video) => VideoController.inst.setVideoQualityFromLocal(
        track: (item as Selectable).track,
        video: video,
      ),
      onStreamVideoTap: (item, videoId, stream, cacheFile, streams) => VideoController.inst.setVideoQualityFromStream(
        track: (item as Selectable).track,
        videoId: videoId,
        stream: stream,
        cacheFile: cacheFile,
        mainStreams: streams,
      ),
    );
  }

  static NamidaMiniPlayerBase getMiniPlayerBase(BuildContext context) {
    return NamidaMiniPlayerBase<Track, SortType>(
      queueItemExtent: Dimensions.inst.trackTileItemExtent,
      trackTileConfigs: const TrackTilePropertiesConfigs(
        displayRightDragHandler: true,
        draggableThumbnail: true,
        horizontalGestures: false,
        queueSource: QueueSource.playerQueue,
      ),
      itemBuilder: (context, i, queue, properties, _) {
        final track = queue[i] as Selectable;
        final key = Key("${i}_${track.track.path}");
        return (
          ObxOSelect(
            rx: Player.inst.currentIndex,
            selector: (currentIndex) => i < currentIndex,
            builder: (context, isPlayed) => TrackTile(
              properties: properties!,
              key: key,
              index: i,
              trackOrTwd: track,
              tracks: queue,
              cardColorOpacity: 0.5,
              fadeOpacity: isPlayed ? 0.3 : 0.0,
              onPlaying: () {
                // -- to improve performance, skipping process of checking new queues, etc..
                if (i == Player.inst.currentIndex.value) {
                  Player.inst.togglePlayPause();
                } else {
                  Player.inst.skipToQueueItem(i);
                }
              },
            ),
          ),
          key,
        );
      },
      getDurationMS: (currentItem) => (currentItem as Selectable).track.durationMS,
      itemsKeyword: (number, item) => number.displayTrackKeyword,
      onAddItemsTap: (currentItem) => TracksAddOnTap().onAddTracksTap(context),
      topText: (currentItem) => (currentItem as Selectable).track.originalAlbum,
      onTopTextTap: (currentItem) => NamidaOnTaps.inst.onAlbumTap((currentItem as Selectable).track.albumsIdentifiersModified.firstOrNull),
      onMenuOpen: (currentItem, _) => openMenu((currentItem as Selectable).trackWithDate, currentItem.track),
      focusedMenuOptions: (currentItem) => buildFocusedMenuOptions(context),
      imageBuilder: (item) => _AdjacentThumbnailScale(
        child: _TrackImage(
          track: (item as Selectable).track,
        ),
      ),
      currentImageBuilder: (item, lyricsMaxSize) => _AnimatingTrackImage(
        track: (item as Selectable).track,
        lyricsMaxSize: lyricsMaxSize,
      ),
      textBuilder: textBuilder,
      canShowBuffering: (currentItem) => (currentItem as Selectable).track.isNetwork,
    );
  }

  @override
  Widget build(BuildContext context) {
    return getMiniPlayerBase(context);
  }
}

class NamidaMiniPlayerYoutubeID extends StatelessWidget {
  const NamidaMiniPlayerYoutubeID({super.key});

  static final _numberOfRepeats = 1.obs;

  static void openMenu(BuildContext context, YoutubeID video, TapUpDetails details) async {
    final vidpage = await YoutubeInfoController.video.fetchVideoPageCache(video.id);
    final vidstreams = await YoutubeInfoController.video.fetchVideoStreamsCache(video.id);
    final videoTitle = vidpage?.videoInfo?.title ?? vidstreams?.info?.title;
    final videoChannelId = vidpage?.channelInfo?.id ?? vidstreams?.info?.channelId;

    final menu = NamidaPopupWrapper(
      onPop: () {
        _numberOfRepeats.value = 1;
      },
      childrenDefault: () => YTUtils.getVideoCardMenuItemsForCurrentlyPlaying(
        queueSource: QueueSourceYoutubeID.ytPlayerQueue,
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

  static bool isYoutubeStreamSelectedR(VideoStream stream, File? cacheFile) {
    if (settings.youtube.isAudioOnlyMode.valueR) return false;
    final currentStream = Player.inst.currentVideoStream.valueR;
    if (currentStream != null) return currentStream.itag == stream.itag;
    if (cacheFile == null) return false;
    return Player.inst.currentCachedVideo.valueR?.path == cacheFile.path;
  }

  static MiniplayerInfoData<String, YTSortType> textBuilder(BuildContext context, Playable playbale) {
    final video = playbale as YoutubeID;
    String firstLine = '';
    String secondLine = '';

    final utils = YoutubeInfoController.utils;
    firstLine = utils.getVideoNameSyncLazy(video.id) ?? '';
    secondLine = utils.getVideoChannelNameSyncLazy(video.id) ?? '';
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
      ytLikeManager: YtVideoLikeManager.current,
    );
  }

  static FocusedMenuOptions buildFocusedMenuOptions(BuildContext context) {
    final theme = context.theme;
    // ignore: unused_local_variable
    final textTheme = theme.textTheme;
    return FocusedMenuOptions(
      onSearch: null,
      onPressed: (currentItem) => Player.inst.setAudioOnlyPlayback(!settings.youtube.isAudioOnlyMode.value),
      videoIconBuilder: (currentItem, size, color) => Obx(
        (context) => Icon(
          !settings.youtube.isAudioOnlyMode.valueR ? Broken.video : Broken.headphone,
          size: size,
          color: color,
        ),
      ),
      builder: (currentItem) {
        final onSecondary = theme.colorScheme.onSecondaryContainer;
        return Obx((context) {
          if (settings.youtube.isAudioOnlyMode.valueR) {
            List<TextSpan>? textChildren;
            if (settings.displayAudioInfoMiniplayer.valueR) {
              final audioStream = Player.inst.currentAudioStream.valueR;
              final formatName = audioStream?.codecInfo.codecCleaned();
              final bitrate = audioStream?.bitrate ?? Player.inst.currentCachedAudio.valueR?.bitrate;
              final bitrateText = bitrate == null ? null : "${bitrate ~/ 1000} kb/s";
              final sampleRate = audioStream?.codecInfo.embeddedAudioInfo?.audioSampleRate;
              final sampleRateText = sampleRate == null ? null : "${sampleRate / 1000} kHz";
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
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 11.0),
                  ),
                ];
              }
            }
            return Text.rich(
              TextSpan(
                text: lang.audio,
                style: textTheme.labelLarge?.copyWith(fontSize: 15.0, color: theme.colorScheme.onSecondaryContainer),
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
                text: lang.video,
                style: textTheme.labelLarge?.copyWith(fontSize: 15.0, color: theme.colorScheme.onSecondaryContainer),
                children: [
                  if (stream == null && cached == null && !ConnectivityController.inst.hasConnectionR) ...[
                    TextSpan(
                      text: " • ",
                      style: TextStyle(color: onSecondary, fontSize: 15.0),
                    ),
                    WidgetSpan(
                      child: Icon(
                        Broken.global_refresh,
                        size: 14.0,
                        color: onSecondary,
                      ),
                    ),
                  ] else
                    TextSpan(
                      text: " • ${qualityText ?? '?'}",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13.0,
                      ),
                    ),
                  // --
                  if (sizeFinal > 0) ...[
                    TextSpan(
                      text: " • ",
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 14.0),
                    ),
                    TextSpan(
                      text: sizeFinal.fileSizeFormatted,
                      style: TextStyle(color: onSecondary, fontSize: 10.0),
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
      isStreamSelected: isYoutubeStreamSelectedR,
      downloadingStream: null,
      downloadedBytes: null,
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
    );
  }

  static NamidaMiniPlayerBase getMiniPlayerBase(BuildContext context) {
    return NamidaMiniPlayerBase<String, YTSortType>(
      queueItemExtent: Dimensions.youtubeCardItemExtent,
      videoTileConfigs: const VideoTilePropertiesConfigs(
        openMenuOnLongPress: false,
        displayTimeAgo: false,
        draggingEnabled: true,
        draggableThumbnail: true,
        horizontalGestures: false,
        queueSource: QueueSourceYoutubeID.ytPlayerQueue,
        showMoreIcon: true,
      ),
      itemBuilder: (context, i, queue, _, properties) {
        final video = queue[i] as YoutubeID;
        final key = Key("${i}_${video.id}");
        return (
          ObxOSelect(
            rx: Player.inst.currentIndex,
            selector: (currentIndex) => i < currentIndex,
            builder: (context, isPlayed) => YTHistoryVideoCard(
              properties: properties!,
              key: key,
              videos: queue,
              index: i,
              day: null,
              thumbnailHeight: Dimensions.youtubeThumbnailHeight,
              cardColorOpacity: 0.5,
              fadeOpacity: isPlayed ? 0.3 : 0.0,
              preferFetchNewInfo: true,
            ),
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
          YoutubeInfoController.utils.getVideoChannelNameSyncLazy((currentItem as YoutubeID).id) ??
          '',
      onTopTextTap: (currentItem) async {
        final pageChannel = YoutubeInfoController.current.currentVideoPage.value?.channelInfo;
        final channelId =
            pageChannel?.id ??
            YoutubeInfoController.current.currentYTStreams.value?.info?.channelId ?? //
            await YoutubeInfoController.utils.getVideoChannelID((currentItem as YoutubeID).id);
        if (channelId != null) YTChannelSubpage(channelID: channelId, channel: pageChannel).navigate();
      },
      onMenuOpen: (currentItem, d) => openMenu(context, (currentItem as YoutubeID), d),
      focusedMenuOptions: (currentItem) => buildFocusedMenuOptions(context),
      imageBuilder: (item) => _AdjacentThumbnailScale(
        child: _YoutubeIDImage(
          video: item as YoutubeID,
        ),
      ),
      currentImageBuilder: (item, lyricsMaxSize) => _AnimatingYoutubeIDImage(
        video: item as YoutubeID,
        lyricsMaxSize: lyricsMaxSize,
      ),
      textBuilder: (item) => textBuilder(context, item),
      textRefreshRx: YoutubeInfoController.utils.lazyInfoRefresh,
      canShowBuffering: (currentItem) => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return getMiniPlayerBase(context);
  }
}

final _lrcAdditionalScale = 0.0.obs;

class _AdjacentThumbnailScale extends StatelessWidget {
  final Widget child;
  const _AdjacentThumbnailScale({required this.child});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.animatingThumbnailInversed,
      builder: (context, isInversed) => ObxO(
        rx: settings.animatingThumbnailScaleMultiplier,
        builder: (context, userScaleMultiplier) => Transform.scale(
          scale: MiniplayerThumbnailScale.resolveBase(isInversed: isInversed, userScaleMultiplier: userScaleMultiplier),
          child: RepaintBoundary(
            // -- matches the current card's lyrics backdrop, so sliding in/out doesn't pop between blurred & not.
            child: LyricsOverlayBackdrop(
              mpAnimation: NamidaMiniPlayerBase.clampedAnimationBCP,
              visibility: Lyrics.inst.lrcOverlayVisibility,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds the main player's video/audio menu options for whichever item is playing.
FocusedMenuOptions? miniplayerFocusedMenuOptionsFor(BuildContext context, Playable item) {
  return item.execute(
    selectable: (_) => NamidaMiniPlayerTrack.buildFocusedMenuOptions(context),
    youtubeID: (_) => NamidaMiniPlayerYoutubeID.buildFocusedMenuOptions(context),
  );
}

/// The miniplayer's animating artwork/video, usable outside the miniplayer itself.
class MiniplayerArtwork extends StatelessWidget {
  final Playable item;
  final ValueListenable<Size> lyricsMaxSize;

  /// when the lyrics live somewhere else, the artwork shouldnt blur itself for them.
  final bool showLyricsOverlay;

  const MiniplayerArtwork({
    super.key,
    required this.item,
    required this.lyricsMaxSize,
    this.showLyricsOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return item.execute(
          selectable: (finalItem) => _AnimatingTrackImage(
            track: finalItem.track,
            lyricsMaxSize: lyricsMaxSize,
            showLyricsOverlay: showLyricsOverlay,
          ),
          youtubeID: (finalItem) => _AnimatingYoutubeIDImage(
            video: finalItem,
            lyricsMaxSize: lyricsMaxSize,
            showLyricsOverlay: showLyricsOverlay,
          ),
        ) ??
        const SizedBox();
  }
}

class _AnimatingTrackImage extends StatelessWidget {
  final Track track;
  final ValueListenable<Size> lyricsMaxSize;
  final bool showLyricsOverlay;

  const _AnimatingTrackImage({
    required this.track,
    required this.lyricsMaxSize,
    this.showLyricsOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatingThumnailWidget(
      isLocal: true,
      lyricsMaxSize: lyricsMaxSize,
      showLyricsOverlay: showLyricsOverlay,
      fallback: _TrackImage(
        track: track,
      ),
    );
  }
}

class _AnimatingThumnailWidget extends StatefulWidget {
  final bool isLocal;
  final Widget fallback;
  final ValueListenable<Size> lyricsMaxSize;
  final bool showLyricsOverlay;

  const _AnimatingThumnailWidget({
    required this.isLocal,
    required this.fallback,
    required this.lyricsMaxSize,
    this.showLyricsOverlay = true,
  });

  @override
  State<_AnimatingThumnailWidget> createState() => _AnimatingThumnailWidgetState();
}

/// The player shares one texture across items and never clears it, so the outgoing item's last
/// frame stays painted for free while the switch animation is in flight, instead of snapping to artwork.
class _AnimatingThumnailWidgetState extends State<_AnimatingThumnailWidget> {
  VideoInfoData? _lastInitialized;
  VideoInfoData? _frozen;
  bool _outgoingDisposed = false;
  bool _incomingArrived = false;
  VideoInfoData? _effective;

  @override
  void initState() {
    super.initState();
    _effective = _resolve();
    VideoController.inst.displayedVideoInfo.addListener(_onChange);
    MiniPlayerController.inst.displayIndicesOverride.addListener(_onChange);
  }

  @override
  void dispose() {
    VideoController.inst.displayedVideoInfo.removeListener(_onChange);
    MiniPlayerController.inst.displayIndicesOverride.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final effective = _resolve();
    if (effective != _effective) refreshState(() => _effective = effective);
  }

  VideoInfoData? _resolve() {
    final info = VideoController.inst.displayedVideoInfo.value;
    final initialized = info != null && info.isInitialized;
    final switching = MiniPlayerController.inst.displayIndicesOverride.value != null;

    if (!switching) {
      _frozen = null;
      _outgoingDisposed = false;
      _incomingArrived = false;
      _lastInitialized = initialized ? info : null;
      return _lastInitialized;
    }

    if (_incomingArrived) return null;

    if (initialized) {
      if (_outgoingDisposed) {
        _frozen = null;
        _incomingArrived = true;
        return null;
      }
      _lastInitialized = info;
      return info;
    }

    if (!_outgoingDisposed) {
      _outgoingDisposed = true;
      _frozen = _lastInitialized;
    }
    return _frozen;
  }

  @override
  Widget build(BuildContext context) {
    final videoInfo = _effective;
    final isLocal = widget.isLocal;
    final lyricsMaxSize = widget.lyricsMaxSize;
    final showLyricsOverlay = widget.showLyricsOverlay;
    return ObxO(
      rx: settings.animatingThumbnailInversed,
      builder: (context, isInversed) => ObxO(
        rx: settings.animatingThumbnailScaleMultiplier,
        builder: (context, userScaleMultiplier) {
          final videoOrImage = Stack(
            alignment: Alignment.center,
            children: [
              videoInfo != null
                  ? ClipRRect(
                      clipper: _ExpandingRadiusClipper(NamidaMiniPlayerBase.clampedAnimationBCP),
                      child: DoubleTapDetector(
                        onDoubleTap: () => VideoController.inst.toggleFullScreenVideoView(isLocal: isLocal),
                        child: NamidaAspectRatio(
                          aspectRatio: videoInfo.aspectRatio,
                          child: Texture(textureId: videoInfo.textureId),
                        ),
                      ),
                    )
                  : widget.fallback,
              if (!isLocal)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: ValueConditionBuilder(
                    listenable: MiniPlayerController.inst.animation,
                    condition: _isFullyExpanded,
                    builder: (context, isFullyExpanded, child) => isFullyExpanded ? child! : const SizedBox(),
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
                ),
            ],
          );

          return ObxO(
            rx: settings.enableLyrics,
            builder: (context, enableLyrics) {
              final shoulShowLyricsView = enableLyrics && showLyricsOverlay;
              final animatedScaleChild = CustomAnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: shoulShowLyricsView
                    ? ValueListenableBuilder(
                        valueListenable: lyricsMaxSize,
                        builder: (context, lyricsMaxSize, _) => LyricsLRCParsedView(
                          key: Lyrics.inst.lrcViewKey,
                          videoOrImage: videoOrImage,
                          maxWidth: lyricsMaxSize.width,
                          maxHeight: lyricsMaxSize.height,
                          insideMiniplayerCard: true,
                          visibilityNotifier: Lyrics.inst.lrcOverlayVisibility,
                        ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('no_lyrics'),
                        child: videoOrImage,
                      ),
              );
              // -- hard cap: whatever the base overshoot, pulse & zoom add up to, never paint
              // -- past the panel. inside the player's scale box this MediaQuery is the panel.
              final maxPaintedWidth = MediaQuery.sizeOf(context).width;
              return ObxO(
                rx: VideoController.inst.videoZoomAdditionalScale,
                builder: (context, videoZoomAdditionalScale) {
                  final additionalScaleVideo = 0.02 * videoZoomAdditionalScale;
                  return ObxO(
                    rx: _lrcAdditionalScale,
                    builder: (context, lrcAdditionalScale) {
                      final additionalScaleLRC = 0.02 * lrcAdditionalScale;
                      return ObxOSelect(
                        rx: Player.inst.nowPlayingPosition,
                        selector: (nowPlayingPosition) => MiniPlayerController.inst.animation.value == 0
                            ? WaveformController.inst.getCurrentAnimatingScaleMinimized(nowPlayingPosition)
                            : shoulShowLyricsView
                            ? WaveformController.inst.getCurrentAnimatingScaleLyrics(nowPlayingPosition)
                            : WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition),
                        builder: (context, animatingScale) {
                          final finalScale = additionalScaleLRC + additionalScaleVideo + animatingScale;
                          return _AnimatedScaleWithinWidth(
                            duration: const Duration(milliseconds: 100),
                            scale: MiniplayerThumbnailScale.resolve(
                              additional: finalScale,
                              isInversed: isInversed,
                              userScaleMultiplier: userScaleMultiplier,
                            ),
                            maxPaintedWidth: maxPaintedWidth,
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
    );
  }

  static bool _isFullyExpanded(double p) => p == 1.0;
}

class _ExpandingRadiusClipper extends CustomClipper<RRect> {
  final Animation<double> expansion;

  _ExpandingRadiusClipper(this.expansion) : super(reclip: expansion);

  @override
  RRect getClip(Size size) {
    final radius = 6.0.multipliedRadius + (8.0.multipliedRadius * expansion.value);
    return RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
  }

  @override
  bool shouldReclip(_ExpandingRadiusClipper oldClipper) => oldClipper.expansion != expansion;
}

// by claude
/// [AnimatedScale] that never paints [child] wider than [maxPaintedWidth]. The cap is applied
/// while painting, so a box resizing every frame neither rebuilds nor re-animates it.
class _AnimatedScaleWithinWidth extends ImplicitlyAnimatedWidget {
  final double scale;
  final double maxPaintedWidth;
  final Widget child;

  const _AnimatedScaleWithinWidth({
    required this.scale,
    required this.maxPaintedWidth,
    required super.duration,
    required this.child,
  });

  @override
  ImplicitlyAnimatedWidgetState<_AnimatedScaleWithinWidth> createState() => _AnimatedScaleWithinWidthState();
}

class _AnimatedScaleWithinWidthState extends ImplicitlyAnimatedWidgetState<_AnimatedScaleWithinWidth> {
  Tween<double>? _scale;
  late Animation<double> _scaleAnimation;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _scale = visitor(_scale, widget.scale, (dynamic value) => Tween<double>(begin: value as double)) as Tween<double>?;
  }

  @override
  void didUpdateTweens() {
    _scaleAnimation = animation.drive(_scale!);
  }

  @override
  Widget build(BuildContext context) {
    return _ScaleWithinWidth(
      scale: _scaleAnimation,
      maxPaintedWidth: widget.maxPaintedWidth,
      child: widget.child,
    );
  }
}

class _ScaleWithinWidth extends SingleChildRenderObjectWidget {
  final Animation<double> scale;
  final double maxPaintedWidth;

  const _ScaleWithinWidth({
    required this.scale,
    required this.maxPaintedWidth,
    required super.child,
  });

  @override
  _RenderScaleWithinWidth createRenderObject(BuildContext context) => _RenderScaleWithinWidth(scale, maxPaintedWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderScaleWithinWidth renderObject) {
    renderObject
      ..scale = scale
      ..maxPaintedWidth = maxPaintedWidth;
  }
}

class _RenderScaleWithinWidth extends RenderProxyBox {
  _RenderScaleWithinWidth(this._scale, this._maxPaintedWidth);

  Animation<double> _scale;
  set scale(Animation<double> value) {
    if (value == _scale) return;
    if (attached) {
      _scale.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _scale = value;
    markNeedsPaint();
  }

  double _maxPaintedWidth;
  set maxPaintedWidth(double value) {
    if (value == _maxPaintedWidth) return;
    _maxPaintedWidth = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scale.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scale.removeListener(markNeedsPaint);
    super.detach();
  }

  double _computeEffectiveScale() {
    final scale = _scale.value;
    final width = size.width;
    if (width <= 0) return scale;
    return scale.withMaximum(_maxPaintedWidth / width);
  }

  Matrix4 _computeTransform(double scale) {
    final dx = size.width / 2 * (1 - scale);
    final dy = size.height / 2 * (1 - scale);
    return Matrix4.diagonal3Values(scale, scale, 1.0)..setTranslationRaw(dx, dy, 0.0);
  }

  // -- like [RenderTransform], the untransformed size isn't checked, the child is hit where it's painted.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => hitTestChildren(result, position: position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _computeTransform(_computeEffectiveScale()),
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_computeTransform(_computeEffectiveScale()));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final scale = _computeEffectiveScale();
    if (scale == 1.0) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _computeTransform(scale),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer as TransformLayer?,
    );
  }
}

class _TrackImage extends StatelessWidget {
  final Track track;

  const _TrackImage({
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutWidthProvider(
      builder: (context, maxWidth) => ArtworkWidget(
        key: Key(track.pathToImage),
        track: track,
        path: track.pathToImage,
        thumbnailSize: maxWidth,
        compressed: MiniPlayerController.inst.shouldCompressArtwork,
        borderRadius: 6.0 + 8.0.multipliedRadius * (maxWidth * 0.004),
        fadeMilliSeconds: 0,
        forceSquared: settings.forceSquaredTrackThumbnail.value,
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(40, 12, 12, 12),
            blurRadius: 18.0,
            offset: Offset(0.0, 6.0),
          ),
        ],
        iconSize: maxWidth * 0.5,
        blur: 32.0 * MiniPlayerController.inst.animation.value,
        disableBlurBgSizeShrink: true,
        allowFloating: true,
      ),
    );
  }
}

class _YoutubeIDImage extends StatelessWidget {
  final YoutubeID video;

  const _YoutubeIDImage({
    required this.video,
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
        compressed: MiniPlayerController.inst.shouldCompressArtwork,
        preferLowerRes: false,
        fadeMilliSeconds: 0,
        borderRadius: 6.0 + 8.0.multipliedRadius * (maxWidth * 0.004),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(40, 12, 12, 12),
            blurRadius: 18.0,
            offset: Offset(0.0, 6.0),
          ),
        ],
        iconSize: maxWidth * 0.5,
        blur: 32.0 * MiniPlayerController.inst.animation.value,
        disableBlurBgSizeShrink: true,
        allowFloating: true,
      ),
    );
  }
}

class _AnimatingYoutubeIDImage extends StatelessWidget {
  final YoutubeID video;
  final ValueListenable<Size> lyricsMaxSize;
  final bool showLyricsOverlay;

  const _AnimatingYoutubeIDImage({
    required this.video,
    required this.lyricsMaxSize,
    this.showLyricsOverlay = true,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatingThumnailWidget(
      isLocal: false,
      lyricsMaxSize: lyricsMaxSize,
      showLyricsOverlay: showLyricsOverlay,
      fallback: _YoutubeIDImage(
        video: video,
      ),
    );
  }
}

class Wallpaper extends StatelessWidget {
  const Wallpaper({
    super.key,
    this.child,
    this.gradient = true,
  });

  final Widget? child;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          if (gradient)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, -0.95),
                  radius: 1.0,
                  colors: [
                    theme.colorScheme.onSecondary.withOpacityExt(.3),
                    theme.colorScheme.onSecondary.withOpacityExt(.2),
                  ],
                ),
              ),
            ),

          const Positioned.fill(
            child: NamidaPlayerBackground(),
          ),

          if (NamidaJellys.enabled)
            const Positioned.fill(
              child: NamidaJellyBackground(
                count: 5,
                opacity: 0.22,
                minHeight: 140.0,
                maxHeight: 380.0,
                reactToPlayback: true,
                seed: 13,
              ),
            ),

          const Positioned.fill(
            child: NamidaVisualizer.wallpaper(),
          ),
          ?child,
        ],
      ),
    );
  }
}
