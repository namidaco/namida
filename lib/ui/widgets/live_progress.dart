// all live progress logic by claude

import 'package:flutter/material.dart';

import 'package:just_audio/just_audio.dart';

import 'package:namida/class/progress_span.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

/// red while at the live edge, tapping it jumps to the live edge.
class LiveEdgeChip extends StatelessWidget {
  final LiveWindow window;
  final double iconSize;

  /// icon color while behind, the red chip always uses white.
  final NColors? color;

  const LiveEdgeChip({
    super.key,
    required this.window,
    this.iconSize = 16.0,
    this.color,
  });

  static final _kAtEdgeBgColor = NColors.fixed(const Color.fromARGB(220, 215, 30, 30));
  static const _kBehindBgColor = NColors(.onSurface, opacity: 0.12);

  @override
  Widget build(BuildContext context) {
    return ObxOSelect(
      rx: Player.inst.nowPlayingPosition,
      selector: window.isAtEdge,
      builder: (context, isAtEdge) {
        final colors = NColorsData.of(context);
        final iconColor = isAtEdge ? Colors.white : color?.resolve(colors);
        return NamidaInkWell(
          onTap: Player.inst.seekToLiveEdge,
          borderRadius: 6.0,
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
          bgColor: isAtEdge ? _kAtEdgeBgColor : _kBehindBgColor,
          child: Icon(
            Broken.radar_1,
            size: iconSize,
            color: iconColor,
          ),
        );
      },
    );
  }
}

/// time watched while at the live edge, how far behind it otherwise.
class LivePositionText extends StatelessWidget {
  final LiveWindow window;
  final NText style;
  final NColors? color;

  const LivePositionText({
    super.key,
    required this.window,
    required this.style,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.nowPlayingPosition,
      builder: (context, positionMS) {
        final behindMS = window.behindEdgeMS(positionMS);
        final text = behindMS > LiveWindowUtils.kAtEdgeToleranceMS
            ? '-${behindMS.milliSecondsLabel}'
            : window.watchedMS(positionMS, Player.inst.liveJoinPosition).milliSecondsLabel;
        return NamidaText(
          text,
          style: style,
          color: color,
        );
      },
    );
  }
}
