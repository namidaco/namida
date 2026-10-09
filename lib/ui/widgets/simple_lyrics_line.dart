import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/romanizer/romanizer_engine.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/lyrics_karaoke_text.dart';

/// built by claude (based on lyrics_lrc_parsed_view.dart)
class SimpleLyricsLineWidget extends StatefulWidget {
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;
  final bool softWrap;
  final Rxn<Lrc>? customSourceRx;
  final bool respectEndTimestamps;
  final bool stretchToItemDuration;

  /// shrinks the font by [shrinkFactor] when the line overflows [maxLines], then allows one extra line.
  final bool fitToWidth;

  /// translations/romanizations sharing the line's timestamp, one smaller line each below it.
  final int maxSecondaryLines;

  /// word synced lines sweep word by word, others get a short reveal or a whole-line sweep. null keeps plain text.
  final LyricsKaraokeEffects? karaoke;

  const SimpleLyricsLineWidget({
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
    this.softWrap = false,
    this.customSourceRx,
    this.respectEndTimestamps = false,
    this.stretchToItemDuration = true,
    this.fitToWidth = false,
    this.maxSecondaryLines = _defaultMaxSecondaryLines,
    this.karaoke = _leanKaraoke,
  });

  static const shrinkFactor = 0.875;
  static const _lineHeightFactor = 1.3;
  static const _secondaryFontFactor = 0.8;
  static const _secondaryAlpha = 0.7;
  static const _defaultMaxSecondaryLines = 1;

  /// only what costs nothing per frame.
  static const _leanKaraoke = LyricsKaraokeEffects(
    accentTint: true,
    glow: true,
    wordBump: false,
    shimmer: true,
    feather: true,
    untimedLineSweep: false,
  );

  /// tallest layout [fitToWidth] can pick for [lrc], for layouts reserving the room ahead of time.
  static double fittedMaxHeight({
    required Lrc lrc,
    required double fontSize,
    required int maxLines,
    int maxSecondaryLines = _defaultMaxSecondaryLines,
    required TextScaler textScaler,
  }) {
    final primaryHeight = textScaler.scale(fontSize * shrinkFactor) * _lineHeightFactor * (maxLines + 1);
    if (maxSecondaryLines == 0 || !_hasSecondaryLines(lrc)) return primaryHeight;
    final secondaryLineHeight = textScaler.scale(fontSize * _secondaryFontFactor) * _lineHeightFactor;
    return primaryHeight + secondaryLineHeight * maxSecondaryLines;
  }

  static final _secondarySourcesCache = Expando<_SecondarySources>();

  static bool _hasSecondaryLines(Lrc lrc) {
    final sources = _secondarySourcesCache[lrc] ??= _findSecondarySources(lrc);
    return sources.hasSharedTimestamps || (sources.needsRomanization && settings.romanizeLyrics.value);
  }

  /// mirrors the grouping of [LrcExtensions.forUiDisplay]: lines sharing a timestamp, or romanized copies.
  static _SecondarySources _findSecondarySources(Lrc lrc) {
    var hasSharedTimestamps = false;
    var needsRomanization = false;
    final timestamps = <Duration>{};
    for (final line in lrc.lyrics) {
      if (line.isBGLyrics || line.readableText.isEmpty) continue;
      if (!hasSharedTimestamps && !timestamps.add(line.timestamp)) hasSharedTimestamps = true;
      if (!needsRomanization && RomanizerEngine.needsRomanization(line.readableText)) needsRomanization = true;
      if (hasSharedTimestamps && needsRomanization) break;
    }
    return (hasSharedTimestamps: hasSharedTimestamps, needsRomanization: needsRomanization);
  }

  @override
  State<SimpleLyricsLineWidget> createState() => _SimpleLyricsLineWidgetState();
}

class _SimpleLyricsLineWidgetState extends State<SimpleLyricsLineWidget> {
  final _currentLine = Rxn<LrcLine>();
  var _lines = <LrcLine>[];
  var _highlightTimestampsMap = <Duration, List<int>>{}; // timestamp: [index]
  var _lineResolver = LrcLineResolver.empty;

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

    // -- fixed line height, otherwise the painted band doesn't match [fittedMaxHeight].
    final fittedStyle = (style ?? const TextStyle()).copyWith(height: SimpleLyricsLineWidget._lineHeightFactor);

    final maxLines = widget.maxLines;
    if (!maxWidth.isFinite) {
      _fitResultStyle = fittedStyle;
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

    if (fits(fittedStyle, maxLines)) {
      _fitResultStyle = fittedStyle;
      _fitResultMaxLines = maxLines;
    } else {
      final fontSize = (fittedStyle.fontSize ?? 14.0) * SimpleLyricsLineWidget.shrinkFactor;
      final small = fittedStyle.copyWith(fontSize: fontSize);
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
      _lineResolver = LrcLineResolver.empty;
      _currentLine.value = null;
      return;
    }
    final romanizer = widget.maxSecondaryLines > 0 ? Romanizer.inst.lyricsRomanizer(lrc) : null;
    final stretchMultiplier = widget.stretchToItemDuration ? Lyrics.inst.getStretchMultiplier(lrc) : 0.0;
    final uiInfo = lrc.forUiDisplay(
      stretchMultiplier,
      durationDifferenceToInsertEmptyLine: const Duration(seconds: 1),
      extraOffsetDuration: Duration(milliseconds: settings.visualDelayMS.value),
      romanizer: romanizer,
    );
    _lines = uiInfo.uiLyricsLines;
    _highlightTimestampsMap = uiInfo.highlightTimestampsMap;
    _lineResolver = uiInfo.lineResolver;
    _updateLine();
  }

  static Duration? _lineEndTimestamp(LrcLine line) {
    final parts = line.parts;
    if (parts == null || parts.isEmpty) return null;
    return parts.last.endTimestamp;
  }

  void _updateLine() {
    final lines = _lines;
    if (lines.isEmpty) return;

    final positionMS = Player.inst.nowPlayingPosition.value;
    final lineIndex = _lineResolver.indexAt(positionMS);
    var newLine = lineIndex < 0 ? null : lines[lineIndex];
    if (newLine != null && widget.respectEndTimestamps) {
      final end = _lineEndTimestamp(newLine);
      if (end != null && end.inMilliseconds <= positionMS + LrcLineResolver.kToleranceMS) newLine = null;
    }
    if (!identical(_currentLine.value, newLine)) _currentLine.value = newLine;
  }

  Duration? _nextLineStartOf(LrcLine line) {
    final lastIndex = _highlightTimestampsMap[line.timestamp]?.lastOrNull;
    if (lastIndex == null) return null;
    final nextIndex = lastIndex + 1;
    return nextIndex < _lines.length ? _lines[nextIndex].timestamp : null;
  }

  List<LrcLine> _secondaryLinesOf(LrcLine line) {
    final maxCount = widget.maxSecondaryLines;
    if (maxCount == 0) return const [];
    final indices = _highlightTimestampsMap[line.timestamp];
    if (indices == null || indices.length < 2) return const [];
    final secondaryLines = <LrcLine>[];
    for (final index in indices) {
      final other = _lines[index];
      if (identical(other, line) || other.isBGLyrics || other.readableText.isEmpty) continue;
      secondaryLines.add(other);
      if (secondaryLines.length == maxCount) break;
    }
    return secondaryLines;
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
          final secondaryLines = _secondaryLinesOf(line);
          final lineEnd = _nextLineStartOf(line);
          final primaryKey = secondaryLines.isEmpty ? key : null;
          final primary = widget.fitToWidth
              ? LayoutBuilder(
                  key: primaryKey,
                  builder: (context, constraints) {
                    _resolveFit(line, text, constraints.maxWidth, direction, MediaQuery.textScalerOf(context));
                    final maxLines = _fitResultMaxLines;
                    return _PrimaryLine(
                      line: line,
                      lineEnd: lineEnd,
                      style: _fitResultStyle,
                      textAlign: widget.textAlign,
                      textDirection: direction,
                      maxLines: maxLines,
                      softWrap: widget.softWrap || maxLines > widget.maxLines,
                      karaoke: widget.karaoke,
                    );
                  },
                )
              : _PrimaryLine(
                  key: primaryKey,
                  line: line,
                  lineEnd: lineEnd,
                  style: widget.style,
                  textAlign: widget.textAlign,
                  textDirection: direction,
                  maxLines: widget.maxLines,
                  softWrap: widget.softWrap,
                  karaoke: widget.karaoke,
                );
          child = secondaryLines.isEmpty
              ? primary
              : Column(
                  key: key,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primary,
                    ...secondaryLines.map(
                      (e) => _SecondaryLine(
                        line: e,
                        baseStyle: widget.style,
                        textAlign: widget.textAlign,
                      ),
                    ),
                  ],
                );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: child,
        );
      },
    );
  }
}

class _PrimaryLine extends StatelessWidget {
  final LrcLine line;
  final Duration? lineEnd;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final int maxLines;
  final bool softWrap;
  final LyricsKaraokeEffects? karaoke;

  const _PrimaryLine({
    super.key,
    required this.line,
    required this.lineEnd,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.maxLines,
    required this.softWrap,
    required this.karaoke,
  });

  @override
  Widget build(BuildContext context) {
    final karaoke = this.karaoke;
    if (karaoke == null) {
      return Text(
        line.readableText,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: TextOverflow.fade,
      );
    }
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final isDark = context.isDarkMode;
    return Obx(
      (context) => LyricsKaraokeText(
        line: line,
        lineEnd: lineEnd,
        textStyle: effectiveStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        accentColor: CurrentColor.inst.miniplayerColor,
        isDark: isDark,
        effects: karaoke,
        maxLines: maxLines,
        lineHeight: SimpleLyricsLineWidget._lineHeightFactor,
      ),
    );
  }
}

class _SecondaryLine extends StatelessWidget {
  final LrcLine line;
  final TextStyle? baseStyle;
  final TextAlign textAlign;

  const _SecondaryLine({
    required this.line,
    required this.baseStyle,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ?? const TextStyle();
    final fontSize = (style.fontSize ?? 14.0) * SimpleLyricsLineWidget._secondaryFontFactor;
    final color = style.color;
    final secondaryColor = color?.withOpacityExt(color.a * SimpleLyricsLineWidget._secondaryAlpha);
    final secondaryStyle = style.copyWith(
      fontSize: fontSize,
      height: SimpleLyricsLineWidget._lineHeightFactor,
      color: secondaryColor,
    );
    return Text(
      line.readableText,
      style: secondaryStyle,
      textAlign: textAlign,
      textDirection: line.isRTL == true ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }
}

typedef _SecondarySources = ({bool hasSharedTimestamps, bool needsRomanization});
