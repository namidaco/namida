import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida_waveform/namida_waveform.dart';

/// Extracted amplitudes, cached as a flat `Float32` blob so reading one back is
/// a single allocation with no parsing.
///
/// by claude (sourced from previous implementation)
class WaveformExtractor {
  WaveformExtractor();

  static const _cacheExtension = '.wavef';

  final _isolate = _WaveformIsolateManager();

  void init() => _isolate.initialize();

  void dispose() => _isolate.dispose();

  /// RMS amplitudes in the `0..100` range, [samplesPerSecond] entries per second
  /// of audio. Empty when [source] could not be decoded.
  Future<Float32List> extractWaveformData(
    String source, {
    required int samplesPerSecond,
    bool useCache = true,
    String? cacheKey,
  }) {
    String? cacheFilePath;
    if (useCache) {
      cacheKey ??= '${source.getFilename}_${source.toFastHashKey()}';
      cacheFilePath = FileParts.joinPath(AppDirs.WAVEFORMS_CACHE, '$cacheKey$_cacheExtension');
    }
    return _isolate.execute(
      source,
      samplesPerSecond: samplesPerSecond,
      cacheFilePath: cacheFilePath,
    );
  }
}

class _WaveformIsolateManager with PortsProvider<SendPort> {
  final _completers = <int, Completer<Float32List>>{};
  final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

  void dispose() => disposePort();

  Future<Float32List> execute(
    String source, {
    required int samplesPerSecond,
    required String? cacheFilePath,
  }) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    final completer = _completers[token] = Completer<Float32List>();
    sendPort([token, source, samplesPerSecond, cacheFilePath]);
    return completer.future;
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, port);
  }

  static Float32List? _readCache(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.isEmpty) return null;
      return bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
    } catch (_) {
      return null;
    }
  }

  static void _writeCache(String path, Float32List values) {
    final file = File(path);
    final bytes = values.buffer.asUint8List(values.offsetInBytes, values.lengthInBytes);
    try {
      file.writeAsBytesSync(bytes, flush: false);
    } on PathNotFoundException {
      try {
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes, flush: false);
      } catch (_) {}
    } catch (_) {}
  }

  static void _prepareResourcesAndListen(SendPort sendPort) async {
    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      p as List;
      final token = p[0] as int;
      final source = p[1] as String;
      final samplesPerSecond = p[2] as int;
      final cacheFilePath = p[3] as String?;

      Float32List values;
      Object? error;

      try {
        final cached = cacheFilePath == null ? null : _readCache(cacheFilePath);
        if (cached != null && cached.isNotEmpty) {
          values = cached;
        } else {
          final data = NamidaWaveform.extract(source, samplesPerSecond: samplesPerSecond);
          values = data.values;
          if (values.isNotEmpty) {
            if (cacheFilePath != null) _writeCache(cacheFilePath, values);
          } else {
            error = '${data.error.name} for $source';
          }
        }
      } catch (e) {
        values = Float32List(0);
        error = e;
      }

      sendPort.send([
        token,
        TransferableTypedData.fromList([values.buffer.asUint8List(values.offsetInBytes, values.lengthInBytes)]),
        ?error,
      ]);
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  @override
  void onResult(result) {
    result as List;
    final token = result[0] as int;
    final completer = _completers.remove(token);
    if (completer != null && !completer.isCompleted) {
      completer.complete((result[1] as TransferableTypedData).materialize().asFloat32List());
    }
    if (result.length > 2) {
      logger.error('WaveformExtractor', e: result[2]);
    }
  }
}
