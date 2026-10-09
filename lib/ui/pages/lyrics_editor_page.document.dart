part of 'lyrics_editor_page.dart';

class _LyricsDocument {
  static const _kFlagUntimed = 1 << 0;
  static const _kFlagOutOfOrder = 1 << 1;
  static const _kFlagPastEnd = 1 << 2;

  static const _kWordJoinMaxGapMS = 150;
  static const _kLastWordFallbackMS = 1000;

  static final _spacesRegex = RegExp(r'\s+');

  var lines = <_EditorLine>[];
  var tags = const _LyricsTags();

  /// the `[length:]` the lines are timed against while the item duration is unknown, see [stretchToDuration].
  String? _unstretchedLength;

  var _lineResolver = LrcLineResolver.empty;
  var flags = Uint8List(0);
  int untimedCount = 0;

  bool isUntimed(int index) => flags[index] & _kFlagUntimed != 0;
  bool hasWarning(int index) => flags[index] & (_kFlagOutOfOrder | _kFlagPastEnd) != 0;

  bool hasTimedWords() {
    for (final line in lines) {
      if (line.hasTimedWords()) return true;
    }
    return false;
  }

  // ==================== loading ====================

  void loadSource(String source, {required int durationMS}) {
    final lrc = source.isValidLRC() ? source.parseLRC() : null;
    if (lrc == null) {
      tags = const _LyricsTags();
      _unstretchedLength = null;
      lines = _linesFromPlainText(source);
      return;
    }
    loadLrc(lrc, durationMS: durationMS);
  }

  void loadLrc(Lrc lrc, {required int durationMS}) {
    tags = _LyricsTags.fromLrc(lrc);
    _unstretchedLength = durationMS > 0 ? null : lrc.length;
    final stretchMultiplier = _stretchMultiplierOf(lrc.length, durationMS);
    lines = _linesFromLrc(lrc, stretchMultiplier: stretchMultiplier);
  }

  /// lines loaded while the item duration was unknown get the stretch [loadLrc] gives them with it, returns the multiplier applied.
  double? stretchToDuration(int durationMS) {
    final length = _unstretchedLength;
    if (length == null || durationMS <= 0) return null;
    _unstretchedLength = null;
    final stretchMultiplier = _stretchMultiplierOf(length, durationMS);
    if (stretchMultiplier != null) scaleAll(stretchMultiplier);
    return stretchMultiplier;
  }

  /// null when lyrics of [lengthText] play unstretched at [durationMS].
  static double? _stretchMultiplierOf(String? lengthText, int durationMS) {
    final stretchMultiplier = Lyrics.getStretchMultiplierFor(lengthText, durationMS);
    final isStretched = stretchMultiplier != 0 && stretchMultiplier != 1;
    return isStretched ? stretchMultiplier : null;
  }

  static List<_EditorLine> _linesFromPlainText(String source) {
    final cleanSource = LrcParser.cleanPlainLyrics(source);
    final lines = <_EditorLine>[];
    for (final rawLine in cleanSource.split('\n')) {
      final text = normalizeText(rawLine);
      if (text.isEmpty) continue;
      lines.add(_EditorLine(text: text));
    }
    return lines;
  }

  /// [Lrc.offset] and the [stretchMultiplier] are applied, so the editor works with what is heard.
  static List<_EditorLine> _linesFromLrc(Lrc lrc, {required double? stretchMultiplier}) {
    final offsetMS = lrc.offset ?? 0;
    int toEditorMS(Duration timestamp) {
      var ms = timestamp.inMilliseconds - offsetMS;
      if (stretchMultiplier != null) ms = (ms * stretchMultiplier).round();
      return ms.withMinimum(0);
    }

    final singers = <int>{};
    for (final l in lrc.lyrics) {
      final person = l.person;
      if (person != null && person > 0) singers.add(person);
    }
    final keepSingers = singers.length > 1;

    final lines = <_EditorLine>[];
    for (final l in lrc.lyrics) {
      final isBackground = l.isBGLyrics;
      final personPre = l.person;
      final person = isBackground ? 0 : (keepSingers ? personPre : null);
      final startMS = toEditorMS(l.timestamp);
      final parts = l.parts;
      final hasWords = l.type == LrcTypes.enhanced && parts != null && parts.isNotEmpty;
      final textPre = hasWords ? parts.map((e) => e.lyrics).join() : l.readableText;
      final text = normalizeText(textPre);

      final previous = lines.lastOrNull;
      final isTranslation =
          previous != null && //
          !isBackground &&
          !hasWords &&
          !previous.isBackground &&
          previous.translation.isEmpty &&
          previous.startMS == startMS &&
          previous.person == person;
      if (isTranslation) {
        previous.translation = text;
        continue;
      }

      List<_EditorWord>? words;
      if (hasWords) {
        words = <_EditorWord>[];
        for (final part in parts) {
          if (part.lyrics.isEmpty) continue; // -- gaps are kept through each word end
          words.add(
            _EditorWord(
              text: part.lyrics,
              startMS: toEditorMS(part.startTimestamp),
              endMS: toEditorMS(part.endTimestamp),
            ),
          );
        }
        if (words.isEmpty) words = null;
      }

      lines.add(
        _EditorLine(
          startMS: startMS,
          text: text,
          person: person,
          words: words,
        ),
      );
    }
    return lines;
  }

  static String normalizeText(String text) => text.trim().replaceAll(_spacesRegex, ' ');

  // ==================== derived ====================

  void refreshDerived({required int durationMS}) {
    final count = lines.length;
    final newFlags = Uint8List(count);
    final timed = <({int startMS, int index})>[];
    var previousStartMS = -1;
    var untimed = 0;
    for (int i = 0; i < count; i++) {
      final startMS = lines[i].startMS;
      if (startMS == null) {
        newFlags[i] |= _kFlagUntimed;
        untimed++;
        continue;
      }
      if (startMS < previousStartMS) newFlags[i] |= _kFlagOutOfOrder;
      if (durationMS > 0 && startMS > durationMS) newFlags[i] |= _kFlagPastEnd;
      previousStartMS = startMS;
      timed.add((startMS: startMS, index: i));
    }
    timed.sort(_compareTimed);

    final startsMS = Int32List(timed.length);
    final indices = Int32List(timed.length);
    for (int i = 0; i < timed.length; i++) {
      final e = timed[i];
      startsMS[i] = e.startMS;
      indices[i] = e.index;
    }
    _lineResolver = LrcLineResolver(startsMS, indices);
    flags = newFlags;
    untimedCount = untimed;
  }

  static int _compareTimed(({int startMS, int index}) a, ({int startMS, int index}) b) {
    final res = a.startMS.compareTo(b.startMS);
    if (res != 0) return res;
    return a.index.compareTo(b.index);
  }

  /// the line playing at [positionMS], -1 before the first one.
  int lineIndexAt(int positionMS) => _lineResolver.indexAt(positionMS);

  int? nextStartAfter(int positionMS) {
    final lineResolver = _lineResolver;
    final index = lineResolver.upperBound(positionMS);
    final starts = lineResolver.startsMS;
    if (index >= starts.length) return null;
    return starts[index];
  }

  void forEachTimedInRange(int fromMS, int toMS, void Function(int lineIndex, int startMS) onLine) {
    final lineResolver = _lineResolver;
    final starts = lineResolver.startsMS;
    final indices = lineResolver.lineIndices;
    var i = lineResolver.upperBound(fromMS - 1);
    for (; i < starts.length; i++) {
      final startMS = starts[i];
      if (startMS > toMS) break;
      onLine(indices[i], startMS);
    }
  }

  // ==================== editing ====================

  List<_EditorLine> snapshot() => [for (final l in lines) l.copy()];

  void stampLine(int index, int positionMS) {
    final line = lines[index];
    final oldStartMS = line.startMS;
    if (oldStartMS != null && line.words != null) {
      line.shiftBy(positionMS - oldStartMS);
    } else {
      line.startMS = positionMS;
    }
  }

  void stampWordStart(int lineIndex, int wordIndex, int positionMS) {
    final line = lines[lineIndex];
    final words = line.ensureWords();
    final word = words[wordIndex];
    word.startMS = positionMS;
    word.endMS = null;
    if (wordIndex == 0 || line.startMS == null) line.startMS = positionMS;
    if (wordIndex == 0) return;

    final previous = words[wordIndex - 1];
    if (previous.startMS == null) return;
    final previousEndMS = previous.endMS;
    final shouldJoin = previousEndMS == null || previousEndMS > positionMS || positionMS - previousEndMS < _kWordJoinMaxGapMS;
    if (shouldJoin) previous.endMS = positionMS;
  }

  void stampWordEnd(int lineIndex, int wordIndex, int positionMS) {
    final word = lines[lineIndex].ensureWords()[wordIndex];
    final startMS = word.startMS;
    if (startMS == null) return;
    word.endMS = positionMS.withMinimum(startMS);
  }

  /// moves a timed line right after the last line starting at or before it, returns its new index.
  int placeInTimeOrder(int index) {
    final startMS = lines[index].startMS;
    if (startMS == null) return index;
    final line = lines.removeAt(index);
    var targetIndex = -1;
    var firstTimedIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final otherStartMS = lines[i].startMS;
      if (otherStartMS == null) continue;
      if (firstTimedIndex < 0) firstTimedIndex = i;
      if (otherStartMS <= startMS) targetIndex = i + 1;
    }
    if (targetIndex < 0) targetIndex = firstTimedIndex < 0 ? index : firstTimedIndex;
    lines.insert(targetIndex, line);
    return targetIndex;
  }

  void shiftLines(int fromIndex, int toIndex, int deltaMS) {
    for (int i = fromIndex; i <= toIndex; i++) {
      lines[i].shiftBy(deltaMS);
    }
  }

  void scaleAll(double factor) {
    for (final line in lines) {
      line.scaleBy(factor);
    }
  }

  void clearTimestamps() {
    for (final line in lines) {
      line.clearTimestamps();
    }
  }

  void mergeWordWithNext(int lineIndex, int wordIndex) {
    final words = lines[lineIndex].words;
    if (words == null || wordIndex + 1 >= words.length) return;
    final word = words[wordIndex];
    final next = words.removeAt(wordIndex + 1);
    word.text += next.text;
    word.endMS = next.endMS ?? word.endMS;
  }

  /// [pieces] replace the word, more than one splits it. a timed word gets its time spread by the pieces length.
  void replaceWord(int lineIndex, int wordIndex, List<String> pieces) {
    final line = lines[lineIndex];
    final words = line.words;
    if (words == null || pieces.isEmpty) return;
    final word = words[wordIndex];
    final startMS = word.startMS;
    final endMS = word.endMS;
    final canSpread = startMS != null && endMS != null && endMS > startMS;
    final totalLength = pieces.fold(0, (sum, e) => sum + e.length);
    final newWords = <_EditorWord>[];
    var cursorMS = startMS;
    var consumedLength = 0;
    for (final piece in pieces) {
      consumedLength += piece.length;
      int? pieceEndMS;
      if (canSpread) pieceEndMS = startMS + (endMS - startMS) * consumedLength ~/ totalLength;
      newWords.add(_EditorWord(text: piece, startMS: canSpread ? cursorMS : null, endMS: pieceEndMS));
      cursorMS = pieceEndMS;
    }
    newWords.first.startMS = startMS;
    newWords.last.endMS = endMS;
    words.replaceRange(wordIndex, wordIndex + 1, newWords);
    final joinedText = words.map((e) => e.text).join();
    line.text = normalizeText(joinedText);
  }

  // ==================== plain text ====================

  String toPlainText() => lines.map((e) => e.text).join('\n');

  /// lines that stayed or were edited in place keep their timings, see [_pairByDiff].
  void applyPlainText(String text) {
    final newTexts = text.split('\n').map(normalizeText).toFixedList();
    final oldTexts = lines.map((e) => e.text).toFixedList();
    final pairs = _pairByDiff(oldTexts, newTexts);
    final newLines = <_EditorLine>[];
    for (int j = 0; j < newTexts.length; j++) {
      final newText = newTexts[j];
      final oldIndex = pairs[j];
      if (oldIndex < 0) {
        if (newText.isEmpty) continue;
        newLines.add(_EditorLine(text: newText));
        continue;
      }
      final line = lines[oldIndex];
      if (line.text != newText) line.setText(newText);
      newLines.add(line);
    }
    lines = newLines;
  }

  // ==================== saving ====================

  /// untimed lines are left out, lines are written in time order.
  String toLrcText({required int durationMS}) {
    final timed = <({int startMS, int index})>[];
    for (int i = 0; i < lines.length; i++) {
      final startMS = lines[i].startMS;
      if (startMS != null) timed.add((startMS: startMS, index: i));
    }
    timed.sort(_compareTimed);

    final canWriteBackground = hasTimedWords();
    final lrcLines = <LrcLine>[];
    var hasEnhanced = false;
    for (int k = 0; k < timed.length; k++) {
      final entry = timed[k];
      final line = lines[entry.index];
      final nextLineStartMS = k + 1 < timed.length ? timed[k + 1].startMS : null;
      var parts = line.buildParts(entry.startMS, nextLineStartMS);
      final isBackground = line.isBackground && canWriteBackground;
      if (isBackground) parts ??= [line.buildSinglePart(entry.startMS, nextLineStartMS)];
      final person = isBackground ? 0 : (line.isBackground ? null : line.person);
      final isEnhanced = parts != null;
      if (isEnhanced) hasEnhanced = true;
      final lineStart = Duration(milliseconds: entry.startMS);
      lrcLines.add(
        LrcLine(
          timestamp: lineStart,
          originalIndex: lrcLines.length,
          lyrics: line.text,
          readableText: line.text,
          type: isEnhanced ? LrcTypes.enhanced : LrcTypes.simple,
          parts: parts,
          person: person,
          isRTL: false,
        ),
      );
      if (line.translation.isNotEmpty && !isBackground) {
        lrcLines.add(
          LrcLine(
            timestamp: lineStart,
            originalIndex: lrcLines.length,
            lyrics: line.translation,
            readableText: line.translation,
            type: LrcTypes.simple,
            parts: null,
            person: person,
            isRTL: false,
          ),
        );
      }
    }

    final tags = this.tags;
    var length = _unstretchedLength;
    if (length == null && durationMS > 0) length = Lyrics.formatLengthTag(durationMS);
    final lrc = Lrc(
      type: hasEnhanced ? LrcTypes.enhanced : LrcTypes.simple,
      lyrics: lrcLines,
      artist: tags.artist,
      album: tags.album,
      title: tags.title,
      author: tags.author,
      creator: tags.creator,
      program: tags.program,
      version: tags.version,
      language: tags.language,
      length: length,
    );
    return lrc.format();
  }

  // ==================== drafts ====================

  Map<String, dynamic> toJson() => {
    'tags': tags.toJson(),
    'lines': [for (final l in lines) l.toJson()],
    'length': ?_unstretchedLength,
  };

  void loadJson(Map<String, dynamic> json, {required int durationMS}) {
    final tagsJson = json['tags'];
    final linesJson = json['lines'] as List? ?? const [];
    final newTags = tagsJson is Map ? _LyricsTags.fromJson(tagsJson.cast<String, dynamic>()) : const _LyricsTags();
    tags = newTags;
    lines = [for (final l in linesJson) _EditorLine.fromJson((l as Map).cast<String, dynamic>())];
    _unstretchedLength = json['length'] as String?;
    stretchToDuration(durationMS);
  }
}

class _EditorLine {
  int? startMS;
  String text;
  String translation;

  /// null for none, 0 for background vocals, like [LrcLine.person].
  int? person;

  /// null while the line is only line synced.
  List<_EditorWord>? words;

  _EditorLine({
    this.startMS,
    required this.text,
    this.translation = '',
    this.person,
    this.words,
  });

  bool get isBackground => person == 0;

  _EditorLine copy() {
    final words = this.words;
    final wordsCopy = words == null ? null : [for (final w in words) w.copy()];
    return _EditorLine(
      startMS: startMS,
      text: text,
      translation: translation,
      person: person,
      words: wordsCopy,
    );
  }

  bool hasTimedWords() {
    final words = this.words;
    if (words == null) return false;
    for (final w in words) {
      if (w.startMS != null) return true;
    }
    return false;
  }

  List<_EditorWord> ensureWords() => words ??= [for (final t in _EditorWord.splitText(text)) _EditorWord(text: t)];

  /// word timings are kept for the words that stayed.
  void setText(String newText) {
    text = newText;
    final words = this.words;
    if (words == null) return;
    final newTexts = _EditorWord.splitText(newText);
    final oldTexts = words.map((e) => e.text.trim()).toFixedList();
    final newTextsTrimmed = newTexts.map((e) => e.trim()).toFixedList();
    final pairs = _pairByDiff(oldTexts, newTextsTrimmed);
    final newWords = <_EditorWord>[];
    for (int j = 0; j < newTexts.length; j++) {
      final oldIndex = pairs[j];
      final oldWord = oldIndex < 0 ? null : words[oldIndex];
      newWords.add(_EditorWord(text: newTexts[j], startMS: oldWord?.startMS, endMS: oldWord?.endMS));
    }
    this.words = newWords;
  }

  void shiftBy(int deltaMS) {
    final startMS = this.startMS;
    if (startMS != null) this.startMS = (startMS + deltaMS).withMinimum(0);
    final words = this.words;
    if (words == null) return;
    for (final w in words) {
      w.shiftBy(deltaMS);
    }
  }

  void scaleBy(double factor) {
    final startMS = this.startMS;
    if (startMS != null) this.startMS = (startMS * factor).round();
    final words = this.words;
    if (words == null) return;
    for (final w in words) {
      w.scaleBy(factor);
    }
  }

  void clearTimestamps() {
    startMS = null;
    final words = this.words;
    if (words == null) return;
    for (final w in words) {
      w.startMS = null;
      w.endMS = null;
    }
  }

  /// null when no word is timed. untimed words join the part before them.
  List<LrcLinePart>? buildParts(int lineStartMS, int? nextLineStartMS) {
    final words = this.words;
    if (words == null || !hasTimedWords()) return null;

    final parts = <LrcLinePart>[];
    final pendingText = StringBuffer();
    final partText = StringBuffer();
    int? partStartMS;
    int? partEndMS;

    void addPart(int startMS, int? endMSPre, int? nextStartMS) {
      var endMS = endMSPre ?? nextStartMS ?? nextLineStartMS ?? startMS + _LyricsDocument._kLastWordFallbackMS;
      if (nextStartMS != null && endMS > nextStartMS) endMS = nextStartMS;
      endMS = endMS.withMinimum(startMS);
      parts.add(_part(startMS, endMS, partText.toString()));
      partText.clear();
      if (nextStartMS != null && endMS < nextStartMS) parts.add(_part(endMS, nextStartMS, ''));
    }

    for (final w in words) {
      final wordStartMS = w.startMS;
      if (wordStartMS == null) {
        if (partStartMS == null) {
          pendingText.write(w.text);
        } else {
          partText.write(w.text);
        }
        continue;
      }
      final currentStartMS = partStartMS;
      if (currentStartMS != null) {
        addPart(currentStartMS, partEndMS, wordStartMS);
      } else if (pendingText.isNotEmpty) {
        final pendingStartMS = lineStartMS.withMaximum(wordStartMS);
        parts.add(_part(pendingStartMS, wordStartMS, pendingText.toString()));
      }
      partStartMS = wordStartMS;
      partEndMS = w.endMS;
      partText.write(w.text);
    }
    final lastStartMS = partStartMS;
    if (lastStartMS != null) addPart(lastStartMS, partEndMS, null);
    return parts;
  }

  LrcLinePart buildSinglePart(int startMS, int? nextLineStartMS) {
    final endMS = nextLineStartMS ?? startMS + _LyricsDocument._kLastWordFallbackMS;
    return _part(startMS, endMS, text);
  }

  static LrcLinePart _part(int startMS, int endMS, String text) {
    return LrcLinePart(
      startTimestamp: Duration(milliseconds: startMS),
      endTimestamp: Duration(milliseconds: endMS),
      lyrics: text,
    );
  }

  Map<String, dynamic> toJson() {
    final words = this.words;
    return {
      's': ?startMS,
      't': text,
      if (translation.isNotEmpty) 'tr': translation,
      'p': ?person,
      if (words != null) 'w': [for (final w in words) w.toJson()],
    };
  }

  factory _EditorLine.fromJson(Map<String, dynamic> json) {
    final wordsJson = json['w'] as List?;
    final words = wordsJson == null ? null : [for (final w in wordsJson) _EditorWord.fromJson(w as List)];
    return _EditorLine(
      startMS: json['s'] as int?,
      text: json['t'] as String? ?? '',
      translation: json['tr'] as String? ?? '',
      person: json['p'] as int?,
      words: words,
    );
  }
}

class _EditorWord {
  /// keeps the space after it, joining all words gives the line text.
  String text;
  int? startMS;
  int? endMS;

  _EditorWord({
    required this.text,
    this.startMS,
    this.endMS,
  });

  _EditorWord copy() => _EditorWord(text: text, startMS: startMS, endMS: endMS);

  void shiftBy(int deltaMS) {
    final startMS = this.startMS;
    final endMS = this.endMS;
    if (startMS != null) this.startMS = (startMS + deltaMS).withMinimum(0);
    if (endMS != null) this.endMS = (endMS + deltaMS).withMinimum(0);
  }

  void scaleBy(double factor) {
    final startMS = this.startMS;
    final endMS = this.endMS;
    if (startMS != null) this.startMS = (startMS * factor).round();
    if (endMS != null) this.endMS = (endMS * factor).round();
  }

  List<Object?> toJson() => [text, startMS, endMS];

  factory _EditorWord.fromJson(List json) {
    return _EditorWord(
      text: json[0] as String,
      startMS: json[1] as int?,
      endMS: json[2] as int?,
    );
  }

  /// words split at spaces, scripts written without spaces (chinese, japanese) get a word per character.
  static List<String> splitText(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var hasContent = false;
    var endedWithSpace = false;
    var wasCJK = false;
    for (final char in text.characters) {
      final codeUnit = char.codeUnitAt(0);
      if (_isAttachedToPrevious(codeUnit)) {
        buffer.write(char);
        if (hasContent) endedWithSpace = true;
        continue;
      }
      final isCJK = _isCJK(codeUnit);
      final startsNewWord = hasContent && (endedWithSpace || isCJK || wasCJK);
      if (startsNewWord) {
        tokens.add(buffer.toString());
        buffer.clear();
        endedWithSpace = false;
      }
      buffer.write(char);
      hasContent = true;
      wasCJK = isCJK;
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  /// spaces and cjk punctuation.
  static bool _isAttachedToPrevious(int c) {
    if (c == 0x20 || c == 0x09 || c == 0xA0) return true;
    return c >= 0x3000 && c <= 0x303F;
  }

  static bool _isCJK(int c) {
    return (c >= 0x3040 && c <= 0x30FF) || // kana
        (c >= 0x31F0 && c <= 0x31FF) || // katakana extension
        (c >= 0x3400 && c <= 0x4DBF) || // han extension a
        (c >= 0x4E00 && c <= 0x9FFF) || // han
        (c >= 0xF900 && c <= 0xFAFF); // han compatibility
  }
}

class _LyricsTags {
  final String? artist;
  final String? album;
  final String? title;
  final String? author;
  final String? creator;
  final String? program;
  final String? version;
  final String? language;

  const _LyricsTags({
    this.artist,
    this.album,
    this.title,
    this.author,
    this.creator,
    this.program,
    this.version,
    this.language,
  });

  factory _LyricsTags.fromLrc(Lrc lrc) {
    return _LyricsTags(
      artist: lrc.artist,
      album: lrc.album,
      title: lrc.title,
      author: lrc.author,
      creator: lrc.creator,
      program: lrc.program,
      version: lrc.version,
      language: lrc.language,
    );
  }

  factory _LyricsTags.fromJson(Map<String, dynamic> json) {
    return _LyricsTags(
      artist: json['ar'] as String?,
      album: json['al'] as String?,
      title: json['ti'] as String?,
      author: json['au'] as String?,
      creator: json['by'] as String?,
      program: json['re'] as String?,
      version: json['ve'] as String?,
      language: json['la'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'ar': ?artist,
    'al': ?album,
    'ti': ?title,
    'au': ?author,
    'by': ?creator,
    're': ?program,
    've': ?version,
    'la': ?language,
  };
}

/// for each item of [b], the index of the item of [a] it continues, or -1 when it's new.
/// equal items pair through the longest common subsequence, the rest pair by position inside each changed stretch.
Int32List _pairByDiff(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  final width = m + 1;
  // -- lcs[i * width + j] is the lcs length of a[i:] and b[j:]
  final lcs = Int32List((n + 1) * width);
  for (int i = n - 1; i >= 0; i--) {
    for (int j = m - 1; j >= 0; j--) {
      final index = i * width + j;
      if (a[i] == b[j]) {
        lcs[index] = lcs[index + width + 1] + 1;
      } else {
        final skipA = lcs[index + width];
        final skipB = lcs[index + 1];
        lcs[index] = skipA >= skipB ? skipA : skipB;
      }
    }
  }

  final pairs = Int32List(m)..fillRange(0, m, -1);
  final removed = <int>[];
  final inserted = <int>[];
  void pairChangedStretch() {
    final count = removed.length < inserted.length ? removed.length : inserted.length;
    for (int k = 0; k < count; k++) {
      pairs[inserted[k]] = removed[k];
    }
    removed.clear();
    inserted.clear();
  }

  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      pairChangedStretch();
      pairs[j] = i;
      i++;
      j++;
    } else if (lcs[(i + 1) * width + j] >= lcs[i * width + j + 1]) {
      removed.add(i);
      i++;
    } else {
      inserted.add(j);
      j++;
    }
  }
  for (; i < n; i++) {
    removed.add(i);
  }
  for (; j < m; j++) {
    inserted.add(j);
  }
  pairChangedStretch();
  return pairs;
}

@visibleForTesting
// ignore: library_private_types_in_public_api
_LyricsDocument debugCreateLyricsDocument() => _LyricsDocument();
