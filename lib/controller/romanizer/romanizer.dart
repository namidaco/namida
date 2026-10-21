import 'dart:io';
import 'dart:typed_data';

import 'package:lrc/lrc.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer_engine.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/sort_key.dart';
import 'package:namida/core/utils.dart';

// by claude
class Romanizer {
  static final inst = Romanizer._();
  Romanizer._() {
    _engine.setDisabledScripts(settings.romanizationDisabledScripts.value);
    settings.romanizationDisabledScripts.addListener(_onDisabledScriptsChanged);
  }

  // hosted bundle (`ipadic/` + `pinyin.bin`, see scripts/gen_pinyin_table.dart).
  static const _bundleUrl = 'https://files.namida.app/romanization_v1.zip';

  final _engine = RomanizerEngine();
  final _sortingCache = <String, String>{};

  /// null when idle.
  final downloadProgress = Rxn<double>();
  late final isDictionaryInstalled = _dictionaryMarker.existsSync().obs;

  CancelToken? _downloadCancelToken;
  bool _loadAttempted = false;

  File get _dictionaryMarker => File('${AppDirs.ROMANIZATION}installed');

  void _ensureLoaded() {
    if (_loadAttempted) return;
    _loadAttempted = true;
    if (isDictionaryInstalled.value) _engine.load(AppDirs.ROMANIZATION);
  }

  String romanizeForSorting(String text) {
    if (!RomanizerEngine.needsRomanization(text)) return text;
    return _sortingCache[text] ??= _romanizeForSorting(text);
  }

  String _romanizeForSorting(String text) {
    _ensureLoaded();
    return _engine.romanize(text, plain: true);
  }

  String Function(int index, String text)? lyricsRomanizer(Lrc lrc) {
    if (!settings.romanizeLyrics.value) return null;
    _ensureLoaded();
    final lines = lrc.lyrics;
    var chinese = true;
    for (var i = 0; i < lines.length; i++) {
      if (RomanizerEngine.containsKana(lines[i].lyrics)) {
        chinese = false;
        break;
      }
    }
    final shipped = _findShippedRomanization(lines, chinese);
    if (shipped.isMostlyRomanized) return null;
    final romanizedLines = shipped.romanizedLines;
    if (romanizedLines == null) return (index, text) => _engine.romanize(text, chinese: chinese);
    return (index, text) => romanizedLines[index] ?? _engine.romanize(text, chinese: chinese);
  }

  /// [_ShippedRomanization.romanizedLines] holds the line itself where a latin line sharing its timestamp, or its own latin part, already romanizes it.
  _ShippedRomanization _findShippedRomanization(List<LrcLine> lines, bool chinese) {
    List<String?>? romanizedLines;
    final normalizedLatinLines = <String>[];
    final normalizedLatinParts = <String>[];
    final romanizableIndices = <int>[];
    var romanizableCount = 0;
    var matchedCount = 0;
    final length = lines.length;
    var groupEnd = 0;
    for (var groupStart = 0; groupStart < length; groupStart = groupEnd) {
      final timestamp = lines[groupStart].timestamp;
      groupEnd = groupStart + 1;
      while (groupEnd < length && lines[groupEnd].timestamp == timestamp) {
        groupEnd++;
      }
      final isGroup = groupEnd - groupStart > 1;

      normalizedLatinLines.clear();
      normalizedLatinParts.clear();
      romanizableIndices.clear();
      for (var i = groupStart; i < groupEnd; i++) {
        final text = lines[i].readableText;
        if (RomanizerEngine.needsRomanization(text)) {
          romanizableIndices.add(i);
          final latinPart = _RomanizationMatcher.normalize(text, scriptsAsWildcards: false);
          if (latinPart.isNotEmpty) normalizedLatinParts.add(latinPart);
        } else if (isGroup) {
          final normalized = _RomanizationMatcher.normalize(text, scriptsAsWildcards: false);
          if (normalized.isNotEmpty) normalizedLatinLines.add(normalized);
        }
      }
      romanizableCount += romanizableIndices.length;
      if (romanizableIndices.isEmpty || (normalizedLatinLines.isEmpty && normalizedLatinParts.isEmpty)) continue;

      romanizedLines ??= List<String?>.filled(length, null);
      for (final i in romanizableIndices) {
        final text = lines[i].readableText;
        final romanized = _engine.romanize(text, chinese: chinese);
        var isAlreadyRomanized = _RomanizationMatcher.matchesAny(romanized, normalizedLatinLines);
        if (!isAlreadyRomanized) isAlreadyRomanized = _isRomanizedByLatinPart(text, romanized, chinese, normalizedLatinLines, normalizedLatinParts);
        if (isAlreadyRomanized) matchedCount++;
        romanizedLines[i] = isAlreadyRomanized ? text : romanized;
      }
    }

    // -- the rest ship it too, the generated one just misread them (unknown kanji, other readings)
    final isMostlyRomanized = matchedCount * 2 > romanizableCount;
    return (romanizedLines: romanizedLines, isMostlyRomanized: isMostlyRomanized);
  }

  static final _latinLettersRegex = RegExp(r'[A-Za-z]+');

  /// only the non-latin text is compared, a latin part can't romanize itself (`oh yeah 僕は`).
  /// latin words of the line (`緋色に染まって (of destiny)`) are often left out of its romanized sibling.
  bool _isRomanizedByLatinPart(String text, String romanized, bool chinese, List<String> normalizedLatinLines, List<String> normalizedLatinParts) {
    final textWithoutLatin = text.replaceAll(_latinLettersRegex, '');
    final hasOwnLatin = textWithoutLatin.length != text.length;
    if (!hasOwnLatin) return _RomanizationMatcher.matchesAny(romanized, normalizedLatinParts);
    final romanizedWithoutLatin = _engine.romanize(textWithoutLatin, chinese: chinese);
    return _RomanizationMatcher.matchesAny(romanizedWithoutLatin, normalizedLatinLines) || _RomanizationMatcher.matchesAny(romanizedWithoutLatin, normalizedLatinParts);
  }

  void setLyricsEnabled(bool enabled) {
    settings.romanizeLyrics.save(enabled);
    if (enabled && !isDictionaryInstalled.value) {
      downloadDictionary();
    } else {
      _refreshLyrics(force: true);
    }
  }

  bool get hasRomanizableSortText => SortKey.seenScripts != 0;

  bool get sortingNeedsDictionary => RomanizerEngine.scriptsNeedDictionary(SortKey.seenScripts);

  void setSortingEnabled(bool enabled) {
    settings.romanizeSorting.save(enabled);
    if (enabled && !isDictionaryInstalled.value && sortingNeedsDictionary) downloadDictionary();
    Indexer.inst.resortAllAfterSortKeysChange();
  }

  void _onDisabledScriptsChanged() {
    final changedScripts = _engine.setDisabledScripts(settings.romanizationDisabledScripts.value);
    if (changedScripts == 0) return;
    _sortingCache.removeWhere((text, _) => RomanizerEngine.hasAnyScript(text, changedScripts));
    _refreshLyrics();
    final isLibraryAffected = SortKey.seenScripts & changedScripts != 0;
    if (isLibraryAffected) _resortIfSortingEnabled();
  }

  void _resortIfSortingEnabled() {
    if (settings.romanizeSorting.value) Indexer.inst.resortAllAfterSortKeysChange();
  }

  Future<bool> downloadDictionary({bool enableLyrics = false}) async {
    if (enableLyrics) settings.romanizeLyrics.save(true);
    if (downloadProgress.value != null) return false;
    downloadProgress.value = 0.0;

    final dir = Directory(AppDirs.ROMANIZATION);
    final zipFile = File('${AppDirs.ROMANIZATION}bundle.zip.temp');
    final cancelToken = _downloadCancelToken = CancelToken();
    final client = HttpClientWrapper.createSync();
    IOSink? sink;
    try {
      await dir.create(recursive: true);
      final response = await client.getStream(_bundleUrl, cancelToken: cancelToken);
      final total = int.tryParse(response.headerMap['content-length'] ?? '') ?? 0;
      sink = zipFile.openWrite(mode: FileMode.writeOnly);
      var received = 0;
      var lastPercentage = 0;
      await for (final data in response.body) {
        sink.add(data);
        received += data.length;
        if (total > 0) {
          final percentage = received * 100 ~/ total;
          if (percentage != lastPercentage) {
            lastPercentage = percentage;
            downloadProgress.value = percentage / 100;
          }
        }
      }
      await sink.close();
      sink = null;

      await ZipManager.platform().extractZip(zipFile: zipFile, destinationDir: dir);
      await _dictionaryMarker.create();

      _loadAttempted = false;
      _sortingCache.clear();
      isDictionaryInstalled.value = true;
      _refreshLyrics();
      _resortIfSortingEnabled();
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close();
      _downloadCancelToken = null;
      downloadProgress.value = null;
      try {
        await zipFile.delete();
      } catch (_) {}
    }
  }

  void _refreshLyrics({bool force = false}) {
    if (!force && !settings.romanizeLyrics.value) return;
    final currentItem = Player.inst.currentItem.value;
    if (currentItem != null) Lyrics.inst.updateLyrics(currentItem);
  }

  void cancelDownload() => _downloadCancelToken?.cancel();

  Future<void> deleteDictionary() async {
    _engine.unload();
    _sortingCache.clear();
    _loadAttempted = false;
    isDictionaryInstalled.value = false;
    _refreshLyrics();
    _resortIfSortingEnabled();
    try {
      await Directory(AppDirs.ROMANIZATION).delete(recursive: true);
    } catch (_) {}
  }
}

// by claude
class _RomanizationMatcher {
  static const _minSimilarity = 0.6;
  static const _minContainedSimilarity = 0.7;
  static const _minContainedLetters = 8;
  static const _wildcard = 0x100;
  static const _wildcardLettersPerChar = 6;

  static var _normalizeBuffer = Uint16List(128);
  static var _previousRow = Int32List(128);
  static var _currentRow = Int32List(128);

  /// lower case a-z only, long vowels collapsed (`ou`, `oo` & `ō` => `o`).
  /// each run of characters left unromanized becomes one wildcard, [_wildcard] + the letters it can stand for.
  static String normalize(String text, {required bool scriptsAsWildcards}) {
    final length = text.length;
    if (_normalizeBuffer.length < length) _normalizeBuffer = Uint16List(length * 2);
    final buffer = _normalizeBuffer;
    var outputLength = 0;
    var previous = 0;
    for (var i = 0; i < length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (RomanizerEngine.scriptOf(codeUnit) != 0) {
        if (!scriptsAsWildcards) continue;
        if (previous >= _wildcard) {
          previous += _wildcardLettersPerChar;
          buffer[outputLength - 1] = previous;
        } else {
          previous = _wildcard + _wildcardLettersPerChar;
          buffer[outputLength++] = previous;
        }
        continue;
      }
      var c = SortKey.baseLetterOf(codeUnit);
      if (c >= 0x41 && c <= 0x5A) c += 0x20;
      if (c < 0x61 || c > 0x7A) continue;
      final isLongVowel = _isVowel(c) && (c == previous || (c == 0x75 && previous == 0x6F));
      if (isLongVowel) continue;
      buffer[outputLength++] = c;
      previous = c;
    }
    return String.fromCharCodes(buffer, 0, outputLength);
  }

  static bool _isVowel(int c) => c == 0x61 || c == 0x65 || c == 0x69 || c == 0x6F || c == 0x75;

  static bool matchesAny(String romanized, List<String> normalizedLines) {
    final pattern = normalize(romanized, scriptsAsWildcards: true);
    var letters = 0;
    var wildcardLetters = 0;
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern.codeUnitAt(i);
      if (c >= _wildcard) {
        wildcardLetters += c - _wildcard;
      } else {
        letters++;
      }
    }
    if (letters == 0) return false;
    final canBeContained = letters >= _minContainedLetters;
    for (final line in normalizedLines) {
      if (_isSimilar(pattern, letters, wildcardLetters, line)) return true;
      if (canBeContained && _isContainedIn(pattern, letters, line)) return true;
    }
    return false;
  }

  static bool _isSimilar(String pattern, int letters, int wildcardLetters, String line) {
    final lineLength = line.length;
    final lineLengthOutsideWildcards = lineLength - wildcardLetters;
    final maxLength = letters > lineLengthOutsideWildcards ? letters : lineLengthOutsideWildcards;
    final maxDistance = (maxLength * (1 - _minSimilarity)).floor();
    final extraPatternLetters = letters - lineLength;
    final extraLineLetters = lineLengthOutsideWildcards - letters;
    if (extraPatternLetters > maxDistance || extraLineLetters > maxDistance) return false;
    return _distance(pattern, line, maxDistance, isContained: false) <= maxDistance;
  }

  /// the line can hold more than the romanization, `Akaku tokekonda jouzai (Tu-ru-ru)` or one line romanizing 2 lines.
  static bool _isContainedIn(String pattern, int letters, String line) {
    final maxDistance = (letters * (1 - _minContainedSimilarity)).floor();
    final extraPatternLetters = letters - line.length;
    if (extraPatternLetters > maxDistance) return false;
    return _distance(pattern, line, maxDistance, isContained: true) <= maxDistance;
  }

  /// levenshtein where a wildcard matches up to its letters for free, [isContained] lets [pattern] start and end anywhere in [line].
  /// returns early with a distance above [maxDistance].
  static int _distance(String pattern, String line, int maxDistance, {required bool isContained}) {
    final patternLength = pattern.length;
    final lineLength = line.length;
    if (_previousRow.length <= lineLength) {
      _previousRow = Int32List(lineLength * 2 + 1);
      _currentRow = Int32List(lineLength * 2 + 1);
    }
    var previousRow = _previousRow;
    var currentRow = _currentRow;
    for (var j = 0; j <= lineLength; j++) {
      previousRow[j] = isContained ? 0 : j;
    }
    for (var i = 0; i < patternLength; i++) {
      final pc = pattern.codeUnitAt(i);
      final isWildcard = pc >= _wildcard;
      final wildcardLetters = pc - _wildcard;
      currentRow[0] = isWildcard ? previousRow[0] : previousRow[0] + 1;
      var rowMin = currentRow[0];
      for (var j = 1; j <= lineLength; j++) {
        var distance = currentRow[j - 1] + 1;
        if (isWildcard) {
          final windowStart = j > wildcardLetters ? j - wildcardLetters : 0;
          for (var k = windowStart; k <= j; k++) {
            if (previousRow[k] < distance) distance = previousRow[k];
          }
        } else {
          final substitutionCost = pc == line.codeUnitAt(j - 1) ? 0 : 1;
          final substitution = previousRow[j - 1] + substitutionCost;
          final deletion = previousRow[j] + 1;
          if (substitution < distance) distance = substitution;
          if (deletion < distance) distance = deletion;
        }
        currentRow[j] = distance;
        if (distance < rowMin) rowMin = distance;
      }
      if (rowMin > maxDistance) return rowMin;
      final swap = previousRow;
      previousRow = currentRow;
      currentRow = swap;
    }
    if (!isContained) return previousRow[lineLength];
    var minDistance = previousRow[0];
    for (var j = 1; j <= lineLength; j++) {
      if (previousRow[j] < minDistance) minDistance = previousRow[j];
    }
    return minDistance;
  }
}

typedef _ShippedRomanization = ({List<String?>? romanizedLines, bool isMostlyRomanized});
