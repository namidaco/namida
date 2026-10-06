// by claude
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/bookmarks_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class BookmarkTicks extends StatelessWidget {
  /// defaults to the miniplayer color.
  final Color? color;
  final double tickWidth;
  final double dotRadius;

  const BookmarkTicks({
    super.key,
    this.color,
    required this.tickWidth,
    this.dotRadius = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final bookmarks = BookmarksController.inst.currentBookmarks.valueR;
        if (bookmarks.isEmpty) return const SizedBox();
        final durationMS = Player.inst.currentItemDuration.valueR?.inMilliseconds ?? 0;
        if (durationMS <= 0) return const SizedBox();
        final color = this.color ?? CurrentColor.inst.miniplayerColor;
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BookmarkTicksPainter(
                bookmarks: bookmarks,
                durationMS: durationMS,
                color: color,
                tickWidth: tickWidth,
                dotRadius: dotRadius,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// stays out of the gesture arena, so holding then dragging still seeks.
class SeekbarLongPress {
  static const _kHoldDuration = Duration(milliseconds: 800);

  Timer? _timer;
  bool _isReady = false;
  Offset _downPosition = Offset.zero;

  void onPointerDown(PointerDownEvent event) {
    _downPosition = event.localPosition;
    _isReady = false;
    _timer?.cancel();
    _timer = Timer(_kHoldDuration, _onReady);
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_timer == null) return;
    final movedDistance = (event.localPosition - _downPosition).distance;
    if (movedDistance > kTouchSlop) _cancelTimer();
  }

  void onPointerUp(PointerUpEvent _) => _cancelTimer();

  void onPointerCancel(PointerCancelEvent _) {
    _isReady = false;
    _cancelTimer();
  }

  /// returns whether the tap was a long press, which then replaces the seek.
  bool handleTapUp(double dx, double widthPx, int durationMS) {
    if (!_isReady) return false;
    _isReady = false;
    final pressedMS = (dx / widthPx * durationMS).round();
    BookmarksController.inst.onSeekbarLongPress(pressedMS, durationMS, widthPx);
    return true;
  }

  void dispose() => _cancelTimer();

  void _onReady() {
    _timer = null;
    _isReady = true;
    VibratorController.medium();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

class _BookmarkTicksPainter extends CustomPainter {
  final List<PlayableBookmark> bookmarks;
  final int durationMS;
  final Color color;
  final double tickWidth;
  final double dotRadius;

  const _BookmarkTicksPainter({
    required this.bookmarks,
    required this.durationMS,
    required this.color,
    required this.tickWidth,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hasDot = dotRadius > 0;
    final lineColor = hasDot ? color.withOpacityExt(0.4) : color;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = tickWidth;
    final dotPaint = Paint()..color = color;
    final lineTop = hasDot ? dotRadius * 2 : 0.0;
    for (final bookmark in bookmarks) {
      final fraction = (bookmark.positionMS / durationMS).clampDouble(0.0, 1.0);
      final x = size.width * fraction;
      canvas.drawLine(Offset(x, lineTop), Offset(x, size.height), linePaint);
      if (hasDot) canvas.drawCircle(Offset(x, dotRadius), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_BookmarkTicksPainter oldDelegate) {
    return !identical(bookmarks, oldDelegate.bookmarks) ||
        durationMS != oldDelegate.durationMS ||
        color != oldDelegate.color ||
        tickWidth != oldDelegate.tickWidth ||
        dotRadius != oldDelegate.dotRadius;
  }
}
