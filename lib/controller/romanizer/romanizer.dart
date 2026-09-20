import 'dart:io';

import 'package:lrc/lrc.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer_engine.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
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

  String Function(String text)? lyricsRomanizer(Lrc lrc) {
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
    return (text) => _engine.romanize(text, chinese: chinese);
  }

  void setLyricsEnabled(bool enabled) {
    settings.save(romanizeLyrics: enabled);
    if (enabled && !isDictionaryInstalled.value) {
      downloadDictionary();
    } else {
      _refreshLyrics(force: true);
    }
  }

  void setSortingEnabled(bool enabled) {
    settings.save(romanizeSorting: enabled);
    if (enabled && !isDictionaryInstalled.value) downloadDictionary();
  }

  Future<bool> downloadDictionary({bool enableLyrics = false}) async {
    if (enableLyrics) settings.save(romanizeLyrics: true);
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
    try {
      await Directory(AppDirs.ROMANIZATION).delete(recursive: true);
    } catch (_) {}
  }
}
