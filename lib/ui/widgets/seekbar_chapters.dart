// by claude
import 'package:flutter/material.dart';

import 'package:namida/class/media_chapter.dart';
import 'package:namida/controller/chapters_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

/// cuts a thin gap into [child] where each chapter of the current item starts.
class ChapterGapsClip extends StatelessWidget {
  final Widget child;

  const ChapterGapsClip({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final chapters = ChaptersController.inst.currentChapters.valueR;
        final durationMS = Player.inst.currentItemDuration.valueR?.inMilliseconds ?? 0;
        final hasGaps = chapters.isNotEmpty && durationMS > 0;
        // -- same tree either way, so [child] keeps its state when chapters come and go
        return ClipPath(
          clipper: hasGaps ? _ChapterGapsClipper(chapters: chapters, durationMS: durationMS) : null,
          clipBehavior: hasGaps ? Clip.hardEdge : Clip.none,
          child: child,
        );
      },
    );
  }
}

class _ChapterGapsClipper extends CustomClipper<Path> {
  static const _kGapWidth = 3.0;

  final List<MediaChapter> chapters;
  final int durationMS;

  const _ChapterGapsClipper({
    required this.chapters,
    required this.durationMS,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    double previousEnd = 0.0;
    for (final chapter in chapters) {
      final startMS = chapter.startMS;
      if (startMS <= 0) continue;
      final x = startMS / durationMS * width;
      if (x >= width) break;
      final gapStart = x - _kGapWidth / 2;
      if (gapStart > previousEnd) path.addRect(Rect.fromLTRB(previousEnd, 0.0, gapStart, height));
      previousEnd = gapStart + _kGapWidth;
    }
    if (previousEnd < width) path.addRect(Rect.fromLTRB(previousEnd, 0.0, width, height));
    return path;
  }

  @override
  bool shouldReclip(_ChapterGapsClipper oldClipper) => !identical(oldClipper.chapters, chapters) || oldClipper.durationMS != durationMS;
}

class ChapterProgressBar extends StatelessWidget {
  final (int, int) rangeMS;

  const ChapterProgressBar({
    super.key,
    required this.rangeMS,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ChapterProgressPainter(
          startMS: rangeMS.$1,
          endMS: rangeMS.$2,
          trackColor: colorScheme.onSecondaryContainer.withOpacityExt(0.15),
          fillColor: colorScheme.primary,
        ),
      ),
    );
  }
}

class _ChapterProgressPainter extends CustomPainter {
  final int startMS;
  final int endMS;
  final Color trackColor;
  final Color fillColor;
  final Paint _trackPaint;
  final Paint _fillPaint;

  _ChapterProgressPainter({
    required this.startMS,
    required this.endMS,
    required this.trackColor,
    required this.fillColor,
  }) : _trackPaint = Paint()..color = trackColor,
       _fillPaint = Paint()..color = fillColor,
       super(repaint: Player.inst.nowPlayingPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromLTRBR(0.0, 0.0, size.width, size.height, radius), _trackPaint);
    final fraction = ((Player.inst.nowPlayingPosition.value - startMS) / (endMS - startMS)).clampDouble(0.0, 1.0);
    if (fraction > 0.0) canvas.drawRRect(RRect.fromLTRBR(0.0, 0.0, size.width * fraction, size.height, radius), _fillPaint);
  }

  @override
  bool shouldRepaint(_ChapterProgressPainter oldDelegate) {
    return oldDelegate.startMS != startMS || oldDelegate.endMS != endMS || oldDelegate.trackColor != trackColor || oldDelegate.fillColor != fillColor;
  }
}
