import 'dart:convert' show LineSplitter;
import 'dart:ui' show Color;

/// A styled run inside a cue line.
class SubtitleCueSpan {
  final String text;
  final Color? color;
  final bool bold;
  final bool italic;
  final bool underline;

  const SubtitleCueSpan({
    required this.text,
    required this.color,
    required this.bold,
    required this.italic,
    required this.underline,
  });
}

/// One displayed line, [line] is its vertical placement as youtube reports it (`0` top, `null` bottom),
/// and the colors inside [spans] carry the karaoke highlight.
class SubtitleCueLine {
  final List<SubtitleCueSpan> spans;
  final double? line;

  const SubtitleCueLine({
    required this.spans,
    required this.line,
  });

  String get plainText {
    final buffer = StringBuffer();
    for (final span in spans) {
      buffer.write(span.text);
    }
    return buffer.toString();
  }
}

/// Every line displayed over one stretch of the timeline, [start] & [end] in milliseconds.
///
/// Groups never overlap, so a position resolves to exactly one of them.
class SubtitleCueGroup {
  final int start;
  final int end;
  final List<SubtitleCueLine> lines;

  const SubtitleCueGroup({
    required this.start,
    required this.end,
    required this.lines,
  });
}

class SubtitleCues {
  final List<SubtitleCueGroup> groups;

  SubtitleCues(this.groups);

  bool get isEmpty => groups.isEmpty;

  /// youtube also serves plain captions as vtt, those are better left to the player's own renderer.
  late final hasStyling = groups.any((group) => group.lines.any((line) => line.spans.any((span) => span.color != null)));

  /// Parses a WebVTT file, keeping the `::cue` class colors & the inline tags.
  /// Returns null when nothing displayable came out of it.
  static SubtitleCues? parseVTT(String content) {
    if (content.isEmpty) return null;

    final classColors = <String, Color>{};
    final cues = <_ParsedCue>[];
    final seenCues = <String>{};

    int? currentStart;
    int? currentEnd;
    double? currentLine;
    final currentPayload = StringBuffer();

    void flushCue() {
      final start = currentStart;
      final end = currentEnd;
      final payload = currentPayload.toString();
      currentPayload.clear();
      if (start == null || end == null || end <= start) return;

      final spans = _parseSpans(payload, classColors);
      if (spans.isEmpty) return;

      final cueLine = SubtitleCueLine(spans: spans, line: currentLine);
      if (!seenCues.add('$start-$end-$currentLine-${cueLine.plainText}')) return; // -- youtube emits every cue twice
      cues.add(_ParsedCue(start, end, cueLine));
    }

    for (final rawLine in LineSplitter.split(content)) {
      final line = rawLine.trimRight();

      final arrowIndex = line.indexOf('-->');
      if (arrowIndex > 0) {
        final start = _parseTimestamp(line.substring(0, arrowIndex));
        if (start == null) continue;

        final rest = line.substring(arrowIndex + 3).trimLeft();
        final spaceIndex = rest.indexOf(' ');
        final end = _parseTimestamp(spaceIndex < 0 ? rest : rest.substring(0, spaceIndex));
        if (end == null) continue;

        flushCue();

        currentStart = start;
        currentEnd = end;
        currentLine = spaceIndex < 0 ? null : _parseLineSetting(rest.substring(spaceIndex + 1));
        continue;
      }

      if (currentStart != null) {
        if (line.isEmpty) continue; // -- the blank line only separates cues, the cue closes on the next timing
        if (currentPayload.isNotEmpty) currentPayload.write('\n');
        currentPayload.write(line);
        continue;
      }

      _parseCueStyle(line, classColors);
    }

    flushCue();

    final groups = _sweepIntoGroups(cues);
    return groups.isEmpty ? null : SubtitleCues(groups);
  }

  /// Cues overlap freely, ex. a translation staying put while the karaoke line above it advances.
  /// Sweeping them into contiguous segments lets the widget hold a single group per position.
  static List<SubtitleCueGroup> _sweepIntoGroups(List<_ParsedCue> cues) {
    if (cues.isEmpty) return const [];

    cues.sort((a, b) => a.start.compareTo(b.start));

    final boundaries = <int>{};
    for (final cue in cues) {
      boundaries.add(cue.start);
      boundaries.add(cue.end);
    }
    final times = boundaries.toList()..sort();

    final groups = <SubtitleCueGroup>[];
    final active = <_ParsedCue>[];
    int nextCue = 0;

    for (int i = 0; i + 1 < times.length; i++) {
      final segmentStart = times[i];

      while (nextCue < cues.length && cues[nextCue].start <= segmentStart) {
        active.add(cues[nextCue]);
        nextCue++;
      }
      active.removeWhere((cue) => cue.end <= segmentStart);
      if (active.isEmpty) continue;

      final segmentEnd = times[i + 1];
      active.sort((a, b) => (a.cueLine.line ?? 100).compareTo(b.cueLine.line ?? 100));
      final lines = active.map((e) => e.cueLine).toList(growable: false);

      // -- a karaoke step only replaces one of the lines, the rest of the segment carries over
      final previous = groups.isEmpty ? null : groups.last;
      if (previous != null && previous.end == segmentStart && _sameLines(previous.lines, lines)) {
        groups[groups.length - 1] = SubtitleCueGroup(start: previous.start, end: segmentEnd, lines: previous.lines);
      } else {
        groups.add(SubtitleCueGroup(start: segmentStart, end: segmentEnd, lines: lines));
      }
    }

    return groups;
  }

  static bool _sameLines(List<SubtitleCueLine> a, List<SubtitleCueLine> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// ex. `::cue(c.colorE23CE7) { color: rgb(226,60,231); }`
  static void _parseCueStyle(String line, Map<String, Color> addTo) {
    const marker = '::cue(.';
    const markerWithTag = '::cue(c.';
    int nameStart = line.indexOf(markerWithTag);
    if (nameStart >= 0) {
      nameStart += markerWithTag.length;
    } else {
      nameStart = line.indexOf(marker);
      if (nameStart < 0) return;
      nameStart += marker.length;
    }
    final nameEnd = line.indexOf(')', nameStart);
    if (nameEnd < 0) return;

    final color = _parseColor(line.substring(nameEnd));
    if (color != null) addTo[line.substring(nameStart, nameEnd)] = color;
  }

  static Color? _parseColor(String text) {
    final rgbIndex = text.indexOf('rgb');
    if (rgbIndex >= 0) {
      final open = text.indexOf('(', rgbIndex);
      final close = text.indexOf(')', open + 1);
      if (open < 0 || close < 0) return null;
      final parts = text.substring(open + 1, close).split(',');
      if (parts.length < 3) return null;
      final r = int.tryParse(parts[0].trim());
      final g = int.tryParse(parts[1].trim());
      final b = int.tryParse(parts[2].trim());
      if (r == null || g == null || b == null) return null;
      return Color.fromARGB(255, r, g, b);
    }

    final hashIndex = text.indexOf('#');
    if (hashIndex >= 0 && text.length >= hashIndex + 7) {
      final value = int.tryParse(text.substring(hashIndex + 1, hashIndex + 7), radix: 16);
      if (value != null) return Color(0xFF000000 | value);
    }
    return null;
  }

  /// `HH:MM:SS.mmm` or `MM:SS.mmm`, as milliseconds
  static int? _parseTimestamp(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex < 0) return null;

    final milliseconds = int.tryParse(trimmed.substring(dotIndex + 1));
    if (milliseconds == null) return null;

    final parts = trimmed.substring(0, dotIndex).split(':');
    int hours = 0, minutes = 0, seconds = 0;
    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      seconds = int.tryParse(parts[2]) ?? 0;
    } else if (parts.length == 2) {
      minutes = int.tryParse(parts[0]) ?? 0;
      seconds = int.tryParse(parts[1]) ?? 0;
    } else {
      return null;
    }

    return ((hours * 60 + minutes) * 60 + seconds) * 1000 + milliseconds;
  }

  /// ex. `position:67% line:0%`
  static double? _parseLineSetting(String settings) {
    const key = 'line:';
    final keyIndex = settings.indexOf(key);
    if (keyIndex < 0) return null;

    int valueEnd = keyIndex + key.length;
    while (valueEnd < settings.length && settings.codeUnitAt(valueEnd) != 0x20 /* space */ ) {
      valueEnd++;
    }
    var value = settings.substring(keyIndex + key.length, valueEnd);
    if (value.endsWith('%')) value = value.substring(0, value.length - 1);
    return double.tryParse(value);
  }

  static bool _isDisplayable(String text) {
    for (int i = 0; i < text.length; i++) {
      if (!_isPadding(text.codeUnitAt(i))) return true;
    }
    return false;
  }

  static List<SubtitleCueSpan> _parseSpans(String payload, Map<String, Color> classColors) {
    if (payload.isEmpty) return const [];

    final spans = <SubtitleCueSpan>[];
    final openTags = <String>[];
    final buffer = StringBuffer();

    Color? activeColor;
    int boldDepth = 0;
    int italicDepth = 0;
    int underlineDepth = 0;

    void flush() {
      if (buffer.isEmpty) return;
      final text = buffer.toString();
      buffer.clear();
      if (spans.isEmpty && !_isDisplayable(text)) return; // -- youtube pads every cue with zero width spaces
      spans.add(
        SubtitleCueSpan(
          text: text,
          color: activeColor,
          bold: boldDepth > 0,
          italic: italicDepth > 0,
          underline: underlineDepth > 0,
        ),
      );
    }

    int index = 0;
    while (index < payload.length) {
      final char = payload.codeUnitAt(index);
      if (char != 0x3C /* < */ ) {
        buffer.writeCharCode(char);
        index++;
        continue;
      }

      final close = payload.indexOf('>', index + 1);
      if (close < 0) {
        buffer.writeCharCode(char);
        index++;
        continue;
      }

      final tag = payload.substring(index + 1, close);
      index = close + 1;

      if (tag.startsWith('/')) {
        final name = tag.substring(1);
        final openIndex = openTags.lastIndexOf(name);
        if (openIndex < 0) continue;
        flush();
        openTags.removeAt(openIndex);
        switch (name) {
          case 'b':
            if (boldDepth > 0) boldDepth--;
          case 'i':
            if (italicDepth > 0) italicDepth--;
          case 'u':
            if (underlineDepth > 0) underlineDepth--;
          case 'c':
            activeColor = null;
        }
        continue;
      }

      final nameEnd = _tagNameEnd(tag);
      final name = tag.substring(0, nameEnd);
      switch (name) {
        case 'b':
          flush();
          boldDepth++;
          openTags.add(name);
        case 'i':
          flush();
          italicDepth++;
          openTags.add(name);
        case 'u':
          flush();
          underlineDepth++;
          openTags.add(name);
        case 'c':
          flush();
          openTags.add(name);
          for (final className in tag.substring(nameEnd).split('.')) {
            final color = classColors[className];
            if (color != null) {
              activeColor = color;
              break;
            }
          }
        default:
          break; // -- `<v speaker>` & inline timestamps carry no styling we render
      }
    }

    flush();

    while (spans.isNotEmpty && !_isDisplayable(spans.last.text)) {
      spans.removeLast();
    }
    if (spans.isNotEmpty) {
      // -- youtube pads both edges, which would offset the centered line
      spans[0] = _copyWithText(spans[0], _trimPadding(spans[0].text, leading: true, trailing: spans.length == 1));
      final last = spans.length - 1;
      if (last > 0) spans[last] = _copyWithText(spans[last], _trimPadding(spans[last].text, leading: false, trailing: true));
    }
    return spans;
  }

  static SubtitleCueSpan _copyWithText(SubtitleCueSpan span, String text) {
    return SubtitleCueSpan(
      text: text,
      color: span.color,
      bold: span.bold,
      italic: span.italic,
      underline: span.underline,
    );
  }

  static bool _isPadding(int code) => code == 0x200B /* zero width space */ || code == 0x20 || code == 0xA0 /* nbsp */;

  static String _trimPadding(String text, {required bool leading, required bool trailing}) {
    int start = 0;
    int end = text.length;
    if (leading) {
      while (start < end && _isPadding(text.codeUnitAt(start))) {
        start++;
      }
    }
    if (trailing) {
      while (end > start && _isPadding(text.codeUnitAt(end - 1))) {
        end--;
      }
    }
    return start == 0 && end == text.length ? text : text.substring(start, end);
  }

  static int _tagNameEnd(String tag) {
    for (int i = 0; i < tag.length; i++) {
      final code = tag.codeUnitAt(i);
      if (code == 0x2E /* . */ || code == 0x20 /* space */ ) return i;
    }
    return tag.length;
  }
}

class _ParsedCue {
  final int start;
  final int end;
  final SubtitleCueLine cueLine;

  const _ParsedCue(this.start, this.end, this.cueLine);
}
