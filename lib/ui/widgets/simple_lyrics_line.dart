import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';

import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

/// built by claude (based on lyrics_lrc_parsed_view.dart)
class SimpleLyricsLineWidget extends StatefulWidget {
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  const SimpleLyricsLineWidget({
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  @override
  State<SimpleLyricsLineWidget> createState() => _SimpleLyricsLineWidgetState();
}

class _SimpleLyricsLineWidgetState extends State<SimpleLyricsLineWidget> {
  final _currentLine = Rxn<LrcLine>();
  var _lines = <LrcLine>[];
  var _highlightTimestampsMap = <Duration, List<int>>{}; // timestamp: [index]
  int _lastScanIndex = -1;

  @override
  void initState() {
    super.initState();
    _fillLines();
    Lyrics.inst.currentLyricsLRC.addListener(_fillLines);
    Player.inst.nowPlayingPosition.addListener(_updateLine);
  }

  @override
  void dispose() {
    Lyrics.inst.currentLyricsLRC.removeListener(_fillLines);
    Player.inst.nowPlayingPosition.removeListener(_updateLine);
    _currentLine.close();
    super.dispose();
  }

  void _fillLines() {
    final lrc = Lyrics.inst.currentLyricsLRC.value;
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

    final newLine = lineIndex < 0 ? null : lines[lineIndex];
    if (!identical(_currentLine.value, newLine)) _currentLine.value = newLine;
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: _currentLine,
      builder: (context, line) {
        final text = line?.readableText ?? '';
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: text.isEmpty
              ? const SizedBox.shrink(key: ValueKey(''))
              : Text(
                  text,
                  key: ValueKey(line!.timestamp),
                  style: widget.style,
                  textAlign: widget.textAlign,
                  textDirection: line.isRTL == true ? TextDirection.rtl : TextDirection.ltr,
                  maxLines: widget.maxLines,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
        );
      },
    );
  }
}
