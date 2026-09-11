// ignore_for_file: unused_element, unused_element_parameter
// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Selectable;

import 'package:playlist_manager/class/favourite_playlist.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/extensions.dart' show StreamFilterVideoUtils, CodecInfoUtils;

import 'package:namida/base/audio_handler.dart';
import 'package:namida/base/yt_video_like_manager.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/focused_menu.dart';
import 'package:namida/packages/miniplayer_raw.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/pages/equalizer_page.dart';
import 'package:namida/ui/pages/wide_screen_player_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/creative_animations.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';
import 'package:namida/ui/widgets/simple_lyrics_line.dart';
import 'package:namida/ui/widgets/waveform.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

class FocusedMenuOptions {
  final void Function(Playable currentItem) onPressed;
  final Widget Function(Playable currentItem, double size, Color color) videoIconBuilder;
  final Widget Function(Playable currentItem) builder;
  final RxList<NamidaVideo> localVideos;
  final String? Function(Playable item) currentId;
  final Rxn<VideoStreamsResult> streams;
  final bool Function(VideoStream stream, File? cacheFile) isStreamSelected;
  final Rxn<VideoStream>? downloadingStream;
  final Rxn<int>? downloadedBytes;
  final Future<void> Function(Playable item)? loadQualities;
  final void Function(Playable item)? onSearch;
  final Future<void> Function(Playable item, NamidaVideo video) onLocalVideoTap;
  final Future<void> Function(Playable item, String? videoId, VideoStream stream, File? cacheFile, VideoStreamsResult? mainStreams) onStreamVideoTap;

  const FocusedMenuOptions({
    required this.onPressed,
    required this.videoIconBuilder,
    required this.builder,
    required this.currentId,
    required this.localVideos,
    required this.streams,
    required this.isStreamSelected,
    required this.downloadingStream,
    required this.downloadedBytes,
    required this.loadQualities,
    required this.onSearch,
    required this.onLocalVideoTap,
    required this.onStreamVideoTap,
  });
}

abstract class MiniplayerThumbnailScale {
  static const _base = 1.13;
  static const _baseInversed = 1.22;

  static double resolve({required double additional, required bool isInversed, required double userScaleMultiplier}) {
    return (isInversed ? _baseInversed - additional : _base + additional) * userScaleMultiplier;
  }

  /// the constant part of [resolve], for layouts that need to reserve room for it.
  static double resolveBase({required bool isInversed, required double userScaleMultiplier}) {
    return (isInversed ? _baseInversed : _base) * userScaleMultiplier;
  }
}

class MiniplayerInfoData<E, S> {
  final String firstLine;
  final String secondLine;
  final FavouritePlaylist<Playable, E, S> favouritePlaylist;
  final E itemToLike;
  final Future<bool> Function(bool isLiked) onLikeTap;
  final void Function() onShowAddToPlaylistDialog;
  final void Function(TapUpDetails details) onMenuOpen;
  final void Function() onTextLongTap;
  final bool enableTextLongTap;
  final IconData likedIcon;
  final IconData normalIcon;
  final YtVideoLikeManager? ytLikeManager;

  late final bool firstLineGood;
  late final bool secondLineGood;

  MiniplayerInfoData({
    required this.firstLine,
    required this.secondLine,
    required this.favouritePlaylist,
    required this.itemToLike,
    required this.onLikeTap,
    required this.onShowAddToPlaylistDialog,
    required this.onMenuOpen,
    required this.onTextLongTap,
    this.enableTextLongTap = false,
    required this.likedIcon,
    required this.normalIcon,
    this.ytLikeManager,
  }) : firstLineGood = firstLine.isNotEmpty,
       secondLineGood = secondLine.isNotEmpty;
}

class NamidaMiniPlayerBase<E, S> extends StatefulWidget {
  final double? queueItemExtent;
  final double? Function(Playable item)? queueItemExtentBuilder;
  final (Widget, Key) Function(BuildContext context, int index, List<Playable> queue, TrackTileProperties? properties, VideoTileProperties? videoTileProperties) itemBuilder;
  final int Function(Playable currentItem)? getDurationMS;
  final String Function(int number, Playable item) itemsKeyword;
  final void Function(Playable currentItem) onAddItemsTap;
  final String Function(Playable currentItem) topText;
  final void Function(Playable currentItem) onTopTextTap;
  final void Function(Playable currentItem, TapUpDetails details) onMenuOpen;
  final FocusedMenuOptions Function(Playable item) focusedMenuOptions;
  final Widget Function(Playable item) imageBuilder;
  final Widget Function(Playable item, ValueListenable<double> maxWidth) currentImageBuilder;
  final MiniplayerInfoData<E, S> Function(Playable item) textBuilder;
  final bool Function(Playable item) canShowBuffering;
  final TrackTilePropertiesConfigs? trackTileConfigs;
  final VideoTilePropertiesConfigs? videoTileConfigs;

  const NamidaMiniPlayerBase({
    super.key,
    required this.queueItemExtent,
    this.queueItemExtentBuilder,
    required this.itemBuilder,
    required this.getDurationMS,
    required this.itemsKeyword,
    required this.onAddItemsTap,
    required this.topText,
    required this.onTopTextTap,
    required this.onMenuOpen,
    required this.focusedMenuOptions,
    required this.imageBuilder,
    required this.currentImageBuilder,
    required this.textBuilder,
    required this.canShowBuffering,
    this.trackTileConfigs,
    this.videoTileConfigs,
  });

  @override
  State<NamidaMiniPlayerBase<E, S>> createState() => _NamidaMiniPlayerBaseState<E, S>();

  static final clampedAnimationCP = _createClampedAnimation();
  static final clampedAnimationBCP = _createClampedAnimation2();

  static Animation<double> _createOpacityAnimation(Animatable<double> animateable) {
    return MiniPlayerController.inst.animation.drive(animateable);
  }

  static Animation<double> _createClampedAnimation() {
    return NamidaMiniPlayerBase._createOpacityAnimation(
      Animatable.fromCallback(
        (p) {
          final double cp = p.clampDouble(0.0, 1.0);
          return cp;
        },
      ),
    );
  }

  static Animation<double> _createClampedAnimation2() {
    return _createOpacityAnimationV1((bcp) => bcp);
  }

  static Animation<double> _createOpacityAnimationV1(double Function(double bcp) transform) {
    return NamidaMiniPlayerBase._createOpacityAnimation(
      Animatable.fromCallback(
        (p) {
          final bounceUp = MiniPlayerController.inst.bounceUp;
          final bounceDown = MiniPlayerController.inst.bounceDown;
          final double rp = inverseAboveOne(p);
          final double bp = !bounceUp
              ? !bounceDown
                    ? rp
                    : 1 - (p - 1)
              : p;
          final double bcp = bp.clampDouble(0.0, 1.0);
          return transform(bcp);
        },
      ),
    );
  }

  static Animation<double> _createOpacityAnimationV2(double Function(double cp) transform) {
    return NamidaMiniPlayerBase._createOpacityAnimation(
      Animatable.fromCallback(
        (p) {
          final double cp = p.clampDouble(0.0, 1.0);
          return transform(cp);
        },
      ),
    );
  }

  static Animation<double> _createOpacityAnimationV3(double Function(double rcp, double qcp) transform) {
    return NamidaMiniPlayerBase._createOpacityAnimation(
      Animatable.fromCallback(
        (p) {
          final double rp = inverseAboveOne(p);
          final double rcp = rp.clampDouble(0, 1);

          final double qp = p.clampDouble(1.0, 3.0) - 1.0;
          final double qcp = qp.clampDouble(0.0, 1.0);

          return transform(rcp, qcp);
        },
      ),
    );
  }

  static Widget getLrcButton(ThemeData theme, {required double iconSize, Color? color}) {
    color ??= theme.colorScheme.onSecondaryContainer;
    return Obx(
      (context) => settings.enableLyrics.valueR
          ? Lyrics.inst.currentLyricsText.valueR.text == '' && Lyrics.inst.currentLyricsLRC.valueR == null
                ? StackedIcon(
                    margin: 0.0,
                    baseIcon: Broken.document,
                    secondaryText: !Lyrics.inst.lyricsCanBeAvailable.valueR ? 'x' : '?',
                    iconSize: iconSize,
                    blurRadius: 6.0,
                    baseIconColor: color,
                    secondaryIconColor: color,
                  )
                : Icon(
                    Broken.document,
                    size: iconSize,
                    color: color,
                  )
          : Icon(
              Broken.card_slash,
              size: iconSize,
              color: color,
            ),
    );
  }
}

class _NamidaMiniPlayerBaseState<E, S> extends State<NamidaMiniPlayerBase<E, S>> {
  final isMenuOpened = false.obs;
  static const animationDuration = Duration(milliseconds: 150);

  final _currentImageMaxWidth = ValueNotifier<double>(0.0);

  /// used to skip implicit decoration animations while the miniplayer itself is animating.
  double _lastAnimationP = 0.0;

  Playable<Object> get _getcurrentItem => Player.inst.currentQueue.value[Player.inst.currentIndex.value];

  /// what the last build used, the cache listener only rebuilds when it changes.
  double? _lastArtworkAspectRatio;

  void _artworkAspectRatiosListener() {
    final item = Player.inst.currentItem.value;
    if (item == null) return;
    final ratio = ArtworkWidget.aspectRatioOf(playableArtworkCacheKey(item));
    if (ratio == null || ratio == _lastArtworkAspectRatio) return;
    refreshState();
  }

  @override
  void initState() {
    super.initState();
    MiniPlayerController.inst.screenValuesVersion.addListener(_screenValuesListener);
    ArtworkWidget.aspectRatiosVersion.addListener(_artworkAspectRatiosListener);

    // -- fix screen touch absorb when minimized, usually happens when switching from yt style to this
    MiniPlayerController.inst.verticalSnapping();
  }

  @override
  void dispose() {
    isMenuOpened.close();
    _currentImageMaxWidth.dispose();
    MiniPlayerController.inst.screenValuesVersion.removeListener(_screenValuesListener);
    ArtworkWidget.aspectRatiosVersion.removeListener(_artworkAspectRatiosListener);
    super.dispose();
  }

  void _screenValuesListener() {
    refreshState();
  }

  Widget _queueItemBuilder(
    BuildContext context,
    int i,
    List<Playable> queue, {
    TrackTileProperties? trackTileProperties,
    VideoTileProperties? videoTileProperties,
  }) {
    final childWK = widget.itemBuilder(context, i, queue, trackTileProperties, videoTileProperties);
    return FadeDismissible(
      key: Key("Diss_${i}_${childWK.$2}_${queue.length}"), // queue length only for when removing current item and next is the same.
      onDismissed: (direction) async {
        await Player.inst.removeFromQueueWithUndo(i);
        Player.inst.invokeQueueModifyLockRelease();
      },
      onDismissStart: (_) => Player.inst.invokeQueueModifyLock(),
      onDismissCancel: (_) => Player.inst.invokeQueueModifyOnModifyCancel(),
      child: childWK.$1,
    );
  }

  void _playPauseTapInitializer(TapGestureRecognizer instance) {
    instance.onTap = Player.inst.togglePlayPause;
    instance.onTapDown = (_) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = true;
    instance.onTapUp = (_) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = false;
    instance.onTapCancel = () => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = !MiniPlayerController.inst.isPlayPauseButtonHighlighted.value;
    instance.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
  }

  static AnimationController get getsAnim => MiniPlayerController.inst.sAnim;

  final leftOpacityAnim = Tween<double>(
    begin: 0.0,
    end: -1.0,
  ).animate(getsAnim);

  final rightOpacityAnim = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(getsAnim);

  final centerItemFadeAnimation = getsAnim.drive(
    Animatable.fromCallback((value) => 1 - value.abs()),
  );

  final slowOpacityAnimation = NamidaMiniPlayerBase._createOpacityAnimationV1(
    (bcp) => (bcp * 4 - 3).clampDouble(0, 1),
  );
  final opacityAnimation = NamidaMiniPlayerBase._createOpacityAnimationV1(
    (bcp) => (bcp * 5 - 4).clampDouble(0, 1),
  );
  final fastOpacityAnimation = NamidaMiniPlayerBase._createOpacityAnimationV1(
    (bcp) => (bcp * 10 - 9).clampDouble(0, 1),
  );

  final partyContainersOpacityAnimation = NamidaMiniPlayerBase.clampedAnimationCP;

  final topRowOpacityAnimation = NamidaMiniPlayerBase._createOpacityAnimationV3(
    (rcp, _) => rcp,
  );

  final progressBarOpacityAnimation = NamidaMiniPlayerBase._createOpacityAnimationV2(
    (cp) => 1 - cp,
  );

  final queueInverseOpacityAnimation = NamidaMiniPlayerBase._createOpacityAnimationV3(
    (_, qcp) => 1.0 - qcp,
  );

  late final simpleLyricsOpacityAnimation = _AnimationProduct(fastOpacityAnimation, centerItemFadeAnimation);

  final playPauseBoxScaleAnimation = MiniPlayerController.inst.animation.drive(
    Animatable.fromCallback(
      (p) => _PlayPauseMetrics.boxSize(_PlayPauseMetrics.iconSize(p)) / _PlayPauseMetrics.maxBoxSize,
    ),
  );

  final playPauseIconScaleAnimation = MiniPlayerController.inst.animation.drive(
    Animatable.fromCallback(
      (p) {
        final iconSize = _PlayPauseMetrics.iconSize(p);
        final boxScale = _PlayPauseMetrics.boxSize(iconSize) / _PlayPauseMetrics.maxBoxSize;
        return iconSize / (_PlayPauseMetrics.maxIconSize * boxScale);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final sAnim = getsAnim;

    final kStParallax = MiniPlayerController.kStParallax;
    final kSiParallax = MiniPlayerController.kSiParallax;

    final onSecondary = theme.colorScheme.onSecondaryContainer;
    const waveformChild = RepaintBoundary(child: WaveformMiniplayer());
    const seekReadyWidget = SeekReadyWidget(
      isLocal: true,
      isFullscreen: false,
      showSponsorBlockSegments: false,
      showBufferBars: false,
      clampCircleEdges: false,
      useReducedProgressColor: true,
    );

    final topBottomMargin = 8.0;

    final topRightButton = _TopActionButton(
      icon: Broken.more,
      iconColor: onSecondary,
      bgColor: theme.colorScheme.secondary.withOpacityExt(.2),
      onTapUp: (details) => widget.onMenuOpen(_getcurrentItem, details),
    );

    final topLeftButton = _TopActionButton(
      icon: Broken.arrow_down_2,
      onTapUp: (_) => MiniPlayerController.inst.snapToMini(),
      iconColor: onSecondary,
      bgColor: null,
    );

    late final topWideScreenButton = _TopActionButton(
      icon: Broken.maximize_3,
      onTapUp: (_) => NamidaNavigator.inst.navigateToRoot(
        const WideScreenPlayerPage(),
        transition: Transition.fade,
      ),
      iconColor: onSecondary,
      bgColor: null,
    );

    const partyContainersChild = RepaintBoundary(
      child: Stack(
        children: [
          NamidaPartyContainer(
            height: 2,
            spreadRadiusMultiplier: 0.8,
          ),
          NamidaPartyContainer(
            width: 2,
            spreadRadiusMultiplier: 0.25,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: NamidaPartyContainer(
              height: 2,
              spreadRadiusMultiplier: 0.8,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: NamidaPartyContainer(
              width: 2,
              spreadRadiusMultiplier: 0.25,
            ),
          ),
        ],
      ),
    );

    final seekPositionTextChild = ObxO(
      rx: MiniPlayerController.inst.seekValue,
      builder: (context, seekNull) => ObxO(
        rx: Player.inst.nowPlayingPosition,
        builder: (context, nowPlayingPosition) => NamidaAnimatedSwitcher(
          key: const ValueKey('seek_switcher'),
          firstChild: Obx(
            (context) {
              final seek = seekNull ?? 0;
              String finalText;
              if (settings.player.displayActualPositionWhenSeeking.value) {
                final itemDur = Player.inst.currentItemDuration.value?.inMilliseconds;
                int seekClamped = seek;
                seekClamped = seekClamped.withMinimum(0);
                if (itemDur != null) seekClamped = seekClamped.withMaximum(itemDur);
                finalText = seekClamped.milliSecondsLabel;
              } else {
                final diffInMs = seek - nowPlayingPosition;
                final plusOrMinus = diffInMs < 0 ? '' : '+';
                final seekText = diffInMs.milliSecondsLabel;
                finalText = "$plusOrMinus$seekText";
              }
              return Text(
                finalText,
                style: textTheme.displaySmall?.copyWith(fontSize: 13.0),
              );
            },
          ),
          secondChild: const SizedBox(),
          showFirst: seekNull != null,
          durationMS: 700,
          allCurves: Curves.easeInOutQuart,
        ),
      ),
    );

    final positionTextChild = SeekBackwardsDetectorWidget(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: ObxO(
          rx: Player.inst.nowPlayingPosition,
          builder: (context, nowPlayingPosition) => Text(
            nowPlayingPosition.milliSecondsLabel,
            style: textTheme.displaySmall?.copyWith(fontSize: 13.0),
          ),
        ),
      ),
    );

    final positionDurationSeekerBoxesRowChild = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SeekBackwardsDetectorWidget(
          child: SizedBox(
            width: 54.0,
            height: 48.0,
          ),
        ),
        SeekForwardDetectorWidget(
          child: SizedBox(
            width: 54.0,
            height: 48.0,
          ),
        ),
      ],
    );

    final buttonsRowChild = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (widget.videoTileConfigs != null && settings.extra.ytStyleButtonSwitcher == true)
          MPCustomIconButton(
            tooltipCallback: () => lang.youtubeStyleMiniplayer,
            onPressed: () {
              MiniPlayerController.inst.snapToMini(haptic: false);
              NamidaYTMiniplayer.setInitialExpanded(true);

              settings.youtube.save(youtubeStyleMiniplayer: true);

              Timer(
                const Duration(milliseconds: 100),
                () {
                  final ytMiniplayer = MiniPlayerController.inst.ytMiniplayerKey.currentState;
                  if (ytMiniplayer != null && ytMiniplayer.isExpanded == false) ytMiniplayer.animateToState(true, dur: const Duration(milliseconds: 200));
                },
              );
            },
            sizeRaw: 19.0,
            icon: Icon(
              Broken.video_octagon,
              size: 19.0,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        RepeatModeIconButton(
          iconSize: MPCustomIconButton.defaultIconSize,
          builder: (child, tooltipCallback, onTap) => MPCustomIconButton(
            icon: child,
            tooltipCallback: tooltipCallback,
            onPressed: onTap,
          ),
        ),
        SoundControlButton(
          iconSize: 21.0,
          builder: (child, tooltipCallback, onTap) => MPCustomIconButton(
            icon: child,
            tooltipCallback: tooltipCallback,
            onPressed: onTap,
          ),
        ),
        LongPressDetector(
          enableSecondaryTap: true,
          onLongPress: () {
            showLRCSetDialog(_getcurrentItem, CurrentColor.inst.miniplayerColor);
          },
          child: MPCustomIconButton(
            tooltipCallback: null,
            onPressed: <T extends Playable>() {
              settings.save(enableLyrics: !settings.enableLyrics.value);
              Lyrics.inst.updateLyrics(_getcurrentItem);
            },
            icon: NamidaMiniPlayerBase.getLrcButton(
              theme,
              iconSize: MPCustomIconButton.defaultIconSize,
            ),
          ),
        ),
        MPCustomIconButton(
          tooltipCallback: () => lang.queue,
          onPressed: MiniPlayerController.inst.snapToQueue,
          sizeRaw: 19.0,
          icon: Icon(
            Broken.row_vertical,
            size: 19.0,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 6.0),
      ],
    );

    final maxQueueHeight = MiniPlayerController.inst.maxOffset - 100.0 - MiniPlayerController.inst.topInset - 12.0;

    final colorScheme = CurrentColor.inst.color;
    final scaffoldBgColor = Color.alphaBlend(context.theme.scaffoldBackgroundColor.withOpacityExt(0.5), context.isDarkMode ? Colors.black : Colors.white);

    Widget queueListChild;
    if (widget.trackTileConfigs != null) {
      queueListChild = TrackTilePropertiesProvider(
        configs: widget.trackTileConfigs!,
        builder: (properties) => Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(scaffoldBgColor.withOpacityExt(0.90), colorScheme).withOpacityExt(0.5),
                    Color.alphaBlend(scaffoldBgColor.withOpacityExt(0.65), colorScheme).withOpacityExt(0.5),
                  ],
                ),
              ),
              child: LocalQueueChipHeaderRow(
                addLeftMargin: true,
                onArrowDownPressed: MiniPlayerController.inst.snapToExpanded,
              ),
            ),
            Expanded(
              child: _QueueListChildWrapper(
                queueItemExtent: widget.queueItemExtent,
                queueItemExtentBuilder: widget.queueItemExtentBuilder,
                itemBuilder: (context, index, queue) => _queueItemBuilder(context, index, queue, trackTileProperties: properties, videoTileProperties: null),
              ),
            ),
          ],
        ),
      );
    } else if (widget.videoTileConfigs != null) {
      queueListChild = VideoTilePropertiesProvider(
        configs: widget.videoTileConfigs!,
        builder: (properties) => Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(scaffoldBgColor.withOpacityExt(0.90), colorScheme).withOpacityExt(0.5),
                    Color.alphaBlend(scaffoldBgColor.withOpacityExt(0.65), colorScheme).withOpacityExt(0.5),
                  ],
                ),
              ),
              child: YTQueueChipHeaderRow(
                addLeftMargin: true,
                onArrowDownPressed: MiniPlayerController.inst.snapToExpanded,
              ),
            ),
            Expanded(
              child: _QueueListChildWrapper(
                queueItemExtent: widget.queueItemExtent,
                queueItemExtentBuilder: widget.queueItemExtentBuilder,
                itemBuilder: (context, index, queue) => _queueItemBuilder(context, index, queue, trackTileProperties: null, videoTileProperties: properties),
              ),
            ),
          ],
        ),
      );
    } else {
      queueListChild = _QueueListChildWrapper(
        queueItemExtent: widget.queueItemExtent,
        queueItemExtentBuilder: widget.queueItemExtentBuilder,
        itemBuilder: _queueItemBuilder,
      );
    }
    final queueChild = RepaintBoundary(
      child: SafeArea(
        bottom: false,
        // -- built here but rendered inside the scale box, so it has to be sized by the
        // -- player's own virtual space, this context's MediaQuery is the real panel.
        child: SizedBox.fromSize(
          size: MiniPlayerController.inst.screenSize,
          child: Stack(
            fit: StackFit.loose,
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: maxQueueHeight,
                child: BorderRadiusClip(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.0.multipliedRadius),
                    topRight: Radius.circular(32.0.multipliedRadius),
                  ),
                  child: queueListChild,
                ),
              ),
              Container(
                width: MiniPlayerController.inst.screenSize.width,
                height: kQueueBottomRowHeight + MediaQuery.paddingOf(context).bottom,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(12.0.multipliedRadius),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0).add(EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: QueueUtilsRow(
                      itemsKeyword: (number) => widget.itemsKeyword(number, _getcurrentItem),
                      onAddItemsTap: () => widget.onAddItemsTap(_getcurrentItem),
                      scrollQueueWidget: ObxO(
                        rx: MiniPlayerController.inst.arrowIcon,
                        builder: (context, arrow) => NamidaButton(
                          tooltip: () => lang.jump,
                          onTap: MiniPlayerController.inst.animateQueueToCurrentTrack,
                          icon: arrow,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ObxO(
      rx: Player.inst.currentQueue,
      builder: (context, queue) {
        if (queue.isEmpty) return const SizedBox();
        return Obx(
          (context) {
            // -- animation index is for items animating, they use frozen index until animation is done
            // -- real index is to update text instantly, use for parts that has no swipe animation
            final currentIndexReal = Player.inst.currentIndex.valueR;
            final int currentIndexAnimationUI;
            final int indminusAnimationUI;
            final int indplusAnimationUI;
            final override = MiniPlayerController.inst.displayIndicesOverride.valueR;
            if (override != null && override.isValidFor(queue.length)) {
              currentIndexAnimationUI = override.current;
              indminusAnimationUI = override.prev;
              indplusAnimationUI = override.next;
            } else {
              // -- queue changed while frozen, or nothing in flight
              currentIndexAnimationUI = currentIndexReal;
              indminusAnimationUI = Player.inst.previousIndexFor(currentIndexReal);
              indplusAnimationUI = Player.inst.nextIndexFor(currentIndexReal);
            }
            final currentItem = queue[currentIndexReal];
            final currentItemAnimationUI = queue[currentIndexAnimationUI];
            final currentDefaultDurationInMS = widget.getDurationMS?.call(currentItem) ?? 0;

            final videoInfo = Player.inst.videoPlayerInfo.valueR;
            final imageAspectRatio = resolvePlayableImageAspectRatio(currentItem, videoInfo != null && videoInfo.isInitialized ? videoInfo.aspectRatio : null);
            _lastArtworkAspectRatio = ArtworkWidget.aspectRatioOf(playableArtworkCacheKey(currentItem));

            Widget? previousImageWidget;
            Widget? nextImageWidget;
            MiniplayerInfoData? prevText;
            MiniplayerInfoData? nextText;

            if (queue.isNotEmpty) {
              final prevItem = queue[indminusAnimationUI];
              final nextItem = queue[indplusAnimationUI];

              prevText = widget.textBuilder(prevItem);
              nextText = widget.textBuilder(nextItem);

              previousImageWidget = widget.imageBuilder(prevItem);
              nextImageWidget = widget.imageBuilder(nextItem);
            }

            final currentText = widget.textBuilder(currentItemAnimationUI);

            Widget currentImage = widget.currentImageBuilder(
              currentItemAnimationUI,
              _currentImageMaxWidth,
            );

            if (settings.artworkTapAction.valueR != TrackExecuteActions.none) {
              currentImage = TapDetector(
                onTap: () => settings.artworkTapAction.value.executePlayingItem(currentItemAnimationUI),
                child: currentImage,
              );
            }

            currentImage = LongPressDetector(
              onLongPress: () {
                final lrcState = Lyrics.inst.lrcViewKey.currentState;
                if (lrcState != null) {
                  lrcState.enterFullScreen();
                  return;
                }
                final longPressAction = settings.artworkLongPressAction.value;
                if (longPressAction != TrackExecuteActions.none) {
                  longPressAction.executePlayingItem(currentItemAnimationUI);
                }
              },
              child: currentImage,
            );

            final topText = widget.topText(currentItem);
            final focusedMenuOptions = widget.focusedMenuOptions(currentItem);

            final playPauseButton = _PlayPauseButton(
              canShowBuffering: widget.canShowBuffering(currentItem),
              iconScaleAnimation: playPauseIconScaleAnimation,
              tapInitializer: _playPauseTapInitializer,
            );

            final topRowChild = Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: topBottomMargin),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Dimensions.inst.miniplayerIsWideScreen ? topWideScreenButton : topLeftButton,
                  Expanded(
                    child: NamidaInkWell(
                      borderRadius: 14.0,
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      onTap: () => widget.onTopTextTap(_getcurrentItem),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${currentIndexReal + 1}/${queue.length}",
                            style: TextStyle(
                              color: onSecondary.withOpacityExt(.8),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            topText,
                            textAlign: TextAlign.center,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.0,
                              color: onSecondary.withOpacityExt(.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  topRightButton,
                ],
              ),
            );

            final positionDurationRowChild = Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                positionTextChild,
                SeekForwardDetectorWidget(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: NamidaHero(
                      tag: 'MINIPLAYER_DURATION',
                      child: Obx(
                        (context) {
                          int toSubtract = 0;
                          String prefix = '';
                          if (settings.player.displayRemainingDurInsteadOfTotal.valueR) {
                            toSubtract = Player.inst.nowPlayingPositionR;
                            prefix = '-';
                          }
                          final currentDurationInMS = currentDefaultDurationInMS > 0 ? currentDefaultDurationInMS : Player.inst.currentItemDuration.valueR?.inMilliseconds ?? 0;
                          final msToDisplay = currentDurationInMS - toSubtract;
                          return Text(
                            "$prefix ${msToDisplay.milliSecondsLabel}",
                            style: textTheme.displaySmall?.copyWith(fontSize: 13.0),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );

            final bottomLeftButton = Expanded(
              child: PlayerVideoAudioChip(
                focusedMenuOptions: focusedMenuOptions,
                currentItem: currentItem,
                isMenuOpened: isMenuOpened,
                animationDuration: animationDuration,
              ),
            );

            final bottomRowChild = Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: topBottomMargin),
              child: Row(
                children: [
                  bottomLeftButton,
                  buttonsRowChild,
                ],
              ),
            );

            // final smolProgressBarDecoratedBox = Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
            //   child: AnimatedDecoration(
            //     duration: const Duration(milliseconds: kThemeAnimationDurationMS),
            //     decoration: BoxDecoration(
            //       color: CurrentColor.inst.miniplayerColor,
            //       borderRadius: BorderRadius.circular(50),
            //       //  color: Color.alphaBlend(theme.colorScheme.onSurface.withAlpha(40), CurrentColor.inst.miniplayerColor)
            //       //   .withOpacityExt(velpy(a: .3, b: .22, c: icp)),
            //     ),
            //   ),
            // );

            return MiniplayerRaw(
              builder:
                  (
                    maxOffset,
                    bounceUp,
                    bounceDown,
                    topInset,
                    bottomInset,
                    rightInset,
                    screenSize,
                    sMaxOffset,
                    p,
                    cp,
                    ip,
                    icp,
                    rp,
                    rcp,
                    qp,
                    qcp,
                    bp,
                    bcp,
                    miniplayerbottomnavheight,
                    bottomOffset,
                    navBarHeight,
                  ) {
                    final BorderRadius borderRadius = BorderRadius.vertical(
                      top: Radius.circular(20.0.multipliedRadius + 6.0 * p),
                      bottom: Radius.circular(20.0.multipliedRadius * (1 - p * 10 + 9).clampDouble(0, 1)),
                    );
                    final shadowBorderRadius = BorderRadius.circular(20.0.multipliedRadius);

                    final waveformYScale = maxOffset < _perfectHeight ? (maxOffset / _perfectHeight * 0.9) : 1.0;

                    final panelH = (maxOffset + navBarHeight - (100.0 + topInset + 4.0) * qp);
                    final panelExtra = panelH / 2.4 - (100.0 + topInset + 4.0) * qp;
                    // final panelExtra = panelH; // -- use if u want to hide it while expanded, looks cool
                    final panelFinal = panelH - (panelExtra * (1 - qcp));

                    final iconSize = _PlayPauseMetrics.iconSize(p);
                    final iconButtonExtraPadding = _PlayPauseMetrics.extraPadding(iconSize);
                    final iconBoxSize = iconSize + iconButtonExtraPadding * 2;

                    final nextprevmultiplier = ((inverseAboveOne(p - 2.0) + 3.0) * (1 - qp)) - 1;
                    final nextPrevIconSize = (21.0 + 11.0 * nextprevmultiplier);
                    final nextPrevIconPadding = (8.0 + 4.0 * cp + 6.0 * nextprevmultiplier);

                    final totalButtonsSize = (iconSize + iconButtonExtraPadding * 2) + (nextPrevIconSize + nextPrevIconPadding * 2) * 2;
                    final buttonsRightPadding = (cp * rcp * ((screenSize.width - totalButtonsSize) / 2)) - rightInset;

                    // -- the vertical layout is designed at [_perfectHeight] and stretches with the panel,
                    // -- shrinking is covered by the scale box but taller panels still spread these out.
                    final heightFactor = _lerpDouble(1.0, maxOffset / _perfectHeight, rp);

                    final topRowHeight = 1.25 * (32.0 * heightFactor + topBottomMargin * 2) * cp;
                    final bottomRowHeight = topRowHeight;
                    final imageWidth = velpy(a: 82.0, b: 92.0, c: qp);

                    final vOffsetExtras = (bottomOffset * (1 - bcp) + ((-maxOffset + topInset + 100.0 + 12.0 * 2 - 4.0) * qp)) - (navBarHeight * cp);
                    final vOffsetExtrasAlt = (bottomOffset * (1 - bcp) + ((-maxOffset + topInset + 100.0 - 8.0 * 2 - 4.0) * qp)) - (navBarHeight * cp);
                    final trackInfoBoxHeight = velpy(a: 58.0, b: 82.0, c: bcp);
                    double vOffsetControls = vOffsetExtrasAlt - bottomRowHeight * bp /* ?? vOffsetExtras + (-bottomRowHeight - 4.0 * bp) * (1 - qp) */;
                    double vOffsetWaveform = vOffsetControls - iconSize - (64.0 * waveformYScale) / 2 - (panelFinal * 0.026);
                    vOffsetWaveform = vOffsetWaveform.withMaximum(-(maxOffset - bottomInset - topInset) * 0.2 * (1 - bcp));

                    double vOffsetTrackInfo = _lerpDouble(
                      _lerpDouble(
                        vOffsetExtras,
                        -maxOffset + imageWidth / 2 + topInset + 100.0 / 2 + 12.0 * heightFactor, // idk bro this the only way it matches :/
                        qp,
                      ),
                      (vOffsetWaveform - 64.0 * waveformYScale).withMaximum(-(maxOffset - bottomInset - topInset) * 0.3), // don't ask why topInset.. it works like that idk
                      bcp,
                    );
                    double vOffsetImage = (vOffsetTrackInfo - (trackInfoBoxHeight * bcp) - 16.0 * heightFactor * bcp) + (6.0 * heightFactor * qp);

                    // -- the picture is painted 1.13x past its box, so the side margin has to grow with the
                    // -- width, a fixed one only holds the overshoot inside the panel up to ~380 wide.
                    final imageMaxWidthPre = sMaxOffset - (sMaxOffset * 0.2).withMinimum(76.0);
                    final imageMaxHeightPre = maxOffset - -vOffsetImage - topRowHeight - topInset - 24.0 * heightFactor;
                    // -- the box follows the picture's ratio, so wide videos/thumbnails use the width
                    // -- instead of shrinking to whatever square fits the height.
                    final imageWidthBig = imageMaxWidthPre.withMaximum(imageMaxHeightPre * imageAspectRatio);
                    final imageHeightBig = imageWidthBig / imageAspectRatio;

                    // -- collapsed thumbnail stays square, the ratio only kicks in while expanding.
                    final imageBoxWidth = velpy(a: imageWidth, b: imageWidthBig, c: bcp);
                    final imageBoxHeight = velpy(a: imageWidth, b: imageHeightBig, c: bcp);
                    final trackInfoLeftMargin = imageWidth * (1 - bcp);

                    double spaceLeftAboveImage = maxOffset - -vOffsetImage - imageBoxHeight - topInset - topRowHeight;
                    if (spaceLeftAboveImage > 0) {
                      final spaceLeftInPanelAboveInfo = (panelFinal - -vOffsetTrackInfo - trackInfoBoxHeight); // dont remove too much that it goes above panel
                      final valueToRemove = ((spaceLeftInPanelAboveInfo * 0.5).withMaximum(spaceLeftAboveImage * 0.5)) * bcp;
                      vOffsetImage -= valueToRemove; // re-adjust offset to make the image semi-centered
                    } else {
                      vOffsetImage += (-spaceLeftAboveImage / 2) * bcp;
                    }

                    // -- image related
                    final imagePaddingAll = 12.0 * (1 - bcp);
                    final imagePadding = EdgeInsets.fromLTRB(
                      imagePaddingAll + 42.0 * bcp,
                      imagePaddingAll,
                      imagePaddingAll,
                      imagePaddingAll,
                    );
                    final imageEmptyRightSpace = screenSize.width - imageBoxWidth;
                    final imageLeftOffset = (((imageEmptyRightSpace / 2) - imagePadding.left - rightInset) * bcp);

                    _currentImageMaxWidth.value = imageWidthBig;

                    final animateDecoration = p == _lastAnimationP;
                    _lastAnimationP = p;

                    return Stack(
                      children: [
                        /// MiniPlayer Body
                        Container(
                          color: p > 0 ? Colors.transparent : null, // hit test only when expanded
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Transform.translate(
                              offset: Offset(0, bottomOffset),
                              child: ColoredBox(
                                color: Colors.transparent, // prevents scrolling gap
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.0 * (1 - cp * 10 + 9).clampDouble(0, 1), vertical: 12.0 * icp),
                                  child: SizedBox(
                                    height: velpy(a: 82.0, b: panelFinal, c: cp),
                                    width: double.infinity,
                                    // -- shadow kept apart with a fixed uniform radius: skia caches the blur as a nine-patch keyed
                                    // -- by (radius, sigma) so resizing the panel per frame stays a cache hit, an animated radius wouldn't.
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: shadowBorderRadius,
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.shadowColor.withOpacityExt(0.2 + 0.1 * cp),
                                            blurRadius: 20.0,
                                          ),
                                        ],
                                      ),
                                      child: _AnimatedDecorationOrDecoration(
                                        animate: animateDecoration,
                                        duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                        decoration: BoxDecoration(
                                          color: theme.scaffoldBackgroundColor,
                                          borderRadius: borderRadius,
                                        ),
                                        child: Stack(
                                          alignment: Alignment.bottomLeft,
                                          children: [
                                            Positioned.fill(
                                              child: _AnimatedDecorationOrDecoration(
                                                animate: animateDecoration,
                                                duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                                // clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  color: CurrentColor.inst.miniplayerColor,
                                                  borderRadius: borderRadius,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Color.alphaBlend(
                                                        theme.colorScheme.onSurface.withAlpha(100),
                                                        CurrentColor.inst.miniplayerColor,
                                                      ).withOpacityExt(velpy(a: .38, b: .28, c: icp)),
                                                      Color.alphaBlend(
                                                        theme.colorScheme.onSurface.withAlpha(40),
                                                        CurrentColor.inst.miniplayerColor,
                                                      ).withOpacityExt(velpy(a: .1, b: .22, c: icp)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),

                                            if (NamidaJellys.enabled)
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius: borderRadius,
                                                  child: NamidaJellyBackground(
                                                    count: 4,
                                                    opacity: 0.3 * cp,
                                                    minHeight: 70.0,
                                                    maxHeight: 210.0,
                                                    reactToPlayback: true,
                                                    enabled: cp > 0.01,
                                                    seed: 7,
                                                  ),
                                                ),
                                              ),

                                            /// Smol progress bar
                                            // Obx(
                                            //   (context) {
                                            //     final nowPlayingPosition = Player.inst.nowPlayingPosition.valueR;
                                            //     final currentDurationInMS =
                                            //         currentDefaultDurationInMS > 0 ? currentDefaultDurationInMS : Player.inst.currentItemDuration.valueR?.inMilliseconds ?? 0;
                                            //     final w = currentDurationInMS > 0 ? nowPlayingPosition / currentDurationInMS : 0;
                                            //     return SizedBox(
                                            //       height: 2 * (1 - cp),
                                            //       width: w > 0 ? (Dimensions.inst.miniplayerMaxWidth * w) : 0,
                                            //       child: smolProgressBarDecoratedBox,
                                            //     );
                                            //   },
                                            // ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (settings.enablePartyModeInMiniplayer.value)
                          FadeIgnoreTransition(
                            opacity: partyContainersOpacityAnimation,
                            child: partyContainersChild,
                          ),

                        /// Top Row
                        Material(
                          type: MaterialType.transparency,
                          child: Padding(
                            padding: EdgeInsets.only(top: topInset),
                            child: FadeIgnoreTransition(
                              opacity: topRowOpacityAnimation,
                              child: Transform.translate(
                                transformHitTests: false,
                                offset: Offset(0, (1 - bp) * -100),
                                child: topRowChild,
                              ),
                            ),
                          ),
                        ),

                        /// Waveform
                        FadeIgnoreTransition(
                          opacity: slowOpacityAnimation,
                          // -- to avoid hero animation when not visible (eg: while entering lyrics fullscreen)
                          // -- this might slightly affect performance while expanding player
                          completelyKillWhenPossible: true,
                          child: Transform.translate(
                            offset: Offset(0, vOffsetWaveform),
                            child: _ScaleYIfNeeded(
                              alignment: Alignment.bottomCenter,
                              scale: waveformYScale,
                              child: const Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                                  child: waveformChild,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Material(
                          type: MaterialType.transparency,
                          child: FadeIgnoreTransition(
                            opacity: slowOpacityAnimation,
                            child: Transform.translate(
                              offset: Offset(0, vOffsetWaveform - 64.0 - 8.0),
                              child: _ScaleYIfNeeded(
                                alignment: Alignment.bottomCenter,
                                scale: waveformYScale,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: seekPositionTextChild,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// Controls
                        Material(
                          type: MaterialType.transparency,
                          child: Transform.translate(
                            offset: Offset(0, vOffsetControls),
                            child: Padding(
                              padding: EdgeInsets.all(12.0 * icp),
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Stack(
                                  alignment: Alignment.centerRight,
                                  children: [
                                    FadeIgnoreTransition(
                                      opacity: fastOpacityAnimation,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: (24.0 * (16.0 * icp + 1))),
                                        child: Stack(
                                          alignment: Alignment.centerRight,
                                          children: [
                                            positionDurationRowChild,
                                            positionDurationSeekerBoxesRowChild,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(right: buttonsRightPadding).add(EdgeInsets.symmetric(vertical: 20.0 * icp)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          FadeIgnoreTransition(
                                            opacity: queueInverseOpacityAnimation,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: nextPrevIconPadding / 2),
                                              child: NamidaIconButton(
                                                icon: Broken.previous,
                                                iconSize: nextPrevIconSize,
                                                horizontalPadding: nextPrevIconPadding / 2,
                                                verticalPadding: nextPrevIconPadding,
                                                onPressed: MiniPlayerController.inst.snapToPrev,
                                                onLongPress: () => Player.inst.seek(Duration.zero),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            key: const Key("playpause"),
                                            height: iconBoxSize,
                                            width: iconBoxSize,
                                            child: _ScaleLayoutBox(
                                              scaleAnimation: playPauseBoxScaleAnimation,
                                              child: playPauseButton,
                                            ),
                                          ),
                                          FadeIgnoreTransition(
                                            opacity: queueInverseOpacityAnimation,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: nextPrevIconPadding / 2),
                                              child: NamidaIconButton(
                                                icon: Broken.next,
                                                iconSize: nextPrevIconSize,
                                                horizontalPadding: nextPrevIconPadding / 2,
                                                verticalPadding: nextPrevIconPadding,
                                                onPressed: MiniPlayerController.inst.snapToNext,
                                                onLongPressStart: Player.inst.startSpeedUp,
                                                onLongPressFinish: Player.inst.endSpeedUp,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// Destination selector
                        FadeIgnoreTransition(
                          opacity: opacityAnimation,
                          child: _AnimatedOrPadding(
                            animated: settings.hideStatusBarInExpandedMiniplayer.value,
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.only(bottom: bottomInset),
                            child: Transform.translate(
                              offset: Offset(0, 100 * ip),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: bottomRowChild,
                              ),
                            ),
                          ),
                        ),

                        /// Track Info
                        ClipRect(
                          child: Material(
                            type: MaterialType.transparency,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: navBarHeight * cp),
                              child: Stack(
                                children: [
                                  if (prevText != null)
                                    FadeIgnoreTransition(
                                      opacity: leftOpacityAnim,
                                      child: MatrixTransition(
                                        animation: sAnim,
                                        onTransform: (animationValue) => Matrix4.translationValues(-animationValue * sMaxOffset / kSiParallax - sMaxOffset / kSiParallax, 0.0, 0.0),
                                        child: Transform.translate(
                                          offset: Offset(0.0, vOffsetTrackInfo),
                                          child: _TrackInfo(
                                            textData: prevText,
                                            isCurrent: false,
                                            p: bp,
                                            qp: qp,
                                            bcp: bcp,
                                            qcp: qcp,
                                            boxHeight: trackInfoBoxHeight,
                                            leftMargin: trackInfoLeftMargin,
                                            bottomOffset: bottomOffset,
                                            maxOffset: maxOffset,
                                            screenSize: screenSize,
                                            opacityAnimation: fastOpacityAnimation,
                                          ),
                                        ),
                                      ),
                                    ),
                                  FadeIgnoreTransition(
                                    opacity: centerItemFadeAnimation,
                                    child: MatrixTransition(
                                      animation: sAnim,
                                      onTransform: (animationValue) => Matrix4.translationValues(-animationValue * sMaxOffset / kStParallax + (12.0 * qp), 0.0, 0.0),
                                      child: Transform.translate(
                                        offset: Offset(0.0, vOffsetTrackInfo),
                                        child: _TrackInfo(
                                          textData: currentText,
                                          isCurrent: true,
                                          p: bp,
                                          qp: qp,
                                          bcp: bcp,
                                          qcp: qcp,
                                          boxHeight: trackInfoBoxHeight,
                                          leftMargin: trackInfoLeftMargin,
                                          bottomOffset: bottomOffset,
                                          maxOffset: maxOffset,
                                          screenSize: screenSize,
                                          opacityAnimation: fastOpacityAnimation,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (nextText != null)
                                    FadeIgnoreTransition(
                                      opacity: rightOpacityAnim,
                                      child: MatrixTransition(
                                        animation: sAnim,
                                        onTransform: (animationValue) => Matrix4.translationValues(-animationValue * sMaxOffset / kSiParallax + sMaxOffset / kSiParallax, 0.0, 0.0),
                                        child: Transform.translate(
                                          offset: Offset(0.0, vOffsetTrackInfo),
                                          child: _TrackInfo(
                                            textData: nextText,
                                            isCurrent: false,
                                            p: bp,
                                            qp: qp,
                                            bcp: bcp,
                                            qcp: qcp,
                                            boxHeight: trackInfoBoxHeight,
                                            leftMargin: trackInfoLeftMargin,
                                            bottomOffset: bottomOffset,
                                            maxOffset: maxOffset,
                                            screenSize: screenSize,
                                            opacityAnimation: fastOpacityAnimation,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        /// Track Image
                        ClipRect(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: navBarHeight * cp),
                            child: Builder(
                              builder: (context) {
                                return Stack(
                                  children: [
                                    if (previousImageWidget != null)
                                      FadeIgnoreTransition(
                                        opacity: leftOpacityAnim,
                                        child: MatrixTransition(
                                          animation: sAnim,
                                          onTransform: (animationValue) {
                                            final horizontalOffset = -animationValue * sMaxOffset / kSiParallax - sMaxOffset / kSiParallax;
                                            return Matrix4.translationValues(horizontalOffset + imageLeftOffset, 0.0, 0.0);
                                          },
                                          child: Transform.translate(
                                            offset: Offset(0.0, vOffsetImage),
                                            child: _RawImageContainer(
                                              width: imageBoxWidth,
                                              height: imageBoxHeight,
                                              padding: imagePadding,
                                              child: Padding(
                                                padding: EdgeInsets.all(12.0 * (1 - bcp)),
                                                child: previousImageWidget,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    FadeIgnoreTransition(
                                      opacity: centerItemFadeAnimation,
                                      child: MatrixTransition(
                                        animation: sAnim,
                                        onTransform: (animationValue) {
                                          final horizontalOffset = -animationValue * sMaxOffset / kSiParallax;
                                          return Matrix4.translationValues(horizontalOffset + imageLeftOffset, 0.0, 0.0);
                                        },
                                        child: Transform.translate(
                                          offset: Offset(0.0, vOffsetImage),
                                          child: _RawImageContainer(
                                            width: imageBoxWidth,
                                            height: imageBoxHeight,
                                            padding: imagePadding,
                                            child: Padding(
                                              padding: EdgeInsets.all(12.0 * (1 - bcp)),
                                              child: ObxO(
                                                rx: settings.artworkGestureDoubleTapLRC,
                                                builder: (context, artworkGestureDoubleTapLRC) {
                                                  if (artworkGestureDoubleTapLRC) {
                                                    return ObxO(
                                                      rx: Lyrics.inst.currentLyricsLRC,
                                                      builder: (context, currentLyricsLRC) {
                                                        // -- only when lrc view is not visible, to prevent other gestures delaying.
                                                        return DoubleTapDetector(
                                                          onDoubleTap: currentLyricsLRC == null
                                                              ? () {
                                                                  settings.save(enableLyrics: !settings.enableLyrics.value);
                                                                  Lyrics.inst.updateLyrics(currentItem);
                                                                }
                                                              : null,
                                                          child: currentImage,
                                                        );
                                                      },
                                                    );
                                                  }
                                                  return currentImage;
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (nextImageWidget != null)
                                      FadeIgnoreTransition(
                                        opacity: rightOpacityAnim,
                                        child: MatrixTransition(
                                          animation: sAnim,
                                          onTransform: (animationValue) {
                                            final horizontalOffset = -animationValue * sMaxOffset / kSiParallax + sMaxOffset / kSiParallax;
                                            return Matrix4.translationValues(horizontalOffset + imageLeftOffset, 0.0, 0.0);
                                          },
                                          child: Transform.translate(
                                            offset: Offset(0.0, vOffsetImage),
                                            child: _RawImageContainer(
                                              width: imageBoxWidth,
                                              height: imageBoxHeight,
                                              padding: imagePadding,
                                              child: Padding(
                                                padding: EdgeInsets.all(12.0 * (1 - bcp)),
                                                child: nextImageWidget,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        /// Simple current lyrics line (under artwork)
                        ObxO(
                          rx: settings.enableSimpleLyricsLine,
                          builder: (context, enableSimpleLyricsLine) => ObxO(
                            rx: settings.enableLyrics,
                            builder: (context, enableLyrics) => enableSimpleLyricsLine && !enableLyrics
                                ? ClipRect(
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: navBarHeight * cp),
                                      child: FadeIgnoreTransition(
                                        completelyKillWhenPossible: true,
                                        opacity: simpleLyricsOpacityAnimation,
                                        child: Transform.translate(
                                          offset: Offset(0.0, vOffsetTrackInfo - trackInfoBoxHeight * bcp + 6.0 * heightFactor * bcp),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 32.0),
                                              child: SimpleLyricsLineWidget(
                                                style: textTheme.displayMedium?.copyWith(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                        ),

                        Positioned(
                          bottom: -bottomOffset + (12.0 * icp) + (-(SeekReadyDimensions.barHeight / 2) + (SeekReadyDimensions.progressBarHeight / 2)),
                          left: borderRadius.bottomLeft.x + 4.0,
                          right: borderRadius.bottomRight.x + 4.0,
                          child: FadeIgnoreTransition(
                            opacity: progressBarOpacityAnimation,
                            child: seekReadyWidget,
                          ),
                        ),

                        Visibility(
                          maintainState: true, // cuz rebuilding from scratch almost kills raster
                          visible: qp > 0 && !bounceUp,
                          child: Transform.translate(
                            offset: Offset(0, (1 - qp) * maxQueueHeight),
                            child: queueChild,
                          ),
                        ),
                      ],
                    );
                  },
            );
          },
        );
      },
    );
  }
}

class _RawImageContainer extends StatelessWidget {
  const _RawImageContainer({
    super.key,
    required this.width,
    required this.height,
    required this.padding,
    required this.child,
  });

  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: padding,
        child: SizedBox(
          height: height,
          width: width,
          child: child,
        ),
      ),
    );
  }
}

class _TrackInfo<E, S> extends StatelessWidget {
  final MiniplayerInfoData<E, S> textData;
  final bool isCurrent;
  final double bcp;
  final double qp;
  final double qcp;
  final double p;
  final double boxHeight;
  final double leftMargin;
  final Size screenSize;
  final double bottomOffset;
  final double maxOffset;
  final Animation<double> opacityAnimation;

  const _TrackInfo({
    super.key,
    required this.textData,
    required this.isCurrent,
    required this.bcp,
    required this.qp,
    required this.qcp,
    required this.p,
    required this.boxHeight,
    required this.leftMargin,
    required this.screenSize,
    required this.bottomOffset,
    required this.maxOffset,
    required this.opacityAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final ytLikeManager = textData.ytLikeManager;

    final paddingAll = 12.0 * (1 - bcp);
    final paddingAllHorizontal = (paddingAll + 24.0 * bcp) * (1 - qcp);

    // -- fade needs an offscreen layer per line, adjacent items are only glimpsed mid-swipe.
    final overflow = isCurrent ? TextOverflow.fade : TextOverflow.ellipsis;

    final padding = EdgeInsets.fromLTRB(
      paddingAllHorizontal + 4.0 * qp,
      paddingAll,
      paddingAllHorizontal,
      paddingAll * 2,
    );

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: padding,
        child: SizedBox(
          height: boxHeight,
          child: Row(
            children: [
              SizedBox(width: leftMargin), // Image placeholder
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: (32.0 + (82.0 * (1 - bcp) * (1 - qp)) + (60.0 * qp))),
                        child: InkWell(
                          onTapUp: bcp == 1 ? textData.onMenuOpen : null,
                          onLongPress: textData.enableTextLongTap && bcp == 1 ? textData.onTextLongTap : null,
                          highlightColor: Color.alphaBlend(theme.scaffoldBackgroundColor.withAlpha(20), theme.highlightColor),
                          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                          child: Padding(
                            padding: EdgeInsets.only(left: 8.0 * bcp),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (textData.firstLineGood)
                                  _ScaleLayoutBox(
                                    scale: velpy(a: 14.5, b: 20.0, c: p) / 20.0,
                                    child: Text(
                                      textData.firstLine,
                                      maxLines: textData.secondLineGood ? 1 : 2,
                                      overflow: overflow,
                                      softWrap: !textData.secondLineGood,
                                      style: textTheme.displayMedium?.copyWith(
                                        fontSize: 20.0,
                                      ),
                                    ),
                                  ),
                                if (textData.firstLineGood && textData.secondLineGood) const SizedBox(height: 4.0),
                                if (textData.secondLineGood)
                                  _ScaleLayoutBox(
                                    scale: velpy(a: 12.5, b: 15.0, c: p) / 15.0,
                                    child: Text(
                                      textData.secondLine,
                                      softWrap: false,
                                      overflow: overflow,
                                      style: textTheme.displayMedium?.copyWith(
                                        fontSize: 15.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    FadeIgnoreTransition(
                      completelyKillWhenPossible: true,
                      opacity: opacityAnimation,
                      child: Transform.translate(
                        offset: Offset(-100 * (1.0 - bcp), 0.0),
                        child: LongPressDetector(
                          enableSecondaryTap: true,
                          onLongPress: textData.onShowAddToPlaylistDialog,
                          child: ytLikeManager != null
                              ? ObxO(
                                  rx: ytLikeManager.currentVideoLikeStatus,
                                  builder: (context, currentLikeStatus) {
                                    final isUserLiked = currentLikeStatus == LikeStatus.liked;
                                    return NamidaLoadingSwitcher(
                                      size: 32.0,
                                      builder: (loadingController) => NamidaRawLikeButton(
                                        size: 32.0,
                                        enableGradient: true,
                                        likedIcon: textData.likedIcon,
                                        normalIcon: textData.normalIcon,
                                        enabledColor: theme.colorScheme.primary.withOpacityExt(0.75),
                                        disabledColor: theme.colorScheme.secondary.withOpacityExt(0.75),
                                        removeConfirmationAction: null, // manually managed
                                        isLiked: isUserLiked,
                                        onTap: (isLiked) async {
                                          return ytLikeManager.onLikeClicked(
                                            YTVideoLikeParamters(
                                              isActive: isLiked,
                                              action: isLiked ? LikeAction.removeLike : LikeAction.addLike,
                                              onStart: loadingController.startLoading,
                                              onEnd: loadingController.stopLoading,
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                )
                              : ObxOClass(
                                  rx: textData.favouritePlaylist,
                                  builder: (context, favouritePlaylist) => NamidaRawLikeButton(
                                    size: 32.0,
                                    enableGradient: true,
                                    likedIcon: textData.likedIcon,
                                    normalIcon: textData.normalIcon,
                                    enabledColor: theme.colorScheme.primary.withOpacityExt(0.75),
                                    disabledColor: theme.colorScheme.secondary.withOpacityExt(0.75),
                                    removeConfirmationAction: lang.removeFromFavourites,
                                    isLiked: favouritePlaylist.isSubItemFavourite(textData.itemToLike),
                                    onTap: textData.onLikeTap,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaveformMiniplayer extends StatelessWidget {
  final bool fixPadding;
  final double height;
  final bool enableHero;
  const WaveformMiniplayer({super.key, this.fixPadding = false, this.height = 64.0, this.enableHero = true});

  int get _currentDurationInMS {
    final totalDur = Player.inst.currentItemDuration.value;
    if (totalDur != null) return totalDur.inMilliseconds;
    final current = Player.inst.currentItem.value;
    if (current is Selectable) {
      return current.track.durationMS;
    }
    return 0;
  }

  void onSeekDragUpdate(double deltax, double maxWidth) {
    if (!_canDragToSeekLatest) return;
    final percentageSwiped = deltax / maxWidth;
    final newSeek = percentageSwiped * _currentDurationInMS;
    MiniPlayerController.inst.seekValue.value = newSeek.toInt();
  }

  void onSeekEnd({bool allowSeek = true}) {
    if (allowSeek && _dragUpToCancel < _dragUpToCancelMax) {
      final ms = MiniPlayerController.inst.seekValue.value;
      if (ms != null) {
        Player.inst.seek(Duration(milliseconds: ms));
      }
    }

    _dragUpToCancel = 0.0;
    _canDragToSeekLatest = true;

    MiniPlayerController.inst.seekValue.value = null;
  }

  bool get _isMiniplayerExpanded => MiniPlayerController.inst.animation.value >= 0.95;

  static bool _canDragToSeekLatest = true;
  static double _dragUpToCancel = 0.0;
  static final _dragUpToCancelMax = 5;

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      tag: 'MINIPLAYER_WAVEFORM',
      enabled: enableHero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: height,
            child: Padding(
              padding: fixPadding ? EdgeInsets.symmetric(horizontal: (16.0 / 2)) : EdgeInsets.zero,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerMove: (event) {
                  if (!_isMiniplayerExpanded) return;
                  if (!_canDragToSeekLatest) return;
                  if (_dragUpToCancel > _dragUpToCancelMax) {
                    _canDragToSeekLatest = false;
                    VibratorController.veryhigh();
                  } else {
                    _dragUpToCancel -= event.localDelta.dy * 0.1;
                  }
                },
                onPointerUp: (_) => _canDragToSeekLatest = true,
                onPointerCancel: (_) => _canDragToSeekLatest = true,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    onSeekDragUpdate(details.localPosition.dx, constraints.maxWidth);
                    onSeekEnd();
                  },
                  onTapCancel: () => onSeekEnd(allowSeek: false),
                  onHorizontalDragUpdate: (details) => onSeekDragUpdate(details.localPosition.dx, constraints.maxWidth),
                  onHorizontalDragEnd: (details) => onSeekEnd(),
                  child: const WaveformComponent(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MPQualityButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Widget? trailing;
  final double padding;
  final void Function()? onTap;
  final double? progress;

  const _MPQualityButton({
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.selected = false,
    this.trailing,
    this.padding = 4.0,
    required this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final progress = this.progress?.clampDouble(0.0, 1.0);
    final color = CurrentColor.inst.miniplayerColor;
    final bgColor = selected ? color.withOpacityExt(0.4) : null;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 36.0),
      child: NamidaInkWell(
        margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        padding: EdgeInsets.all(padding),
        onTap: onTap,
        borderRadius: 8.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: progress != null ? null : bgColor,
          gradient: progress == null
              ? null
              : LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    color.withOpacityExt(0.4),
                    color.withOpacityExt(0.4),
                    color.withOpacityExt(0.2),
                    color.withOpacityExt(0.2),
                  ],
                  stops: [0.0, progress, progress, 1.0],
                ),
        ),
        child: Row(
          children: [
            SizedBox(width: 4.0),
            progress == null
                ? Icon(
                    icon,
                    size: 18.0,
                  )
                : SizedBox(
                    width: 18.0,
                    child: FittedBox(
                      fit: .scaleDown,
                      child: Text(
                        "${(progress * 100).toStringAsFixed(0)}%",
                        textAlign: TextAlign.center,
                        style: textTheme.displaySmall?.copyWith(
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ),
            SizedBox(width: 6.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.displayMedium?.copyWith(
                      fontSize: 13.0,
                    ),
                  ),
                  if (subtitle != '')
                    Text(
                      subtitle,
                      style: textTheme.displaySmall?.copyWith(
                        fontSize: 13.0,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: 4.0),
              trailing!,
              SizedBox(width: 4.0),
            ],
            SizedBox(width: 4.0),
          ],
        ),
      ),
    );
  }
}

class _QueueListChildWrapper extends StatelessWidget {
  final double? queueItemExtent;
  final double? Function(Playable item)? queueItemExtentBuilder;
  final Widget Function(BuildContext context, int index, List<Playable> queue) itemBuilder;

  const _QueueListChildWrapper({
    super.key,
    required this.queueItemExtent,
    required this.queueItemExtentBuilder,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final deviceBottomInsets = MediaQuery.paddingOf(context).bottom;
    return ObxO(
      rx: SelectedTracksController.inst.bottomPadding,
      builder: (context, selectedTracksPadding) {
        final padding = EdgeInsets.only(bottom: 8.0 + selectedTracksPadding + kQueueBottomRowHeight + deviceBottomInsets);
        return ObxO(
          rx: Player.inst.currentQueue,
          builder: (context, queue) {
            final queueLength = queue.length;
            if (queueLength == 0) return const SizedBox();
            // -- tiles observe the current index themselves, so a track change never rebuilds the whole list.
            return NamidaScrollbar(
              controller: MiniPlayerController.inst.queueScrollController,
              child: SmoothCustomScrollView(
                controller: MiniPlayerController.inst.queueScrollController,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(top: 2.0),
                  ),
                  NamidaSliverReorderableList(
                    itemCount: queueLength,
                    itemExtent: queueItemExtent,
                    itemExtentBuilder: queueItemExtentBuilder == null ? null : (index, d) => queueItemExtentBuilder!(queue[index]),
                    onReorderStart: (index) => Player.inst.invokeQueueModifyLock(),
                    onReorderEnd: (index) => Player.inst.invokeQueueModifyLockRelease(),
                    onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                    onReorderCancel: () => Player.inst.invokeQueueModifyOnModifyCancel(),
                    itemBuilder: (context, i) => itemBuilder(context, i, queue),
                  ),
                  SliverPadding(
                    padding: padding,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Tap seeks backwards, long press rewinds.
class SeekBackwardsDetectorWidget extends StatelessWidget {
  final Widget child;
  const SeekBackwardsDetectorWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TapDetector(
      behavior: HitTestBehavior.translucent,
      onTap: Player.inst.seekSecondsBackward,
      child: LongPressDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: null,
        initializer: (instance) {
          instance
            ..onLongPressStart = Player.inst.startRewind
            ..onLongPressEnd = Player.inst.endRewind
            ..onLongPressCancel = Player.inst.endRewind
            ..onLongPressUp = Player.inst.endRewind;
        },
        child: child,
      ),
    );
  }
}

/// Tap seeks forward, long press fast forwards.
class SeekForwardDetectorWidget extends StatelessWidget {
  final Widget child;
  const SeekForwardDetectorWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TapDetector(
      behavior: HitTestBehavior.translucent,
      onTap: Player.inst.seekSecondsForward,
      child: LongPressDetector(
        onLongPress: null,
        initializer: (instance) {
          instance
            ..onLongPressStart = Player.inst.startFastForward
            ..onLongPressEnd = Player.inst.endFastForward
            ..onLongPressCancel = Player.inst.endFastForward
            ..onLongPressUp = Player.inst.endFastForward;
        },
        child: child,
      ),
    );
  }
}

class _AnimatedDecorationOrDecoration extends StatelessWidget {
  final Duration duration;
  final Decoration decoration;
  final Widget? child;
  final bool animate;

  const _AnimatedDecorationOrDecoration({
    super.key,
    required this.duration,
    required this.decoration,
    required this.animate,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // -- same widget type either way, swapping to a plain [DecoratedBox] would remount the whole subtree.
    return AnimatedDecoration(
      decoration: decoration,
      duration: animate && settings.animatedTheme.value ? duration : Duration.zero,
      child: child,
    );
  }
}

/// Lays [child] out as if it had `1 / scale` of the available space, then paints it scaled by [scale].
///
/// Unlike [Transform.scale], the box reports the scaled size to its parent, and unlike changing
/// font sizes or paddings, [child] keeps its constraints so text is never re-shaped per frame.
class _ScaleLayoutBox extends SingleChildRenderObjectWidget {
  final double scale;
  final Animation<double>? scaleAnimation;

  const _ScaleLayoutBox({
    super.key,
    this.scale = 1.0,
    this.scaleAnimation,
    required super.child,
  });

  @override
  _RenderScaleLayoutBox createRenderObject(BuildContext context) => _RenderScaleLayoutBox(scale, scaleAnimation);

  @override
  void updateRenderObject(BuildContext context, _RenderScaleLayoutBox renderObject) {
    renderObject
      ..scale = scale
      ..scaleAnimation = scaleAnimation;
  }
}

class _RenderScaleLayoutBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  _RenderScaleLayoutBox(this._scale, this._scaleAnimation);

  double _scale;
  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    if (_scaleAnimation == null) markNeedsLayout();
  }

  Animation<double>? _scaleAnimation;
  set scaleAnimation(Animation<double>? value) {
    if (_scaleAnimation == value) return;
    if (attached) {
      _scaleAnimation?.removeListener(markNeedsLayout);
      value?.addListener(markNeedsLayout);
    }
    _scaleAnimation = value;
    markNeedsLayout();
  }

  double get _effectiveScale => _scaleAnimation?.value ?? _scale;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scaleAnimation?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _scaleAnimation?.removeListener(markNeedsLayout);
    super.detach();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints, double scale) {
    return BoxConstraints(
      maxWidth: constraints.maxWidth / scale,
      maxHeight: constraints.maxHeight / scale,
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final scale = _effectiveScale;
    child.layout(_childConstraints(constraints, scale), parentUsesSize: true);
    size = constraints.constrain(child.size * scale);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final scale = _effectiveScale;
    return constraints.constrain(child.getDryLayout(_childConstraints(constraints, scale)) * scale);
  }

  @override
  double computeMinIntrinsicWidth(double height) => (child?.getMinIntrinsicWidth(height / _effectiveScale) ?? 0.0) * _effectiveScale;

  @override
  double computeMaxIntrinsicWidth(double height) => (child?.getMaxIntrinsicWidth(height / _effectiveScale) ?? 0.0) * _effectiveScale;

  @override
  double computeMinIntrinsicHeight(double width) => (child?.getMinIntrinsicHeight(width / _effectiveScale) ?? 0.0) * _effectiveScale;

  @override
  double computeMaxIntrinsicHeight(double width) => (child?.getMaxIntrinsicHeight(width / _effectiveScale) ?? 0.0) * _effectiveScale;

  Matrix4 get _transform {
    final scale = _effectiveScale;
    return Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (_effectiveScale == 1.0) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer as TransformLayer?,
    );
  }
}

/// Play/pause button geometry as a function of the miniplayer animation value.
abstract class _PlayPauseMetrics {
  static double iconSize(double p) {
    final cp = p.clampDouble(0.0, 1.0);
    final rp = inverseAboveOne(p);
    final rcp = rp.clampDouble(0, 1);
    return ((velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp);
  }

  static double extraPadding(double iconSize) => (iconSize * 0.5).withMaximum(14.0);

  static double boxSize(double iconSize) => iconSize + extraPadding(iconSize) * 2;

  /// at `p == 1`, the button is laid out at this size and scaled down from there.
  static double get maxIconSize => 40.0;
  static double get maxBoxSize => boxSize(maxIconSize);
}

/// Laid out once at its largest size, the miniplayer scales it per frame without rebuilding it.
class _PlayPauseButton extends StatelessWidget {
  final bool canShowBuffering;
  final Animation<double> iconScaleAnimation;
  final void Function(TapGestureRecognizer instance) tapInitializer;

  const _PlayPauseButton({
    super.key,
    required this.canShowBuffering,
    required this.iconScaleAnimation,
    required this.tapInitializer,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = _PlayPauseMetrics.maxIconSize;
    final boxSize = _PlayPauseMetrics.boxSize(iconSize);
    final iconStack = Stack(
      alignment: Alignment.center,
      children: [
        ObxO(
          rx: Player.inst.playWhenReady,
          builder: (context, playWhenReady) => CustomAnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: playWhenReady
                ? Icon(
                    Broken.pause,
                    size: iconSize,
                    key: const Key("pauseicon"),
                    color: Colors.white.withAlpha(180),
                  )
                : Icon(
                    Broken.play,
                    size: iconSize,
                    key: const Key("playicon"),
                    color: Colors.white.withAlpha(180),
                  ),
          ),
        ),
        if (canShowBuffering)
          IgnorePointer(
            child: Obx(
              (context) => Player.inst.shouldShowLoadingIndicatorR
                  ? ThreeArchedCircle(
                      color: Colors.white.withAlpha(120),
                      size: iconSize * 1.4,
                    )
                  : const SizedBox(),
            ),
          ),
      ],
    );
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: RepaintBoundary(
        child: Obx(
          (context) {
            final isButtonHighlighed = MiniPlayerController.inst.isPlayPauseButtonHighlighted.valueR;
            final color = CurrentColor.inst.miniplayerColor;
            Widget playPauseButtonChild = AnimatedScale(
              duration: const Duration(milliseconds: 400),
              scale: isButtonHighlighed ? 0.97 : 1.0,
              child: AnimatedDecoration(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: isButtonHighlighed ? Color.alphaBlend(color.withAlpha(233), Colors.white) : color,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.alphaBlend(color.withAlpha(200), Colors.grey),
                    ],
                    stops: const [0, 0.7],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(160),
                      blurRadius: 8.0,
                      spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                      offset: const Offset(0.0, 2.0),
                    ),
                  ],
                ),
                child: Center(
                  child: _ScaleLayoutBox(
                    scaleAnimation: iconScaleAnimation,
                    child: iconStack,
                  ),
                ),
              ),
            );
            if (kEnableFancyAnimations) {
              playPauseButtonChild = CAMagneticButton(
                radius: boxSize,
                pullFactor: 0.08,
                maxSkewRadians: 0.08,
                pressScale: 0.98,
                child: playPauseButtonChild,
              );
            }
            return NamidaMouseRegion(
              child: TapDetector(
                onTap: null,
                initializer: tapInitializer,
                child: playPauseButtonChild,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// [first] × [next], so two fades stack into one opacity layer instead of two.
class _AnimationProduct extends CompoundAnimation<double> {
  _AnimationProduct(Animation<double> first, Animation<double> next) : super(first: first, next: next);

  @override
  double get value => first.value * next.value;
}

class MPCustomIconButton extends StatelessWidget {
  final Widget icon;
  final double sizeRaw;
  final void Function() onPressed;
  final String Function()? tooltipCallback;

  const MPCustomIconButton({
    super.key,
    required this.icon,
    this.sizeRaw = defaultIconSize,
    required this.onPressed,
    required this.tooltipCallback,
  });

  static const defaultIconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final finalSize = sizeRaw;
    Widget child = IconButton(
      visualDensity: VisualDensity.compact,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStatePropertyAll(
          Size(finalSize, finalSize) * 1.8,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
      onPressed: onPressed,
      icon: icon,
    );
    if (tooltipCallback != null) {
      child = NamidaTooltip(
        message: tooltipCallback,
        child: child,
      );
    }
    return child;
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? bgColor;
  final void Function(TapUpDetails details) onTapUp;

  const _TopActionButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.all(8.0),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(12.0, 12.0),
        ),
      ),
      onPressed: () {
        onTapUp(
          TapUpDetails(
            kind: PointerDeviceKind.unknown,
            globalPosition: const Offset(1, 0),
            localPosition: const Offset(1, 0),
          ),
        );
      },
      icon: TapDetector(
        onTap: null,
        initializer: (instance) {
          instance
            ..onTapUp = onTapUp
            ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
        },
        child: Container(
          padding: EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
          ),
        ),
      ),
      iconSize: 22.0,
    );
  }
}

class _AnimatedOrPadding extends StatelessWidget {
  final bool animated;
  final Duration duration;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _AnimatedOrPadding({
    super.key,
    required this.animated,
    required this.duration,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return animated
        ? AnimatedPadding(padding: padding, duration: duration, child: child)
        : Padding(
            padding: padding,
            child: child,
          );
  }
}

class _ScaleYIfNeeded extends StatelessWidget {
  final double? scale;
  final AlignmentGeometry? alignment;
  final Widget child;

  const _ScaleYIfNeeded({
    super.key,
    required this.scale,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (scale == null || scale == 1.0) return child;
    return Transform.scale(
      scaleY: scale,
      alignment: alignment,
      child: child,
    );
  }
}

class PlayerVideoAudioChip extends StatelessWidget {
  final FocusedMenuOptions focusedMenuOptions;
  final Playable currentItem;
  final Rx<bool> isMenuOpened;
  final Duration animationDuration;
  final double Function(BuildContext context)? menuWidth;
  final double scale;

  const PlayerVideoAudioChip({
    super.key,
    required this.focusedMenuOptions,
    required this.currentItem,
    required this.isMenuOpened,
    this.animationDuration = const Duration(milliseconds: 150),
    this.menuWidth,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final onSecondary = theme.colorScheme.onSecondaryContainer;
    final videoIconBuilder = focusedMenuOptions.videoIconBuilder(currentItem, 18.0, onSecondary);
    final focusedMenuBuilder = focusedMenuOptions.builder(currentItem);
    final chip = Stack(
      alignment: Alignment.centerLeft,
      children: [
        FocusedMenuHolder(
          options: (containerKey) {
            return FocusedMenuDetails(
              containerKey: containerKey,
              menuOpenAlignment: Alignment.bottomLeft,
              bottomOffsetHeight: 12.0,
              leftOffsetHeight: 4.0,
              onMenuOpen: () {
                // ScrollSearchController.inst.unfocusKeyboard(); // the miniplayer should have alr done that.
                isMenuOpened.value = true;
                if (focusedMenuOptions.loadQualities != null) {
                  final currentId = focusedMenuOptions.currentId(currentItem);
                  // auto load if possible
                  if (currentId != null &&
                      currentId.isNotEmpty &&
                      (focusedMenuOptions.streams.value?.videoStreams
                              .withoutWebmIfNeccessaryOrExperimentalCodecs(allowExperimentalCodecs: settings.youtube.allowExperimentalCodecs)
                              .isEmpty ??
                          true)) {
                    focusedMenuOptions.loadQualities!(currentItem);
                  }
                }
                return true;
              },
              onMenuClose: () => isMenuOpened.value = false,
              blurSize: 2.0,
              duration: animationDuration,
              animateMenuItems: false,
              menuWidth: (context) => menuWidth?.call(context) ?? Dimensions.inst.miniplayerMaxWidth * 0.5,
              menuBoxDecoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
              ),
              menuWidget: Obx(
                (context) {
                  final currentId = focusedMenuOptions.currentId(currentItem);
                  final ytVideos = focusedMenuOptions.streams.valueR?.videoStreams.withoutWebmIfNeccessaryOrExperimentalCodecs(
                    allowExperimentalCodecs: settings.youtube.allowExperimentalCodecs,
                  );
                  final availableVideos = List<NamidaVideo>.from(focusedMenuOptions.localVideos.valueR);
                  YoutubeController.removeDuplicateCachedQualities(availableVideos, ytVideos, currentId);

                  final audioTracks = Player.inst.audioTracks.valueR;
                  final downloadingStream = focusedMenuOptions.downloadingStream?.valueR;

                  final currentVideoConfig = VideoController.inst.currentVideoConfig;
                  return SuperSmoothListView(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    children: [
                      _MPQualityButton(
                        icon: Broken.play_cricle,
                        title: lang.playbackSetting,
                        onTap: () => NamidaNavigator.inst.navigateDialog(
                          dialog: Dialog(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: kDialogMaxWidth),
                              child: PlaybackSettings(isInDialog: true),
                            ),
                          ),
                        ),
                      ),
                      Obx(
                        (context) {
                          final hasHighConnection = ConnectivityController.inst.hasHighConnection;
                          final rx = hasHighConnection ? settings.youtube.dataSaverMode : settings.youtube.dataSaverModeMobile;
                          final value = rx.valueR;
                          final isOff = value == DataSaverMode.off;
                          return _MPQualityButton(
                            title: lang.dataSaver,
                            onTap: () => YoutubeSettings.openDataSaverConfigureDialog(),
                            subtitle: isOff ? '' : value.toText(),
                            icon: Broken.blur,
                          );
                        },
                      ),
                      if (currentId == null || currentId.isEmpty)
                        _MPQualityButton(
                          title: lang.search,
                          icon: Broken.search_normal,
                          onTap: () {
                            focusedMenuOptions.onSearch?.call(currentItem);
                          },
                        )
                      else if (focusedMenuOptions.loadQualities != null)
                        _MPQualityButton(
                          title: lang.checkForMore,
                          icon: Broken.chart,
                          trailing: currentVideoConfig.isLoadingCurrentYTStreams.valueR ? const LoadingIndicator() : null,
                          onTap: () => focusedMenuOptions.loadQualities!(currentItem),
                        ),

                      if (audioTracks != null && audioTracks.length > 1) ...[
                        const NamidaContainerDivider(height: 2.0, margin: EdgeInsets.symmetric(vertical: 4.0)),
                        _MPQualityButton(
                          onTap: () => Player.inst.setAudioTrackAndSave(null),
                          icon: Broken.audio_square,
                          title: lang.auto,
                        ),
                        ...audioTracks.map(
                          (e) {
                            final isCurrent = e.isSelected;
                            final title = e.displayName;
                            return _MPQualityButton(
                              onTap: () => Player.inst.setAudioTrackAndSave(e.id),
                              selected: isCurrent,
                              icon: Broken.audio_square,
                              title: [
                                title.capitalizeFirst(),
                                if (e.label != title) e.label?.capitalizeFirst(),
                                ?e.mimeType?.toUpperCase(),
                              ].joinText(separator: ' • '),
                              subtitle: [
                                if (e.sampleRate != null) '${e.sampleRate! / 1000} kHz',
                                if (e.bitrate != null) "${e.bitrate! ~/ 1000} kb/s",
                                if (e.channelCount != null) "${e.channelCount!} ch",
                              ].joinText(separator: ' • '),
                              trailing: NamidaCheckMark(
                                active: isCurrent,
                                size: 12.0,
                              ),
                            );
                          },
                        ),
                      ],

                      const NamidaContainerDivider(height: 2.0, margin: EdgeInsets.symmetric(vertical: 4.0)),

                      ...availableVideos.map(
                        (element) {
                          final localOrCache = element.ytID == null ? lang.local : lang.cache;
                          return Obx(
                            (context) {
                              final isCurrent = element.path == (VideoController.inst.currentVideo.valueR?.path ?? Player.inst.currentCachedVideo.valueR?.path);
                              return _MPQualityButton(
                                onTap: () => focusedMenuOptions.onLocalVideoTap(currentItem, element),
                                selected: isCurrent,
                                icon: Broken.video,
                                title: [
                                  "${element.resolution}p${element.framerateText()}",
                                  localOrCache,
                                ].join(' • '),
                                subtitle: [
                                  element.sizeInBytes.fileSizeFormatted,
                                  "${element.bitrate ~/ 1000} kb/s",
                                ].join(' • '),
                                trailing: NamidaCheckMark(
                                  active: isCurrent,
                                  size: 12.0,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      ...?ytVideos?.map(
                        (element) {
                          final cacheFile = currentId == null ? null : element.getCachedFileSync(currentId);
                          final cacheExists = cacheFile != null;
                          var codecIdentifier = element.codecInfo.codecIdentifierIfCustom();
                          var codecIdentifierText = codecIdentifier != null ? ' (${codecIdentifier.toUpperCase()})' : '';
                          final title = "${element.qualityLabel} • ${element.sizeInBytes.fileSizeFormatted}";
                          final subtitle = "${element.codecInfo.container} • ${element.bitrateText()}$codecIdentifierText";

                          void onTap() => focusedMenuOptions.onStreamVideoTap(currentItem, currentId, element, cacheFile, focusedMenuOptions.streams.value);

                          final isCurrent = focusedMenuOptions.isStreamSelected(element, cacheFile);

                          final downloadedBytesRx = focusedMenuOptions.downloadedBytes;
                          if (downloadedBytesRx != null && YoutubeController.isSameVideoStream(downloadingStream, element)) {
                            final totalBytes = element.sizeInBytes;
                            return ObxO(
                              rx: downloadedBytesRx,
                              builder: (context, downloadedBytes) => _MPQualityButton(
                                onTap: onTap,
                                selected: isCurrent,
                                icon: Broken.import,
                                title: title,
                                subtitle: subtitle,
                                progress: totalBytes <= 0 ? null : (downloadedBytes ?? 0) / totalBytes,
                                trailing: totalBytes <= 0 ? const LoadingIndicator() : null,
                              ),
                            );
                          }

                          return _MPQualityButton(
                            onTap: onTap,
                            selected: isCurrent,
                            icon: cacheExists ? Broken.tick_circle : Broken.import,
                            title: title,
                            subtitle: subtitle,
                            trailing: isCurrent
                                ? NamidaCheckMark(
                                    active: true,
                                    size: 12.0,
                                  )
                                : null,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            );
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Obx(
                (context) {
                  return AnimatedDecoration(
                    duration: animationDuration,
                    decoration: isMenuOpened.valueR
                        ? BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(24.0.multipliedRadius),
                          )
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                          ),
                    child: TextButton(
                      onPressed: () => focusedMenuOptions.onPressed(currentItem),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 3.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: NamidaIconButton(
                                padding: EdgeInsets.all(6.0),
                                icon: null,
                                child: videoIconBuilder,
                                onPressed: () {
                                  String toPercentage(double val) => "${(val * 100).toStringAsFixed(0)}%";

                                  Widget getTextWidget(IconData icon, String title, double value) {
                                    return Row(
                                      children: [
                                        Icon(icon, color: context.defaultIconColor(CurrentColor.inst.miniplayerColor)),
                                        const SizedBox(width: 12.0),
                                        NamidaButtonText(
                                          title,
                                          style: textTheme.displayLarge,
                                        ),
                                        const SizedBox(width: 8.0),
                                        NamidaButtonText(
                                          toPercentage(value),
                                          style: textTheme.displayMedium,
                                        ),
                                      ],
                                    );
                                  }

                                  Widget getSlider({
                                    double min = 0.0,
                                    double max = 2.0,
                                    required double value,
                                    required void Function(double newValue)? onChanged,
                                  }) {
                                    return Slider.adaptive(
                                      min: min,
                                      max: max,
                                      value: value.clampDouble(min, max),
                                      onChanged: onChanged,
                                      divisions: (max * 100).round(),
                                      label: "${(value * 100).toStringAsFixed(0)}%",
                                    );
                                  }

                                  NamidaNavigator.inst.navigateDialog(
                                    dialog: CustomBlurryDialog(
                                      title: lang.configure,
                                      horizontalInset: 38.0,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12.0),
                                      actions: [
                                        NamidaIconButton(
                                          icon: Broken.refresh,
                                          onPressed: () {
                                            const val = 1.0;
                                            Player.inst.setPitch(val);
                                            Player.inst.setSpeed(val);
                                            Player.inst.setVolume(val);
                                            settings.player.save(
                                              pitch: val,
                                              speed: val,
                                              volume: val,
                                            );
                                          },
                                        ),
                                        const DoneButton(),
                                      ],
                                      child: const SoundControlMainSlidersColumn(
                                        verticalInBetweenPadding: 6.0,
                                        tapToUpdate: false,
                                        isInDialog: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 8.0),
                          Flexible(
                            child: focusedMenuBuilder,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
    return scale == 1.0 ? chip : _ScaleLayoutBox(scale: scale, child: chip);
  }
}

// ========= UI UTILS =========
const _perfectHeight = 540.0;

double _lerpDouble(double a, double b, double t) {
  if (a == b || (a.isNaN && b.isNaN)) {
    return a;
  }
  return a * (1.0 - t) + b * t;
}

// ===========================

/// The key [ArtworkWidget] caches an item's decoded artwork ratio under.
Object? playableArtworkCacheKey(Playable item) => item.execute<Object?>(
  selectable: (finalItem) => finalItem.track.pathToImage,
  youtubeID: (finalItem) => null,
);

/// Aspect ratio the item's picture is going to render at, so its box can match it
/// instead of letterboxing wide videos & thumbnails inside a square.
///
/// The video's own ratio once initialized, else the decoded artwork ratio (known after
/// it resolved once), else the 16:9 youtube thumbnails always are, else square.
double resolvePlayableImageAspectRatio(Playable item, double? videoAspectRatio) {
  if (videoAspectRatio != null && videoAspectRatio > 0) return videoAspectRatio;
  if (settings.forceSquaredTrackThumbnail.value) return 1.0;
  final cached = ArtworkWidget.aspectRatioOf(playableArtworkCacheKey(item));
  if (cached != null && cached > 0) return cached;
  if (item is YoutubeID) return 16 / 9;
  return 1.0;
}
