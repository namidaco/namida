// ignore_for_file: unused_element, unused_element_parameter
// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:playlist_manager/class/favourite_playlist.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/extensions.dart';

import 'package:namida/base/yt_video_like_manager.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/focused_menu.dart';
import 'package:namida/packages/miniplayer_raw.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/pages/equalizer_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/waveform.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';

class FocusedMenuOptions {
  final bool Function(Playable currentItem) onOpen;
  final void Function(Playable currentItem) onPressed;
  final Widget Function(Playable currentItem, double size, Color color) videoIconBuilder;
  final Widget Function(Playable currentItem) builder;
  final RxList<NamidaVideo> localVideos;
  final String? Function(Playable item) currentId;
  final Rxn<VideoStreamsResult> streams;
  final Future<void> Function(Playable item)? loadQualities;
  final void Function(Playable item)? onSearch;
  final Future<void> Function(Playable item, NamidaVideo video) onLocalVideoTap;
  final Future<void> Function(Playable item, String? videoId, VideoStream stream, File? cacheFile, VideoStreamsResult? mainStreams) onStreamVideoTap;

  const FocusedMenuOptions({
    required this.onOpen,
    required this.onPressed,
    required this.videoIconBuilder,
    required this.builder,
    required this.currentId,
    required this.localVideos,
    required this.streams,
    required this.loadQualities,
    required this.onSearch,
    required this.onLocalVideoTap,
    required this.onStreamVideoTap,
  });
}

class MiniplayerInfoData<E, S> {
  final String firstLine;
  final String secondLine;
  final FavouritePlaylist<Playable, E, S> favouritePlaylist;
  final E itemToLike;
  final Future<bool> Function(bool isLiked) onLikeTap;
  final void Function() onShowAddToPlaylistDialog;
  final void Function(TapUpDetails details) onMenuOpen;
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
    required this.likedIcon,
    required this.normalIcon,
    this.ytLikeManager,
  })  : firstLineGood = firstLine.isNotEmpty,
        secondLineGood = secondLine.isNotEmpty;
}

class NamidaMiniPlayerBase<E, S> extends StatefulWidget {
  final double? queueItemExtent;
  final double? Function(Playable item)? queueItemExtentBuilder;
  final (Widget, Key) Function(BuildContext context, int index, int currentIndex, List<Playable> queue, TrackTileProperties? properties, VideoTileProperties? videoTileProperties)
      itemBuilder;
  final int Function(Playable currentItem)? getDurationMS;
  final String Function(int number, Playable item) itemsKeyword;
  final void Function(Playable currentItem) onAddItemsTap;
  final String Function(Playable currentItem) topText;
  final void Function(Playable currentItem) onTopTextTap;
  final void Function(Playable currentItem, TapUpDetails details) onMenuOpen;
  final FocusedMenuOptions Function(Playable item) focusedMenuOptions;
  final Widget Function(Playable item, double cp) imageBuilder;
  final Widget Function(Playable item, double bcp) currentImageBuilder;
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
  State<NamidaMiniPlayerBase> createState() => _NamidaMiniPlayerBaseState();
}

class _NamidaMiniPlayerBaseState extends State<NamidaMiniPlayerBase> {
  final isMenuOpened = false.obs;
  final isLoadingMore = false.obs;
  static const animationDuration = Duration(milliseconds: 150);

  Playable<Object> get _getcurrentItem => Player.inst.currentQueue.value[Player.inst.currentIndex.value];

  @override
  void dispose() {
    isMenuOpened.close();
    isLoadingMore.close();
    super.dispose();
  }

  int refine(int index) {
    if (index <= -1) {
      return Player.inst.currentQueue.value.length - 1;
    } else if (index >= Player.inst.currentQueue.value.length) {
      return 0;
    } else {
      return index;
    }
  }

  Widget _queueItemBuilder(BuildContext context, int i, int currentIndex, List<Playable> queue,
      {TrackTileProperties? trackTileProperties, VideoTileProperties? videoTileProperties}) {
    final childWK = widget.itemBuilder(context, i, currentIndex, queue, trackTileProperties, videoTileProperties);
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

  @override
  Widget build(BuildContext context) {
    final onSecondary = context.theme.colorScheme.onSecondaryContainer;
    const waveformChild = RepaintBoundary(child: WaveformMiniplayer());

    final topRightButton = IconButton(
      onPressed: () {
        widget.onMenuOpen(
          _getcurrentItem,
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
          void tapUp(TapUpDetails details) => widget.onMenuOpen(_getcurrentItem, details);
          instance
            ..onTapUp = tapUp
            ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
        },
        child: Container(
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.secondary.withValues(alpha: .2),
            shape: BoxShape.circle,
          ),
          child: Icon(Broken.more, color: onSecondary),
        ),
      ),
      iconSize: 22.0,
    );

    final topLeftButton = IconButton(
      onPressed: MiniPlayerController.inst.snapToMini,
      icon: Icon(Broken.arrow_down_2, color: onSecondary),
      iconSize: 22.0,
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
    final positionTextChild = TapDetector(
      onTap: () => Player.inst.seekSecondsBackward(),
      child: LongPressDetector(
        onLongPress: () => Player.inst.seek(Duration.zero),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                (context) {
                  final seek = MiniPlayerController.inst.seekValue.valueR;
                  final diffInMs = seek - Player.inst.nowPlayingPositionR;
                  final plusOrMinus = diffInMs < 0 ? '' : '+';
                  final seekText = seek == 0 ? '00:00' : diffInMs.milliSecondsLabel;
                  return Text(
                    "$plusOrMinus$seekText",
                    style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0),
                  ).animateEntrance(
                    showWhen: seek != 0,
                    durationMS: 700,
                    allCurves: Curves.easeInOutQuart,
                  );
                },
              ),
              NamidaHero(
                tag: 'MINIPLAYER_POSITION',
                child: Obx(
                  (context) => Text(
                    Player.inst.nowPlayingPositionR.milliSecondsLabel,
                    style: context.textTheme.displaySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final buttonsRowChild = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      children: [
        const RepeatModeIconButton(),
        const EqualizerIconButton(),
        LongPressDetector(
          onLongPress: () {
            showLRCSetDialog(_getcurrentItem, CurrentColor.inst.miniplayerColor);
          },
          child: IconButton(
            visualDensity: VisualDensity.compact,
            style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
            onPressed: <T extends Playable>() {
              settings.save(enableLyrics: !settings.enableLyrics.value);
              Lyrics.inst.updateLyrics(_getcurrentItem);
            },
            icon: Obx(
              (context) => settings.enableLyrics.valueR
                  ? Lyrics.inst.currentLyricsText.valueR == '' && Lyrics.inst.currentLyricsLRC.valueR == null
                      ? StackedIcon(
                          baseIcon: Broken.document,
                          secondaryText: !Lyrics.inst.lyricsCanBeAvailable.valueR ? 'x' : '?',
                          iconSize: 20.0,
                          blurRadius: 6.0,
                          baseIconColor: context.theme.colorScheme.onSecondaryContainer,
                          secondaryIconColor: context.theme.colorScheme.onSecondaryContainer,
                        )
                      : Icon(
                          Broken.document,
                          size: 20.0,
                          color: context.theme.colorScheme.onSecondaryContainer,
                        )
                  : Icon(
                      Broken.card_slash,
                      size: 20.0,
                      color: context.theme.colorScheme.onSecondaryContainer,
                    ),
            ),
          ),
        ),
        IconButton(
          tooltip: lang.QUEUE,
          visualDensity: VisualDensity.compact,
          style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
          onPressed: MiniPlayerController.inst.snapToQueue,
          icon: Icon(
            Broken.row_vertical,
            size: 19.0,
            color: context.theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 6.0),
      ],
    );

    final maxQueueHeight = MiniPlayerController.inst.maxOffset - 100.0 - MiniPlayerController.inst.topInset - 12.0;

    Widget queueListChild;
    if (widget.trackTileConfigs != null) {
      queueListChild = TrackTilePropertiesProvider(
        configs: widget.trackTileConfigs!,
        builder: (properties) => _QueueListChildWrapper(
          queueItemExtent: widget.queueItemExtent,
          queueItemExtentBuilder: widget.queueItemExtentBuilder,
          itemBuilder: (context, index, currentIndex, queue) => _queueItemBuilder(context, index, currentIndex, queue, trackTileProperties: properties, videoTileProperties: null),
        ),
      );
    } else if (widget.videoTileConfigs != null) {
      queueListChild = VideoTilePropertiesProvider(
        configs: widget.videoTileConfigs!,
        builder: (properties) => _QueueListChildWrapper(
          queueItemExtent: widget.queueItemExtent,
          queueItemExtentBuilder: widget.queueItemExtentBuilder,
          itemBuilder: (context, index, currentIndex, queue) => _queueItemBuilder(context, index, currentIndex, queue, trackTileProperties: null, videoTileProperties: properties),
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
        child: SizedBox(
          height: context.height,
          width: context.width,
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
                width: context.width,
                height: kQueueBottomRowHeight + MediaQuery.paddingOf(context).bottom,
                decoration: BoxDecoration(
                  color: context.theme.scaffoldBackgroundColor,
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
                      scrollQueueWidget: (buttonStyle) => ObxO(
                        rx: MiniPlayerController.inst.arrowIcon,
                        builder: (context, arrow) => NamidaButton(
                          style: buttonStyle,
                          onPressed: MiniPlayerController.inst.animateQueueToCurrentTrack,
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
        return ObxO(
            rx: Player.inst.currentIndex,
            builder: (context, currentIndex) {
              final indminus = refine(currentIndex - 1);
              final indplus = refine(currentIndex + 1);
              final prevItem = queue.isEmpty ? null : queue[indminus];
              final currentItem = queue[currentIndex];
              final nextItem = queue.isEmpty ? null : queue[indplus];
              final currentDefaultDurationInMS = widget.getDurationMS?.call(currentItem) ?? 0;

              final prevText = prevItem == null ? null : widget.textBuilder(prevItem);
              final currentText = widget.textBuilder(currentItem);
              final nextText = nextItem == null ? null : widget.textBuilder(nextItem);

              final topText = widget.topText(currentItem);
              final focusedMenuOptions = widget.focusedMenuOptions(currentItem);
              final videoIconBuilder = focusedMenuOptions.videoIconBuilder(currentItem, 18.0, onSecondary);
              final focusedMenuBuilder = focusedMenuOptions.builder(currentItem);

              final topRowChild = RepaintBoundary(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        topLeftButton,
                        Expanded(
                          child: NamidaInkWell(
                            borderRadius: 14.0,
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            onTap: () => widget.onTopTextTap(_getcurrentItem),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${currentIndex + 1}/${queue.length}",
                                  style: TextStyle(
                                    color: onSecondary.withValues(alpha: .8),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  topText,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.0, color: onSecondary.withValues(alpha: .9)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        topRightButton,
                      ],
                    ),
                  ),
                ),
              );

              final positionDurationRowChild = Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  positionTextChild,
                  TapDetector(
                    onTap: () => Player.inst.seekSecondsForward(),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
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
                              style: context.textTheme.displaySmall,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );

              final bottomLeftButton = Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    FocusedMenuHolder(
                      options: (childOffset, childSize) {
                        return FocusedMenuDetails(
                          childOffset: childOffset,
                          childSize: childSize,
                          menuOpenAlignment: Alignment.bottomLeft,
                          bottomOffsetHeight: 12.0,
                          leftOffsetHeight: 4.0,
                          onMenuOpen: () {
                            // ScrollSearchController.inst.unfocusKeyboard(); // the miniplayer should have alr done that.
                            final canOpen = focusedMenuOptions.onOpen(_getcurrentItem);
                            isMenuOpened.value = canOpen;
                            return canOpen;
                          },
                          onMenuClose: () => isMenuOpened.value = false,
                          blurSize: 2.0,
                          duration: animationDuration,
                          animateMenuItems: false,
                          menuWidth: context.width * 0.5,
                          menuBoxDecoration: BoxDecoration(
                            color: context.theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                          ),
                          menuWidget: Obx(
                            (context) {
                              final currentId = focusedMenuOptions.currentId(currentItem);
                              final availableVideos = focusedMenuOptions.localVideos.valueR;
                              final ytVideos = focusedMenuOptions.streams.valueR?.videoStreams
                                  .withoutWebmIfNeccessaryOrExperimentalCodecs(allowExperimentalCodecs: settings.youtube.allowExperimentalCodecs);
                              return ListView(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                children: [
                                  if (currentId == null || currentId.isEmpty)
                                    _MPQualityButton(
                                      title: lang.SEARCH,
                                      icon: Broken.search_normal,
                                      bgColor: null,
                                      onTap: () {
                                        focusedMenuOptions.onSearch?.call(currentItem);
                                      },
                                    )
                                  else if (focusedMenuOptions.loadQualities != null)
                                    _MPQualityButton(
                                      title: lang.CHECK_FOR_MORE,
                                      icon: Broken.chart,
                                      bgColor: null,
                                      trailing: isLoadingMore.valueR ? const LoadingIndicator() : null,
                                      onTap: () async {
                                        isLoadingMore.value = true;
                                        await focusedMenuOptions.loadQualities!(currentItem);
                                        isLoadingMore.value = false;
                                      },
                                    ),
                                  ...availableVideos.map(
                                    (element) {
                                      final localOrCache = element.ytID == null ? lang.LOCAL : lang.CACHE;
                                      return Obx(
                                        (context) {
                                          final isCurrent = element.path == (VideoController.inst.currentVideo.valueR?.path ?? Player.inst.currentCachedVideo.valueR?.path);
                                          return _MPQualityButton(
                                            onTap: () => focusedMenuOptions.onLocalVideoTap(currentItem, element),
                                            bgColor: isCurrent ? CurrentColor.inst.miniplayerColor.withAlpha(20) : null,
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
                                  const NamidaContainerDivider(height: 2.0, margin: EdgeInsets.symmetric(vertical: 6.0)),
                                  ...?ytVideos?.map(
                                    (element) {
                                      final currentId = focusedMenuOptions.currentId(currentItem);
                                      final cacheFile = currentId == null ? null : element.getCachedFile(currentId);
                                      final cacheExists = cacheFile != null;
                                      var codecIdentifier = element.codecInfo.codecIdentifierIfCustom();
                                      var codecIdentifierText = codecIdentifier != null ? ' (${codecIdentifier.toUpperCase()})' : '';
                                      return _MPQualityButton(
                                        onTap: () => focusedMenuOptions.onStreamVideoTap(currentItem, currentId, element, cacheFile, focusedMenuOptions.streams.value),
                                        bgColor: cacheExists ? CurrentColor.inst.miniplayerColor.withAlpha(40) : null,
                                        icon: cacheExists ? Broken.tick_circle : Broken.import,
                                        title: "${element.qualityLabel} • ${element.sizeInBytes.fileSizeFormatted}",
                                        subtitle: "${element.codecInfo.container} • ${element.bitrateText()}$codecIdentifierText",
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
                                        color: context.theme.scaffoldBackgroundColor,
                                        borderRadius: BorderRadius.circular(24.0.multipliedRadius),
                                      )
                                    : BoxDecoration(
                                        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                      ),
                                child: TextButton(
                                  onPressed: () => focusedMenuOptions.onPressed(_getcurrentItem),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: context.theme.colorScheme.secondaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: NamidaIconButton(
                                            padding: const EdgeInsets.all(6.0),
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
                                                      style: context.textTheme.displayLarge,
                                                    ),
                                                    const SizedBox(width: 8.0),
                                                    NamidaButtonText(
                                                      toPercentage(value),
                                                      style: context.textTheme.displayMedium,
                                                    )
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
                                                  value: value.clamp(min, max),
                                                  onChanged: onChanged,
                                                  divisions: (max * 100).round(),
                                                  label: "${(value * 100).toStringAsFixed(0)}%",
                                                );
                                              }

                                              NamidaNavigator.inst.navigateDialog(
                                                dialog: CustomBlurryDialog(
                                                  title: lang.CONFIGURE,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                  actions: [
                                                    NamidaIconButton(
                                                      icon: Broken.refresh,
                                                      onPressed: () {
                                                        const val = 1.0;
                                                        Player.inst.setPlayerPitch(val);
                                                        Player.inst.setPlayerSpeed(val);
                                                        if (!settings.player.replayGain.value) Player.inst.setPlayerVolume(val);
                                                        settings.player.save(
                                                          pitch: val,
                                                          speed: val,
                                                          volume: settings.player.replayGain.value ? null : val,
                                                        );
                                                      },
                                                    ),
                                                    const DoneButton(),
                                                  ],
                                                  child: const EqualizerMainSlidersColumn(
                                                    verticalInBetweenPadding: 18.0,
                                                    tapToUpdate: false,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
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
                ),
              );

              final bottomRowChild = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
                child: Row(
                  children: [
                    bottomLeftButton,
                    buttonsRowChild,
                  ],
                ),
              );

              return MiniplayerRaw(
                builder: (maxOffset, bounceUp, bounceDown, topInset, bottomInset, screenSize, sAnim, sMaxOffset, stParallax, siParallax, p, cp, ip, icp, rp, rcp, qp, qcp, bp, bcp,
                    borderRadius, slowOpacity, opacity, fastOpacity, miniplayerbottomnavheight, bottomOffset, navBarHeight) {
                  final panelH = (maxOffset + navBarHeight - (100.0 + topInset + 4.0));
                  final panelExtra = panelH / 2.25 - navBarHeight - (100.0 + topInset + 4.0);
                  final panelFinal = panelH - (panelExtra * (1 - qcp));

                  final currentImage = widget.currentImageBuilder(currentItem, bcp);
                  final iconBoxSize = (velpy(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp;
                  final iconSize = (velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp;

                  final nextprevmultiplier = ((inverseAboveOne(p - 2.0) + 3.0) * (1 - qp)) - 1;
                  final nextPrevIconSize = 21.0 + 11.0 * nextprevmultiplier;
                  final nextPrevIconPadding = 8.0 + 4.0 * nextprevmultiplier;
                  final nextPrevOpacity = (nextprevmultiplier + 1).clamp(0.0, 1.0);

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
                                padding: EdgeInsets.symmetric(horizontal: 6 * (1 - cp * 10 + 9).clamp(0, 1), vertical: 12 * icp),
                                child: SizedBox(
                                  height: velpy(a: 82.0, b: panelFinal, c: cp),
                                  width: double.infinity,
                                  child: _AnimatedDecorationOrDecoration(
                                    duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                    decoration: BoxDecoration(
                                      color: context.theme.scaffoldBackgroundColor,
                                      borderRadius: borderRadius,
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.theme.shadowColor.withValues(alpha: 0.2 + 0.1 * cp),
                                          blurRadius: 20.0,
                                        )
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.bottomLeft,
                                      children: [
                                        Positioned.fill(
                                          child: AnimatedDecoration(
                                            duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                            // clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: CurrentColor.inst.miniplayerColor,
                                              borderRadius: borderRadius,
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Color.alphaBlend(context.theme.colorScheme.onSurface.withAlpha(100), CurrentColor.inst.miniplayerColor)
                                                      .withValues(alpha: velpy(a: .38, b: .28, c: icp)),
                                                  Color.alphaBlend(context.theme.colorScheme.onSurface.withAlpha(40), CurrentColor.inst.miniplayerColor)
                                                      .withValues(alpha: velpy(a: .1, b: .22, c: icp)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        /// Smol progress bar
                                        Obx(
                                          (context) {
                                            final nowPlayingPosition = Player.inst.nowPlayingPosition.valueR;
                                            final currentDurationInMS =
                                                currentDefaultDurationInMS > 0 ? currentDefaultDurationInMS : Player.inst.currentItemDuration.valueR?.inMilliseconds ?? 0;
                                            final w = currentDurationInMS > 0 ? nowPlayingPosition / currentDurationInMS : 0;
                                            return Container(
                                              height: 2 * (1 - cp),
                                              width: w > 0 ? ((context.width * w) * 0.9) : 0,
                                              margin: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: AnimatedDecoration(
                                                duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                                                decoration: BoxDecoration(
                                                  color: CurrentColor.inst.miniplayerColor,
                                                  borderRadius: BorderRadius.circular(50),
                                                  //  color: Color.alphaBlend(context.theme.colorScheme.onSurface.withAlpha(40), CurrentColor.inst.miniplayerColor)
                                                  //   .withValues(alpha: velpy(a: .3, b: .22, c: icp)),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (settings.enablePartyModeInMiniplayer.value)
                        NamidaOpacity(
                          opacity: cp,
                          child: partyContainersChild,
                        ),

                      /// Top Row
                      if (rcp > 0.0)
                        Material(
                          type: MaterialType.transparency,
                          child: NamidaOpacity(
                            opacity: rcp,
                            child: Transform.translate(
                              offset: Offset(0, (1 - bp) * -100),
                              child: topRowChild,
                            ),
                          ),
                        ),

                      /// Controls
                      Material(
                        type: MaterialType.transparency,
                        child: Transform.translate(
                          offset: Offset(
                              0,
                              (bottomOffset +
                                      (-maxOffset / 8.8 * bp) +
                                      ((-maxOffset + topInset + 80.0) *
                                          (!bounceUp
                                              ? !bounceDown
                                                  ? qp
                                                  : (1 - bp)
                                              : 0.0))) -
                                  (navBarHeight * cp)),
                          child: Padding(
                            padding: EdgeInsets.all(12.0 * icp),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  if (fastOpacity > 0.0)
                                    NamidaOpacity(
                                      opacity: fastOpacity,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 24.0 * (16 * (!bounceDown ? icp : 0.0) + 1)),
                                        child: positionDurationRowChild,
                                      ),
                                    ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20.0 * icp, horizontal: 2.0 * (1 - cp)).add(EdgeInsets.only(
                                        right: !bounceDown
                                            ? !bounceUp
                                                ? screenSize.width * rcp / 2 - (80 + 32.0 * 3) * rcp / 1.82 + (qp * 2.0)
                                                : screenSize.width * cp / 2 - (80 + 32.0 * 3) * cp / 1.82
                                            : screenSize.width * bcp / 2 - (80 + 32.0 * 3) * bcp / 1.82 + (qp * 2.0))),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Opacity(
                                          opacity: nextPrevOpacity,
                                          child: IgnorePointer(
                                            ignoring: nextPrevOpacity == 0.0,
                                            child: NamidaIconButton(
                                              icon: Broken.previous,
                                              iconSize: nextPrevIconSize,
                                              horizontalPadding: nextPrevIconPadding,
                                              verticalPadding: nextPrevIconPadding,
                                              onPressed: MiniPlayerController.inst.snapToPrev,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          key: const Key("playpause"),
                                          height: iconBoxSize,
                                          width: iconBoxSize,
                                          child: Center(
                                            child: Obx(
                                              (context) {
                                                final isButtonHighlighed = MiniPlayerController.inst.isPlayPauseButtonHighlighted.valueR;
                                                return TapDetector(
                                                  onTap: null,
                                                  initializer: (instance) {
                                                    instance.onTapDown = (_) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = true;
                                                    instance.onTapUp = (_) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = false;
                                                    instance.onTapCancel = () => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value =
                                                        !MiniPlayerController.inst.isPlayPauseButtonHighlighted.value;
                                                    instance.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
                                                  },
                                                  child: AnimatedScale(
                                                    duration: const Duration(milliseconds: 400),
                                                    scale: isButtonHighlighed ? 0.97 : 1.0,
                                                    child: AnimatedDecoration(
                                                      duration: const Duration(milliseconds: 400),
                                                      decoration: BoxDecoration(
                                                        color: isButtonHighlighed
                                                            ? Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(233), Colors.white)
                                                            : CurrentColor.inst.miniplayerColor,
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          colors: [
                                                            CurrentColor.inst.miniplayerColor,
                                                            Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(200), Colors.grey),
                                                          ],
                                                          stops: const [0, 0.7],
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: CurrentColor.inst.miniplayerColor.withAlpha(160),
                                                            blurRadius: 8.0,
                                                            spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                                                            offset: const Offset(0.0, 2.0),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          IconButton(
                                                            highlightColor: Colors.transparent,
                                                            onPressed: Player.inst.togglePlayPause,
                                                            icon: Padding(
                                                              padding: EdgeInsets.all(6.0 * cp * rcp),
                                                              child: ObxO(
                                                                rx: Player.inst.playWhenReady,
                                                                builder: (context, playWhenReady) => AnimatedSwitcher(
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
                                                            ),
                                                          ),
                                                          if (widget.canShowBuffering(currentItem))
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
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Opacity(
                                          opacity: nextPrevOpacity,
                                          child: IgnorePointer(
                                            ignoring: nextPrevOpacity == 0.0,
                                            child: NamidaIconButton(
                                              icon: Broken.next,
                                              iconSize: nextPrevIconSize,
                                              horizontalPadding: nextPrevIconPadding,
                                              verticalPadding: nextPrevIconPadding,
                                              onPressed: MiniPlayerController.inst.snapToNext,
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
                      Visibility(
                        maintainState: true,
                        visible: opacity > 0.0,
                        child: NamidaOpacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, -100 * ip),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SafeArea(
                                child: bottomRowChild,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /// Track Info
                      Material(
                        type: MaterialType.transparency,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: navBarHeight * cp),
                          child: AnimatedBuilder(
                            animation: sAnim,
                            builder: (context, child) {
                              final leftOpacity = -sAnim.value.clamp(-1.0, 0.0);
                              final rightOpacity = sAnim.value.clamp(0.0, 1.0);
                              return Stack(
                                children: [
                                  if (prevText != null && leftOpacity > 0)
                                    NamidaOpacity(
                                      opacity: leftOpacity,
                                      child: Transform.translate(
                                        offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                                        child: RepaintBoundary(
                                          child: _TrackInfo(
                                            textData: prevText,
                                            p: bp,
                                            qp: qp,
                                            cp: bcp,
                                            bottomOffset: bottomOffset,
                                            maxOffset: maxOffset,
                                            screenSize: screenSize,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Opacity(
                                    opacity: 1 - sAnim.value.abs(),
                                    child: Transform.translate(
                                      offset: Offset(
                                          -sAnim.value * sMaxOffset / stParallax + (12.0 * qp),
                                          (-maxOffset + topInset + 102.0) *
                                              (!bounceUp
                                                  ? !bounceDown
                                                      ? qp
                                                      : (1 - bp)
                                                  : 0.0)),
                                      child: RepaintBoundary(
                                        child: _TrackInfo(
                                          textData: currentText,
                                          p: bp,
                                          qp: qp,
                                          cp: bcp,
                                          bottomOffset: bottomOffset,
                                          maxOffset: maxOffset,
                                          screenSize: screenSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (nextText != null && rightOpacity > 0)
                                    NamidaOpacity(
                                      opacity: rightOpacity,
                                      child: Transform.translate(
                                        offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                                        child: RepaintBoundary(
                                          child: _TrackInfo(
                                            textData: nextText,
                                            p: bp,
                                            qp: qp,
                                            cp: bcp,
                                            bottomOffset: bottomOffset,
                                            maxOffset: maxOffset,
                                            screenSize: screenSize,
                                          ),
                                        ),
                                      ),
                                    )
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      /// Track Image
                      Padding(
                        padding: EdgeInsets.only(bottom: navBarHeight * cp),
                        child: AnimatedBuilder(
                          animation: sAnim,
                          builder: (context, child) {
                            final verticalOffset = !bounceUp ? (-maxOffset + topInset + 108.0) * (!bounceDown ? qp : (1 - bp)) : 0.0;
                            final horizontalOffset = -sAnim.value * sMaxOffset / siParallax;
                            final width = velpy(a: 82.0, b: 92.0, c: qp);
                            final leftOpacity = -sAnim.value.clamp(-1.0, 0.0);
                            final rightOpacity = sAnim.value.clamp(0.0, 1.0);
                            return Stack(
                              children: [
                                if (prevItem != null && leftOpacity > 0)
                                  NamidaOpacity(
                                    opacity: leftOpacity,
                                    child: Transform.translate(
                                      offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                                      child: RepaintBoundary(
                                        child: _RawImageContainer(
                                          cp: bcp,
                                          p: bp,
                                          width: width,
                                          screenSize: screenSize,
                                          bottomOffset: bottomOffset,
                                          maxOffset: maxOffset,
                                          child: widget.imageBuilder(prevItem, cp),
                                        ),
                                      ),
                                    ),
                                  ),
                                Opacity(
                                  opacity: 1 - sAnim.value.abs(),
                                  child: Transform.translate(
                                    offset: Offset(horizontalOffset, verticalOffset),
                                    child: RepaintBoundary(
                                      child: _RawImageContainer(
                                        cp: bcp,
                                        p: bp,
                                        width: width,
                                        screenSize: screenSize,
                                        bottomOffset: bottomOffset,
                                        maxOffset: maxOffset,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0 * (1 - bcp)),
                                          child: LongPressDetector(
                                            onLongPress: () => Lyrics.inst.lrcViewKey?.currentState?.enterFullScreen(),
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
                                ),
                                if (nextItem != null && rightOpacity > 0)
                                  NamidaOpacity(
                                    opacity: rightOpacity,
                                    child: Transform.translate(
                                      offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                                      child: RepaintBoundary(
                                        child: _RawImageContainer(
                                          cp: bcp,
                                          p: bp,
                                          width: width,
                                          screenSize: screenSize,
                                          bottomOffset: bottomOffset,
                                          maxOffset: maxOffset,
                                          child: widget.imageBuilder(nextItem, cp),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),

                      /// Slider
                      Visibility(
                        maintainState: false,
                        visible: slowOpacity > 0.0,
                        child: Opacity(
                          opacity: slowOpacity,
                          child: Transform.translate(
                            offset: Offset(
                                0,
                                (bottomOffset +
                                        (-maxOffset / 4.4 * p) +
                                        ((-maxOffset + topInset) *
                                            ((!bounceUp
                                                ? !bounceDown
                                                    ? qp
                                                    : (1 - bp)
                                                : 0.0)) *
                                            0.4)) -
                                    (navBarHeight * cp)),
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

                      Visibility(
                        maintainState: true, // cuz rebuilding from scratch almost kills raster
                        visible: qp > 0 && !bounceUp,
                        child: Opacity(
                          opacity: qp.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - qp) * maxQueueHeight),
                            child: queueChild,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            });
      },
    );
  }
}

class _RawImageContainer extends StatelessWidget {
  const _RawImageContainer({
    super.key,
    required this.child,
    required this.bottomOffset,
    required this.maxOffset,
    required this.screenSize,
    required this.cp,
    required this.p,
    required this.width,
  });

  final Widget child;
  final double width;
  final double bottomOffset;
  final double maxOffset;
  final Size screenSize;
  final double cp;
  final double p;

  @override
  Widget build(BuildContext context) {
    final size = velpy(a: width, b: screenSize.width.withMaximum(screenSize.height / 2) - 84.0, c: cp);
    final verticalOffset = bottomOffset + (-maxOffset / 2.15 * p.clamp(0, 2));
    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.only(left: 42.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            height: size,
            width: size,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TrackInfo<E, S> extends StatelessWidget {
  final MiniplayerInfoData<E, S> textData;
  final double cp;
  final double qp;
  final double p;
  final Size screenSize;
  final double bottomOffset;
  final double maxOffset;

  const _TrackInfo({
    super.key,
    required this.textData,
    required this.cp,
    required this.qp,
    required this.p,
    required this.screenSize,
    required this.bottomOffset,
    required this.maxOffset,
  });

  @override
  Widget build(BuildContext context) {
    final double opacity = (inverseAboveOne(p) * 10 - 9).clamp(0, 1);
    final ytLikeManager = textData.ytLikeManager;

    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 4.0 * p.clamp(0, 2))),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.symmetric(horizontal: 24.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0).add(EdgeInsets.only(bottom: velpy(a: 0, b: (screenSize.width.withMaximum(screenSize.height / 2)) / 9, c: cp))),
            child: SizedBox(
              height: velpy(a: 58.0, b: 82, c: cp),
              child: Row(
                children: [
                  SizedBox(width: 82.0 * (1 - cp)), // Image placeholder
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 32.0 + (82 * (1 - cp) * (1 - qp)) + (60 * qp)),
                            child: InkWell(
                              onTapUp: cp == 1 ? textData.onMenuOpen : null,
                              highlightColor: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withAlpha(20), context.theme.highlightColor),
                              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                              child: Padding(
                                padding: EdgeInsets.only(left: 8.0 * cp),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (textData.firstLineGood)
                                      Text(
                                        textData.firstLine,
                                        maxLines: textData.secondLine == '' ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: velpy(a: 14.5, b: 20.0, c: p),
                                        ),
                                      ),
                                    if (textData.firstLineGood && textData.secondLineGood) const SizedBox(height: 4.0),
                                    if (textData.secondLineGood)
                                      Text(
                                        textData.secondLine,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: velpy(a: 12.5, b: 15.0, c: p),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        NamidaOpacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(-100 * (1.0 - cp), 0.0),
                            child: RepaintBoundary(
                              child: LongPressDetector(
                                onLongPress: textData.onShowAddToPlaylistDialog,
                                child: ytLikeManager != null
                                    ? ObxO(
                                        rx: ytLikeManager.currentVideoLikeStatus,
                                        builder: (context, currentLikeStatus) {
                                          final isUserLiked = currentLikeStatus == LikeStatus.liked;
                                          return NamidaLoadingSwitcher(
                                            size: 32.0,
                                            builder: (loadingController) => NamidaRawLikeButton(
                                              isLiked: isUserLiked,
                                              likedIcon: textData.likedIcon,
                                              normalIcon: textData.normalIcon,
                                              size: 32.0,
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
                                          likedIcon: textData.likedIcon,
                                          normalIcon: textData.normalIcon,
                                          isLiked: favouritePlaylist.isSubItemFavourite(textData.itemToLike),
                                          onTap: textData.onLikeTap,
                                        ),
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
        ),
      ),
    );
  }
}

class WaveformMiniplayer extends StatelessWidget {
  final bool fixPadding;
  const WaveformMiniplayer({super.key, this.fixPadding = false});

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
    final percentageSwiped = deltax / maxWidth;
    final newSeek = percentageSwiped * _currentDurationInMS;
    MiniPlayerController.inst.seekValue.value = newSeek.toInt();
  }

  void onSeekEnd() {
    final ms = MiniPlayerController.inst.seekValue.value;
    Player.inst.seek(Duration(milliseconds: ms));
    MiniPlayerController.inst.seekValue.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      tag: 'MINIPLAYER_WAVEFORM',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: 64.0,
            child: Padding(
              padding: fixPadding ? const EdgeInsets.symmetric(horizontal: 16.0 / 2) : EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) => onSeekDragUpdate(details.localPosition.dx, constraints.maxWidth),
                onTapUp: (details) => onSeekEnd(),
                onTapCancel: () => MiniPlayerController.inst.seekValue.value = 0,
                onHorizontalDragUpdate: (details) => onSeekDragUpdate(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragEnd: (details) => onSeekEnd(),
                child: const WaveformComponent(),
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
  final Color? bgColor;
  final Widget? trailing;
  final double padding;
  final void Function()? onTap;

  const _MPQualityButton({
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.bgColor,
    this.trailing,
    this.padding = 4.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaInkWell(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      padding: EdgeInsets.all(padding),
      onTap: onTap,
      borderRadius: 8.0,
      width: context.width,
      bgColor: bgColor,
      child: Row(
        children: [
          Icon(icon, size: 18.0),
          const SizedBox(width: 6.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.displayMedium?.copyWith(
                    fontSize: 13.0,
                  ),
                ),
                if (subtitle != '')
                  Text(
                    subtitle,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: 13.0,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4.0),
            trailing!,
            const SizedBox(width: 4.0),
          ],
        ],
      ),
    );
  }
}

class _QueueListChildWrapper extends StatefulWidget {
  final double? queueItemExtent;
  final double? Function(Playable item)? queueItemExtentBuilder;
  final Widget Function(BuildContext context, int index, int currentIndex, List<Playable> queue) itemBuilder;

  const _QueueListChildWrapper({
    super.key,
    required this.queueItemExtent,
    required this.queueItemExtentBuilder,
    required this.itemBuilder,
  });

  @override
  State<_QueueListChildWrapper> createState() => _QueueListChildWrapperState();
}

class _QueueListChildWrapperState extends State<_QueueListChildWrapper> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {})); // attempt workaround for empty queue view
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final deviceBottomInsets = MediaQuery.paddingOf(context).bottom;
    return ObxO(
      rx: SelectedTracksController.inst.bottomPadding,
      builder: (context, selectedTracksPadding) {
        final padding = EdgeInsets.only(bottom: 8.0 + selectedTracksPadding + kQueueBottomRowHeight + deviceBottomInsets);
        return ObxO(
          key: const Key('minikuru'),
          rx: Player.inst.currentQueue,
          builder: (context, queue) {
            final queueLength = queue.length;
            if (queueLength == 0) return const SizedBox();
            return ObxO(
              rx: Player.inst.currentIndex,
              builder: (context, currentIndex) => CustomScrollView(
                controller: MiniPlayerController.inst.queueScrollController,
                slivers: [
                  NamidaSliverReorderableList(
                    itemCount: queueLength,
                    itemExtent: widget.queueItemExtent,
                    itemExtentBuilder: widget.queueItemExtentBuilder == null ? null : (index, d) => widget.queueItemExtentBuilder!(queue[index]),
                    onReorderStart: (index) => Player.inst.invokeQueueModifyLock(),
                    onReorderEnd: (index) => Player.inst.invokeQueueModifyLockRelease(),
                    onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                    onReorderCancel: () => Player.inst.invokeQueueModifyOnModifyCancel(),
                    itemBuilder: (context, i) => widget.itemBuilder(context, i, currentIndex, queue),
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

class _AnimatedDecorationOrDecoration extends StatelessWidget {
  final Duration duration;
  final Decoration decoration;
  final Widget child;

  const _AnimatedDecorationOrDecoration({
    super.key,
    required this.duration,
    required this.decoration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return settings.animatedTheme.value
        ? AnimatedDecoration(
            decoration: decoration,
            duration: duration,
            child: child,
          )
        : DecoratedBox(
            decoration: decoration,
            child: child,
          );
  }
}
