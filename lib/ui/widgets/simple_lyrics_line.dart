import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';

import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/utils.dart';

/// built by claude (based on lyrics_lrc_parsed_view.dart)
class SimpleLyricsLineWidget extends StatefulWidget {
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;
  final bool softWrap;
  final Rxn<Lrc>? customSourceRx;
  final bool respectEndTimestamps;

  /// shrinks the font by [shrinkFactor] when the line overflows [maxLines], then allows one extra line.
  final bool fitToWidth;

  const SimpleLyricsLineWidget({
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
    this.softWrap = false,
    this.customSourceRx,
    this.respectEndTimestamps = false,
    this.fitToWidth = false,
  });

  static const shrinkFactor = 0.875;
  static const _lineHeightFactor = 1.3;

  /// tallest layout [fitToWidth] can pick, for layouts reserving the room ahead of time.
  static double fittedMaxHeight({required double fontSize, required int maxLines}) {
    return fontSize * shrinkFactor * _lineHeightFactor * (maxLines + 1);
  }

  @override
  State<SimpleLyricsLineWidget> createState() => _SimpleLyricsLineWidgetState();
}

class _SimpleLyricsLineWidgetState extends State<SimpleLyricsLineWidget> {
  final _currentLine = Rxn<LrcLine>();
  var _lines = <LrcLine>[];
  var _highlightTimestampsMap = <Duration, List<int>>{}; // timestamp: [index]
  int _lastScanIndex = -1;

  late final Rxn<Lrc> _source = widget.customSourceRx ?? Lyrics.inst.currentLyricsLRC;

  LrcLine? _fitLine;
  double _fitMaxWidth = -1;
  TextStyle? _fitStyle;
  TextScaler? _fitScaler;
  TextStyle? _fitResultStyle;
  int _fitResultMaxLines = 1;

  void _resolveFit(LrcLine line, String text, double maxWidth, TextDirection direction, TextScaler scaler) {
    final style = widget.style;
    if (identical(line, _fitLine) && maxWidth == _fitMaxWidth && scaler == _fitScaler && style == _fitStyle) return;
    _fitLine = line;
    _fitMaxWidth = maxWidth;
    _fitScaler = scaler;
    _fitStyle = style;

    final maxLines = widget.maxLines;
    if (!maxWidth.isFinite) {
      _fitResultStyle = style;
      _fitResultMaxLines = maxLines;
      return;
    }

    final painter = TextPainter(
      textDirection: direction,
      textAlign: widget.textAlign,
      textScaler: scaler,
    );
    bool fits(TextStyle? style, int lines) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..maxLines = lines
        ..layout(maxWidth: maxWidth);
      return !painter.didExceedMaxLines;
    }

    if (fits(style, maxLines)) {
      _fitResultStyle = style;
      _fitResultMaxLines = maxLines;
    } else {
      final fontSize = (style?.fontSize ?? 14.0) * SimpleLyricsLineWidget.shrinkFactor;
      final small = style?.copyWith(fontSize: fontSize) ?? TextStyle(fontSize: fontSize);
      _fitResultStyle = small;
      _fitResultMaxLines = fits(small, maxLines) ? maxLines : maxLines + 1;
    }
    painter.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fillLines();
    _source.addListener(_fillLines);
    Player.inst.nowPlayingPosition.addListener(_updateLine);
  }

  @override
  void dispose() {
    _source.removeListener(_fillLines);
    Player.inst.nowPlayingPosition.removeListener(_updateLine);
    _currentLine.close();
    super.dispose();
  }

  void _fillLines() {
    final lrc = _source.value;
    if (lrc == null) {
      _lines = [];
      _highlightTimestampsMap = {};
      _lastScanIndex = -1;
      _currentLine.value = null;
      return;
    }
    final uiInfo = lrc.forUiDisplay(
      0,
      durationDifferenceToInsertEmptyLine: const Duration(seconds: 1),
      extraOffsetDuration: Duration(milliseconds: -settings.visualDelayMS.value),
      romanize: false,
    );
    _lines = uiInfo.uiLyricsLines;
    _highlightTimestampsMap = uiInfo.highlightTimestampsMap;
    _lastScanIndex = -1;
    _updateLine();
  }

  static Duration? _lineEndTimestamp(LrcLine line) {
    final parts = line.parts;
    if (parts == null || parts.isEmpty) return null;
    final shift = line.timestamp - parts.first.startTimestamp;
    return parts.last.endTimestamp + shift;
  }

  void _updateLine() {
    final lines = _lines;
    if (lines.isEmpty) return;

    final position = Duration(milliseconds: Player.inst.nowPlayingPosition.value + 5);

    // -- incremental scan, index only advances by few steps normally
    int idx = _lastScanIndex;
    if (idx >= lines.length) idx = -1;
    if (idx >= 0 && lines[idx].timestamp > position) idx = -1; // -- seeked backwards
    while (idx + 1 < lines.length && lines[idx + 1].timestamp <= position) {
      idx++;
    }
    _lastScanIndex = idx;

    // -- resolve to a primary displayable line
    var lineIndex = idx;
    while (lineIndex >= 0 && lines[lineIndex].isBGLyrics) {
      lineIndex--;
    }
    if (lineIndex >= 0) {
      lineIndex = _highlightTimestampsMap[lines[lineIndex].timestamp]?.firstOrNull ?? lineIndex;
    }

    var newLine = lineIndex < 0 ? null : lines[lineIndex];
    if (newLine != null && widget.respectEndTimestamps) {
      final end = _lineEndTimestamp(newLine);
      if (end != null && end <= position) newLine = null;
    }
    if (!identical(_currentLine.value, newLine)) _currentLine.value = newLine;
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: _currentLine,
      builder: (context, line) {
        final text = line?.readableText ?? '';
        final Widget child;
        if (text.isEmpty) {
          child = const SizedBox.shrink(key: ValueKey(''));
        } else {
          final key = ValueKey(line!.timestamp);
          final direction = line.isRTL == true ? TextDirection.rtl : TextDirection.ltr;
          child = widget.fitToWidth
              ? LayoutBuilder(
                  key: key,
                  builder: (context, constraints) {
                    _resolveFit(line, text, constraints.maxWidth, direction, MediaQuery.textScalerOf(context));
                    final maxLines = _fitResultMaxLines;
                    return Text(
                      text,
                      style: _fitResultStyle,
                      textAlign: widget.textAlign,
                      textDirection: direction,
                      maxLines: maxLines,
                      softWrap: widget.softWrap || maxLines > widget.maxLines,
                      overflow: TextOverflow.fade,
                    );
                  },
                )
              : Text(
                  text,
                  key: key,
                  style: widget.style,
                  textAlign: widget.textAlign,
                  textDirection: direction,
                  maxLines: widget.maxLines,
                  softWrap: widget.softWrap,
                  overflow: TextOverflow.fade,
                );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
    );
  }
}
