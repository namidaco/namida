// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'package:flutter/material.dart';

import 'package:animated_background/animated_background.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
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
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
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
    return Stack(
      children: [
        // -- MiniPlayer Wallpaper
        Obx(
          () {
            final anim = MiniPlayerController.inst.miniplayerHP.value;
            return Visibility(
              visible: anim > 0.01,
              child: Positioned.fill(
                child: Opacity(
                  opacity: MiniPlayerController.inst.miniplayerHP.value,
                  child: const Wallpaper(gradient: false, particleOpacity: .3),
                ),
              ),
            );
          },
        ),

        // -- MiniPlayers
        const MiniPlayerSwitchers(),
      ],
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
          child: Player.inst.nowPlayingTrack.value == kDummyTrack
              ? const SizedBox(
                  key: Key('emptyminiplayer'),
                )
              : SettingsController.inst.useYoutubeMiniplayer.value
                  ? YoutubeMiniPlayer(key: const Key('actualminiplayer'))
                  : const NamidaMiniPlayer(key: Key('actualminiplayer')),
        );
      },
    );
  }
}

class NamidaMiniPlayer extends StatelessWidget {
  const NamidaMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: MiniPlayerController.inst.onWillPop,
      child: Listener(
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
          child: AnimatedBuilder(
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

              final double rp = inverseAboveOne(p);
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
              final double opacity = (bcp * 5 - 4).clamp(0, 1);
              final double fastOpacity = (bcp * 10 - 9).clamp(0, 1);
              double panelHeight = maxOffset / 1.6;
              if (p > 1.0) {
                panelHeight = vp(a: panelHeight, b: maxOffset / 1.6 - 100.0 - topInset, c: qcp);
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
                              height: vp(a: 82.0, b: panelHeight, c: p.clamp(0, 3)),
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
                                      color: CurrentColor.inst.color.value,
                                      borderRadius: borderRadius,
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(100), CurrentColor.inst.color.value)
                                              .withOpacity(vp(a: .38, b: .28, c: icp)),
                                          Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.color.value)
                                              .withOpacity(vp(a: .1, b: .22, c: icp)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  /// Smol progress bar
                                  Obx(
                                    () {
                                      final w = Player.inst.nowPlayingPosition.value / Player.inst.nowPlayingTrack.value.duration;
                                      return Container(
                                        height: 2 * (1 - cp),
                                        width: w > 0 ? ((Get.width * w) * 0.9) : 0,
                                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                                        decoration: BoxDecoration(
                                          color: CurrentColor.inst.color.value,
                                          borderRadius: BorderRadius.circular(50),
                                          //  color: Color.alphaBlend(context.theme.colorScheme.onBackground.withAlpha(40), CurrentColor.inst.color.value)
                                          //   .withOpacity(vp(a: .3, b: .22, c: icp)),
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
                                      onTap: () {
                                        //todo: remove after exposing to another class.
                                        MiniPlayerController.inst.snapToMini();
                                        NamidaOnTaps.inst.onAlbumTap(Player.inst.nowPlayingTrack.value.album);
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "${Player.inst.currentIndex.value + 1}/${Player.inst.currentQueue.length}",
                                            style: TextStyle(
                                              color: onSecondary.withOpacity(.8),
                                              fontSize: 12.0.multipliedFontScale,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            Player.inst.nowPlayingTrack.value.album,
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
                                      NamidaDialogs.inst.showTrackDialog(Player.inst.nowPlayingTrack.value);
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
                                            child: Obx(
                                              () => Text(
                                                Player.inst.nowPlayingPosition.value.milliseconds.label,
                                                style: context.textTheme.displaySmall,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Player.inst.seekSecondsForward(),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              Player.inst.nowPlayingTrack.value.duration.milliseconds.label,
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
                                      height: (vp(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp,
                                      width: (vp(a: 60.0, b: 80.0, c: rcp) - 8) + 8 * rcp - 8 * icp,
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
                                                    color: isButtonHighlighed
                                                        ? Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(233), Colors.white)
                                                        : CurrentColor.inst.color.value,
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        CurrentColor.inst.color.value,
                                                        Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(200), Colors.grey),
                                                      ],
                                                      stops: const [0, 0.7],
                                                    ),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: CurrentColor.inst.color.value.withAlpha(160),
                                                        blurRadius: 8.0,
                                                        spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                                                        offset: const Offset(0.0, 2.0),
                                                      ),
                                                    ],
                                                  ),
                                                  child: IconButton(
                                                    highlightColor: Colors.transparent,
                                                    onPressed: () => Player.inst.playOrPause(Player.inst.currentIndex.value, [], QueueSource.playerQueue),
                                                    icon: Padding(
                                                      padding: EdgeInsets.all(6.0 * cp * rcp),
                                                      child: Obx(
                                                        () => AnimatedSwitcher(
                                                          duration: const Duration(milliseconds: 200),
                                                          child: Player.inst.isPlaying.value
                                                              ? Icon(
                                                                  Broken.pause,
                                                                  size: (vp(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp,
                                                                  key: const Key("pauseicon"),
                                                                  color: Colors.white.withAlpha(180),
                                                                )
                                                              : Icon(
                                                                  Broken.play,
                                                                  size: (vp(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp * rcp,
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
                              child: TextButton(
                                onLongPress: () {
                                  ScrollSearchController.inst.unfocusKeyboard();
                                  NamidaNavigator.inst.navigateDialog(const Dialog(child: PlaybackSettings(isInDialog: true)));
                                },
                                onPressed: () async {
                                  VideoController.inst.updateYTLink(Player.inst.nowPlayingTrack.value);
                                  await VideoController.inst.toggleVideoPlaybackInSetting();
                                },
                                child: Obx(
                                  () => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: BoxDecoration(
                                          color: context.theme.colorScheme.secondaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(SettingsController.inst.enableVideoPlayback.value ? Broken.video : Broken.video_slash, size: 18.0, color: onSecondary),
                                      ),
                                      const SizedBox(
                                        width: 8.0,
                                      ),
                                      if (!SettingsController.inst.enableVideoPlayback.value) ...[
                                        Text(
                                          Language.inst.AUDIO,
                                          style: TextStyle(color: onSecondary),
                                        ),
                                        if (SettingsController.inst.displayAudioInfoMiniplayer.value)
                                          Text(
                                            " • ${Player.inst.nowPlayingTrack.value.audioInfoFormattedCompact}",
                                            style: TextStyle(color: context.theme.colorScheme.onPrimaryContainer, fontSize: 10.0.multipliedFontScale),
                                          ),
                                      ],
                                      if (SettingsController.inst.enableVideoPlayback.value) ...[
                                        Text(
                                          Language.inst.VIDEO,
                                          style: TextStyle(
                                            color: onSecondary,
                                          ),
                                        ),
                                        Text(
                                          " • ${VideoController.inst.videoCurrentQuality.value}",
                                          style: TextStyle(fontSize: 13.0.multipliedFontScale),
                                        ),
                                        if (VideoController.inst.videoTotalSize.value > 10) ...[
                                          Text(
                                            " • ",
                                            style: TextStyle(fontSize: 13.0.multipliedFontScale),
                                          ),
                                          if (VideoController.inst.videoCurrentSize.value > 10)
                                            Text(
                                              "${VideoController.inst.videoCurrentSize.value.fileSizeFormatted}/",
                                              style: TextStyle(color: onSecondary, fontSize: 10.0.multipliedFontScale),
                                            ),
                                          Text(
                                            VideoController.inst.videoTotalSize.value.fileSizeFormatted,
                                            style: TextStyle(color: onSecondary, fontSize: 10.0.multipliedFontScale),
                                          ),
                                        ]
                                      ]
                                    ],
                                  ),
                                ),
                              ),
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
                                          tooltip: SettingsController.inst.playerRepeatMode.value.toText().replaceFirst('_NUM_', Player.inst.numberOfRepeats.value.toString()),
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
                                                  Player.inst.numberOfRepeats.value.toString(),
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
                                          Lyrics.inst.updateLyrics(Player.inst.nowPlayingTrack.value);
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
                                child: TrackInfo(
                                  trackPre: Player.inst.nowPlayingTrack.value,
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
                      return Stack(
                        children: [
                          Opacity(
                            opacity: 1 - sAnim.value.abs(),
                            child: Transform.translate(
                              offset: Offset(-sAnim.value * sMaxOffset / siParallax, !bounceUp ? (-maxOffset + topInset + 108.0) * (!bounceDown ? qp : (1 - bp)) : 0.0),
                              child: Obx(
                                () => TrackImage(
                                  track: Player.inst.nowPlayingTrack.value,
                                  p: bp,
                                  cp: bcp,
                                  width: vp(a: 82.0, b: 92.0, c: qp),
                                  screenSize: screenSize,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  /// Slider
                  if (fastOpacity > 0.0)
                    Opacity(
                      opacity: fastOpacity,
                      child: Transform.translate(
                        offset: Offset(0, bottomOffset + (-maxOffset / 4.4 * p)),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Obx(
                                () {
                                  final seekValue = MiniPlayerController.inst.seekValue.value;
                                  final position = seekValue != 0.0 ? seekValue : Player.inst.nowPlayingPosition.value;
                                  final dur = Player.inst.nowPlayingTrack.value.duration;
                                  final percentage = (position / dur).clamp(0.0, dur.toDouble());
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Stack(
                                      children: [
                                        WaveformComponent(
                                          color: context.theme.colorScheme.onBackground.withAlpha(40),
                                        ),
                                        ShaderMask(
                                          blendMode: BlendMode.srcIn,
                                          shaderCallback: (Rect bounds) {
                                            return LinearGradient(
                                              tileMode: TileMode.decal,
                                              stops: [0.0, percentage, percentage + 0.005, 1.0],
                                              colors: [
                                                Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(220), context.theme.colorScheme.onBackground).withAlpha(255),
                                                Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(180), context.theme.colorScheme.onBackground).withAlpha(255),
                                                Colors.transparent,
                                                Colors.transparent,
                                              ],
                                            ).createShader(bounds);
                                          },
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              WaveformComponent(
                                                color: context.theme.colorScheme.onBackground.withAlpha(110),
                                              ),
                                              // Slider
                                              // TODO: fix non-accurate seeking.
                                              if (percentage >= 0)
                                                Opacity(
                                                  opacity: 0.0,
                                                  child: Material(
                                                    child: Slider(
                                                      value: percentage,
                                                      onChanged: (double newValue) {
                                                        MiniPlayerController.inst.seekValue.value = newValue;
                                                      },
                                                      min: 0.0,
                                                      max: dur.toDouble(),
                                                      onChangeEnd: (newValue) {
                                                        Player.inst.seek(Duration(milliseconds: newValue.toInt()));
                                                        MiniPlayerController.inst.seekValue.value = 0.0;
                                                      },
                                                    ),
                                                  ),
                                                )
                                            ],
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
                                        return GestureDetector(
                                          key: Key("$i${track.path}"),
                                          onHorizontalDragStart: (details) => MiniPlayerController.inst.isReorderingQueue = true,
                                          onHorizontalDragEnd: (details) => MiniPlayerController.inst.isReorderingQueue = false,
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 300),
                                            opacity: i < Player.inst.currentIndex.value ? 0.7 : 1.0,
                                            child: FadeDismissible(
                                              key: Key("Diss_$i${track.path}"),
                                              onDismissed: (direction) {
                                                Player.inst.removeFromQueue(i);
                                              },
                                              child: TrackTile(
                                                index: i,
                                                key: ValueKey(i.toString()),
                                                track: track,
                                                displayRightDragHandler: true,
                                                draggableThumbnail: true,
                                                queueSource: QueueSource.playerQueue,
                                                onDragStart: (event) => MiniPlayerController.inst.isReorderingQueue = true,
                                                onDragEnd: (event) => MiniPlayerController.inst.isReorderingQueue = false,
                                              ),
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
                                      padding: const EdgeInsets.all(4.0).add(EdgeInsets.only(left: context.width * 0.22)),
                                      child: FittedBox(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const SizedBox(width: 6.0),
                                            Tooltip(
                                              message: Language.inst.REMOVE_DUPLICATES,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  final qlBefore = Player.inst.currentQueue.length;
                                                  Player.inst.removeDuplicatesFromQueue();
                                                  final qlAfter = Player.inst.currentQueue.length;
                                                  final difference = qlBefore - qlAfter;
                                                  Get.snackbar(Language.inst.NOTE, "${Language.inst.REMOVED} ${difference.displayTrackKeyword}");
                                                },
                                                child: const Icon(Broken.trash),
                                              ),
                                            ),
                                            const SizedBox(width: 6.0),
                                            Tooltip(
                                              message: Language.inst.NEW_TRACKS_ADD,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  NamidaNavigator.inst.navigateDialog(
                                                    CustomBlurryDialog(
                                                      normalTitleStyle: true,
                                                      title: Language.inst.NEW_TRACKS_ADD,
                                                      child: Column(
                                                        children: [
                                                          CustomListTile(
                                                            title: Language.inst.NEW_TRACKS_RANDOM,
                                                            subtitle: Language.inst.NEW_TRACKS_RANDOM_SUBTITLE,
                                                            icon: Broken.format_circle,
                                                            maxSubtitleLines: 22,
                                                            onTap: () {
                                                              NamidaNavigator.inst.closeDialog();
                                                              final rt = getRandomTracks(8, 11);
                                                              if (rt.isEmpty) {
                                                                Get.snackbar(Language.inst.ERROR, Language.inst.NO_ENOUGH_TRACKS);
                                                                return;
                                                              }
                                                              Player.inst.addToQueue(rt);
                                                            },
                                                          ),
                                                          CustomListTile(
                                                            title: Language.inst.GENERATE_FROM_DATES,
                                                            subtitle: Language.inst.GENERATE_FROM_DATES_SUBTITLE,
                                                            icon: Broken.calendar,
                                                            maxSubtitleLines: 22,
                                                            onTap: () {
                                                              NamidaNavigator.inst.closeDialog();
                                                              final historyTracks = HistoryController.inst.historyTracks;
                                                              if (historyTracks.isEmpty) {
                                                                Get.snackbar(Language.inst.NOTE, Language.inst.NO_TRACKS_IN_HISTORY);
                                                                return;
                                                              }
                                                              List<DateTime?> dates = [];
                                                              NamidaNavigator.inst.navigateDialog(
                                                                CustomBlurryDialog(
                                                                  scale: 0.9,
                                                                  title: Language.inst.GENERATE_FROM_DATES,
                                                                  normalTitleStyle: true,
                                                                  insetPadding: const EdgeInsets.symmetric(horizontal: 28.0),
                                                                  actions: [
                                                                    const CancelButton(),
                                                                    ElevatedButton(
                                                                      onPressed: () {
                                                                        final tracks = generateTracksFromHistoryDates(dates.firstOrNull, dates.lastOrNull);
                                                                        if (tracks.isEmpty) {
                                                                          Get.snackbar(Language.inst.NOTE, Language.inst.NO_TRACKS_FOUND_BETWEEN_DATES);
                                                                          return;
                                                                        }
                                                                        Player.inst.addToQueue(tracks);
                                                                        NamidaNavigator.inst.closeDialog();
                                                                      },
                                                                      child: Text(Language.inst.GENERATE),
                                                                    ),
                                                                  ],
                                                                  child: CalendarDatePicker2(
                                                                    onValueChanged: (value) => dates.assignAll(value),
                                                                    config: CalendarDatePicker2Config(
                                                                      calendarType: CalendarDatePicker2Type.range,
                                                                      firstDate: HistoryController.inst.oldestTrack?.dateAdded.milliSecondsSinceEpoch,
                                                                      lastDate: HistoryController.inst.newestTrack?.dateAdded.milliSecondsSinceEpoch,
                                                                    ),
                                                                    value: const [],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          CustomListTile(
                                                            title: Language.inst.NEW_TRACKS_MOODS,
                                                            subtitle: Language.inst.NEW_TRACKS_MOODS_SUBTITLE,
                                                            icon: Broken.emoji_happy,
                                                            maxSubtitleLines: 22,
                                                            onTap: () {
                                                              NamidaNavigator.inst.closeDialog();

                                                              final moods = <String>[];

                                                              // moods from playlists.
                                                              final allAvailableMoodsPlaylists =
                                                                  PlaylistController.inst.playlistsMap.entries.expand((element) => element.value.moods).toSet();
                                                              moods.addAll(allAvailableMoodsPlaylists);
                                                              // moods from tracks.
                                                              Indexer.inst.trackStatsMap.forEach((key, value) => moods.addAll(value.moods));
                                                              if (moods.isEmpty) {
                                                                Get.snackbar(Language.inst.ERROR, Language.inst.NO_MOODS_AVAILABLE);
                                                                return;
                                                              }
                                                              final RxSet<String> selectedmoods = <String>{}.obs;
                                                              NamidaNavigator.inst.navigateDialog(
                                                                CustomBlurryDialog(
                                                                  normalTitleStyle: true,
                                                                  insetPadding: const EdgeInsets.symmetric(horizontal: 48.0),
                                                                  title: Language.inst.MOODS,
                                                                  actions: [
                                                                    const CancelButton(),
                                                                    ElevatedButton(
                                                                      onPressed: () {
                                                                        Player.inst.addToQueue(generateTracksFromMoods(selectedmoods));
                                                                        NamidaNavigator.inst.closeDialog();
                                                                      },
                                                                      child: Text(Language.inst.GENERATE),
                                                                    ),
                                                                  ],
                                                                  child: SizedBox(
                                                                    height: context.height * 0.4,
                                                                    width: context.width,
                                                                    child: NamidaListView(
                                                                      itemCount: moods.length,
                                                                      itemExtents: null,
                                                                      itemBuilder: (context, i) {
                                                                        final e = moods[i];
                                                                        return Column(
                                                                          key: ValueKey(i),
                                                                          children: [
                                                                            const SizedBox(height: 12.0),
                                                                            Obx(
                                                                              () => ListTileWithCheckMark(
                                                                                title: e,
                                                                                active: selectedmoods.contains(e),
                                                                                onTap: () {
                                                                                  if (selectedmoods.contains(e)) {
                                                                                    selectedmoods.remove(e);
                                                                                  } else {
                                                                                    selectedmoods.add(e);
                                                                                  }
                                                                                },
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          CustomListTile(
                                                            title: Language.inst.NEW_TRACKS_RATINGS,
                                                            subtitle: Language.inst.NEW_TRACKS_RATINGS_SUBTITLE,
                                                            icon: Broken.happyemoji,
                                                            maxSubtitleLines: 22,
                                                            onTap: () {
                                                              NamidaNavigator.inst.closeDialog();

                                                              final RxInt minRating = 80.obs;
                                                              final RxInt maxRating = 100.obs;
                                                              final RxInt maxNumberOfTracks = 40.obs;
                                                              NamidaNavigator.inst.navigateDialog(
                                                                CustomBlurryDialog(
                                                                  normalTitleStyle: true,
                                                                  title: Language.inst.NEW_TRACKS_RATINGS,
                                                                  actions: [
                                                                    const CancelButton(),
                                                                    ElevatedButton(
                                                                      onPressed: () {
                                                                        if (minRating.value > maxRating.value) {
                                                                          Get.snackbar(Language.inst.ERROR, Language.inst.MIN_VALUE_CANT_BE_MORE_THAN_MAX);
                                                                          return;
                                                                        }
                                                                        final tracks = generateTracksFromRatings(minRating.value, maxRating.value, maxNumberOfTracks.value);
                                                                        Player.inst.addToQueue(tracks);
                                                                        NamidaNavigator.inst.closeDialog();
                                                                      },
                                                                      child: Text(Language.inst.GENERATE),
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
                                                                      const SizedBox(height: 24.0),
                                                                      Text(Language.inst.NUMBER_OF_TRACKS),
                                                                      NamidaWheelSlider(
                                                                        totalCount: 100,
                                                                        initValue: maxNumberOfTracks.value,
                                                                        itemSize: 1,
                                                                        squeeze: 0.3,
                                                                        onValueChanged: (val) {
                                                                          maxNumberOfTracks.value = val;
                                                                        },
                                                                      ),
                                                                      const SizedBox(height: 2.0),
                                                                      Obx(
                                                                        () => Text(
                                                                          maxNumberOfTracks.value == 0 ? Language.inst.UNLIMITED : '${maxNumberOfTracks.value}',
                                                                          style: context.textTheme.displaySmall,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                          const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0)),
                                                          CustomListTile(
                                                            title: Language.inst.NEW_TRACKS_SIMILARR_RELEASE_DATE,
                                                            subtitle: Language.inst.NEW_TRACKS_SIMILARR_RELEASE_DATE_SUBTITLE.replaceFirst(
                                                              '_CURRENT_TRACK_',
                                                              Player.inst.nowPlayingTrack.value.title.addDQuotation(),
                                                            ),
                                                            icon: Broken.calendar_1,
                                                            onTap: () {
                                                              final currentTrack = Player.inst.nowPlayingTrack.value;
                                                              final year = currentTrack.year;
                                                              if (year == 0) {
                                                                Get.snackbar(Language.inst.ERROR, Language.inst.NEW_TRACKS_UNKNOWN_YEAR);
                                                                return;
                                                              }
                                                              final tracks = generateTracksFromSameEra(year, currentTrack: currentTrack);
                                                              if (tracks.isEmpty) {
                                                                Get.snackbar(Language.inst.NOTE, Language.inst.NO_TRACKS_FOUND_BETWEEN_DATES);
                                                                return;
                                                              }
                                                              Player.inst.addToQueue(tracks);
                                                              NamidaNavigator.inst.closeDialog();
                                                            },
                                                          ),
                                                          Obx(
                                                            () => CustomListTile(
                                                              title: Language.inst.NEW_TRACKS_RECOMMENDED,
                                                              subtitle: Language.inst.NEW_TRACKS_RECOMMENDED_SUBTITLE.replaceFirst(
                                                                '_CURRENT_TRACK_',
                                                                Player.inst.nowPlayingTrack.value.title.addDQuotation(),
                                                              ),
                                                              icon: Broken.bezier,
                                                              maxSubtitleLines: 22,
                                                              onTap: () {
                                                                NamidaNavigator.inst.closeDialog();
                                                                final gentracks = generateRecommendedTrack(Player.inst.nowPlayingTrack.value);
                                                                if (gentracks.isEmpty) {
                                                                  Get.snackbar(Language.inst.NOTE, Language.inst.NO_TRACKS_IN_HISTORY);
                                                                  return;
                                                                }
                                                                Player.inst.addToQueue(gentracks, insertNext: true);
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: const Icon(Broken.add_circle),
                                              ),
                                            ),
                                            const SizedBox(width: 6.0),
                                            ElevatedButton(
                                              onPressed: MiniPlayerController.inst.animateQueueToCurrentTrack,
                                              child: Obx(() => Icon(MiniPlayerController.inst.arrowIcon.value)),
                                            ),
                                            const SizedBox(width: 6.0),
                                            ElevatedButton.icon(
                                              onPressed: () => Player.inst.shuffleNextTracks(),
                                              label: Text(Language.inst.SHUFFLE),
                                              icon: const Icon(Broken.shuffle),
                                            ),
                                            const SizedBox(width: 8.0),
                                          ],
                                        ),
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
          ),
        ),
      ),
    );
  }
}

class TrackInfo extends StatelessWidget {
  const TrackInfo({
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
    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 4.0 * p.clamp(0, 2))),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.symmetric(horizontal: 24.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0).add(EdgeInsets.only(bottom: vp(a: 0, b: screenSize.width / 9, c: cp))),
            child: SizedBox(
              height: vp(a: 58.0, b: 82, c: cp),
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
                              onTap: cp == 1 ? () => NamidaDialogs.inst.showTrackDialog(trackPre) : null,
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
                                      fontSize: vp(a: 15.0, b: 20.0, c: p).multipliedFontScale,
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
                                      fontSize: vp(a: 13.0, b: 15.0, c: p).multipliedFontScale,
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
                            child: NamidaLikeButton(track: trackPre),
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

class TrackImage extends StatelessWidget {
  const TrackImage({
    Key? key,
    required this.track,
    required this.bottomOffset,
    required this.maxOffset,
    required this.screenSize,
    required this.cp,
    required this.p,
    this.width = 82.0,
    this.large = false,
  }) : super(key: key);

  final Track track;
  final bool large;

  final double width;

  final double bottomOffset;
  final double maxOffset;
  final Size screenSize;
  final double cp;
  final double p;

  @override
  Widget build(BuildContext context) {
    // final radius = vp(a: 14.0, b: 32.0, c: cp);
    final size = vp(a: width, b: screenSize.width - 84.0, c: cp);
    // const imgSize = Size(400, 400);

    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 2.15 * p.clamp(0, 2))),
      child: Padding(
        padding: EdgeInsets.all(12.0 * (1 - cp)).add(EdgeInsets.only(left: 42.0 * cp)),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            height: size,
            width: size,
            child: Padding(
              padding: EdgeInsets.all(12.0 * (1 - cp)),
              child: Obx(
                () {
                  final finalScale = WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition.value);
                  final isInversed = SettingsController.inst.animatingThumbnailInversed.value;
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 100),
                    scale: isInversed ? 1.25 - finalScale : 1.13 + finalScale,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: VideoController.inst.shouldShowVideo
                          ? ClipRRect(
                              key: const ValueKey('videocontainer'),
                              borderRadius: BorderRadius.circular((6.0 + 10.0 * cp).multipliedRadius),
                              child: AspectRatio(
                                aspectRatio: VideoController.inst.vidcontroller!.value.aspectRatio,
                                child: LyricsWrapper(
                                  cp: cp,
                                  child: VideoPlayer(
                                    key: const ValueKey('video'),
                                    VideoController.inst.vidcontroller!,
                                  ),
                                ),
                              ),
                            )
                          : LyricsWrapper(
                              cp: cp,
                              child: ArtworkWidget(
                                path: track.pathToImage,
                                track: track,
                                thumbnailSize: Get.width,
                                compressed: cp == 0,
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
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
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

double vp({
  required final double a,
  required final double b,
  required final double c,
}) {
  return c * (b - a) + a;
}

double pv({
  required final double min,
  required final double max,
  required final double value,
}) {
  return (value - min) / (max - min);
}

double norm(double val, double minVal, double maxVal, double newMin, double newMax) {
  return newMin + (val - minVal) * (newMax - newMin) / (maxVal - minVal);
}

double inverseAboveOne(double n) {
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
    return Obx(
      () {
        final bpm = 2000 * WaveformController.inst.getCurrentAnimatingScale(Player.inst.nowPlayingPosition.value);
        final background = AnimatedBackground(
          vsync: this,
          behaviour: RandomParticleBehaviour(
            options: ParticleOptions(
              baseColor: context.theme.colorScheme.tertiary,
              spawnMaxRadius: 4,
              spawnMinRadius: 2,
              spawnMaxSpeed: 60 + bpm,
              spawnMinSpeed: bpm,
              maxOpacity: widget.particleOpacity,
              minOpacity: 0,
              particleCount: 50,
            ),
          ),
          child: const SizedBox(),
        );

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
                AnimatedOpacity(
                  duration: const Duration(seconds: 1),
                  opacity: Player.inst.isPlaying.value ? 1 : 0,
                  child: background,
                ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class ScrollBoundaryLimitPhysics extends ScrollPhysics {
  final double topLimit;

  const ScrollBoundaryLimitPhysics({required ScrollPhysics parent, required this.topLimit}) : super(parent: parent);

  @override
  ScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ScrollBoundaryLimitPhysics(parent: buildParent(ancestor)!, topLimit: topLimit);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final double pixels = value.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (pixels <= topLimit) {
      // when the scroll position reaches the top limit, prevent scrolling
      return topLimit;
    }
    return super.applyBoundaryConditions(position, pixels);
  }
}
