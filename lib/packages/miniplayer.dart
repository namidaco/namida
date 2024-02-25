// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'package:animated_background/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/focused_menu.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/packages/miniplayer_raw.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/video_widget.dart';
import 'package:namida/ui/widgets/waveform.dart';
import 'package:namida/youtube/youtube_miniplayer.dart';

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
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    MiniPlayerController.inst.updateScreenValues(context); // useful for updating after split screen & if landscape ever got supported.
    return Obx(
      () => AnimatedTheme(
        duration: const Duration(milliseconds: 300),
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
            const MiniPlayerSwitchers(),
          ],
        ),
      ),
    );
  }
}

class MiniPlayerSwitchers extends StatelessWidget {
  const MiniPlayerSwitchers({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: (Player.inst.nowPlayingTrack == kDummyTrack || Player.inst.currentQueue.isEmpty
            ? Player.inst.currentQueueYoutube.isNotEmpty
                ? const YoutubeMiniPlayer(key: Key('ytminiplayer'))
                : const SizedBox(key: Key('empty_miniplayer'))
            : const NamidaMiniPlayer(key: Key('actualminiplayer'))),
      ),
    );
  }
}

class NamidaMiniPlayer extends StatefulWidget {
  const NamidaMiniPlayer({super.key});

  @override
  State<NamidaMiniPlayer> createState() => _NamidaMiniPlayerState();
}

class _NamidaMiniPlayerState extends State<NamidaMiniPlayer> {
  final isMenuOpened = false.obs;
  final isLoadingMore = false.obs;
  static const animationDuration = Duration(milliseconds: 150);

  @override
  void dispose() {
    isMenuOpened.close();
    isLoadingMore.close();
    super.dispose();
  }

  int refine(int index) {
    if (index <= -1) {
      return Player.inst.currentQueue.length - 1;
    }
    if (index >= Player.inst.currentQueue.length) {
      return 0;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final onSecondary = context.theme.colorScheme.onSecondaryContainer;

    return MiniplayerRaw(
      constantChild: SafeArea(
        bottom: false,
        child: SizedBox(
          height: context.height,
          width: context.width,
          child: Stack(
            fit: StackFit.loose,
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: MiniPlayerController.inst.maxOffset - 100.0 - MiniPlayerController.inst.topInset - 12.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.0.multipliedRadius),
                    topRight: Radius.circular(32.0.multipliedRadius),
                  ),
                  child: Obx(
                    () {
                      final currentIndex = Player.inst.currentIndex;
                      return NamidaListView(
                        key: const Key('minikuru'),
                        itemExtents: List.filled(Player.inst.currentQueue.length, Dimensions.inst.trackTileItemExtent),
                        scrollController: MiniPlayerController.inst.queueScrollController,
                        padding: EdgeInsets.only(bottom: 8.0 + SelectedTracksController.inst.bottomPadding.value + kQueueBottomRowHeight + MediaQuery.paddingOf(context).bottom),
                        onReorderStart: (index) => MiniPlayerController.inst.invokeStartReordering(),
                        onReorderEnd: (index) => MiniPlayerController.inst.invokeDoneReordering(),
                        onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                        itemCount: Player.inst.currentQueue.length,
                        itemBuilder: (context, i) {
                          final track = Player.inst.currentQueue[i];
                          final key = "$i${track.track.path}";
                          return FadeDismissible(
                            key: Key("Diss_$key"),
                            onDismissed: (direction) {
                              Player.inst.removeFromQueue(i);
                              MiniPlayerController.inst.invokeDoneReordering();
                            },
                            onUpdate: (details) {
                              final isReordering = details.progress != 0.0;
                              if (isReordering) {
                                MiniPlayerController.inst.invokeStartReordering();
                              } else {
                                MiniPlayerController.inst.invokeDoneReordering();
                              }
                            },
                            child: TrackTile(
                              key: Key("tt_$key"),
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
                          );
                        },
                      );
                    },
                  ),
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
                    child: QueueUtilsRow(
                      itemsKeyword: (number) => number.displayTrackKeyword,
                      onAddItemsTap: () => _addTracksButtonTap(context),
                      scrollQueueWidget: Obx(
                        () => NamidaButton(
                          onPressed: MiniPlayerController.inst.animateQueueToCurrentTrack,
                          icon: MiniPlayerController.inst.arrowIcon.value,
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
      builder: (
        maxOffset,
        bounceUp,
        bounceDown,
        topInset,
        bottomInset,
        screenSize,
        sAnim,
        sMaxOffset,
        stParallax,
        siParallax,
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
        borderRadius,
        slowOpacity,
        opacity,
        fastOpacity,
        miniplayerbottomnavheight,
        bottomOffset,
        navBarHeight,
        constantChild,
      ) {
        final panelH = (maxOffset + navBarHeight - (100.0 + topInset + 4.0));
        final panelExtra = panelH / 2.25 - navBarHeight - (100.0 + topInset + 4.0);
        final panelFinal = panelH - (panelExtra * (1 - qcp));
        return Obx(
          () {
            final currentIndex = Player.inst.currentIndex;
            final indminus = refine(currentIndex - 1);
            final indplus = refine(currentIndex + 1);
            final prevTrack = Player.inst.currentQueue.isEmpty ? null : Player.inst.currentQueue[indminus];
            final currentTrack = Player.inst.nowPlayingTrack;
            final nextTrack = Player.inst.currentQueue.isEmpty ? null : Player.inst.currentQueue[indplus];
            final currentDuration = currentTrack.duration;
            final currentDurationInMS = currentDuration * 1000;
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
                          child: Container(
                            height: velpy(a: 82.0, b: panelFinal, c: cp),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.theme.scaffoldBackgroundColor,
                              borderRadius: borderRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: context.theme.shadowColor.withOpacity(0.2 + 0.1 * cp),
                                  blurRadius: 20.0,
                                )
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.bottomLeft,
                              children: [
                                Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: CurrentColor.inst.miniplayerColor,
                                    borderRadius: borderRadius,
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(100), CurrentColor.inst.miniplayerColor)
                                            .withOpacity(velpy(a: .38, b: .28, c: icp)),
                                        Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.miniplayerColor)
                                            .withOpacity(velpy(a: .1, b: .22, c: icp)),
                                      ],
                                    ),
                                  ),
                                ),

                                /// Smol progress bar
                                Obx(
                                  () {
                                    final w = Player.inst.nowPlayingPosition / currentDurationInMS;
                                    return Container(
                                      height: 2 * (1 - cp),
                                      width: w > 0 ? ((Get.width * w) * 0.9) : 0,
                                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                                      decoration: BoxDecoration(
                                        color: CurrentColor.inst.miniplayerColor,
                                        borderRadius: BorderRadius.circular(50),
                                        //  color: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.miniplayerColor)
                                        //   .withOpacity(velpy(a: .3, b: .22, c: icp)),
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
                if (settings.enablePartyModeInMiniplayer.value)
                  NamidaOpacity(
                    opacity: cp,
                    child: const Stack(
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
                  ),

                /// Top Row
                if (rcp > 0.0)
                  Material(
                    type: MaterialType.transparency,
                    child: NamidaOpacity(
                      opacity: rcp,
                      child: Transform.translate(
                        offset: Offset(0, (1 - bp) * -100),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: MiniPlayerController.inst.snapToMini,
                                  icon: Icon(Broken.arrow_down_2, color: onSecondary),
                                  iconSize: 22.0,
                                ),
                                Expanded(
                                  child: NamidaInkWell(
                                    borderRadius: 14.0,
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    onTap: () => NamidaOnTaps.inst.onAlbumTap(currentTrack.albumIdentifier),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "${currentIndex + 1}/${Player.inst.currentQueue.length}",
                                          style: TextStyle(
                                            color: onSecondary.withOpacity(.8),
                                            fontSize: 12.0.multipliedFontScale,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          currentTrack.album,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.0.multipliedFontScale, color: onSecondary.withOpacity(.9)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    NamidaDialogs.inst.showTrackDialog(currentTrack, source: QueueSource.playerQueue);
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(4.0),
                                    decoration: BoxDecoration(
                                      color: context.theme.colorScheme.secondary.withOpacity(.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Broken.more, color: onSecondary),
                                  ),
                                  iconSize: 22.0,
                                ),
                              ],
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () => Player.inst.seekSecondsBackward(),
                                        onLongPress: () => Player.inst.seek(Duration.zero),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Obx(
                                                () {
                                                  final seek = MiniPlayerController.inst.seekValue.value;
                                                  final diffInMs = seek - Player.inst.nowPlayingPosition;
                                                  final plusOrMinus = diffInMs < 0 ? '' : '+';
                                                  final seekText = seek == 0 ? '00:00' : diffInMs.abs().milliSecondsLabel;
                                                  return Text(
                                                    "$plusOrMinus$seekText",
                                                    style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0.multipliedFontScale),
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
                                                  () => Text(
                                                    Player.inst.nowPlayingPosition.milliSecondsLabel,
                                                    style: context.textTheme.displaySmall,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      TapDetector(
                                        onTap: () => Player.inst.seekSecondsForward(),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: NamidaHero(
                                            tag: 'MINIPLAYER_DURATION',
                                            child: Obx(
                                              () {
                                                final displayRemaining = settings.player.displayRemainingDurInsteadOfTotal.value;
                                                final toSubtract = displayRemaining ? Player.inst.nowPlayingPosition : 0;
                                                final msToDisplay = currentDurationInMS - toSubtract;
                                                final prefix = displayRemaining ? '-' : '';
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
                                  ),
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
                                  NamidaIconButton(
                                    icon: Broken.previous,
                                    iconSize: 22.0 + 10 * rcp,
                                    onPressed: MiniPlayerController.inst.snapToPrev,
                                  ),
                                  SizedBox(width: 7 * rcp),
                                  SizedBox(
                                    key: const Key("playpause"),
                                    height: (velpy(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp,
                                    width: (velpy(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp,
                                    child: Center(
                                      child: Obx(
                                        () {
                                          final isButtonHighlighed = MiniPlayerController.inst.isPlayPauseButtonHighlighted.value;
                                          return GestureDetector(
                                            onTapDown: (value) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = true,
                                            onTapUp: (value) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = false,
                                            onTapCancel: () =>
                                                MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = !MiniPlayerController.inst.isPlayPauseButtonHighlighted.value,
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
                                                child: IconButton(
                                                  highlightColor: Colors.transparent,
                                                  onPressed: () => Player.inst.togglePlayPause(),
                                                  icon: Padding(
                                                    padding: EdgeInsets.all(6.0 * cp * rcp),
                                                    child: Obx(
                                                      () => AnimatedSwitcher(
                                                        duration: const Duration(milliseconds: 200),
                                                        child: Player.inst.isPlaying
                                                            ? Icon(
                                                                Broken.pause,
                                                                size: (velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp,
                                                                key: const Key("pauseicon"),
                                                                color: Colors.white.withAlpha(180),
                                                              )
                                                            : Icon(
                                                                Broken.play,
                                                                size: (velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp,
                                                                key: const Key("playicon"),
                                                                color: Colors.white.withAlpha(180),
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 7 * rcp),
                                  NamidaIconButton(
                                    icon: Broken.next,
                                    iconSize: 22.0 + 10 * rcp,
                                    onPressed: MiniPlayerController.inst.snapToNext,
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
                if (opacity > 0.0)
                  NamidaOpacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, -100 * ip),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      FocusedMenuHolder(
                                        menuOpenAlignment: Alignment.bottomLeft,
                                        bottomOffsetHeight: 12.0,
                                        leftOffsetHeight: 4.0,
                                        onMenuOpen: () {
                                          if (settings.enableVideoPlayback.value) {
                                            isMenuOpened.value = true;
                                            return true;
                                          } else {
                                            ScrollSearchController.inst.unfocusKeyboard();
                                            NamidaNavigator.inst.navigateDialog(dialog: const Dialog(child: PlaybackSettings(isInDialog: true)));
                                            return false;
                                          }
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
                                          () {
                                            final availableVideos = VideoController.inst.currentPossibleVideos;
                                            final ytVideos = VideoController.inst.currentYTQualities.where((s) => s.formatSuffix != 'webm');
                                            return ListView(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                                              children: [
                                                _MPQualityButton(
                                                  title: lang.CHECK_FOR_MORE,
                                                  icon: Broken.chart,
                                                  bgColor: null,
                                                  trailing: isLoadingMore.value ? const LoadingIndicator() : null,
                                                  onTap: () async {
                                                    isLoadingMore.value = true;
                                                    await VideoController.inst.fetchYTQualities(currentTrack);
                                                    isLoadingMore.value = false;
                                                  },
                                                ),
                                                ...availableVideos.map(
                                                  (element) {
                                                    final localOrCache = element.ytID == null ? lang.LOCAL : lang.CACHE;
                                                    return Obx(
                                                      () {
                                                        final currentVideo = VideoController.inst.currentVideo.value;
                                                        final isCurrent = element.path == currentVideo?.path;
                                                        return _MPQualityButton(
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
                                                          onTap: () {
                                                            VideoController.inst.playVideoCurrent(video: element, track: currentTrack);
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                                const NamidaContainerDivider(height: 2.0, margin: EdgeInsets.symmetric(vertical: 6.0)),
                                                ...ytVideos.map(
                                                  (element) {
                                                    return Obx(
                                                      () {
                                                        final currentVideo = VideoController.inst.currentVideo.value;
                                                        final cacheFile = currentVideo?.ytID == null ? null : element.getCachedFile(currentVideo!.ytID!);
                                                        final cacheExists = cacheFile != null;
                                                        return _MPQualityButton(
                                                          onTap: () async {
                                                            if (!cacheExists) await VideoController.inst.getVideoFromYoutubeAndUpdate(currentVideo?.ytID, stream: element);
                                                            VideoController.inst.playVideoCurrent(
                                                                video: null, cacheIdAndPath: (currentVideo?.ytID ?? '', cacheFile?.path ?? ''), track: currentTrack);
                                                          },
                                                          bgColor: cacheExists ? CurrentColor.inst.miniplayerColor.withAlpha(40) : null,
                                                          icon: cacheExists ? Broken.tick_circle : Broken.import,
                                                          title: "${element.resolution} • ${element.sizeInBytes?.fileSizeFormatted}",
                                                          subtitle: "${element.formatSuffix} • ${element.bitrateText}",
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        child: Stack(
                                          alignment: Alignment.centerLeft,
                                          children: [
                                            Obx(
                                              () {
                                                final videoPlaybackEnabled = settings.enableVideoPlayback.value;
                                                final currentVideo = VideoController.inst.currentVideo.value;
                                                final downloadedBytes = VideoController.inst.currentDownloadedBytes.value;
                                                final videoTotalSize = currentVideo?.sizeInBytes ?? 0;
                                                final videoQuality = currentVideo?.resolution ?? 0;
                                                final videoFramerate = currentVideo?.framerateText(30);
                                                final markText = VideoController.inst.isNoVideosAvailable.value ? 'x' : '?';
                                                final fallbackQualityLabel = currentVideo?.nameInCache?.split('_').last;
                                                final qualityText = videoQuality == 0 ? fallbackQualityLabel ?? markText : '${videoQuality}p';
                                                final framerateText = videoFramerate ?? '';
                                                return AnimatedDecoration(
                                                  duration: animationDuration,
                                                  decoration: isMenuOpened.value
                                                      ? BoxDecoration(
                                                          color: context.theme.scaffoldBackgroundColor,
                                                          borderRadius: BorderRadius.circular(24.0.multipliedRadius),
                                                        )
                                                      : BoxDecoration(
                                                          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                                        ),
                                                  child: TextButton(
                                                    onPressed: () async => await VideoController.inst.toggleVideoPlayback(),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.all(6.0),
                                                          decoration: BoxDecoration(
                                                            color: context.theme.colorScheme.secondaryContainer,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: NamidaIconButton(
                                                            horizontalPadding: 0.0,
                                                            onPressed: () {
                                                              String toPercentage(double val) => "${(val * 100).toStringAsFixed(0)}%";

                                                              Widget getTextWidget(IconData icon, String title, double value) {
                                                                return Row(
                                                                  children: [
                                                                    Icon(icon, color: context.defaultIconColor()),
                                                                    const SizedBox(width: 12.0),
                                                                    Text(
                                                                      title,
                                                                      style: context.textTheme.displayLarge,
                                                                    ),
                                                                    const SizedBox(width: 8.0),
                                                                    Text(
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
                                                                  divisions: 100,
                                                                  label: "${(value * 100).toStringAsFixed(0)}%",
                                                                );
                                                              }

                                                              NamidaNavigator.inst.navigateDialog(
                                                                dialog: CustomBlurryDialog(
                                                                  title: lang.CONFIGURE,
                                                                  actions: [
                                                                    NamidaIconButton(
                                                                      icon: Broken.refresh,
                                                                      onPressed: () {
                                                                        const val = 1.0;
                                                                        Player.inst.setPlayerPitch(val);
                                                                        Player.inst.setPlayerSpeed(val);
                                                                        Player.inst.setPlayerVolume(val);
                                                                        settings.player.save(
                                                                          pitch: val,
                                                                          speed: val,
                                                                          volume: val,
                                                                        );
                                                                      },
                                                                    ),
                                                                    NamidaButton(
                                                                      text: lang.DONE,
                                                                      onPressed: () {
                                                                        NamidaNavigator.inst.closeDialog();
                                                                      },
                                                                    )
                                                                  ],
                                                                  child: ListView(
                                                                    padding: const EdgeInsets.all(12.0),
                                                                    shrinkWrap: true,
                                                                    children: [
                                                                      Obx(() => getTextWidget(Broken.airpods, lang.PITCH, settings.player.pitch.value)),
                                                                      Obx(
                                                                        () => getSlider(
                                                                          value: settings.player.pitch.value,
                                                                          onChanged: (value) {
                                                                            Player.inst.setPlayerPitch(value);
                                                                            settings.player.save(pitch: value);
                                                                          },
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 12.0),
                                                                      Obx(
                                                                        () => getTextWidget(Broken.forward, lang.SPEED, settings.player.speed.value),
                                                                      ),
                                                                      Obx(
                                                                        () => getSlider(
                                                                          value: settings.player.speed.value,
                                                                          onChanged: (value) {
                                                                            Player.inst.setPlayerSpeed(value);
                                                                            settings.player.save(speed: value);
                                                                          },
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 12.0),
                                                                      Obx(
                                                                        () => getTextWidget(settings.player.volume.value > 0 ? Broken.volume_high : Broken.volume_slash,
                                                                            lang.VOLUME, settings.player.volume.value),
                                                                      ),
                                                                      Obx(
                                                                        () => getSlider(
                                                                          max: 1.0,
                                                                          value: settings.player.volume.value,
                                                                          onChanged: (value) {
                                                                            Player.inst.setPlayerVolume(value);
                                                                            settings.player.save(volume: value);
                                                                          },
                                                                        ),
                                                                      ),
                                                                      const SizedBox(height: 12.0),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            icon: videoPlaybackEnabled ? Broken.video : Broken.headphone,
                                                            iconSize: 18.0,
                                                            iconColor: onSecondary,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8.0),
                                                        Flexible(
                                                          child: !videoPlaybackEnabled
                                                              ? RichText(
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  text: TextSpan(
                                                                    text: lang.AUDIO,
                                                                    style: context.textTheme.labelLarge?.copyWith(color: context.theme.colorScheme.onSecondaryContainer),
                                                                    children: [
                                                                      if (settings.displayAudioInfoMiniplayer.value)
                                                                        TextSpan(
                                                                          text: " • ${currentTrack.audioInfoFormattedCompact}",
                                                                          style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 10.0.multipliedFontScale),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : RichText(
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  text: TextSpan(
                                                                    text: lang.VIDEO,
                                                                    style: context.textTheme.labelLarge?.copyWith(color: context.theme.colorScheme.onSecondaryContainer),
                                                                    children: [
                                                                      if (qualityText == '?' && !ConnectivityController.inst.hasConnection) ...[
                                                                        TextSpan(text: " • ", style: TextStyle(color: onSecondary, fontSize: 13.0.multipliedFontScale)),
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
                                                                            fontSize: 13.0.multipliedFontScale,
                                                                          ),
                                                                        ),
                                                                      // --
                                                                      if (videoTotalSize > 0) ...[
                                                                        TextSpan(
                                                                            text: " • ",
                                                                            style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 13.0.multipliedFontScale)),
                                                                        TextSpan(
                                                                          text: downloadedBytes == null
                                                                              ? videoTotalSize.fileSizeFormatted
                                                                              : "${downloadedBytes.fileSizeFormatted}/${videoTotalSize.fileSizeFormatted}",
                                                                          style: TextStyle(color: onSecondary, fontSize: 10.0.multipliedFontScale),
                                                                        ),
                                                                      ],
                                                                    ],
                                                                  ),
                                                                ),
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
                                ),
                                // -- Buttons Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    const RepeatModeIconButton(),
                                    const EqualizerIconButton(),
                                    GestureDetector(
                                      onLongPress: () {
                                        showLRCSetDialog(currentTrack, CurrentColor.inst.miniplayerColor);
                                      },
                                      child: IconButton(
                                        visualDensity: VisualDensity.compact,
                                        style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                        padding: const EdgeInsets.all(2.0),
                                        onPressed: () {
                                          settings.save(enableLyrics: !settings.enableLyrics.value);
                                          Lyrics.inst.updateLyrics(currentTrack);
                                        },
                                        icon: Obx(
                                          () => settings.enableLyrics.value
                                              ? Lyrics.inst.currentLyricsText.value == '' && Lyrics.inst.currentLyricsLRC.value == null
                                                  ? StackedIcon(
                                                      baseIcon: Broken.document,
                                                      secondaryText: !Lyrics.inst.lyricsCanBeAvailable.value ? 'x' : '?',
                                                      iconSize: 20.0,
                                                      blurRadius: 6.0,
                                                      baseIconColor: context.theme.colorScheme.onSecondaryContainer,
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
                                      padding: const EdgeInsets.all(2.0),
                                      onPressed: MiniPlayerController.inst.snapToQueue,
                                      icon: Icon(
                                        Broken.row_vertical,
                                        size: 19.0,
                                        color: context.theme.colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 6.0),
                                  ],
                                )
                              ],
                            ),
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
                            if (prevTrack != null && leftOpacity > 0)
                              NamidaOpacity(
                                opacity: leftOpacity,
                                child: Transform.translate(
                                  offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                                  child: _TrackInfo(
                                    trackPre: prevTrack.track,
                                    p: bp,
                                    cp: bcp,
                                    bottomOffset: bottomOffset,
                                    maxOffset: maxOffset,
                                    screenSize: screenSize,
                                  ),
                                ),
                              ),
                            NamidaOpacity(
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
                                child: _TrackInfo(
                                  trackPre: currentTrack,
                                  p: bp,
                                  cp: bcp,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  screenSize: screenSize,
                                ),
                              ),
                            ),
                            if (nextTrack != null && rightOpacity > 0)
                              NamidaOpacity(
                                opacity: rightOpacity,
                                child: Transform.translate(
                                  offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                                  child: _TrackInfo(
                                    trackPre: nextTrack.track,
                                    p: bp,
                                    cp: bcp,
                                    bottomOffset: bottomOffset,
                                    maxOffset: maxOffset,
                                    screenSize: screenSize,
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
                          if (prevTrack != null && leftOpacity > 0)
                            NamidaOpacity(
                              opacity: leftOpacity,
                              child: Transform.translate(
                                offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                                child: _RawImageContainer(
                                  cp: bcp,
                                  p: bp,
                                  width: width,
                                  screenSize: screenSize,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  child: _TrackImage(
                                    track: prevTrack.track,
                                    cp: cp,
                                  ),
                                ),
                              ),
                            ),
                          NamidaOpacity(
                            opacity: 1 - sAnim.value.abs(),
                            child: Transform.translate(
                              offset: Offset(horizontalOffset, verticalOffset),
                              child: _RawImageContainer(
                                cp: bcp,
                                p: bp,
                                width: width,
                                screenSize: screenSize,
                                bottomOffset: bottomOffset,
                                maxOffset: maxOffset,
                                child: _AnimatingTrackImage(
                                  key: ValueKey(currentTrack),
                                  track: currentTrack,
                                  cp: bcp,
                                ),
                              ),
                            ),
                          ),
                          if (nextTrack != null && rightOpacity > 0)
                            NamidaOpacity(
                              opacity: rightOpacity,
                              child: Transform.translate(
                                offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                                child: _RawImageContainer(
                                  cp: bcp,
                                  p: bp,
                                  width: width,
                                  screenSize: screenSize,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  child: _TrackImage(
                                    track: nextTrack.track,
                                    cp: cp,
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
                if (slowOpacity > 0.0)
                  Opacity(
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
                          child: WaveformMiniplayer(),
                        ),
                      ),
                    ),
                  ),

                if (qp > 0 && !bounceUp)
                  Opacity(
                    opacity: qp.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - qp) * maxOffset * 0.8),
                      child: constantChild,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _addTracksButtonTap(BuildContext context) {
    final currentTrack = Player.inst.nowPlayingTrack;
    showAddItemsToQueueDialog(
      context: context,
      tiles: (getAddTracksTile) {
        return [
          getAddTracksTile(
            title: lang.NEW_TRACKS_RANDOM,
            subtitle: lang.NEW_TRACKS_RANDOM_SUBTITLE,
            icon: Broken.format_circle,
            insertionType: QueueInsertionType.random,
            onTap: (insertionType) {
              final config = insertionType.toQueueInsertion();
              final count = config.numberOfTracks;
              final rt = NamidaGenerator.inst.getRandomTracks(exclude: currentTrack, min: count - 1, max: count);
              Player.inst.addToQueue(rt, insertionType: insertionType, emptyTracksMessage: lang.NO_ENOUGH_TRACKS).closeDialog();
            },
          ),
          getAddTracksTile(
            title: lang.GENERATE_FROM_DATES,
            subtitle: lang.GENERATE_FROM_DATES_SUBTITLE,
            icon: Broken.calendar,
            insertionType: QueueInsertionType.listenTimeRange,
            onTap: (insertionType) {
              NamidaNavigator.inst.closeDialog();
              final historyTracks = HistoryController.inst.historyTracks;
              if (historyTracks.isEmpty) {
                snackyy(title: lang.NOTE, message: lang.NO_TRACKS_IN_HISTORY);
                return;
              }
              showCalendarDialog(
                title: lang.GENERATE_FROM_DATES,
                buttonText: lang.GENERATE,
                useHistoryDates: true,
                onGenerate: (dates) {
                  final tracks = NamidaGenerator.inst.generateItemsFromHistoryDates(dates.firstOrNull, dates.lastOrNull);
                  Player.inst
                      .addToQueue(
                        tracks,
                        insertionType: insertionType,
                        emptyTracksMessage: lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                      )
                      .closeDialog();
                },
              );
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_MOODS,
            subtitle: lang.NEW_TRACKS_MOODS_SUBTITLE,
            icon: Broken.emoji_happy,
            insertionType: QueueInsertionType.mood,
            onTap: (insertionType) async {
              NamidaNavigator.inst.closeDialog();

              // -- moods from playlists.
              final allAvailableMoodsPlaylists = <String, List<Track>>{};
              for (final pl in PlaylistController.inst.playlistsMap.entries) {
                pl.value.moods.loop((mood, _) {
                  allAvailableMoodsPlaylists.addAllNoDuplicatesForce(mood, pl.value.tracks.tracks);
                });
              }
              // -- moods from tracks.
              final allAvailableMoodsTracks = <String, List<Track>>{};
              for (final tr in Indexer.inst.trackStatsMap.entries) {
                tr.value.moods.loop((mood, _) {
                  allAvailableMoodsTracks.addNoDuplicatesForce(mood, tr.key);
                });
              }

              // -- moods from track embedded tag
              final library = allTracksInLibrary;
              for (final tr in library) {
                tr.moodList.loop((mood, _) {
                  allAvailableMoodsTracks.addNoDuplicatesForce(mood, tr);
                });
              }

              if (allAvailableMoodsPlaylists.isEmpty && allAvailableMoodsTracks.isEmpty) {
                snackyy(title: lang.ERROR, message: lang.NO_MOODS_AVAILABLE);
                return;
              }

              final playlistsAllMoods = allAvailableMoodsPlaylists.keys.toList();
              final tracksAllMoods = allAvailableMoodsTracks.keys.toList();

              final selectedmoodsPlaylists = <String>[].obs;
              final selectedmoodsTracks = <String>[].obs;

              List<Widget> getListy({
                required String title,
                required List<String> moodsList,
                required Map<String, List<Track>> allAvailableMoods,
                required List<String> selectedList,
              }) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text("$title (${moodsList.length})", style: context.textTheme.displayMedium),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Wrap(
                      children: [
                        ...moodsList.map(
                          (m) {
                            final tracksCount = allAvailableMoods[m]?.length ?? 0;
                            return NamidaInkWell(
                              borderRadius: 6.0,
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                              margin: const EdgeInsets.all(2.0),
                              bgColor: context.theme.cardColor,
                              onTap: () => selectedList.addOrRemove(m),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "$m ($tracksCount)",
                                    style: context.textTheme.displayMedium,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Obx(
                                    () => NamidaCheckMark(
                                      size: 12.0,
                                      active: selectedList.contains(m),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ];
              }

              await NamidaNavigator.inst.navigateDialog(
                onDisposing: () {
                  selectedmoodsPlaylists.close();
                  selectedmoodsTracks.close();
                },
                dialog: CustomBlurryDialog(
                  normalTitleStyle: true,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 48.0),
                  title: lang.MOODS,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.GENERATE,
                      onPressed: () {
                        final finalTracks = <Track>[];
                        selectedmoodsPlaylists.loop((m, _) {
                          finalTracks.addAll(allAvailableMoodsPlaylists[m] ?? []);
                        });
                        selectedmoodsTracks.loop((m, _) {
                          finalTracks.addAll(allAvailableMoodsTracks[m] ?? []);
                        });
                        Player.inst.addToQueue(
                          finalTracks.uniqued(),
                          insertionType: insertionType,
                        );
                        NamidaNavigator.inst.closeDialog();
                      },
                    ),
                  ],
                  child: SizedBox(
                    height: context.height * 0.4,
                    width: context.width,
                    child: CustomScrollView(
                      slivers: [
                        // -- Tracks moods (embedded & custom)
                        ...getListy(
                          title: lang.TRACKS,
                          moodsList: tracksAllMoods,
                          allAvailableMoods: allAvailableMoodsTracks,
                          selectedList: selectedmoodsTracks,
                        ),
                        // -- Playlist moods
                        ...getListy(
                          title: lang.PLAYLISTS,
                          moodsList: playlistsAllMoods,
                          allAvailableMoods: allAvailableMoodsPlaylists,
                          selectedList: selectedmoodsPlaylists,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_RATINGS,
            subtitle: lang.NEW_TRACKS_RATINGS_SUBTITLE,
            icon: Broken.happyemoji,
            insertionType: QueueInsertionType.rating,
            onTap: (insertionType) async {
              NamidaNavigator.inst.closeDialog();

              final RxInt minRating = 80.obs;
              final RxInt maxRating = 100.obs;
              await NamidaNavigator.inst.navigateDialog(
                onDisposing: () {
                  minRating.close();
                  maxRating.close();
                },
                dialog: CustomBlurryDialog(
                  normalTitleStyle: true,
                  title: lang.NEW_TRACKS_RATINGS,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.GENERATE,
                      onPressed: () {
                        if (minRating.value > maxRating.value) {
                          snackyy(title: lang.ERROR, message: lang.MIN_VALUE_CANT_BE_MORE_THAN_MAX);
                          return;
                        }
                        final tracks = NamidaGenerator.inst.generateTracksFromRatings(
                          minRating.value,
                          maxRating.value,
                        );
                        Player.inst.addToQueue(tracks, insertionType: insertionType);
                        NamidaNavigator.inst.closeDialog();
                      },
                    ),
                  ],
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(lang.MINIMUM),
                              const SizedBox(height: 24.0),
                              NamidaWheelSlider<int>(
                                totalCount: 100,
                                initValue: minRating.value,
                                itemSize: 1,
                                squeeze: 0.3,
                                onValueChanged: (val) {
                                  minRating.value = val;
                                },
                              ),
                              const SizedBox(height: 2.0),
                              Obx(
                                () => Text(
                                  '${minRating.value}%',
                                  style: context.textTheme.displaySmall,
                                ),
                              )
                            ],
                          ),
                          Column(
                            children: [
                              Text(lang.MAXIMUM),
                              const SizedBox(height: 24.0),
                              NamidaWheelSlider<int>(
                                totalCount: 100,
                                initValue: maxRating.value,
                                itemSize: 1,
                                squeeze: 0.3,
                                onValueChanged: (val) {
                                  maxRating.value = val;
                                },
                              ),
                              const SizedBox(height: 2.0),
                              Obx(
                                () => Text(
                                  '${maxRating.value}%',
                                  style: context.textTheme.displaySmall,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0)),
          getAddTracksTile(
            title: lang.NEW_TRACKS_SIMILARR_RELEASE_DATE,
            subtitle: lang.NEW_TRACKS_SIMILARR_RELEASE_DATE_SUBTITLE.replaceFirst(
              '_CURRENT_TRACK_',
              currentTrack.title.addDQuotation(),
            ),
            icon: Broken.calendar_1,
            insertionType: QueueInsertionType.sameReleaseDate,
            onTap: (insertionType) {
              final year = currentTrack.year;
              if (year == 0) {
                snackyy(title: lang.ERROR, message: lang.NEW_TRACKS_UNKNOWN_YEAR);
                return;
              }
              final tracks = NamidaGenerator.inst.generateTracksFromSameEra(year, currentTrack: currentTrack);
              Player.inst
                  .addToQueue(
                    tracks,
                    insertionType: insertionType,
                    emptyTracksMessage: lang.NO_TRACKS_FOUND_BETWEEN_DATES,
                  )
                  .closeDialog();
            },
          ),
          getAddTracksTile(
            title: lang.NEW_TRACKS_RECOMMENDED,
            subtitle: lang.NEW_TRACKS_RECOMMENDED_SUBTITLE.replaceFirst(
              '_CURRENT_TRACK_',
              currentTrack.title.addDQuotation(),
            ),
            icon: Broken.bezier,
            insertionType: QueueInsertionType.algorithm,
            onTap: (insertionType) {
              final gentracks = NamidaGenerator.inst.generateRecommendedTrack(currentTrack);

              Player.inst
                  .addToQueue(
                    gentracks,
                    insertionType: insertionType,
                    insertNext: true,
                    emptyTracksMessage: lang.NO_TRACKS_IN_HISTORY,
                  )
                  .closeDialog();
            },
          ),
        ];
      },
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
    // ignore: unused_element
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
                    fontSize: 13.0.multipliedFontScale,
                  ),
                ),
                if (subtitle != '')
                  Text(
                    subtitle,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: 13.0.multipliedFontScale,
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

class WaveformMiniplayer extends StatelessWidget {
  final bool fixPadding;
  const WaveformMiniplayer({super.key, this.fixPadding = false});

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      tag: 'MINIPLAYER_WAVEFORM',
      child: LayoutBuilder(
        builder: (context, constraints) {
          void onSeekDragUpdate(double deltax) {
            final percentageSwiped = deltax / constraints.maxWidth;
            final newSeek = percentageSwiped * Player.inst.nowPlayingTrack.duration * 1000;
            MiniPlayerController.inst.seekValue.value = newSeek.toInt();
          }

          void onSeekEnd() {
            final ms = MiniPlayerController.inst.seekValue.value;
            Player.inst.seek(Duration(milliseconds: ms));
            MiniPlayerController.inst.seekValue.value = 0;
          }

          return GestureDetector(
            onTapDown: (details) => onSeekDragUpdate(details.localPosition.dx),
            onTapUp: (details) => onSeekEnd(),
            onTapCancel: () => MiniPlayerController.inst.seekValue.value = 0,
            onHorizontalDragUpdate: (details) => onSeekDragUpdate(details.localPosition.dx),
            onHorizontalDragEnd: (details) => onSeekEnd(),
            child: WaveformComponent(
              key: const Key('waveform_widget'),
              color: context.theme.colorScheme.onBackground.withAlpha(40),
              barsColorOnTop: context.theme.colorScheme.onBackground.withAlpha(110),
              padding: fixPadding ? const EdgeInsets.symmetric(horizontal: 16.0 / 2) : null,
              widgetOnTop: (barsWidgetWithDiffColor) {
                return Obx(
                  () {
                    final seekValue = MiniPlayerController.inst.seekValue.value;
                    final position = seekValue != 0.0 ? seekValue : Player.inst.nowPlayingPosition;
                    final durInMs = Player.inst.nowPlayingTrack.duration * 1000;
                    final percentage = (position / durInMs).clamp(0.0, durInMs.toDouble());
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          tileMode: TileMode.decal,
                          stops: [0.0, percentage, percentage + 0.005, 1.0],
                          colors: [
                            Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(220), context.theme.colorScheme.onBackground),
                            Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(180), context.theme.colorScheme.onBackground),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ).createShader(bounds);
                      },
                      child: SizedBox(
                        width: Get.width - 16.0 / 2,
                        child: barsWidgetWithDiffColor,
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({
    Key? key,
    required this.trackPre,
    required this.cp,
    required this.p,
    required this.screenSize,
    required this.bottomOffset,
    required this.maxOffset,
  }) : super(key: key);

  final Track trackPre;
  final double cp;
  final double p;
  final Size screenSize;
  final double bottomOffset;
  final double maxOffset;

  @override
  Widget build(BuildContext context) {
    final double opacity = (inverseAboveOne(p) * 10 - 9).clamp(0, 1);
    final track = trackPre.toTrackExt();
    final title = track.title;
    final artist = track.originalArtist;

    String firstLine = '';
    String secondLine = '';

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

    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 4.0 * p.clamp(0, 2))),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.symmetric(horizontal: 24.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0).add(EdgeInsets.only(bottom: velpy(a: 0, b: screenSize.width / 9, c: cp))),
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
                            padding: EdgeInsets.only(right: 22.0 + 92 * (1 - cp)),
                            child: NamidaInkWell(
                              borderRadius: 12.0,
                              onTap: cp == 1 ? () => NamidaDialogs.inst.showTrackDialog(trackPre, source: QueueSource.playerQueue) : null,
                              padding: EdgeInsets.only(left: 8.0 * cp),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (firstLine != '')
                                    Text(
                                      firstLine,
                                      maxLines: secondLine == '' ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.displayMedium?.copyWith(
                                        fontSize: velpy(a: 15.0, b: 20.0, c: p).multipliedFontScale,
                                        height: 1,
                                      ),
                                    ),
                                  if (firstLine != '' && secondLine != '') const SizedBox(height: 4.0),
                                  if (secondLine != '')
                                    Text(
                                      secondLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.displayMedium?.copyWith(
                                        fontSize: velpy(a: 13.0, b: 15.0, c: p).multipliedFontScale,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        NamidaOpacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(-100 * (1.0 - cp), 0.0),
                            child: NamidaLikeButton(
                              track: trackPre,
                              size: 32.0,
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

double _previousScale = 1.0;
final _lrcAdditionalScale = 0.0.obs;
bool _isScalingLRC = false;

class _AnimatingTrackImage extends StatelessWidget {
  final Track track;
  final double cp;

  const _AnimatingTrackImage({
    super.key,
    required this.track,
    required this.cp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12.0 * (1 - cp)),
      child: Obx(
        () {
          final videoInfo = Player.inst.videoPlayerInfo;
          return GestureDetector(
            // -- only when lrc view is not visible, to prevent other gestures delaying.
            onDoubleTap: settings.artworkGestureDoubleTapLRC.value && Lyrics.inst.currentLyricsLRC.value == null
                ? () {
                    settings.save(enableLyrics: !settings.enableLyrics.value);
                    Lyrics.inst.updateLyrics(track);
                  }
                : null,
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
            child: Obx(
              () {
                final additionalScaleVideo = 0.02 * VideoController.inst.videoZoomAdditionalScale.value;
                final additionalScaleLRC = 0.02 * _lrcAdditionalScale.value;
                final finalScale = additionalScaleLRC + additionalScaleVideo + WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition);
                final isInversed = settings.animatingThumbnailInversed.value;
                final userScaleMultiplier = settings.animatingThumbnailScaleMultiplier.value;
                return AnimatedScale(
                  duration: const Duration(milliseconds: 100),
                  scale: (isInversed ? 1.22 - finalScale : 1.13 + finalScale) * userScaleMultiplier,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: videoInfo != null && videoInfo.isInitialized
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular((6.0 + 10.0 * cp).multipliedRadius),
                                child: GestureDetector(
                                  onDoubleTap: () => VideoController.inst.toggleFullScreenVideoView(isLocal: true),
                                  child: NamidaAspectRatio(
                                    aspectRatio: videoInfo.aspectRatio,
                                    child: Texture(textureId: videoInfo.textureId),
                                  ),
                                ),
                              )
                            : _TrackImage(
                                track: track,
                                cp: cp,
                              ),
                      ),
                      Obx(
                        () => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: !settings.enableLyrics.value
                              ? const IgnorePointer(key: Key('empty_lrc'), child: SizedBox())
                              : Lyrics.inst.currentLyricsLRC.value != null
                                  ? LyricsLRCParsedView(
                                      key: Lyrics.inst.lrcViewKey,
                                      cp: cp,
                                      lrc: Lyrics.inst.currentLyricsLRC.value,
                                      videoOrImage: const SizedBox(),
                                      totalDuration: track.duration.seconds,
                                    )
                                  : Lyrics.inst.currentLyricsText.value != ''
                                      ? Opacity(
                                          opacity: cp,
                                          child: Container(
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                                              color: context.theme.scaffoldBackgroundColor.withAlpha(110),
                                            ),
                                            width: double.infinity,
                                            height: double.infinity,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                            child: NamidaBgBlur(
                                              blur: 12.0,
                                              enabled: true,
                                              child: ShaderFadingWidget(
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    children: [
                                                      const SizedBox(height: 48.0),
                                                      Text(Lyrics.inst.currentLyricsText.value, style: context.textTheme.displayMedium),
                                                      const SizedBox(height: 48.0),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const IgnorePointer(key: Key('empty_lrc_2'), child: SizedBox()),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
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

class _RawImageContainer extends StatelessWidget {
  const _RawImageContainer({
    Key? key,
    required this.child,
    required this.bottomOffset,
    required this.maxOffset,
    required this.screenSize,
    required this.cp,
    required this.p,
    required this.width,
  }) : super(key: key);

  final Widget child;
  final double width;
  final double bottomOffset;
  final double maxOffset;
  final Size screenSize;
  final double cp;
  final double p;

  @override
  Widget build(BuildContext context) {
    final size = velpy(a: width, b: screenSize.width - 84.0, c: cp);
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

class Wallpaper extends StatefulWidget {
  const Wallpaper({Key? key, this.child, this.particleOpacity = .1, this.gradient = true}) : super(key: key);

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
          if (settings.enableMiniplayerParticles.value && Player.inst.nowPlayingTrack != kDummyTrack)
            Obx(
              () {
                final bpmb = 2000 * WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition);
                final bpm = bpmb.withMinimum(0);
                return AnimatedOpacity(
                  duration: const Duration(seconds: 1),
                  opacity: Player.inst.isPlaying ? 1 : 0,
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
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
