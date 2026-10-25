// by claude

import 'package:just_audio/just_audio.dart';

import 'package:namida/core/extensions.dart';

/// what a progress bar spans: the whole item, or the seekable window of a live item.
class ProgressSpan {
  final int startMS;
  final int lengthMS;

  /// live only, positions at the edge draw as a full bar instead of drifting around it.
  final int? _liveEdgeMS;

  const ProgressSpan.item(int durationMS) : startMS = 0, lengthMS = durationMS, _liveEdgeMS = null;

  ProgressSpan.live(LiveWindow window) : startMS = window.start.inMilliseconds, lengthMS = (window.edge - window.start).inMilliseconds, _liveEdgeMS = window.edge.inMilliseconds;

  bool get isEmpty => lengthMS <= 0;

  double fractionOf(int positionMS) {
    final liveEdgeMS = _liveEdgeMS;
    if (liveEdgeMS != null && liveEdgeMS - positionMS <= LiveWindowUtils.kAtEdgeToleranceMS) return 1.0;
    if (lengthMS <= 0) return 0.0;
    final fraction = (positionMS - startMS) / lengthMS;
    return fraction.clampDouble(0.0, 1.0);
  }

  int positionAt(double fraction) => startMS + (fraction * lengthMS).round();
}

extension LiveWindowUtils on LiveWindow {
  /// playback within this distance of [LiveWindow.edge] counts as live, players drift by up to a segment.
  static const kAtEdgeToleranceMS = 6000;

  int behindEdgeMS(int positionMS) => (edge.inMilliseconds - positionMS).withMinimum(0);

  bool isAtEdge(int positionMS) => behindEdgeMS(positionMS) <= kAtEdgeToleranceMS;

  /// [joinPosition] is where playback of this item started, in [LiveWindow.offset] timebase.
  int watchedMS(int positionMS, Duration? joinPosition) {
    if (joinPosition == null) return 0;
    final stablePositionMS = positionMS + offset.inMilliseconds;
    return (stablePositionMS - joinPosition.inMilliseconds).withMinimum(0);
  }
}
