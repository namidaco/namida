import 'dart:io';

import 'package:animated_background/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:namida/core/utils.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
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
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/youtube_miniplayer.dart';
import 'package:namida/youtube/yt_utils.dart';

class MiniPlayerParent extends StatefulWidget {
  final AnimationController animation;
  const MiniPlayerParent({super.key, required this.animation});

  @override
  State<MiniPlayerParent> createState() => _MiniPlayerParentState();
}

class _MiniPlayerParentState extends State<MiniPlayerParent> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    MiniPlayerController.inst.updateScreenValuesInitial();
    MiniPlayerController.inst.initializeSAnim(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {})); // workaround for empty queue view
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    MiniPlayerController.inst.updateScreenValues(context); // useful for updating after split screen & if landscape ever got supported.
    return Obx(
      () => Theme(
        data: AppThemes.inst.getAppTheme(CurrentColor.inst.miniplayerColor, !context.isDarkMode),
        child: Stack(
          children: [
            // -- MiniPlayer Wallpaper
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.animation,
                child: const Wallpaper(gradient: false, particleOpacity: .3),
                builder: (context, child) {
                  if (widget.animation.value > 0.01) {
                    return Opacity(
                      opacity: widget.animation.value.clamp(0.0, 1.0),
                      child: child!,
                    );
                  } else {
                    return const SizedBox();
                  }
                },
              ),
            ),

            // -- MiniPlayers
            ObxO(
              rx: Player.inst.currentItem,
              builder: (currentItem) => currentItem is YoutubeID
                  ? ObxO(
                      rx: settings.youtubeStyleMiniplayer,
                      builder: (youtubeStyleMiniplayer) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: youtubeStyleMiniplayer
                            ? const YoutubeMiniPlayer(key: Key('yt_miniplayer')) //
                            : const NamidaMiniPlayerYoutubeID(key: Key('local_miniplayer_yt')),
                      ),
                    )
                  : currentItem is Selectable
                      ? const NamidaMiniPlayerTrack(key: Key('local_miniplayer'))
                      : const SizedBox(key: Key('empty_miniplayer')),
            ),
          ],
        ),
      ),
    );
  }
}

class NamidaMiniPlayerTrack extends StatelessWidget {
  const NamidaMiniPlayerTrack({super.key});

  void _openMenu(Track track) => NamidaDialogs.inst.showTrackDialog(track, source: QueueSource.playerQueue);

  MiniplayerTextData _textBuilder(Selectable selectable) {
    String firstLine = '';
    String secondLine = '';

    final track = selectable.track;
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
    return MiniplayerTextData(
      firstLine: firstLine,
      secondLine: secondLine,
      isLiked: track.isFavouriteR,
      onLikeTap: (isLiked) async => await PlaylistController.inst.favouriteButtonOnPressed(track),
      onMenuOpen: (_) => _openMenu(track),
      likedIcon: Broken.heart_tick,
      normalIcon: Broken.heart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaMiniPlayerBase(
      queueItemExtent: Dimensions.inst.trackTileItemExtent,
      itemBuilder: (context, i, currentIndex, queue) {
        final track = queue[i] as Selectable;
        final key = Key("${i}_${track.track.path}");
        return (
          TrackTile(
            key: key,
            index: i,
            trackOrTwd: track,
            displayRightDragHandler: true,
            draggableThumbnail: true,
            queueSource: QueueSource.playerQueue,
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
      getDurationMS: (currentItem) => currentItem.track.duration * 1000,
      itemsKeyword: (number) => number.displayTrackKeyword,
      onAddItemsTap: (currentItem) => TracksAddOnTap().onAddTracksTap(context),
      topText: (currentItem) => currentItem.track.album,
      onTopTextTap: (currentItem) => NamidaOnTaps.inst.onAlbumTap(currentItem.track.albumIdentifier),
      onMenuOpen: (currentItem, _) => _openMenu(currentItem.track),
      focusedMenuOptions: FocusedMenuOptions<Selectable>(
        onOpen: (currentItem) {
          if (settings.enableVideoPlayback.value) return true;

          ScrollSearchController.inst.unfocusKeyboard();
          NamidaNavigator.inst.navigateDialog(dialog: const Dialog(child: PlaybackSettings(isInDialog: true)));
          return false;
        },
        onPressed: (currentItem) => VideoController.inst.toggleVideoPlayback(),
        videoIconBuilder: (currentItem, size, color) => Obx(
          () => Icon(
            settings.enableVideoPlayback.valueR ? Broken.video : Broken.headphone,
            size: size,
            color: color,
          ),
        ),
        builder: (currentItem) {
          final onSecondary = context.theme.colorScheme.onSecondaryContainer;
          return Obx(() {
            final currentVideo = VideoController.inst.currentVideo.valueR;
            final downloadedBytes = VideoController.inst.currentDownloadedBytes.valueR;
            final videoTotalSize = currentVideo?.sizeInBytes ?? 0;
            final videoQuality = currentVideo?.resolution ?? 0;
            final videoFramerate = currentVideo?.framerateText(30);
            final markText = VideoController.inst.isNoVideosAvailable.valueR ? 'x' : '?';
            final fallbackQualityLabel = currentVideo?.nameInCache?.split('_').last;
            final qualityText = videoQuality == 0 ? fallbackQualityLabel ?? markText : '${videoQuality}p';
            final framerateText = videoFramerate ?? '';
            return !settings.enableVideoPlayback.valueR
                ? Text.rich(
                    TextSpan(
                      text: lang.AUDIO,
                      style: context.textTheme.labelLarge?.copyWith(fontSize: 15.0, color: context.theme.colorScheme.onSecondaryContainer),
                      children: [
                        if (settings.displayAudioInfoMiniplayer.valueR)
                          TextSpan(
                            text: " • ${currentItem.track.audioInfoFormattedCompact}",
                            style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 11.0),
                          )
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text.rich(
                    TextSpan(
                      text: lang.VIDEO,
                      style: context.textTheme.labelLarge?.copyWith(fontSize: 15.0, color: context.theme.colorScheme.onSecondaryContainer),
                      children: [
                        if (qualityText == '?' && !ConnectivityController.inst.hasConnectionR) ...[
                          TextSpan(text: " • ", style: TextStyle(color: onSecondary, fontSize: 15.0)),
                          WidgetSpan(
                            child: Icon(
                              Broken.global_refresh,
                              size: 14.0,
                              color: onSecondary,
                            ),
                          ),
                        ] else
                          TextSpan(
                            text: " • $qualityText$framerateText",
                            style: TextStyle(
                              color: context.theme.colorScheme.primary,
                              fontSize: 13.0,
                            ),
                          ),
                        // --
                        if (videoTotalSize > 0) ...[
                          TextSpan(text: " • ", style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 14.0)),
                          TextSpan(
                            text: downloadedBytes == null ? videoTotalSize.fileSizeFormatted : "${downloadedBytes.fileSizeFormatted}/${videoTotalSize.fileSizeFormatted}",
                            style: TextStyle(color: onSecondary, fontSize: 10.0),
                          ),
                        ],
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
          });
        },
        currentId: (item) => item.track.youtubeID,
        loadQualities: (item) async => await VideoController.inst.fetchYTQualities(item.track),
        localVideos: VideoController.inst.currentPossibleVideos,
        streamVideos: VideoController.inst.currentYTQualities,
        onLocalVideoTap: (item, video) async {
          VideoController.inst.playVideoCurrent(video: video, track: item.track);
        },
        onStreamVideoTap: (item, videoId, stream, cacheFile) async {
          final cacheExists = cacheFile != null;
          if (!cacheExists) await VideoController.inst.getVideoFromYoutubeAndUpdate(videoId, stream: stream);
          VideoController.inst.playVideoCurrent(
            video: null,
            cacheIdAndPath: (videoId ?? '', cacheFile?.path ?? ''),
            track: item.track,
          );
        },
      ),
      imageBuilder: (item, cp) => _TrackImage(
        track: item.track,
        cp: cp,
      ),
      currentImageBuilder: (item, bcp) => _AnimatingTrackImage(
        track: item.track,
        cp: bcp,
      ),
      textBuilder: _textBuilder,
      canShowBuffering: false,
    );
  }
}

class NamidaMiniPlayerYoutubeID extends StatelessWidget {
  const NamidaMiniPlayerYoutubeID({super.key});

  void _openMenu(BuildContext context, YoutubeID video, TapUpDetails details) {
    final info = YoutubeController.inst.getVideoInfo(video.id);
    final popUpItems = NamidaPopupWrapper(
      childrenDefault: () => YTUtils.getVideoCardMenuItems(
        videoId: video.id,
        url: info?.url,
        channelUrl: info?.uploaderUrl,
        playlistID: null,
        idsNamesLookup: {video.id: info?.name},
        playlistName: '',
        videoYTID: video,
        copyUrl: true,
      ),
    ).convertItems(context);
    NamidaNavigator.inst.showMenu(
      context: context,
      position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      items: popUpItems,
    );
  }

  MiniplayerTextData _textBuilder(BuildContext context, YoutubeID video) {
    String firstLine = '';
    String secondLine = '';

    firstLine = YoutubeController.inst.getVideoName(video.id) ?? '';
    secondLine = YoutubeController.inst.getVideoChannelName(video.id) ?? '';
    if (firstLine == '') {
      firstLine = secondLine;
      secondLine = '';
    }

    return MiniplayerTextData(
      firstLine: firstLine,
      secondLine: secondLine,
      isLiked: YoutubePlaylistController.inst.favouritesPlaylist.value.tracks.firstWhereEff((element) => element.id == video.id) != null,
      onLikeTap: (isLiked) async => YoutubePlaylistController.inst.favouriteButtonOnPressed(video.id),
      onMenuOpen: (d) => _openMenu(context, video, d),
      likedIcon: Broken.like_filled,
      normalIcon: Broken.like_1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaMiniPlayerBase<YoutubeID>(
      queueItemExtent: Dimensions.youtubeCardItemExtent,
      itemBuilder: (context, i, currentIndex, queue) {
        final video = queue[i] as YoutubeID;
        final key = Key("${i}_${video.id}");
        return (
          YTHistoryVideoCard(
            key: key,
            videos: queue,
            index: i,
            day: null,
            playlistID: null,
            playlistName: '',
            openMenuOnLongPress: false,
            displayTimeAgo: false,
            thumbnailHeight: Dimensions.youtubeThumbnailHeight,
            fromPlayerQueue: true,
            draggingEnabled: true,
            draggableThumbnail: true,
            showMoreIcon: true,
            cardColorOpacity: 0.5,
            fadeOpacity: i < currentIndex ? 0.3 : 0.0,
          ),
          key,
        );
      },
      getDurationMS: null,
      itemsKeyword: (number) => number.displayVideoKeyword,
      onAddItemsTap: (currentItem) => TracksAddOnTap().onAddVideosTap(context),
      topText: (currentItem) =>
          YoutubeController.inst.currentYoutubeMetadataChannel.value?.name ??
          Player.inst.currentChannelInfo.value?.name ??
          YoutubeController.inst.getVideoChannelName(currentItem.id) ??
          '',
      onTopTextTap: (currentItem) {
        final channel = YoutubeController.inst.currentYoutubeMetadataChannel.value ?? Player.inst.currentChannelInfo.value;
        final chid = channel?.id;
        if (chid != null) NamidaNavigator.inst.navigateTo(YTChannelSubpage(channelID: chid, channel: channel));
      },
      onMenuOpen: (currentItem, d) => _openMenu(context, currentItem, d),
      focusedMenuOptions: FocusedMenuOptions<YoutubeID>(
        onOpen: (currentItem) => true,
        onPressed: (currentItem) => Player.inst.setAudioOnlyPlayback(!settings.ytIsAudioOnlyMode.value),
        videoIconBuilder: (currentItem, size, color) => Obx(
          () => Icon(
            !settings.ytIsAudioOnlyMode.valueR ? Broken.video : Broken.headphone,
            size: size,
            color: color,
          ),
        ),
        builder: (currentItem) {
          final onSecondary = context.theme.colorScheme.onSecondaryContainer;
          return Obx(() {
            if (settings.ytIsAudioOnlyMode.valueR) {
              List<TextSpan>? textChildren;
              if (settings.displayAudioInfoMiniplayer.valueR) {
                final audioStream = Player.inst.currentAudioStream.valueR;
                final formatName = audioStream?.formatName;
                final bitrate = audioStream?.bitrate ?? Player.inst.currentCachedAudio.valueR?.bitrate;
                final bitrateText = bitrate == null ? null : "${bitrate ~/ 1000} kps";
                final sampleRate = audioStream?.samplerate;
                final sampleRateText = sampleRate == null ? null : "$sampleRate khz";
                final language = audioStream?.language ?? Player.inst.currentCachedAudio.valueR?.langaugeCode;

                final finalText = [
                  formatName,
                  bitrateText,
                  sampleRateText,
                  language,
                ];

                if (finalText.isNotEmpty) {
                  textChildren = <TextSpan>[
                    TextSpan(
                      text: " • ${finalText.joinText(separator: ' • ')}",
                      style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 11.0),
                    ),
                  ];
                }
              }
              return Text.rich(
                TextSpan(
                  text: lang.AUDIO,
                  style: context.textTheme.labelLarge?.copyWith(fontSize: 15.0, color: context.theme.colorScheme.onSecondaryContainer),
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
              final qualityText = stream?.resolution ?? (cached == null ? null : "${cached.resolution}p${cached.framerateText()}");
              return Text.rich(
                TextSpan(
                  text: lang.VIDEO,
                  style: context.textTheme.labelLarge?.copyWith(fontSize: 15.0, color: context.theme.colorScheme.onSecondaryContainer),
                  children: [
                    if (stream == null && cached == null && !ConnectivityController.inst.hasConnectionR) ...[
                      TextSpan(text: " • ", style: TextStyle(color: onSecondary, fontSize: 15.0)),
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
                          color: context.theme.colorScheme.primary,
                          fontSize: 13.0,
                        ),
                      ),
                    // --
                    if (sizeFinal > 0) ...[
                      TextSpan(text: " • ", style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 14.0)),
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
        currentId: (item) => item.id,
        loadQualities: null,
        localVideos: YoutubeController.inst.currentCachedQualities,
        streamVideos: YoutubeController.inst.currentYTQualities,
        onLocalVideoTap: (item, video) async {
          Player.inst.onItemPlayYoutubeIDSetQuality(
            stream: null,
            cachedFile: File(video.path),
            videoItem: video,
            useCache: true,
            videoId: Player.inst.currentVideo?.id ?? '',
          );
        },
        onStreamVideoTap: (item, videoId, stream, cacheFile) async {
          Player.inst.onItemPlayYoutubeIDSetQuality(
            stream: stream,
            cachedFile: null,
            useCache: true,
            videoId: item.id,
          );
        },
      ),
      imageBuilder: (item, cp) => _YoutubeIDImage(
        video: item,
        cp: cp,
      ),
      currentImageBuilder: (item, bcp) => _AnimatingYoutubeIDImage(
        video: item,
        cp: bcp,
      ),
      textBuilder: (item) => _textBuilder(context, item),
      canShowBuffering: true,
    );
  }
}

double _previousScale = 1.0;
final _lrcAdditionalScale = 0.0.obs;
bool _isScalingLRC = false;

class _AnimatingTrackImage extends StatelessWidget {
  final Track track;
  final double cp;

  const _AnimatingTrackImage({
    required this.track,
    required this.cp,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.artworkGestureDoubleTapLRC,
      builder: (artworkGestureDoubleTapLRC) => DoubleTapDetector(
        // -- only when lrc view is not visible, to prevent other gestures delaying.
        onDoubleTap: artworkGestureDoubleTapLRC && Lyrics.inst.currentLyricsLRC.value == null
            ? () {
                settings.save(enableLyrics: !settings.enableLyrics.value);
                Lyrics.inst.updateLyrics(track);
              }
            : null,
        child: GestureDetector(
          onLongPress: () {
            Lyrics.inst.lrcViewKey?.currentState?.enterFullScreen();
          },
          onScaleStart: (details) {
            final lrcState = Lyrics.inst.lrcViewKey?.currentState;
            final lrcVisible = lrcState != null;
            _isScalingLRC = lrcVisible;
            _previousScale = lrcVisible ? 1.0 : settings.animatingThumbnailScaleMultiplier.value;
          },
          onScaleUpdate: (details) {
            if (_isScalingLRC || settings.artworkGestureScale.value) {
              final m = (details.scale * _previousScale);
              if (_isScalingLRC) {
                _lrcAdditionalScale.value = m;
              } else {
                settings.save(animatingThumbnailScaleMultiplier: m.clamp(0.4, 1.5));
              }
            }
          },
          onScaleEnd: (details) {
            final lrcState = Lyrics.inst.lrcViewKey?.currentState;
            if (lrcState != null) {
              final pps = details.velocity.pixelsPerSecond;
              if (pps.dx > 0 || pps.dy > 0) {
                lrcState.enterFullScreen();
              }
            }
            _lrcAdditionalScale.value = 0.0;
          },
          child: _AnimatingThumnailWidget(
            cp: cp,
            isLocal: true,
            displayLyrics: true,
            fallback: _TrackImage(
              track: track,
              cp: cp,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatingThumnailWidget extends StatelessWidget {
  final double cp;
  final bool isLocal;
  final bool displayLyrics;
  final Widget fallback;
  const _AnimatingThumnailWidget({super.key, required this.cp, required this.isLocal, required this.fallback, required this.displayLyrics});

  @override
  Widget build(BuildContext context) {
    final lyricsWidget = displayLyrics
        ? Obx(
            () => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: settings.enableLyrics.valueR && (Lyrics.inst.currentLyricsLRC.valueR != null || Lyrics.inst.currentLyricsText.valueR != '')
                  ? LyricsLRCParsedView(
                      key: Lyrics.inst.lrcViewKey,
                      cp: cp,
                      initialLrc: Lyrics.inst.currentLyricsLRC.valueR,
                      videoOrImage: const SizedBox(),
                    )
                  : const IgnorePointer(
                      key: Key('empty_lrc'),
                      child: SizedBox(),
                    ),
            ),
          )
        : null;
    return ObxO(
      rx: settings.animatingThumbnailInversed,
      builder: (isInversed) => ObxO(
        rx: settings.animatingThumbnailScaleMultiplier,
        builder: (userScaleMultiplier) => ObxO(
          rx: Player.inst.videoPlayerInfo,
          builder: (videoInfo) {
            final videoOrImage = videoInfo != null && videoInfo.isInitialized
                ? BorderRadiusClip(
                    borderRadius: BorderRadius.circular((6.0 + 10.0 * cp).multipliedRadius),
                    child: DoubleTapDetector(
                      onDoubleTap: () => VideoController.inst.toggleFullScreenVideoView(isLocal: isLocal),
                      child: NamidaAspectRatio(
                        aspectRatio: videoInfo.aspectRatio,
                        child: Texture(textureId: videoInfo.textureId),
                      ),
                    ),
                  )
                : fallback;
            final animatedScaleChild = Stack(
              alignment: Alignment.center,
              children: [
                videoOrImage,
                if (lyricsWidget != null) lyricsWidget,
              ],
            );
            return ObxO(
              rx: VideoController.inst.videoZoomAdditionalScale,
              builder: (videoZoomAdditionalScale) {
                final additionalScaleVideo = 0.02 * videoZoomAdditionalScale;
                return ObxO(
                  rx: _lrcAdditionalScale,
                  builder: (lrcAdditionalScale) {
                    final additionalScaleLRC = 0.02 * lrcAdditionalScale;
                    return ObxO(
                      rx: Player.inst.nowPlayingPosition,
                      builder: (nowPlayingPosition) {
                        final finalScale = additionalScaleLRC + additionalScaleVideo + WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition);
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
        ),
      ),
    );
  }
}

class _TrackImage extends StatelessWidget {
  final Track track;
  final double cp;

  const _TrackImage({
    required this.track,
    required this.cp,
  });

  @override
  Widget build(BuildContext context) {
    return ArtworkWidget(
      key: Key(track.pathToImage),
      track: track,
      path: track.pathToImage,
      thumbnailSize: context.width,
      compressed: false,
      borderRadius: 6.0 + 10.0 * cp,
      forceSquared: settings.forceSquaredTrackThumbnail.value,
      boxShadow: [
        BoxShadow(
          color: context.theme.shadowColor.withAlpha(100),
          blurRadius: 24.0,
          offset: const Offset(0.0, 8.0),
        ),
      ],
      iconSize: 24.0 + 114 * cp,
    );
  }
}

class _YoutubeIDImage extends StatelessWidget {
  final YoutubeID video;
  final double cp;

  const _YoutubeIDImage({
    required this.video,
    required this.cp,
  });

  @override
  Widget build(BuildContext context) {
    final width = context.width;
    return YoutubeThumbnail(
      key: Key(video.id),
      videoId: video.id,
      width: width,
      forceSquared: settings.forceSquaredTrackThumbnail.value,
      isImportantInCache: true,
      compressed: false,
      preferLowerRes: false,
      borderRadius: 6.0 + 10.0 * cp,
      boxShadow: [
        BoxShadow(
          color: context.theme.shadowColor.withAlpha(100),
          blurRadius: 24.0,
          offset: const Offset(0.0, 8.0),
        ),
      ],
      iconSize: 24.0 + 114 * cp,
    );
  }
}

class _AnimatingYoutubeIDImage extends StatelessWidget {
  final YoutubeID video;
  final double cp;

  const _AnimatingYoutubeIDImage({
    required this.video,
    required this.cp,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatingThumnailWidget(
      cp: cp,
      isLocal: false,
      displayLyrics: false,
      fallback: _YoutubeIDImage(
        video: video,
        cp: cp,
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

class _WallpaperState extends State<Wallpaper> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (widget.gradient)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.95, -0.95),
                  radius: 1.0,
                  colors: [
                    context.theme.colorScheme.onSecondary.withOpacity(.3),
                    context.theme.colorScheme.onSecondary.withOpacity(.2),
                  ],
                ),
              ),
            ),
          if (settings.enableMiniplayerParticles.value)
            ObxO(
              rx: Player.inst.isPlaying,
              builder: (playing) => AnimatedOpacity(
                duration: const Duration(seconds: 1),
                opacity: playing ? 1 : 0,
                child: ObxO(
                  rx: Player.inst.nowPlayingPosition,
                  builder: (nowPlayingPosition) {
                    final scale = WaveformController.inst.getCurrentAnimatingScale(nowPlayingPosition);
                    final bpm = (2000 * scale).withMinimum(0);
                    return AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: 1.0 + scale * 1.5,
                      child: AnimatedBackground(
                        vsync: this,
                        behaviour: RandomParticleBehaviour(
                          options: ParticleOptions(
                            baseColor: context.theme.colorScheme.tertiary,
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
