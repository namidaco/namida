// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:animated_background/animated_background.dart';
import 'package:get/get.dart';

import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
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
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/waveform.dart';

class MiniPlayerParent extends StatefulWidget {
  const MiniPlayerParent({super.key});

  @override
  State<MiniPlayerParent> createState() => _MiniPlayerParentState();
}

class _MiniPlayerParentState extends State<MiniPlayerParent> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    MiniPlayerController.inst.initialize(this);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedTheme(
        duration: const Duration(milliseconds: 300),
        data: AppThemes.inst.getAppTheme(CurrentColor.inst.color, !context.isDarkMode),
        child: Stack(
          children: [
            // -- MiniPlayer Wallpaper
            Obx(
              () {
                final anim = MiniPlayerController.inst.miniplayerHP.value;
                return Visibility(
                  visible: anim > 0.01,
                  child: Positioned.fill(
                    child: Opacity(
                      opacity: anim,
                      child: const Wallpaper(gradient: false, particleOpacity: .3),
                    ),
                  ),
                );
              },
            ),

            // -- MiniPlayers
            const MiniPlayerSwitchers(),
          ],
        ),
      ),
    );
  }
}

class MiniPlayerSwitchers extends StatefulWidget {
  const MiniPlayerSwitchers({super.key});

  @override
  State<MiniPlayerSwitchers> createState() => _MiniPlayerSwitchersState();
}

class _MiniPlayerSwitchersState extends State<MiniPlayerSwitchers> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    MiniPlayerController.inst.initializeSAnim(this);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        // to refresh after toggling [enableBottomNavBar]
        SettingsController.inst.enableBottomNavBar.value;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: Player.inst.nowPlayingTrack == kDummyTrack
              ? const SizedBox(
                  key: Key('emptyminiplayer'),
                )
              : SettingsController.inst.useYoutubeMiniplayer.value
                  ? YoutubeMiniPlayer(key: const Key('ytminiplayer'))
                  : const NamidaMiniPlayer(key: Key('actualminiplayer')),
        );
      },
    );
  }
}

class NamidaMiniPlayer extends StatelessWidget {
  const NamidaMiniPlayer({super.key});

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
    return WillPopScope(
      onWillPop: MiniPlayerController.inst.onWillPop,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: MiniPlayerController.inst.onPointerDown,
        onPointerMove: MiniPlayerController.inst.onPointerMove,
        onPointerUp: MiniPlayerController.inst.onPointerUp,
        child: GestureDetector(
          onTap: MiniPlayerController.inst.gestureDetectorOnTap,
          onVerticalDragUpdate: MiniPlayerController.inst.gestureDetectorOnVerticalDragUpdate,
          onVerticalDragEnd: (_) => MiniPlayerController.inst.verticalSnapping(),
          onHorizontalDragStart: MiniPlayerController.inst.gestureDetectorOnHorizontalDragStart,
          onHorizontalDragUpdate: MiniPlayerController.inst.gestureDetectorOnHorizontalDragUpdate,
          onHorizontalDragEnd: MiniPlayerController.inst.gestureDetectorOnHorizontalDragEnd,
          child: Obx(
            () {
              final currentIndex = Player.inst.currentIndex;
              final indminus = refine(currentIndex - 1);
              final indplus = refine(currentIndex + 1);
              final prevTrack = Player.inst.currentQueue[indminus];
              final currentTrack = Player.inst.nowPlayingTrack;
              final nextTrack = Player.inst.currentQueue[indplus];
              final currentDuration = currentTrack.duration;
              final currentDurationInMS = currentDuration * 1000;
              return AnimatedBuilder(
                animation: MiniPlayerController.inst.animation,
                builder: (context, child) {
                  final Color onSecondary = context.theme.colorScheme.onSecondaryContainer;
                  final maxOffset = MiniPlayerController.inst.maxOffset;
                  final bounceUp = MiniPlayerController.inst.bounceUp;
                  final bounceDown = MiniPlayerController.inst.bounceDown;
                  final topInset = MiniPlayerController.inst.topInset;
                  final bottomInset = MiniPlayerController.inst.bottomInset;
                  final screenSize = MiniPlayerController.inst.screenSize;
                  final sAnim = MiniPlayerController.inst.sAnim;
                  final sMaxOffset = MiniPlayerController.inst.sMaxOffset;
                  final stParallax = MiniPlayerController.inst.stParallax;
                  final siParallax = MiniPlayerController.inst.siParallax;

                  final double p = MiniPlayerController.inst.animation.value;
                  final double cp = MiniPlayerController.inst.miniplayerHP.value;
                  final double ip = 1 - p;
                  final double icp = 1 - cp;

                  final double rp = _inverseAboveOne(p);
                  final double rcp = rp.clamp(0, 1);

                  final double qp = p.clamp(1.0, 3.0) - 1.0;
                  final double qcp = MiniPlayerController.inst.miniplayerQueueHP.value;

                  final double bp = !bounceUp
                      ? !bounceDown
                          ? rp
                          : 1 - (p - 1)
                      : p;
                  final double bcp = bp.clamp(0.0, 1.0);

                  final BorderRadius borderRadius = BorderRadius.only(
                    topLeft: Radius.circular(20.0.multipliedRadius + 6.0 * p),
                    topRight: Radius.circular(20.0.multipliedRadius + 6.0 * p),
                    bottomLeft: Radius.circular(20.0.multipliedRadius * (1 - p * 10 + 9).clamp(0, 1)),
                    bottomRight: Radius.circular(20.0.multipliedRadius * (1 - p * 10 + 9).clamp(0, 1)),
                  );
                  final double slowOpacity = (bcp * 4 - 3).clamp(0, 1);
                  final double opacity = (bcp * 5 - 4).clamp(0, 1);
                  final double fastOpacity = (bcp * 10 - 9).clamp(0, 1);
                  double panelHeight = maxOffset / 1.6;
                  if (p > 1.0) {
                    panelHeight = _velpy(a: panelHeight, b: maxOffset / 1.6 - 100.0 - topInset, c: qcp);
                  }

                  final miniplayerbottomnavheight = SettingsController.inst.enableBottomNavBar.value ? 60.0 : 0.0;
                  final double bottomOffset = (-miniplayerbottomnavheight * icp + p.clamp(-1, 0) * -200) - (bottomInset * icp);

                  return Stack(
                    children: [
                      /// MiniPlayer Body
                      Container(
                        color: p > 0 ? Colors.transparent : null, // hit test only when expanded
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: Offset(0, bottomOffset),
                            child: Container(
                              color: Colors.transparent, // prevents scrolling gap
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6 * (1 - cp * 10 + 9).clamp(0, 1), vertical: 12 * icp),
                                child: Container(
                                  height: _velpy(a: 82.0, b: panelHeight, c: p.clamp(0, 3)),
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
                                          color: CurrentColor.inst.color,
                                          borderRadius: borderRadius,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(100), CurrentColor.inst.color)
                                                  .withOpacity(_velpy(a: .38, b: .28, c: icp)),
                                              Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.color)
                                                  .withOpacity(_velpy(a: .1, b: .22, c: icp)),
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
                                              color: CurrentColor.inst.color,
                                              borderRadius: BorderRadius.circular(50),
                                              //  color: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.color)
                                              //   .withOpacity(_velpy(a: .3, b: .22, c: icp)),
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
                      if (SettingsController.inst.enablePartyModeInMiniplayer.value) ...[
                        NamidaPartyContainer(
                          height: 2,
                          spreadRadiusMultiplier: 0.8,
                          opacity: cp,
                        ),
                        NamidaPartyContainer(
                          width: 2,
                          spreadRadiusMultiplier: 0.25,
                          opacity: cp,
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: NamidaPartyContainer(
                            height: 2,
                            spreadRadiusMultiplier: 0.8,
                            opacity: cp,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: NamidaPartyContainer(
                            width: 2,
                            spreadRadiusMultiplier: 0.25,
                            opacity: cp,
                          ),
                        ),
                      ],

                      /// Top Row
                      if (rcp > 0.0)
                        Material(
                          type: MaterialType.transparency,
                          child: Opacity(
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
                                          borderRadius: 16.0,
                                          onTap: () => NamidaOnTaps.inst.onAlbumTap(currentTrack.album),
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
                              bottomOffset +
                                  (-maxOffset / 8.8 * bp) +
                                  ((-maxOffset + topInset + 80.0) *
                                      (!bounceUp
                                          ? !bounceDown
                                              ? qp
                                              : (1 - bp)
                                          : 0.0))),
                          child: Padding(
                            padding: EdgeInsets.all(12.0 * icp),
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  if (fastOpacity > 0.0)
                                    Opacity(
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
                                                        final plusOrMinus = diffInMs < 0 ? '-' : '+';
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
                                                    Obx(
                                                      () => Text(
                                                        Player.inst.nowPlayingPosition.milliSecondsLabel,
                                                        style: context.textTheme.displaySmall,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => Player.inst.seekSecondsForward(),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  currentDuration.secondsLabel,
                                                  style: context.textTheme.displaySmall,
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
                                          height: (_velpy(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp,
                                          width: (_velpy(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp,
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
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 400),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            isButtonHighlighed ? Color.alphaBlend(CurrentColor.inst.color.withAlpha(233), Colors.white) : CurrentColor.inst.color,
                                                        gradient: LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          colors: [
                                                            CurrentColor.inst.color,
                                                            Color.alphaBlend(CurrentColor.inst.color.withAlpha(200), Colors.grey),
                                                          ],
                                                          stops: const [0, 0.7],
                                                        ),
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: CurrentColor.inst.color.withAlpha(160),
                                                            blurRadius: 8.0,
                                                            spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                                                            offset: const Offset(0.0, 2.0),
                                                          ),
                                                        ],
                                                      ),
                                                      child: IconButton(
                                                        highlightColor: Colors.transparent,
                                                        onPressed: () => Player.inst.playOrPause(currentIndex, [], QueueSource.playerQueue),
                                                        icon: Padding(
                                                          padding: EdgeInsets.all(6.0 * cp * rcp),
                                                          child: Obx(
                                                            () => AnimatedSwitcher(
                                                              duration: const Duration(milliseconds: 200),
                                                              child: Player.inst.isPlaying
                                                                  ? Icon(
                                                                      Broken.pause,
                                                                      size: (_velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp,
                                                                      key: const Key("pauseicon"),
                                                                      color: Colors.white.withAlpha(180),
                                                                    )
                                                                  : Icon(
                                                                      Broken.play,
                                                                      size: (_velpy(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp,
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
                        Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, -100 * ip),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
                                  child: () {
                                    final isMenuOpened = false.obs;
                                    final isLoadingMore = false.obs;
                                    const animationDuration = Duration(milliseconds: 150);

                                    Widget getQualityButton({
                                      required String title,
                                      String subtitle = '',
                                      required IconData icon,
                                      Color? bgColor,
                                      Widget? trailing,
                                      double padding = 4.0,
                                      required void Function()? onTap,
                                    }) {
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
                                              trailing,
                                              const SizedBox(width: 4.0),
                                            ],
                                          ],
                                        ),
                                      );
                                    }

                                    Widget getTextWidget(String text, {required bool colored, Color? textColor, double? fontSize}) {
                                      return Text(
                                        text,
                                        style: TextStyle(color: textColor ?? (colored ? onSecondary : null), fontSize: fontSize?.multipliedFontScale),
                                      );
                                    }

                                    return FocusedMenuHolder(
                                      menuOpenAlignment: Alignment.bottomLeft,
                                      bottomOffsetHeight: 12.0,
                                      leftOffsetHeight: 4.0,
                                      onMenuOpen: () {
                                        if (SettingsController.inst.enableVideoPlayback.value) {
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
                                          final ytVideos = VideoController.inst.currentYTQualities;
                                          return ListView(
                                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                                            children: [
                                              getQualityButton(
                                                title: 'check for more',
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
                                                  final localOrCache = element.ytID == null ? Language.inst.LOCAL : Language.inst.CACHE;
                                                  return Obx(
                                                    () {
                                                      final currentVideo = VideoController.inst.currentVideo.value;
                                                      final isCurrent = element.path == currentVideo?.path;
                                                      return getQualityButton(
                                                        bgColor: isCurrent ? CurrentColor.inst.color.withAlpha(20) : null,
                                                        icon: Broken.video,
                                                        title: [
                                                          "${element.height}p${element.framerateText()}",
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
                                                      final cacheFile = File("${AppDirs.VIDEOS_CACHE}${currentVideo?.ytID}_${element.resolution}.${element.formatSuffix}");
                                                      final cacheExists = currentVideo?.ytID == null ? false : cacheFile.existsSync();
                                                      return getQualityButton(
                                                        onTap: () async {
                                                          if (!cacheExists) await VideoController.inst.getVideoFromYoutubeAndUpdate(currentVideo?.ytID, stream: element);
                                                          VideoController.inst
                                                              .playVideoCurrent(video: null, cacheIdAndPath: (currentVideo?.ytID ?? '', cacheFile.path), track: currentTrack);
                                                        },
                                                        bgColor: cacheExists ? CurrentColor.inst.color.withAlpha(40) : null,
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
                                      child: Obx(
                                        () {
                                          final videoPlaybackEnabled = SettingsController.inst.enableVideoPlayback.value;
                                          final currentVideo = VideoController.inst.currentVideo.value;
                                          final downloadedBytes = VideoController.inst.currentDownloadedBytes.value;
                                          final videoTotalSize = currentVideo?.sizeInBytes ?? 0;
                                          final videoQuality = currentVideo?.height ?? 0;
                                          final videoFramerate = currentVideo?.framerateText(30);
                                          final markText = VideoController.inst.isNoVideosAvailable.value ? 'x' : '?';
                                          final fallbackQualityLabel = currentVideo?.nameInCache?.split('_').last;
                                          final qualityText = videoQuality == 0 ? fallbackQualityLabel ?? markText : '${videoQuality}p';
                                          final framerateText = videoFramerate ?? '';
                                          return AnimatedContainer(
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
                                                    child: Icon(videoPlaybackEnabled ? Broken.video : Broken.video_slash, size: 18.0, color: onSecondary),
                                                  ),
                                                  const SizedBox(
                                                    width: 8.0,
                                                  ),
                                                  if (!videoPlaybackEnabled) ...[
                                                    getTextWidget(Language.inst.AUDIO, colored: true),
                                                    if (SettingsController.inst.displayAudioInfoMiniplayer.value)
                                                      getTextWidget(
                                                        " • ${currentTrack.audioInfoFormattedCompact}",
                                                        colored: true,
                                                        textColor: context.theme.colorScheme.onPrimaryContainer,
                                                        fontSize: 10.0,
                                                      ),
                                                  ],
                                                  if (videoPlaybackEnabled) ...[
                                                    getTextWidget(Language.inst.VIDEO, colored: true),
                                                    qualityText == '?' && !ConnectivityController.inst.hasConnection
                                                        ? Row(
                                                            children: [
                                                              getTextWidget(" • ", colored: true),
                                                              Icon(
                                                                Broken.global_refresh,
                                                                size: 14.0,
                                                                color: onSecondary,
                                                              ),
                                                            ],
                                                          )
                                                        : getTextWidget(" • $qualityText$framerateText", colored: false, fontSize: 13.0),
                                                    if (videoTotalSize > 0) ...[
                                                      getTextWidget(" • ", colored: false, fontSize: 13.0),
                                                      if (downloadedBytes != null) getTextWidget("${downloadedBytes.fileSizeFormatted}/", colored: true, fontSize: 10.0),
                                                      getTextWidget(videoTotalSize.fileSizeFormatted, colored: true, fontSize: 10.0),
                                                    ]
                                                  ]
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }(),
                                ),
                              ),
                            ),
                          ),
                        ),

                      /// Buttons Row
                      if (opacity > 0.0)
                        Material(
                          type: MaterialType.transparency,
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, -100 * ip),
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: Obx(
                                            () => IconButton(
                                              visualDensity: VisualDensity.compact,
                                              tooltip: SettingsController.inst.playerRepeatMode.value.toText().replaceFirst('_NUM_', Player.inst.numberOfRepeats.toString()),
                                              onPressed: () => SettingsController.inst.playerRepeatMode.value.toggleSetting(),
                                              padding: const EdgeInsets.all(2.0),
                                              icon: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Icon(
                                                    SettingsController.inst.playerRepeatMode.value.toIcon(),
                                                    size: 20.0,
                                                    color: context.theme.colorScheme.onSecondaryContainer,
                                                  ),
                                                  if (SettingsController.inst.playerRepeatMode.value == RepeatMode.forNtimes)
                                                    Text(
                                                      Player.inst.numberOfRepeats.toString(),
                                                      style: context.textTheme.displaySmall?.copyWith(color: context.theme.colorScheme.onSecondaryContainer),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: IconButton(
                                            tooltip: Language.inst.LYRICS,
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () {
                                              SettingsController.inst.save(enableLyrics: !SettingsController.inst.enableLyrics.value);
                                              Lyrics.inst.updateLyrics(currentTrack);
                                            },
                                            padding: const EdgeInsets.all(2.0),
                                            icon: Obx(
                                              () => SettingsController.inst.enableLyrics.value
                                                  ? Lyrics.inst.currentLyrics.value == ''
                                                      ? StackedIcon(
                                                          baseIcon: Broken.document,
                                                          secondaryText: !Lyrics.inst.lyricsAvailable.value ? 'x' : '?',
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
                                        SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: IconButton(
                                            tooltip: Language.inst.QUEUE,
                                            visualDensity: VisualDensity.compact,
                                            onPressed: MiniPlayerController.inst.snapToQueue,
                                            padding: const EdgeInsets.all(2.0),
                                            icon: Icon(
                                              Broken.row_vertical,
                                              size: 19.0,
                                              color: context.theme.colorScheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      /// Track Info
                      Material(
                        type: MaterialType.transparency,
                        child: AnimatedBuilder(
                          animation: sAnim,
                          builder: (context, child) {
                            return Stack(
                              children: [
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
                              ],
                            );
                          },
                        ),
                      ),

                      /// Track Image
                      AnimatedBuilder(
                        animation: sAnim,
                        builder: (context, child) {
                          final verticalOffset = !bounceUp ? (-maxOffset + topInset + 108.0) * (!bounceDown ? qp : (1 - bp)) : 0.0;
                          final horizontalOffset = -sAnim.value * sMaxOffset / siParallax;
                          final width = _velpy(a: 82.0, b: 92.0, c: qp);

                          return Stack(
                            children: [
                              // Opacity(
                              //   opacity: -sAnim.value.clamp(-1.0, 0.0),
                              //   child: Transform.translate(
                              //     offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                              //     child: _RawImageContainer(
                              //       cp: bcp,
                              //       p: bp,
                              //       width: width,
                              //       screenSize: screenSize,
                              //       bottomOffset: bottomOffset,
                              //       maxOffset: maxOffset,
                              //       child: _TrackImage(
                              //         track: prevTrack.track,
                              //         cp: cp,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                              Opacity(
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
                              // Opacity(
                              //   opacity: sAnim.value.clamp(0.0, 1.0),
                              //   child: Transform.translate(
                              //     offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                              //     child: _RawImageContainer(
                              //       cp: bcp,
                              //       p: bp,
                              //       width: width,
                              //       screenSize: screenSize,
                              //       bottomOffset: bottomOffset,
                              //       maxOffset: maxOffset,
                              //       child: _TrackImage(
                              //         track: nextTrack.track,
                              //         cp: cp,
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          );
                        },
                      ),

                      /// Slider
                      if (slowOpacity > 0.0)
                        Opacity(
                          opacity: slowOpacity,
                          child: Transform.translate(
                            offset: Offset(
                                0,
                                bottomOffset +
                                    (-maxOffset / 4.4 * p) +
                                    ((-maxOffset + topInset) *
                                        ((!bounceUp
                                            ? !bounceDown
                                                ? qp
                                                : (1 - bp)
                                            : 0.0)) *
                                        0.4)),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    void onSeekDragUpdate(double deltax) {
                                      final percentageSwiped = deltax / constraints.maxWidth;
                                      final newSeek = percentageSwiped * currentDurationInMS;
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
                                        widgetOnTop: (barsWidgetWithDiffColor) {
                                          return Obx(
                                            () {
                                              final seekValue = MiniPlayerController.inst.seekValue.value;
                                              final position = seekValue != 0.0 ? seekValue : Player.inst.nowPlayingPosition;
                                              final durInMs = currentDurationInMS;
                                              final percentage = (position / durInMs).clamp(0.0, durInMs.toDouble());
                                              return ShaderMask(
                                                blendMode: BlendMode.srcIn,
                                                shaderCallback: (Rect bounds) {
                                                  return LinearGradient(
                                                    tileMode: TileMode.decal,
                                                    stops: [0.0, percentage, percentage + 0.005, 1.0],
                                                    colors: [
                                                      Color.alphaBlend(CurrentColor.inst.color.withAlpha(220), context.theme.colorScheme.onBackground),
                                                      Color.alphaBlend(CurrentColor.inst.color.withAlpha(180), context.theme.colorScheme.onBackground),
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
                              ),
                            ),
                          ),
                        ),

                      if (qp > 0.0)
                        Opacity(
                          opacity: qp.clamp(0, 1),
                          child: Transform.translate(
                            offset: Offset(0, (1 - qp) * maxOffset * 0.8),
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32.0.multipliedRadius), topRight: Radius.circular(32.0.multipliedRadius)),
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Obx(
                                        () => NamidaListView(
                                          itemExtents: Player.inst.currentQueue.toTrackItemExtents(),
                                          scrollController: MiniPlayerController.inst.queueScrollController,
                                          padding: EdgeInsets.only(bottom: 56.0 + SelectedTracksController.inst.bottomPadding.value),
                                          onReorderStart: (index) => MiniPlayerController.inst.isReorderingQueue = true,
                                          onReorderEnd: (index) => MiniPlayerController.inst.isReorderingQueue = false,
                                          onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                                          itemCount: Player.inst.currentQueue.length,
                                          itemBuilder: (context, i) {
                                            final track = Player.inst.currentQueue[i];
                                            final key = "$i${track.track.path}";
                                            return AnimatedOpacity(
                                              key: Key('GD_$key'),
                                              duration: const Duration(milliseconds: 300),
                                              opacity: i < currentIndex ? 0.7 : 1.0,
                                              child: FadeDismissible(
                                                key: Key("Diss_$key"),
                                                onDismissed: (direction) {
                                                  Player.inst.removeFromQueue(i);
                                                  MiniPlayerController.inst.isReorderingQueue = false;
                                                },
                                                onUpdate: (detailts) => MiniPlayerController.inst.isReorderingQueue = detailts.progress != 0.0,
                                                child: TrackTile(
                                                  index: i,
                                                  key: Key('tile_$key'),
                                                  trackOrTwd: track,
                                                  displayRightDragHandler: true,
                                                  draggableThumbnail: true,
                                                  queueSource: QueueSource.playerQueue,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Container(
                                        width: context.width,
                                        height: kQueueBottomRowHeight,
                                        decoration: BoxDecoration(
                                          color: context.theme.scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(12.0.multipliedRadius),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: FittedBox(
                                            child: _queueUtilsRow(context, currentTrack),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _queueUtilsRow(BuildContext context, Track currentTrack) {
    const tileHeight = 48.0;
    const tileVPadding = 3.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(width: context.width * 0.23),
        const SizedBox(width: 6.0),
        NamidaButton(
          tooltip: Language.inst.REMOVE_DUPLICATES,
          icon: Broken.trash,
          onPressed: () {
            final removed = Player.inst.removeDuplicatesFromQueue();
            Get.snackbar(Language.inst.NOTE, "${Language.inst.REMOVED} ${removed.displayTrackKeyword}");
          },
        ),
        const SizedBox(width: 6.0),
        _addTracksButton(context, currentTrack),
        const SizedBox(width: 6.0),
        Obx(
          () => NamidaButton(
            onPressed: MiniPlayerController.inst.animateQueueToCurrentTrack,
            icon: MiniPlayerController.inst.arrowIcon.value,
          ),
        ),
        const SizedBox(width: 6.0),
        GestureDetector(
          onLongPressStart: (details) async {
            void saveSetting(bool shuffleAll) => SettingsController.inst.save(playerShuffleAllTracks: shuffleAll);
            await showMenu(
              context: context,
              position: RelativeRect.fromLTRB(
                details.globalPosition.dx,
                details.globalPosition.dy - kQueueBottomRowHeight - (tileHeight + tileVPadding * 2) * 2,
                details.globalPosition.dx,
                details.globalPosition.dy,
              ),
              items: [
                ...[
                  (
                    Language.inst.SHUFFLE_NEXT,
                    Broken.forward,
                    false,
                  ),
                  (
                    Language.inst.SHUFFLE_ALL,
                    Broken.task,
                    true,
                  ),
                ].map(
                  (e) => PopupMenuItem(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: tileVPadding),
                      child: Obx(
                        () => SizedBox(
                          height: tileHeight,
                          child: ListTileWithCheckMark(
                            active: SettingsController.inst.playerShuffleAllTracks.value == e.$3,
                            leading: StackedIcon(
                              baseIcon: Broken.shuffle,
                              secondaryIcon: e.$2,
                              blurRadius: 8.0,
                            ),
                            title: e.$1,
                            onTap: () => saveSetting(e.$3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: NamidaButton(
            text: Language.inst.SHUFFLE,
            icon: Broken.shuffle,
            onPressed: () => Player.inst.shuffleTracks(SettingsController.inst.playerShuffleAllTracks.value),
          ),
        ),
        const SizedBox(width: 8.0),
      ],
    );
  }

  Widget _addTracksButton(BuildContext context, Track currentTrack) {
    final shouldShowConfigureIcon = false.obs;

    void openQueueInsertionConfigure(QueueInsertionType insertionType, String title) {
      final qinsertion = insertionType.toQueueInsertion();
      final tracksNo = qinsertion.numberOfTracks.obs;
      final insertN = qinsertion.insertNext.obs;
      final sortBy = qinsertion.sortBy.obs;
      final maxCount = 200.withMaximum(allTracksInLibrary.length);
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          title: Language.inst.CONFIGURE,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: Language.inst.SAVE,
              onPressed: () {
                SettingsController.inst.updateQueueInsertion(
                  insertionType,
                  QueueInsertion(
                    numberOfTracks: tracksNo.value,
                    insertNext: insertN.value,
                    sortBy: sortBy.value,
                  ),
                );
                NamidaNavigator.inst.closeDialog();
              },
            )
          ],
          child: Column(
            children: [
              NamidaInkWell(
                bgColor: context.theme.cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: Text(title, style: context.textTheme.displayLarge),
              ),
              const SizedBox(height: 24.0),
              CustomListTile(
                icon: Broken.computing,
                title: Language.inst.NUMBER_OF_TRACKS,
                subtitle: "${Language.inst.UNLIMITED}-$maxCount",
                trailing: Obx(
                  () => NamidaWheelSlider(
                    totalCount: maxCount,
                    initValue: tracksNo.value,
                    itemSize: 1,
                    squeeze: 0.3,
                    onValueChanged: (val) => tracksNo.value = val,
                    text: tracksNo.value == 0 ? Language.inst.UNLIMITED : '${tracksNo.value}',
                  ),
                ),
              ),
              Obx(
                () => CustomSwitchListTile(
                  icon: Broken.next,
                  title: Language.inst.PLAY_NEXT,
                  value: insertN.value,
                  onChanged: (isTrue) => insertN.value = !isTrue,
                ),
              ),
              CustomListTile(
                icon: Broken.sort,
                title: Language.inst.SORT_BY,
                trailingRaw: PopupMenuButton<InsertionSortingType>(
                  child: Obx(
                    () => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sortBy.value.toIcon(), size: 18.0),
                        const SizedBox(width: 8.0),
                        Text(sortBy.value.toText()),
                      ],
                    ),
                  ),
                  itemBuilder: (context) {
                    return <PopupMenuEntry<InsertionSortingType>>[
                      ...InsertionSortingType.values
                          .map(
                            (e) => PopupMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Icon(e.toIcon(), size: 20.0),
                                  const SizedBox(width: 8.0),
                                  Text(e.toText()),
                                ],
                              ),
                            ),
                          )
                          .toList()
                    ];
                  },
                  onSelected: (value) => sortBy.value = value,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget getAddTracksTile({
      required String title,
      required String subtitle,
      required IconData icon,
      required QueueInsertionType insertionType,
      required void Function(QueueInsertionType insertionType) onTap,
    }) {
      return Stack(
        alignment: Alignment.centerRight,
        children: [
          CustomListTile(
            title: title,
            subtitle: subtitle,
            icon: icon,
            maxSubtitleLines: 22,
            onTap: () => onTap(insertionType),
          ),
          Obx(
            () => NamidaIconButton(
              icon: Broken.setting_4,
              onPressed: () => openQueueInsertionConfigure(insertionType, title),
            ).animateEntrance(
              showWhen: shouldShowConfigureIcon.value,
              durationMS: 200,
            ),
          ),
        ],
      );
    }

    return NamidaButton(
      tooltip: Language.inst.NEW_TRACKS_ADD,
      icon: Broken.add_circle,
      onPressed: () {
        NamidaNavigator.inst.navigateDialog(
          dialog: CustomBlurryDialog(
            normalTitleStyle: true,
            title: Language.inst.NEW_TRACKS_ADD,
            trailingWidgets: [
              NamidaIconButton(
                icon: Broken.setting_3,
                tooltip: Language.inst.CONFIGURE,
                onPressed: () => shouldShowConfigureIcon.value = !shouldShowConfigureIcon.value,
              ),
            ],
            child: Column(
              children: [
                getAddTracksTile(
                  title: Language.inst.NEW_TRACKS_RANDOM,
                  subtitle: Language.inst.NEW_TRACKS_RANDOM_SUBTITLE,
                  icon: Broken.format_circle,
                  insertionType: QueueInsertionType.random,
                  onTap: (insertionType) {
                    final config = insertionType.toQueueInsertion();
                    final count = config.numberOfTracks;
                    final rt = NamidaGenerator.inst.getRandomTracks(count - 1, count);
                    Player.inst.addToQueue(rt, insertionType: insertionType, emptyTracksMessage: Language.inst.NO_ENOUGH_TRACKS).closeDialog();
                  },
                ),
                getAddTracksTile(
                  title: Language.inst.GENERATE_FROM_DATES,
                  subtitle: Language.inst.GENERATE_FROM_DATES_SUBTITLE,
                  icon: Broken.calendar,
                  insertionType: QueueInsertionType.listenTimeRange,
                  onTap: (insertionType) {
                    NamidaNavigator.inst.closeDialog();
                    final historyTracks = HistoryController.inst.historyTracks;
                    if (historyTracks.isEmpty) {
                      Get.snackbar(Language.inst.NOTE, Language.inst.NO_TRACKS_IN_HISTORY);
                      return;
                    }
                    showCalendarDialog(
                      title: Language.inst.GENERATE_FROM_DATES,
                      buttonText: Language.inst.GENERATE,
                      useHistoryDates: true,
                      onGenerate: (dates) {
                        final tracks = NamidaGenerator.inst.generateTracksFromHistoryDates(dates.firstOrNull, dates.lastOrNull);
                        Player.inst
                            .addToQueue(
                              tracks,
                              insertionType: insertionType,
                              emptyTracksMessage: Language.inst.NO_TRACKS_FOUND_BETWEEN_DATES,
                            )
                            .closeDialog();
                      },
                    );
                  },
                ),
                getAddTracksTile(
                  title: Language.inst.NEW_TRACKS_MOODS,
                  subtitle: Language.inst.NEW_TRACKS_MOODS_SUBTITLE,
                  icon: Broken.emoji_happy,
                  insertionType: QueueInsertionType.mood,
                  onTap: (insertionType) {
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

                    if (allAvailableMoodsPlaylists.isEmpty && allAvailableMoodsTracks.isEmpty) {
                      Get.snackbar(Language.inst.ERROR, Language.inst.NO_MOODS_AVAILABLE);
                      return;
                    }

                    final playlistsAllMoods = allAvailableMoodsPlaylists.keys.toList();
                    final tracksAllMoods = allAvailableMoodsTracks.keys.toList();

                    final selectedmoodsPlaylists = <String>[].obs;
                    final selectedmoodsTracks = <String>[].obs;

                    NamidaNavigator.inst.navigateDialog(
                      dialog: CustomBlurryDialog(
                        normalTitleStyle: true,
                        insetPadding: const EdgeInsets.symmetric(horizontal: 48.0),
                        title: Language.inst.MOODS,
                        actions: [
                          const CancelButton(),
                          NamidaButton(
                            text: Language.inst.GENERATE,
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
                                // -- Playlist moods
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(Language.inst.PLAYLISTS, style: context.textTheme.displayMedium),
                                  ),
                                ),
                                SliverList.separated(
                                  separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                                  itemCount: playlistsAllMoods.length,
                                  itemBuilder: (context, index) {
                                    final m = playlistsAllMoods[index];
                                    final tracksCount = allAvailableMoodsPlaylists[m]?.length ?? 0;
                                    return Obx(
                                      () => ListTileWithCheckMark(
                                        title: "$m ($tracksCount)",
                                        active: selectedmoodsPlaylists.contains(m),
                                        onTap: () => selectedmoodsPlaylists.addOrRemove(m),
                                      ),
                                    );
                                  },
                                ),
                                // -- Tracks moods
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(Language.inst.TRACKS, style: context.textTheme.displayMedium),
                                  ),
                                ),
                                SliverList.separated(
                                  separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                                  itemCount: tracksAllMoods.length,
                                  itemBuilder: (context, index) {
                                    final m = tracksAllMoods[index];
                                    final tracksCount = allAvailableMoodsTracks[m]?.length ?? 0;
                                    return Obx(
                                      () => ListTileWithCheckMark(
                                        title: "$m ($tracksCount)",
                                        active: selectedmoodsTracks.contains(m),
                                        onTap: () => selectedmoodsTracks.addOrRemove(m),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )),
                      ),
                    );
                  },
                ),
                getAddTracksTile(
                  title: Language.inst.NEW_TRACKS_RATINGS,
                  subtitle: Language.inst.NEW_TRACKS_RATINGS_SUBTITLE,
                  icon: Broken.happyemoji,
                  insertionType: QueueInsertionType.rating,
                  onTap: (insertionType) {
                    NamidaNavigator.inst.closeDialog();

                    final RxInt minRating = 80.obs;
                    final RxInt maxRating = 100.obs;
                    NamidaNavigator.inst.navigateDialog(
                      dialog: CustomBlurryDialog(
                        normalTitleStyle: true,
                        title: Language.inst.NEW_TRACKS_RATINGS,
                        actions: [
                          const CancelButton(),
                          NamidaButton(
                            text: Language.inst.GENERATE,
                            onPressed: () {
                              if (minRating.value > maxRating.value) {
                                Get.snackbar(Language.inst.ERROR, Language.inst.MIN_VALUE_CANT_BE_MORE_THAN_MAX);
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
                                    Text(Language.inst.MINIMUM),
                                    const SizedBox(height: 24.0),
                                    NamidaWheelSlider(
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
                                    Text(Language.inst.MAXIMUM),
                                    const SizedBox(height: 24.0),
                                    NamidaWheelSlider(
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
                  title: Language.inst.NEW_TRACKS_SIMILARR_RELEASE_DATE,
                  subtitle: Language.inst.NEW_TRACKS_SIMILARR_RELEASE_DATE_SUBTITLE.replaceFirst(
                    '_CURRENT_TRACK_',
                    currentTrack.title.addDQuotation(),
                  ),
                  icon: Broken.calendar_1,
                  insertionType: QueueInsertionType.sameReleaseDate,
                  onTap: (insertionType) {
                    final year = currentTrack.year;
                    if (year == 0) {
                      Get.snackbar(Language.inst.ERROR, Language.inst.NEW_TRACKS_UNKNOWN_YEAR);
                      return;
                    }
                    final tracks = NamidaGenerator.inst.generateTracksFromSameEra(year, currentTrack: currentTrack);
                    Player.inst
                        .addToQueue(
                          tracks,
                          insertionType: insertionType,
                          emptyTracksMessage: Language.inst.NO_TRACKS_FOUND_BETWEEN_DATES,
                        )
                        .closeDialog();
                  },
                ),
                getAddTracksTile(
                  title: Language.inst.NEW_TRACKS_RECOMMENDED,
                  subtitle: Language.inst.NEW_TRACKS_RECOMMENDED_SUBTITLE.replaceFirst(
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
                          emptyTracksMessage: Language.inst.NO_TRACKS_IN_HISTORY,
                        )
                        .closeDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
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
    final double opacity = (_inverseAboveOne(p) * 10 - 9).clamp(0, 1);
    final track = trackPre.toTrackExt();
    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 4.0 * p.clamp(0, 2))),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.symmetric(horizontal: 24.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0).add(EdgeInsets.only(bottom: _velpy(a: 0, b: screenSize.width / 9, c: cp))),
            child: SizedBox(
              height: _velpy(a: 58.0, b: 82, c: cp),
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
                                key: Key(track.title),
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.originalArtist.overflow,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.displayMedium?.copyWith(
                                      fontSize: _velpy(a: 15.0, b: 20.0, c: p).multipliedFontScale,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4.0,
                                  ),
                                  Text(
                                    track.title.overflow,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.displayMedium?.copyWith(
                                      fontSize: _velpy(a: 13.0, b: 15.0, c: p).multipliedFontScale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Opacity(
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
          final additionalScale = VideoController.inst.videoZoomAdditionalScale.value;
          final finalScale = (additionalScale * 0.02) + WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition);
          final isInversed = SettingsController.inst.animatingThumbnailInversed.value;
          return AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: isInversed ? 1.25 - finalScale : 1.13 + finalScale,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: VideoController.inst.shouldShowVideo
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular((6.0 + 10.0 * cp).multipliedRadius),
                      child: LyricsWrapper(
                        cp: cp,
                        child: VideoController.inst.getVideoWidget(const Key('video_widget'), false),
                      ),
                    )
                  : LyricsWrapper(
                      cp: cp,
                      child: _TrackImage(
                        track: track,
                        cp: cp,
                      ),
                    ),
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
      key: Key(track.path),
      path: track.pathToImage,
      thumbnailSize: Get.width,
      compressed: false,
      borderRadius: 6.0 + 10.0 * cp,
      forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
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
    final size = _velpy(a: width, b: screenSize.width - 84.0, c: cp);
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

class LyricsWrapper extends StatelessWidget {
  final Widget child;
  final double cp;
  const LyricsWrapper({super.key, this.child = const SizedBox(), required this.cp});

  @override
  Widget build(BuildContext context) {
    if (cp == 0.0) {
      return child;
    }
    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: !SettingsController.inst.enableLyrics.value || Lyrics.inst.currentLyrics.value == ''
            ? child
            : Stack(
                alignment: Alignment.center,
                children: [
                  child,
                  Opacity(
                    opacity: cp,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                      child: NamidaBgBlur(
                        blur: 12.0,
                        enabled: true,
                        child: Container(
                          color: context.theme.scaffoldBackgroundColor.withAlpha(110),
                          width: double.infinity,
                          height: double.infinity,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 16.0),
                                Text(Lyrics.inst.currentLyrics.value, style: context.textTheme.displayMedium),
                                const SizedBox(height: 16.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

double _velpy({
  required final double a,
  required final double b,
  required final double c,
}) {
  return c * (b - a) + a;
}

double _inverseAboveOne(double n) {
  if (n > 1) return (1 - (1 - n) * -1);
  return n;
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
          if (SettingsController.inst.enableMiniplayerParticles.value)
            Obx(
              () {
                final bpm = 2000 * WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition);
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
