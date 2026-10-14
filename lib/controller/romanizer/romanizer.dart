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
  Romanizer._();

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
    final groupedLinesRomanized = _romanizeLinesGroupedWithLatin(lines, chinese);
    if (groupedLinesRomanized == null) return (index, text) => _engine.romanize(text, chinese: chinese);
    return (index, text) => groupedLinesRomanized[index] ?? _engine.romanize(text, chinese: chinese);
  }

  /// the line itself where a latin line sharing its timestamp already romanizes it.
  List<String?>? _romanizeLinesGroupedWithLatin(List<LrcLine> lines, bool chinese) {
    List<String?>? romanizedLines;
    final normalizedLatinLines = <String>[];
    final romanizableIndices = <int>[];
    final length = lines.length;
    var groupEnd = 0;
    for (var groupStart = 0; groupStart < length; groupStart = groupEnd) {
      final timestamp = lines[groupStart].timestamp;
      groupEnd = groupStart + 1;
      while (groupEnd < length && lines[groupEnd].timestamp == timestamp) {
        groupEnd++;
      }
      if (groupEnd - groupStart == 1) continue;

      normalizedLatinLines.clear();
      romanizableIndices.clear();
      for (var i = groupStart; i < groupEnd; i++) {
        final text = lines[i].readableText;
        if (RomanizerEngine.needsRomanization(text)) {
          romanizableIndices.add(i);
        } else {
          final normalized = _RomanizationMatcher.normalize(text);
          if (normalized.isNotEmpty) normalizedLatinLines.add(normalized);
        }
      }
      if (normalizedLatinLines.isEmpty || romanizableIndices.isEmpty) continue;

      romanizedLines ??= List<String?>.filled(length, null);
      for (final i in romanizableIndices) {
        final text = lines[i].readableText;
        final romanized = _engine.romanize(text, chinese: chinese);
        final isAlreadyRomanized = _RomanizationMatcher.matchesAny(romanized, normalizedLatinLines);
        romanizedLines[i] = isAlreadyRomanized ? text : romanized;
      }
    }
    return romanizedLines;
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

  static var _normalizeBuffer = Uint16List(128);
  static var _previousRow = Int32List(128);
  static var _currentRow = Int32List(128);

  /// lower case a-z only, long vowels collapsed (`ou`, `oo` & `ō` => `o`).
  static String normalize(String text) {
    final length = text.length;
    if (_normalizeBuffer.length < length) _normalizeBuffer = Uint16List(length * 2);
    final buffer = _normalizeBuffer;
    var outputLength = 0;
    var previous = 0;
    for (var i = 0; i < length; i++) {
      final codeUnit = text.codeUnitAt(i);
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
    final normalized = normalize(romanized);
    if (normalized.isEmpty) return false;
    for (final line in normalizedLines) {
      if (_isSimilar(normalized, line)) return true;
    }
    return false;
  }

  static bool _isSimilar(String a, String b) {
    final aLength = a.length;
    final bLength = b.length;
    final maxLength = aLength > bLength ? aLength : bLength;
    final maxDistance = (maxLength * (1 - _minSimilarity)).floor();
    final lengthDifference = (aLength - bLength).abs();
    if (lengthDifference > maxDistance) return false;

    if (_previousRow.length <= bLength) {
      _previousRow = Int32List(bLength * 2 + 1);
      _currentRow = Int32List(bLength * 2 + 1);
    }
    var previousRow = _previousRow;
    var currentRow = _currentRow;
    for (var j = 0; j <= bLength; j++) {
      previousRow[j] = j;
    }
    for (var i = 1; i <= aLength; i++) {
      final ac = a.codeUnitAt(i - 1);
      currentRow[0] = i;
      var rowMin = i;
      for (var j = 1; j <= bLength; j++) {
        final bc = b.codeUnitAt(j - 1);
        final substitutionCost = ac == bc ? 0 : 1;
        final substitution = previousRow[j - 1] + substitutionCost;
        final deletion = previousRow[j] + 1;
        final insertion = currentRow[j - 1] + 1;
        var distance = substitution < deletion ? substitution : deletion;
        if (insertion < distance) distance = insertion;
        currentRow[j] = distance;
        if (distance < rowMin) rowMin = distance;
      }
      if (rowMin > maxDistance) return false;
      final swap = previousRow;
      previousRow = currentRow;
      currentRow = swap;
    }
    return previousRow[bLength] <= maxDistance;
  }
}
