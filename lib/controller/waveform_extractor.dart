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

  /// RMS amplitudes extracted at [samplesPerSecond], then resized to each of [targetSizes] and clamped around `64`.
  /// Empty when [source] could not be decoded.
  Future<List<Float32List>> extractDownscaledWaveforms(
    String source, {
    required int samplesPerSecond,
    required List<int> targetSizes,
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
      targetSizes: targetSizes,
      cacheFilePath: cacheFilePath,
    );
  }
}

class _WaveformIsolateManager with PortsProvider<SendPort> {
  final _completers = <int, Completer<List<Float32List>>>{};
  final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

  void dispose() => disposePort();

  Future<List<Float32List>> execute(
    String source, {
    required int samplesPerSecond,
    required List<int> targetSizes,
    required String? cacheFilePath,
  }) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    final completer = _completers[token] = Completer<List<Float32List>>();
    sendPort([token, source, samplesPerSecond, targetSizes, cacheFilePath]);
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
      final targetSizes = p[3] as List<int>;
      final cacheFilePath = p[4] as String?;

      var downscaled = const <TransferableTypedData>[];
      Object? error;

      try {
        Float32List values;
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
        if (values.isNotEmpty) {
          downscaled = targetSizes.map((targetSize) => _downscale(values, targetSize)).toFixedList();
        }
      } catch (e) {
        error = e;
      }

      sendPort.send([
        token,
        downscaled,
        ?error,
      ]);
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  static const _kMaxClamping = 64.0;

  static TransferableTypedData _downscale(Float32List values, int targetSize) {
    final downscaled = values.changeListSize(
      targetSize: targetSize,
      clampToMax: _kMaxClamping,
      enforceClampToMax: _shouldEnforceClamping,
    );
    final downscaledFloats = Float32List.fromList(downscaled);
    return TransferableTypedData.fromList([downscaledFloats]);
  }

  // -- clamping tries to normalize among all target sizes, so only enforced for really loud ones
  static bool _shouldEnforceClamping(num minValue, num maxValue) => maxValue > _kMaxClamping * 2.0;

  @override
  void onResult(result) {
    result as List;
    final token = result[0] as int;
    final completer = _completers.remove(token);
    if (completer != null && !completer.isCompleted) {
      final downscaled = result[1] as List<TransferableTypedData>;
      final waveforms = downscaled.map((e) => e.materialize().asFloat32List()).toFixedList();
      completer.complete(waveforms);
    }
    if (result.length > 2) {
      logger.error('WaveformExtractor', e: result[2]);
    }
  }
}
