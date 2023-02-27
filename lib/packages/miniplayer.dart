// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

// ignore: prefer_const_constructors_in_immutables
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:like_button/like_button.dart';
import 'package:video_player/video_player.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/dialogs/track_popup_dialog.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/video_playback.dart';
import 'package:namida/ui/widgets/waveform.dart';

class MiniPlayerParent extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  MiniPlayerParent({super.key});

  @override
  State<MiniPlayerParent> createState() => _MiniPlayerParentState();
}

class _MiniPlayerParentState extends State<MiniPlayerParent> with SingleTickerProviderStateMixin {
  late AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      upperBound: 2.1,
      lowerBound: -0.1,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Get.textTheme.displayMedium!,
      child: Stack(
        children: [
          /// MiniPlayer Wallpaper
          Positioned.fill(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                if (animation.value > 0.01) {
                  return Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),
                    child: Container(
                      color: context.theme.scaffoldBackgroundColor,
                    ),
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),
          ),

          /// MiniMiniPlayer
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Player.inst.nowPlayingTrack.value == kDummyTrack
                ? const SizedBox(
                    key: Key('emptyminiplayer'),
                  )
                : MiniPlayer(key: const Key('actualminiplayer'), animation: animation),
          )
        ],
      ),
    );
  }
}
// ignore_for_file: dead_code

enum MiniPlayerState { mini, expanded, queue }

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({Key? key, required this.animation}) : super(key: key);

  final AnimationController animation;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  double offset = 0.0;
  double prevOffset = 0.0;
  late Size screenSize;
  late double topInset;
  late double bottomInset;
  late double maxOffset;
  final velocity = VelocityTracker.withKind(PointerDeviceKind.touch);
  static const Cubic bouncingCurve = Cubic(0.175, 0.885, 0.32, 1.125);

  static const headRoom = 50.0;
  static const actuationOffset = 100.0; // min distance to snap
  static const deadSpace = 100.0; // Distance from bottom to ignore swipes

  /// Horizontal track switching
  double sOffset = 0.0;
  double sPrevOffset = 0.0;
  double stParallax = 1.0;
  double siParallax = 1.15;
  static const sActuationMulti = 1.5;
  late double sMaxOffset;
  late AnimationController sAnim;

  late AnimationController playPauseAnim;

  late ScrollController scrollController;
  bool queueScrollable = false;
  bool bounceUp = false;
  bool bounceDown = false;
  RxDouble seekValue = 0.0.obs;
  @override
  void initState() {
    super.initState();
    final media = MediaQueryData.fromWindow(window);
    topInset = media.padding.top;
    bottomInset = media.padding.bottom;
    screenSize = media.size;
    maxOffset = screenSize.height;
    sMaxOffset = screenSize.width;
    sAnim = AnimationController(
      vsync: this,
      lowerBound: -1,
      upperBound: 1,
      value: 0.0,
    );
    playPauseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    sAnim.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void verticalSnapping() {
    final distance = prevOffset - offset;
    final speed = velocity.getVelocity().pixelsPerSecond.dy;
    const threshold = 500.0;

    // speed threshold is an eyeballed value
    // used to actuate on fast flicks too

    if (prevOffset > maxOffset) {
      // Start from queue
      if (speed > threshold || distance > actuationOffset) {
        snapToExpanded();
      } else {
        snapToQueue();
      }
    } else if (prevOffset > maxOffset / 2) {
      // Start from top
      if (speed > threshold || distance > actuationOffset) {
        snapToMini();
      } else if (-speed > threshold || -distance > actuationOffset) {
        snapToQueue();
      } else {
        snapToExpanded();
      }
    } else {
      // Start from bottom
      if (-speed > threshold || -distance > actuationOffset) {
        snapToExpanded();
      } else {
        snapToMini();
      }
    }
  }

  void snapToExpanded({bool haptic = true}) {
    offset = maxOffset;
    if (prevOffset < maxOffset) bounceUp = true;
    if (prevOffset > maxOffset) bounceDown = true;
    snap(haptic: haptic);
  }

  void snapToMini({bool haptic = true}) {
    offset = 0;
    bounceDown = false;
    snap(haptic: haptic);
  }

  void snapToQueue({bool haptic = true}) {
    offset = maxOffset * 2;
    bounceUp = false;
    snap(haptic: haptic);
  }

  void snap({bool haptic = true}) {
    widget.animation
        .animateTo(
      offset / maxOffset,
      curve: bouncingCurve,
      duration: const Duration(milliseconds: 300),
    )
        .then((_) {
      bounceUp = false;
    });
    if (haptic && (prevOffset - offset).abs() > actuationOffset) HapticFeedback.lightImpact();
  }

  void snapToPrev() {
    sOffset = -sMaxOffset;
    sAnim
        .animateTo(
      -1.0,
      curve: bouncingCurve,
      duration: const Duration(milliseconds: 300),
    )
        .then((_) {
      sOffset = 0;
      sAnim.animateTo(0.0, duration: Duration.zero);
      Player.inst.previous();
    });
    if ((sPrevOffset - sOffset).abs() > actuationOffset) HapticFeedback.lightImpact();
  }

  void snapToCurrent() {
    sOffset = 0;
    sAnim.animateTo(
      0.0,
      curve: bouncingCurve,
      duration: const Duration(milliseconds: 300),
    );

    if ((sPrevOffset - sOffset).abs() > actuationOffset) HapticFeedback.lightImpact();
  }

  void snapToNext() {
    sOffset = sMaxOffset;
    sAnim
        .animateTo(
      1.0,
      curve: bouncingCurve,
      duration: const Duration(milliseconds: 300),
    )
        .then((_) {
      sOffset = 0;
      sAnim.animateTo(0.0, duration: Duration.zero);
      Player.inst.next();
    });
    if ((sPrevOffset - sOffset).abs() > actuationOffset) HapticFeedback.lightImpact();
  }

  bool isPlayPauseButtonHighlighted = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.position.dy > screenSize.height - deadSpace) return;

        velocity.addPosition(event.timeStamp, event.position);

        prevOffset = offset;

        bounceUp = false;
        bounceDown = false;
      },
      onPointerMove: (event) {
        if (event.position.dy > screenSize.height - deadSpace) return;

        velocity.addPosition(event.timeStamp, event.position);

        if (offset <= maxOffset) return;
        if (scrollController.positions.isNotEmpty && scrollController.positions.first.pixels > 0.0 && offset >= maxOffset * 2) return;

        offset -= event.delta.dy;
        offset = offset.clamp(-headRoom, maxOffset * 2);

        widget.animation.animateTo(offset / maxOffset, duration: Duration.zero);

        setState(() => queueScrollable = offset >= maxOffset * 2);
      },
      onPointerUp: (event) {
        if (offset <= maxOffset) return;
        if (scrollController.positions.isNotEmpty && scrollController.positions.first.pixels > 0.0 && offset >= maxOffset * 2) return;

        setState(() => queueScrollable = true);
        verticalSnapping();
      },
      child: GestureDetector(
        /// Tap
        onTap: () {
          if (widget.animation.value < (actuationOffset / maxOffset)) {
            snapToExpanded();
          }
        },

        /// Vertical
        onVerticalDragUpdate: (details) {
          if (details.globalPosition.dy > screenSize.height - deadSpace) return;
          if (offset > maxOffset) return;

          offset -= details.primaryDelta ?? 0;
          offset = offset.clamp(-headRoom, maxOffset * 2 + headRoom / 2);

          widget.animation.animateTo(offset / maxOffset, duration: Duration.zero);
        },
        onVerticalDragEnd: (_) => verticalSnapping(),

        /// Horizontal
        onHorizontalDragStart: (details) {
          return;
          if (offset > maxOffset) return;

          sPrevOffset = sOffset;
        },
        onHorizontalDragUpdate: (details) {
          return;
          if (offset > maxOffset) return;
          if (details.globalPosition.dy > screenSize.height - deadSpace) return;

          sOffset -= details.primaryDelta ?? 0.0;
          sOffset = sOffset.clamp(-sMaxOffset, sMaxOffset);

          sAnim.animateTo(sOffset / sMaxOffset, duration: Duration.zero);
        },
        onHorizontalDragEnd: (details) {
          return;
          if (offset > maxOffset) return;

          final distance = sPrevOffset - sOffset;
          final speed = velocity.getVelocity().pixelsPerSecond.dx;
          const threshold = 1000.0;

          // speed threshold is an eyeballed value
          // used to actuate on fast flicks too

          if (speed > threshold || distance > actuationOffset * sActuationMulti) {
            snapToPrev();
          } else if (-speed > threshold || -distance > actuationOffset * sActuationMulti) {
            snapToNext();
          } else {
            snapToCurrent();
          }
        },

        // Child
        child: AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            final Color onSecondary = context.theme.colorScheme.onSecondaryContainer;

            final double p = widget.animation.value;
            final double cp = p.clamp(0, 1);
            final double ip = 1 - p;
            final double icp = 1 - cp;

            final double rp = inverseAboveOne(p);
            final double rcp = rp.clamp(0, 1);
            // final double rip = 1 - rp;
            // final double ricp = 1 - rcp;

            final double qp = p.clamp(1.0, 3.0) - 1.0;
            final double qcp = qp.clamp(0.0, 1.0);

            // print(1.0 - (p.clamp(1, 3) - 1));

            final double bp = !bounceUp
                ? !bounceDown
                    ? rp
                    : 1 - (p - 1)
                : p;
            final double bcp = bp.clamp(0.0, 1.0);

            final BorderRadius borderRadius = BorderRadius.only(
              topLeft: Radius.circular(24.0 + 6.0 * p),
              topRight: Radius.circular(24.0 + 6.0 * p),
              bottomLeft: Radius.circular(24.0 * (1 - p * 10 + 9).clamp(0, 1)),
              bottomRight: Radius.circular(24.0 * (1 - p * 10 + 9).clamp(0, 1)),
            );
            final double bottomOffset = (-60 * icp + p.clamp(-1, 0) * -200) - (bottomInset * icp);
            final double opacity = (bcp * 5 - 4).clamp(0, 1);
            final double fastOpacity = (bcp * 10 - 9).clamp(0, 1);
            double panelHeight = maxOffset / 1.6;
            if (p > 1.0) {
              panelHeight = vp(a: panelHeight, b: maxOffset / 1.6 - 100.0 - topInset, c: qcp);
            }

            final double queueOpacity = ((p.clamp(1.0, 3.0) - 1).clamp(0.0, 1.0) * 4 - 3).clamp(0, 1);
            final double queueOffset = qp;

            return Obx(
              () => Stack(
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
                            padding: EdgeInsets.symmetric(horizontal: 12 * (1 - cp * 10 + 9).clamp(0, 1), vertical: 12 * icp),
                            child: Container(
                              height: vp(a: 82.0, b: panelHeight, c: p.clamp(0, 3)),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: context.theme.scaffoldBackgroundColor,
                                borderRadius: borderRadius,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2 + 0.1 * cp),
                                    blurRadius: 32.0,
                                  )
                                ],
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                decoration: BoxDecoration(
                                  color: CurrentColor.inst.color.value,
                                  borderRadius: borderRadius,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      CurrentColor.inst.color.value.withOpacity(vp(a: .3, b: .4, c: icp)),
                                      CurrentColor.inst.color.value.withOpacity(vp(a: .1, b: .4, c: icp)),
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
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      snapToMini();
                                    },
                                    icon: Icon(Broken.arrow_down_2, color: onSecondary),
                                    iconSize: 22.0,
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(45.0),
                                      onTap: () {
                                        // if (currentTrack.playing != null && currentTrack.playing!.album != null) {
                                        //   snapToMini();
                                        //   AlbumView.view(currentTrack.playing!.album!, context: context).then((_) => context.read<ThemeProvider>().resetTheme());
                                        // }
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Playing from",
                                            style: TextStyle(
                                              color: onSecondary.withOpacity(.8),
                                              fontSize: 15.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            Player.inst.nowPlayingTrack.value.album,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20.0, color: onSecondary.withOpacity(.9)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      // showMaterialModalBottomSheet(
                                      //   context: context,
                                      //   useRootNavigator: true,
                                      //   builder: (context) => Container(height: 300),
                                      // );
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

                  // Align(
                  //   alignment: Alignment.topLeft,
                  //   child: SafeArea(
                  //     child: Container(
                  //       color: Colors.red,
                  //       height: 100.0,
                  //       width: double.infinity,
                  //     ),
                  //   ),
                  // ),

                  /// Controls
                  Material(
                    type: MaterialType.transparency,
                    child: Transform.translate(
                      offset: Offset(
                          0,
                          bottomOffset +
                              (-maxOffset / 7.0 * bp) +
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
                                        IconButton(
                                          iconSize: 28.0,
                                          icon: Icon(Broken.shuffle, color: onSecondary),
                                          onPressed: () {},
                                        ),
                                        IconButton(
                                          iconSize: 28.0,
                                          icon: Icon(Broken.repeat, color: onSecondary),
                                          onPressed: () {},
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // if (fastOpacity > 0.0)
                              //   Opacity(
                              //     opacity: fastOpacity,
                              //     child: Padding(
                              //       padding: EdgeInsets.symmetric(horizontal: 96.0 * (2 * (!bounceDown ? icp : 0.0) + 1)),
                              //       child: Row(
                              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //         children: [
                              //           IconButton(
                              //             iconSize: 32.0,
                              //             icon: Icon(Broken.previous, color: onSecondary),
                              //             onPressed: snapToPrev,
                              //           ),
                              //           IconButton(
                              //             iconSize: 32.0,
                              //             icon: Icon(Broken.next, color: onSecondary),
                              //             onPressed: snapToNext,
                              //           ),
                              //         ],
                              //       ),
                              //     ),
                              //   ),
                              Padding(
                                  padding: EdgeInsets.all(12.0 * icp).add(EdgeInsets.only(
                                      right: !bounceDown
                                          ? !bounceUp
                                              ? screenSize.width * rcp / 2 - (80 + 32.0 * 3) * rcp / 2 + (qp * 24.0)
                                              : screenSize.width * cp / 2 - (80 + 32.0 * 3) * cp / 2
                                          : screenSize.width * bcp / 2 - (80 + 32.0 * 3) * bcp / 2 + (qp * 24.0))),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        iconSize: 22.0 + 10 * cp,
                                        icon: Icon(Broken.previous, color: onSecondary),
                                        onPressed: snapToPrev,
                                      ),
                                      SizedBox(
                                        key: const Key("playpause"),
                                        height: (vp(a: 60.0, b: 80.0, c: cp) - 18) + 18 * cp,
                                        width: (vp(a: 60.0, b: 80.0, c: cp) - 18) + 18 * cp,
                                        child: Center(
                                          child: GestureDetector(
                                            onTapDown: (value) {
                                              setState(() {
                                                isPlayPauseButtonHighlighted = true;
                                              });
                                            },
                                            onTapUp: (value) {
                                              setState(() {
                                                isPlayPauseButtonHighlighted = false;
                                              });
                                            },
                                            onTapCancel: () {
                                              setState(() {
                                                isPlayPauseButtonHighlighted = !isPlayPauseButtonHighlighted;
                                              });
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 400),
                                              decoration: BoxDecoration(
                                                  color: isPlayPauseButtonHighlighted
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
                                                      color: CurrentColor.inst.color.value,
                                                      blurRadius: 8.0,
                                                      spreadRadius: isPlayPauseButtonHighlighted ? 3.0 : 1.0,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                  // borderRadius: BorderRadius
                                                  //       .circular(Configuration
                                                  //               .instance
                                                  //               .borderRadiusMultiplier *
                                                  //           12),
                                                  ),
                                              child: IconButton(
                                                  highlightColor: Colors.transparent,
                                                  onPressed: () {
                                                    Player.inst.playOrPause();
                                                  },
                                                  icon: Padding(
                                                    padding: EdgeInsets.all(6.0 * cp),
                                                    child: Obx(
                                                      () => Player.inst.isPlaying.value
                                                          ? Icon(
                                                              Broken.pause,
                                                              size: (vp(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp,
                                                              key: const Key("pauseicon"),
                                                              color: Colors.white.withAlpha(180),
                                                            )
                                                          : Icon(
                                                              Broken.play,
                                                              size: (vp(a: 60.0 * 0.5, b: 80.0 * 0.5, c: rp) - 8) + 8 * cp,
                                                              key: const Key("playicon"),
                                                              color: Colors.white.withAlpha(180),
                                                            ),
                                                    ),
                                                  )),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        iconSize: 22.0 + 10 * cp,
                                        icon: Icon(Broken.next, color: onSecondary),
                                        onPressed: snapToNext,
                                      ),
                                    ],
                                  )
                                  //  Text("WHAT IS THISSS SO MUCHHHHH"),

                                  // Builder(builder: (context) {
                                  //   final audioLoading = context.select<currentTrackProvider, AudioLoadingState>((value) => value.audioLoading);
                                  //   Widget playbackIndicator;

                                  //   if (audioLoading == AudioLoadingState.loading) {
                                  //     playbackIndicator = SizedBox(
                                  //       key: const Key("loading"),
                                  //       height: vp(a: 60.0, b: 80.0, c: rp),
                                  //       width: vp(a: 60.0, b: 80.0, c: rp),
                                  //       child: Center(
                                  //         child: LoadingAnimationWidget.staggeredDotsWave(
                                  //           color: context.theme.colorScheme.secondary,
                                  //           size: 42.0,
                                  //         ),
                                  //       ),
                                  //     );
                                  //   } else if (audioLoading == AudioLoadingState.error) {
                                  //     playbackIndicator = SizedBox(
                                  //       key: const Key("error"),
                                  //       height: vp(a: 60.0, b: 80.0, c: rp),
                                  //       width: vp(a: 60.0, b: 80.0, c: rp),
                                  //       child: Center(
                                  //         child: Icon(
                                  //           Icons.warning,
                                  //           size: 42.0,
                                  //           color: context.theme.colorScheme.error,
                                  //         ),
                                  //       ),
                                  //     );
                                  //   } else {
                                  //     playbackIndicator = MultiProvider(
                                  //       key: const Key("ready"),
                                  //       providers: [
                                  //         StreamProvider(create: (_) => currentTrack.MiniPlayer.positionStream, initialData: currentTrack.MiniPlayer.position),
                                  //         StreamProvider(create: (_) => currentTrack.MiniPlayer.playingStream, initialData: currentTrack.MiniPlayer.playing),
                                  //       ],
                                  //       builder: (context, snapshot) => Consumer2<bool, Duration>(
                                  //         builder: (context, value1, value2, child) {
                                  //           if (value1) {
                                  //             playPauseAnim.forward();
                                  //           } else {
                                  //             playPauseAnim.reverse();
                                  //           }
                                  //           return Container(
                                  //             decoration: BoxDecoration(
                                  //               color: Colors.black,
                                  //               borderRadius: BorderRadius.circular(16.0),
                                  //             ),
                                  //             child: CustomPaint(
                                  //               painter: MiniMiniPlayerProgressPainter(currentTrack.progress * (1 - rcp)),
                                  //               child: FloatingActionButton(
                                  //                 heroTag: currentTrack.playing,
                                  //                 onPressed: () {
                                  //                   if (currentTrack.MiniPlayer.playing) {
                                  //                     currentTrack.pause();
                                  //                     playPauseAnim.reverse();
                                  //                   } else {
                                  //                     currentTrack.play();
                                  //                     playPauseAnim.forward();
                                  //                   }
                                  //                 },
                                  //                 elevation: 0,
                                  //                 backgroundColor: context.theme.colorScheme.surfaceTint.withOpacity(.3),
                                  //                 child: AnimatedIcon(
                                  //                   progress: playPauseAnim,
                                  //                   icon: AnimatedIcons.play_pause,
                                  //                 ),
                                  //               ),
                                  //             ),
                                  //           );
                                  //         },
                                  //       ),
                                  //     );
                                  //   }

                                  //   return PageTransitionSwitcher(
                                  //     transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                                  //       return FadeThroughTransition(
                                  //         animation: primaryAnimation,
                                  //         secondaryAnimation: secondaryAnimation,
                                  //         fillColor: Colors.transparent,
                                  //         child: child,
                                  //       );
                                  //     },
                                  //     child: playbackIndicator,
                                  //   );
                                  // }
                                  // ),
                                  // ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                              child: TextButton(
                                onLongPress: () {
                                  // Get.focusScope?.unfocus();
                                  Get.dialog(const Dialog(child: VideoPlaybackSettings(disableSubtitle: true)));
                                },
                                onPressed: () async {
                                  await VideoController.inst.toggleVideoPlaybackInSetting();
                                  VideoController.inst.updateYTLink(Player.inst.nowPlayingTrack.value);
                                },
                                child: Row(
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
                                      width: 10.0,
                                    ),
                                    if (!SettingsController.inst.enableVideoPlayback.value)
                                      Text(
                                        Language.inst.AUDIO,
                                        style: TextStyle(color: onSecondary),
                                      ),
                                    if (SettingsController.inst.enableVideoPlayback.value) ...[
                                      Text(
                                        Language.inst.VIDEO,
                                        style: TextStyle(color: onSecondary),
                                      ),
                                      VideoController.inst.youtubeLink.value == '' ? const Text(" ? ") : Text(" • ${VideoController.inst.videoCurrentQuality.value} • "),
                                      const SizedBox(
                                        width: 4.0,
                                      ),
                                      if (VideoController.inst.videoCurrentSize.value > 10)
                                        Text("${VideoController.inst.videoCurrentSize.value.fileSizeFormatted}/", style: TextStyle(color: onSecondary, fontSize: 11.0)),
                                      if (VideoController.inst.youtubeLink.value != '')
                                        Text(VideoController.inst.videoTotalSize.value.fileSizeFormatted, style: TextStyle(color: onSecondary, fontSize: 11.0)),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  /// Lyrics button
                  if (opacity > 0.0)
                    Material(
                      type: MaterialType.transparency,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(-50, -100 * ip),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                child: IconButton(
                                  onPressed: () {
                                    // final track = context.read<currentTrackProvider>().playing!;
                                    // LyricsView.view(track, context: context);
                                  },
                                  icon: Icon(
                                    Broken.document,
                                    size: 22.0,
                                    color: context.theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  /// Queue button
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
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                child: IconButton(
                                  onPressed: () {
                                    snapToQueue();
                                  },
                                  icon: Icon(
                                    Broken.row_vertical,
                                    size: 22.0,
                                    color: context.theme.colorScheme.onSecondaryContainer,
                                  ),
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
                                  track: Player.inst.nowPlayingTrack.value,
                                  p: bp,
                                  cp: bcp,
                                  bottomOffset: bottomOffset,
                                  maxOffset: maxOffset,
                                  screenSize: screenSize,
                                  // ),
                                ),
                              ),
                            ),
                            // Opacity(
                            //   opacity: sAnim.value.clamp(0.0, 1.0),
                            //   child: Transform.translate(
                            //     offset: Offset(-sAnim.value * sMaxOffset / stParallax + sMaxOffset / stParallax, 0),
                            //     child: TrackInfo(
                            //         artist: tracks[2].artists.map((e) => e.name).join(", "),
                            //         title: tracks[2].name,
                            //         cp: cp,
                            //         p: p,
                            //         bottomOffset: bottomOffset,
                            //         maxOffset: maxOffset,
                            //         screenSize: screenSize),
                            //   ),
                            // ),
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
                          // Opacity(
                          //   opacity: -sAnim.value.clamp(-1.0, 0.0),
                          //   child: Transform.translate(
                          //     offset: Offset(-sAnim.value * sMaxOffset / siParallax - sMaxOffset / siParallax, 0),
                          //     child: TrackImage(
                          //       image: tracks[0].album?.images!.maxSize,
                          //       large: true,
                          //       p: p,
                          //       cp: cp,
                          //       screenSize: screenSize,
                          //       bottomOffset: bottomOffset,
                          //       maxOffset: maxOffset,
                          //     ),
                          //   ),
                          // ),
                          Opacity(
                            opacity: 1 - sAnim.value.abs(),
                            child: Transform.translate(
                              offset: Offset(-sAnim.value * sMaxOffset / siParallax, !bounceUp ? (-maxOffset + topInset + 108.0) * (!bounceDown ? qp : (1 - bp)) : 0.0),
                              child: TrackImage(
                                p: bp,
                                cp: bcp,
                                width: vp(a: 82.0, b: 92.0, c: qp),
                                screenSize: screenSize,
                                bottomOffset: bottomOffset,
                                maxOffset: maxOffset,
                              ),
                            ),
                          ),
                          // Opacity(
                          //   opacity: sAnim.value.clamp(0.0, 1.0),
                          //   child: Transform.translate(
                          //     offset: Offset(-sAnim.value * sMaxOffset / siParallax + sMaxOffset / siParallax, 0),
                          //     child: TrackImage(
                          //       image: tracks[2].album?.images!.maxSize,
                          //       large: true,
                          //       p: p,
                          //       cp: cp,
                          //       screenSize: screenSize,
                          //       bottomOffset: bottomOffset,
                          //       maxOffset: maxOffset,
                          //     ),
                          //   ),
                          // ),
                        ],
                      );
                    },
                  ),

                  /// Slider
                  if (fastOpacity > 0.0)
                    Opacity(
                      opacity: fastOpacity,
                      child: Transform.translate(
                        offset: Offset(0, bottomOffset + (-maxOffset / 4.0 * p)),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Obx(
                                () {
                                  final position = seekValue.value != 0.0 ? seekValue.value : Player.inst.nowPlayingPosition.value;
                                  // final position = seekValue.value;
                                  final dur = Player.inst.nowPlayingTrack.value.duration;
                                  final percentage = position / dur;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: ShaderMask(
                                      blendMode: BlendMode.srcATop,
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          tileMode: TileMode.decal,
                                          stops: [0.0, percentage, percentage + 0.01, 1.0],
                                          colors: [
                                            CurrentColor.inst.color.value.withAlpha(200),
                                            CurrentColor.inst.color.value.withAlpha(200),
                                            Colors.transparent,
                                            Colors.transparent
                                          ],
                                        ).createShader(bounds);
                                      },
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          WaveformComponent(
                                            waveDataList: WaveformController.inst.downscaleList(WaveformController.inst.curentWaveform.toList(), Get.width.toInt() ~/ 3.2),
                                            color: context.theme.colorScheme.onBackground.withAlpha(150),
                                            heightMultiplier: 1.1,
                                            // boxMaxHeight: 80.0,
                                          ),
                                          // Slider
                                          Opacity(
                                            opacity: 0.0,
                                            child: Material(
                                              child: Slider(
                                                value: percentage,
                                                onChanged: (double newValue) {
                                                  seekValue.value = newValue;
                                                },
                                                min: 0.0,
                                                max: dur.toDouble(),
                                                onChangeStart: (_) {
                                                  // Disable scrolling or other gestures while the slider is active
                                                },
                                                onChangeEnd: (newValue) {
                                                  Player.inst.seek(Duration(milliseconds: newValue.toInt()));
                                                  seekValue.value = 0.0;
                                                },
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // StreamBuilder(
                              //   stream: currentTrack.MiniPlayer.positionStream,
                              //   builder: (context, snapshot) {
                              //     final pos = currentTrack.MiniPlayer.position;
                              //     final dHours = (currentTrack.MiniPlayer.duration?.inHours ?? 0) > 0;

                              //     return Padding(
                              //       padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              //       child: Row(
                              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //         children: [
                              //           Row(children: [
                              //             if (dHours)
                              //               AnimatedFlipCounter(
                              //                 value: pos.inHours,
                              //                 curve: Curves.easeIn,
                              //                 textStyle: TextStyle(color: onSecondary, letterSpacing: -.5),
                              //               ),
                              //             if (dHours) const Text(":"),
                              //             AnimatedFlipCounter(
                              //               value: pos.inMinutes % 60,
                              //               wholeDigits: dHours ? 2 : 1,
                              //               curve: Curves.easeIn,
                              //               textStyle: TextStyle(color: onSecondary, letterSpacing: -.5),
                              //             ),
                              //             Text(
                              //               ":",
                              //               style: TextStyle(color: onSecondary, letterSpacing: 1),
                              //             ),
                              //             AnimatedFlipCounter(
                              //               value: pos.inSeconds % 60,
                              //               wholeDigits: 2,
                              //               textStyle: TextStyle(color: onSecondary, letterSpacing: -.5),
                              //             ),
                              //           ]),
                              //           Text(
                              //             currentTrack.MiniPlayer.duration?.shortFormat() ?? "0:00",
                              //             style: TextStyle(color: onSecondary),
                              //           ),
                              //         ],
                              //       ),
                              //     );
                              //   },
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (queueOpacity > 0.0)
                    Opacity(
                      opacity: queueOpacity,
                      child: Transform.translate(
                        offset: Offset(0, (1 - queueOffset) * maxOffset),
                        child: IgnorePointer(
                            ignoring: !queueScrollable,
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(38.0), topRight: Radius.circular(38.0)),
                                  child: Obx(
                                    () => ReorderableListView(
                                      scrollController: scrollController,
                                      cacheExtent: Get.height * 3,
                                      onReorderStart: (index) {
                                        setState(() {
                                          queueScrollable = false;
                                        });
                                      },
                                      onReorderEnd: (index) {
                                        setState(() {
                                          queueScrollable = true;
                                        });
                                      },
                                      onReorder: (oldIndex, newIndex) {},
                                      physics: queueScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),

                                      // padding: EdgeInsets.only(top: context.mediaQuery.padding.top + 180),
                                      // controller: scrollController,
                                      children: Player.inst.currentQueue
                                          .asMap()
                                          .entries
                                          .map((e) => TrackTile(
                                                key: ValueKey(e.toString()),
                                                track: e.value,
                                                displayRightDragHandler: true,
                                                draggableThumbnail: true,
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                            )

                            // QueueView(controller: scrollController),
                            ),
                      ),
                    ),

                  // Container(
                  //   color: Colors.red,
                  //   width: 100.0 * bp + 100,
                  //   height: 100.0 * bp + 100,
                  // ),
                ],
              ),
            );
          },
        ),
      ),
      // ),
    );
  }
}

class TrackInfo extends StatelessWidget {
  const TrackInfo({
    Key? key,
    required this.track,
    required this.cp,
    required this.p,
    required this.screenSize,
    required this.bottomOffset,
    required this.maxOffset,
  }) : super(key: key);

  final Track track;
  final double cp;
  final double p;
  final Size screenSize;
  final double bottomOffset;
  final double maxOffset;

  @override
  Widget build(BuildContext context) {
    final double opacity = (inverseAboveOne(p) * 10 - 9).clamp(0, 1);

    return Transform.translate(
      offset: Offset(0, bottomOffset + (-maxOffset / 3.6 * p.clamp(0, 2))),
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
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.0),
                              onTap: cp == 1 ? () => showTrackDialog(track) : null,
                              child: PageTransitionSwitcher(
                                transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                                  return SharedAxisTransition(
                                    fillColor: Colors.transparent,
                                    animation: primaryAnimation,
                                    secondaryAnimation: secondaryAnimation,
                                    transitionType: SharedAxisTransitionType.horizontal,
                                    child: child,
                                  );
                                },
                                layoutBuilder: (entries) => Stack(children: entries),
                                child: Padding(
                                  padding: EdgeInsets.only(left: 8.0 * cp),
                                  child: Column(
                                    key: Key(track.title),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title.overflow,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: vp(a: 15.0, b: 21.0, c: p),
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 4.0,
                                      ),
                                      Text(
                                        track.artistsList.take(3).join(', ').overflow,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.displayMedium?.copyWith(
                                          fontSize: vp(a: 13.0, b: 16.0, c: p),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(-100 * (1.0 - cp), 0.0),
                            child:
                                // final currentMusic = Player.inst.nowPlayingTrack.value;

                                LikeButton(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              bubblesColor: BubblesColor(
                                dotPrimaryColor: context.theme.colorScheme.primary,
                                dotSecondaryColor: context.theme.colorScheme.primaryContainer,
                              ),
                              circleColor: CircleColor(
                                start: context.theme.colorScheme.tertiary,
                                end: context.theme.colorScheme.tertiary,
                              ),
                              isLiked: Player.inst.nowPlayingTrack.value.isFavourite,
                              onTap: (isLiked) async {
                                PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack.value);
                                return !isLiked;
                              },
                              likeBuilder: (value) => value
                                  ? Icon(
                                      Broken.heart_tick,
                                      color: context.theme.colorScheme.primary,
                                      size: 32.0,
                                    )
                                  : Icon(
                                      Broken.heart,
                                      color: context.theme.colorScheme.onSecondaryContainer,
                                      size: 32.0,
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

class TrackImage extends StatelessWidget {
  const TrackImage({
    Key? key,
    this.track,
    required this.bottomOffset,
    required this.maxOffset,
    required this.screenSize,
    required this.cp,
    required this.p,
    this.width = 82.0,
    this.large = false,
  }) : super(key: key);

  final Track? track;
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
              child: PageTransitionSwitcher(
                transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                  return FadeThroughTransition(
                    fillColor: Colors.transparent,
                    animation: primaryAnimation,
                    secondaryAnimation: secondaryAnimation,
                    child: child,
                  );
                },
                child: Obx(
                  () {
                    final isNull = VideoController.inst.vidcontroller == null;
                    final shouldShowVideo = !isNull && VideoController.inst.localVidPath.value != '' && (VideoController.inst.vidcontroller?.value.isInitialized ?? false);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: shouldShowVideo ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          child: ArtworkWidget(
                            track: Player.inst.nowPlayingTrack.value,
                            thumnailSize: Get.width,
                            compressed: false,
                            borderRadius: 6.0 + 12.0 * cp,
                            forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
                            boxShadow: [
                              BoxShadow(
                                color: context.theme.shadowColor.withAlpha(100),
                                blurRadius: 24.0,
                                offset: const Offset(0.0, 8.0),
                              ),
                            ],
                          ),
                        ),
                        isNull
                            ? const SizedBox()
                            : AnimatedOpacity(
                                opacity: shouldShowVideo ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 400),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular((6.0 + 12.0 * cp).multipliedRadius),
                                  child: AspectRatio(
                                    aspectRatio: VideoController.inst.vidcontroller!.value.aspectRatio,
                                    child: VideoPlayer(
                                      VideoController.inst.vidcontroller!,
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
          ),
        ),
      ),
    );
  }
}

class MiniMiniPlayerProgressPainter extends CustomPainter {
  MiniMiniPlayerProgressPainter(this.progress);

  final double progress;
  static const strokeWidth = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawDRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16.0),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(strokeWidth, strokeWidth, size.width - strokeWidth * 2, size.height - strokeWidth * 2),
        const Radius.circular(12.0),
      ),
      Paint()..color = Colors.white.withOpacity(.25),
    );
    canvas.saveLayer(Rect.fromLTWH(-10, -10, size.width + 20, size.height + 20), Paint());
    canvas.drawArc(
      Rect.fromLTWH(-10, -10, size.width + 20, size.height + 20),
      -1.570796,
      6.283185 * (1 - progress) * -1,
      true,
      Paint()..color = Colors.black,
    );
    canvas.drawDRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-10, -10, size.width + 20, size.height + 20),
        const Radius.circular(0.0),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16.0),
      ),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MiniMiniPlayerProgressPainter oldDelegate) => oldDelegate.progress != progress;
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
