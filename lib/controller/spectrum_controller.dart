// by claude
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:namida_waveform/namida_spectrum.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class SpectrumController {
  static final inst = SpectrumController._();
  SpectrumController._();

  static const bandCount = 16;
  static const _stride = bandCount + 1;
  static const _framesPerSecond = 30;
  static const _maxDuration = Duration(hours: 2);

  static const _maxGuessAheadMS = 400.0;

  static final _emptyRows = Uint8List(0);

  Uint8List _rows = _emptyRows;
  int _frameCount = 0;

  _SpectrumSource? _source;
  bool _isExtracting = false;

  int _listenersCount = 0;
  int _spectrumListenersCount = 0;

  final _clock = Stopwatch();
  int _reportedPositionMS = 0;
  int _reportedAtUS = 0;

  bool get hasSpectrum => _frameCount > 0;

  void attach({required bool isSpectrumNeeded}) {
    _listenersCount++;
    if (_listenersCount == 1) {
      _clock.start();
      _onPositionChanged();
      Player.inst.nowPlayingPosition.addListener(_onPositionChanged);
    }
    if (isSpectrumNeeded) {
      _spectrumListenersCount++;
      if (_spectrumListenersCount == 1) _extractIfNeeded();
    }
  }

  void detach({required bool isSpectrumNeeded}) {
    if (isSpectrumNeeded) _spectrumListenersCount--;
    _listenersCount--;
    if (_listenersCount == 0) {
      Player.inst.nowPlayingPosition.removeListener(_onPositionChanged);
      _clock.stop();
    }
  }

  void reset() {
    _source = null;
    _rows = _emptyRows;
    _frameCount = 0;
  }

  void onSourceReady({required String path, required Duration duration}) {
    _source = _SpectrumSource(path, duration);
    if (_spectrumListenersCount > 0) _extractIfNeeded();
  }

  void _onPositionChanged() {
    _reportedPositionMS = Player.inst.nowPlayingPosition.value;
    _reportedAtUS = _clock.elapsedMicroseconds;
  }

  double positionMS() {
    final reported = _reportedPositionMS.toDouble();
    if (!Player.inst.isPlaying.value) return reported;
    final sinceReportMS = (_clock.elapsedMicroseconds - _reportedAtUS) / 1000;
    final aheadMS = sinceReportMS * Player.inst.currentSpeed.value;
    return reported + aheadMS.withMaximum(_maxGuessAheadMS);
  }

  double sample(double positionMS, Float32List bands) {
    final lastFrame = _frameCount - 1;
    if (lastFrame < 0) return 0.0;
    final framePosition = (positionMS * _framesPerSecond / 1000).clampDouble(0.0, lastFrame.toDouble());
    final frame = framePosition.floor();
    final nextFrame = frame < lastFrame ? frame + 1 : frame;
    final toNext = framePosition - frame;
    final rows = _rows;
    final offset = frame * _stride;
    final nextOffset = nextFrame * _stride;
    for (int b = 0; b < bandCount; b++) {
      final level = rows[offset + b];
      final nextLevel = rows[nextOffset + b];
      bands[b] = (level + (nextLevel - level) * toNext) / 255;
    }
    final beat = rows[offset + bandCount];
    final nextBeat = rows[nextOffset + bandCount];
    return (beat + (nextBeat - beat) * toNext) / 255;
  }

  Future<void> _extractIfNeeded() async {
    if (_isExtracting || hasSpectrum) return;
    final source = _source;
    if (source == null || source.duration > _maxDuration) return;

    _isExtracting = true;
    final path = source.path;
    final cacheFileName = '${path.getFilename}_${path.toFastHashKey()}$_cacheExtension';
    final cacheFilePath = FileParts.joinPath(AppDirs.WAVEFORMS_CACHE, cacheFileName);
    Uint8List rows = _emptyRows;
    try {
      final cached = await _readCache(cacheFilePath);
      rows = cached ?? await _extractInIsolate(path, cacheFilePath);
    } catch (e, st) {
      logger.error('SpectrumController', e: e, st: st);
    }
    _isExtracting = false;

    if (!identical(source, _source)) {
      if (_spectrumListenersCount > 0) _extractIfNeeded();
      return;
    }
    _rows = rows;
    _frameCount = rows.length ~/ _stride;
  }

  static const _cacheExtension = '.spec';

  // -- bumped along with the rows the native side produces
  static const _formatVersion = 1;
  static const _headerLength = 8;

  static Future<Uint8List> _extractInIsolate(String path, String cacheFilePath) {
    return Isolate.run(() => _extractAndCache(path, cacheFilePath));
  }

  static Uint8List _extractAndCache(String path, String cacheFilePath) {
    final data = NamidaSpectrum.extract(path, framesPerSecond: _framesPerSecond, bandCount: bandCount);
    final rows = data.rows;
    if (rows.isEmpty) throw Exception('${data.error.name} for $path');
    if (data.bandCount != bandCount || data.framesPerSecond != _framesPerSecond) return _emptyRows;
    _writeCache(cacheFilePath, rows);
    return rows;
  }

  static Future<Uint8List?> _readCache(String path) async {
    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.length <= _headerLength) return null;
    final header = _buildHeader();
    for (int i = 0; i < _headerLength; i++) {
      if (bytes[i] != header[i]) return null;
    }
    return Uint8List.sublistView(bytes, _headerLength);
  }

  static void _writeCache(String path, Uint8List rows) {
    final bytes = Uint8List(_headerLength + rows.length);
    bytes.setRange(0, _headerLength, _buildHeader());
    bytes.setRange(_headerLength, bytes.length, rows);
    final file = File(path);
    try {
      file.writeAsBytesSync(bytes, flush: false);
    } on PathNotFoundException {
      try {
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes, flush: false);
      } catch (_) {}
    } catch (_) {}
  }

  static Uint8List _buildHeader() {
    final header = Uint8List(_headerLength);
    header[0] = 0x4E;
    header[1] = 0x53;
    header[2] = 0x50;
    header[3] = _formatVersion;
    header[4] = _framesPerSecond;
    header[5] = bandCount;
    return header;
  }
}

class _SpectrumSource {
  final String path;
  final Duration duration;

  const _SpectrumSource(this.path, this.duration);
}
