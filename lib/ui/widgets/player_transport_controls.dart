// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/live_progress.dart';
import 'package:namida/youtube/class/youtube_id.dart';

/// Used in fullscreen lyrics & widescreen player
class PlayerTransportControls extends StatefulWidget {
  final bool addBottomSafePadding;
  final double waveformYScale;
  final double waveformBottomGap;
  final double bottomPadding;

  const PlayerTransportControls({
    super.key,
    this.addBottomSafePadding = true,
    this.waveformYScale = 1.0,
    this.waveformBottomGap = 12.0,
    this.bottomPadding = 24.0,
  });

  @override
  State<PlayerTransportControls> createState() => _PlayerTransportControlsState();
}

class _PlayerTransportControlsState extends State<PlayerTransportControls> {
  final _currentItemDurationMS = RxnO<int>();

  @override
  void initState() {
    super.initState();
    _itemDurationUpdater();
    Player.inst.currentItemDuration.addListener(_itemDurationUpdater);
  }

  @override
  void dispose() {
    Player.inst.currentItemDuration.removeListener(_itemDurationUpdater);
    _currentItemDurationMS.close();
    super.dispose();
  }

  int _itemDurationUpdater() {
    int totalDurMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
    if (totalDurMS == 0) {
      final current = Player.inst.currentItem.value;
      if (current is Selectable) {
        totalDurMS = current.track.durationMS;
      } else if (current is YoutubeID) {
        totalDurMS = Player.inst.getCurrentVideoDuration.inMilliseconds;
      }
    }
    _currentItemDurationMS.value = totalDurMS;
    return totalDurMS;
  }

  @override
  Widget build(BuildContext context) {
    const waveform = WaveformMiniplayer(
      fixPadding: true,
      enableHero: false,
    );
    final waveformYScale = widget.waveformYScale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        waveformYScale == 1.0
            ? waveform
            : Align(
                heightFactor: waveformYScale,
                child: Transform.scale(
                  scaleY: waveformYScale,
                  child: waveform,
                ),
              ),
        SizedBox(height: widget.waveformBottomGap),
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SeekBackwardsDetectorWidget(
                      child: NamidaHero(
                        enabled: false,
                        tag: 'MINIPLAYER_POSITION',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: ObxO(
                            rx: Player.inst.currentLiveWindow,
                            builder: (context, liveWindow) => liveWindow != null
                                ? LivePositionText(
                                    window: liveWindow,
                                    style: NText.small,
                                  )
                                : ObxO(
                                    rx: Player.inst.nowPlayingPosition,
                                    builder: (context, currentMS) => NamidaText(
                                      currentMS.milliSecondsLabel,
                                      style: NText.small,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              NamidaIconButton(
                icon: Broken.previous,
                iconSize: 24.0,
                onPressed: Player.inst.previous,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: (constraints.maxWidth * 0.04).clampDouble(8.0, 32.0)),
                child: const _PlayPauseButton(),
              ),
              NamidaIconButton(
                icon: Broken.next,
                iconSize: 24.0,
                onPressed: Player.inst.next,
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SeekForwardDetectorWidget(
                      child: NamidaHero(
                        enabled: false,
                        tag: 'MINIPLAYER_DURATION',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: ObxO(
                            rx: Player.inst.currentLiveWindow,
                            builder: (context, liveWindow) => liveWindow != null
                                ? LiveEdgeChip(window: liveWindow)
                                : ObxO(
                                    rx: settings.player.displayRemainingDurInsteadOfTotal,
                                    builder: (context, displayRemainingDurInsteadOfTotal) => displayRemainingDurInsteadOfTotal
                                        ? ObxO(
                                            rx: _currentItemDurationMS,
                                            builder: (context, durMS) {
                                              int finalDurMS = durMS ?? 0;
                                              return ObxO(
                                                rx: Player.inst.currentItem,
                                                builder: (context, currentItem) {
                                                  if (finalDurMS == 0 && currentItem is Selectable) {
                                                    finalDurMS = currentItem.track.durationMS;
                                                  }
                                                  return ObxO(
                                                    rx: Player.inst.nowPlayingPosition,
                                                    builder: (context, toSubtract) => NamidaText(
                                                      "- ${(finalDurMS - toSubtract).milliSecondsLabel}",
                                                      style: NText.small,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          )
                                        : ObxO(
                                            rx: _currentItemDurationMS,
                                            builder: (context, milliseconds) {
                                              if (milliseconds == null || milliseconds == 0) {
                                                return ObxO(
                                                  rx: Player.inst.currentItem,
                                                  builder: (context, currentItem) => NamidaText(
                                                    (currentItem is Selectable ? currentItem.track.durationMS : 0).milliSecondsLabel,
                                                    style: NText.small,
                                                  ),
                                                );
                                              }
                                              return NamidaText(
                                                milliseconds.milliSecondsLabel,
                                                style: NText.small,
                                              );
                                            },
                                          ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: widget.bottomPadding),
        if (widget.addBottomSafePadding) SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

/// Play/pause with the same colored circle the main player uses.
class _PlayPauseButton extends StatelessWidget {
  final double iconSize;
  final double extraPadding;

  const _PlayPauseButton({this.iconSize = 32.0, this.extraPadding = 12.0});

  void _setHighlighted(bool value) => MiniPlayerController.inst.isPlayPauseButtonHighlighted.value = value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: Player.inst.togglePlayPause,
      onTapDown: (_) => _setHighlighted(true),
      onTapUp: (_) => _setHighlighted(false),
      onTapCancel: () => _setHighlighted(false),
      child: Obx(
        (context) {
          final isButtonHighlighed = MiniPlayerController.inst.isPlayPauseButtonHighlighted.valueR;
          final miniplayerColor = CurrentColor.inst.miniplayerColor;
          return AnimatedScale(
            duration: const Duration(milliseconds: 400),
            scale: isButtonHighlighed ? 0.97 : 1.0,
            child: AnimatedDecoration(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                color: isButtonHighlighed ? Color.alphaBlend(miniplayerColor.withOpacityExt(0.91), Colors.white) : miniplayerColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    miniplayerColor,
                    Color.alphaBlend(miniplayerColor.withOpacityExt(0.78), Colors.grey),
                  ],
                  stops: const [0, 0.7],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: miniplayerColor.withOpacityExt(0.63),
                    blurRadius: 8.0,
                    spreadRadius: isButtonHighlighed ? 3.0 : 1.0,
                    offset: const Offset(0.0, 2.0),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(extraPadding),
                    child: ObxO(
                      rx: Player.inst.playWhenReady,
                      builder: (context, playWhenReady) => CustomAnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          playWhenReady ? Broken.pause : Broken.play,
                          size: iconSize,
                          key: Key(playWhenReady ? 'pauseicon' : 'playicon'),
                          color: Colors.white.withOpacityExt(0.71),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Obx(
                      (context) => Player.inst.shouldShowLoadingIndicatorR
                          ? ThreeArchedCircle(
                              color: Colors.white.withOpacityExt(0.47),
                              size: iconSize * 1.4,
                            )
                          : const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
