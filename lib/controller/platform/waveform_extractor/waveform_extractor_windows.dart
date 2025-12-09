part of 'waveform_extractor.dart';

class _WaveformExtractorWindows extends WaveformExtractor {
  final NamidaFFMPEG ffmpegController;
  _WaveformExtractorWindows._internal(this.ffmpegController);

  @override
  void init() {
    _isolateExecuter.initialize();
  }

  final _isolateExecuter = _WaveformWindowsIsolateManager();

  @override
  Future<List<num>> extractWaveformData(
    String source, {
    bool useCache = true,
    String? cacheKey,
    int? samplesPerSecond,
  }) async {
    final appCacheDir = AppDirs.APP_CACHE;
    File? cacheFile;
    if (useCache) {
      cacheKey ??= "${source.getFilename}_${source.toFastHashKey()}";
      cacheFile = FileParts.join(appCacheDir, '$cacheKey.txt');
      final cachedWaveform = await _parseWaveformFile(cacheFile);
      if (cachedWaveform != null && cachedWaveform.isNotEmpty) return cachedWaveform;
    }
    final wavelist = await _extractWaveformRaw(
      source,
      samplesPerSecond: samplesPerSecond,
      cacheFile: cacheFile,
      appCacheDir: appCacheDir,
    );
    return wavelist;
  }

  Future<List<num>?> _parseWaveformFile(File cacheFile) async {
    if (await cacheFile.exists()) return LineSplitter.split(await cacheFile.readAsString()).map((e) => num.parse(e)).toList();
    return null;
  }

  Future<List<num>> _extractWaveformRaw(
    String source, {
    int? samplesPerSecond,
    File? cacheFile,
    required String appCacheDir,
  }) async {
    final res = await _isolateExecuter.executeIsolate(
      source,
      samplesPerSecond: samplesPerSecond,
      cacheFile: cacheFile,
      appCacheDir: appCacheDir,
    );
    return res as List<num>;
  }
}

class _WaveformWindowsIsolateManager with PortsProvider<SendPort> {
  _WaveformWindowsIsolateManager();

  final _completers = <int, Completer<dynamic>?>{};
  final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

  void dispose() => disposePort();

  Future<dynamic> executeIsolate(
    String source, {
    int? samplesPerSecond,
    File? cacheFile,
    required String appCacheDir,
  }) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    _completers[token]?.complete(null); // useless but anyways
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([token, source, samplesPerSecond, cacheFile, appCacheDir]);
    var res = await completer.future;
    return res;
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, port);
  }

  static void _prepareResourcesAndListen(SendPort sendPort) async {
    final executablesPath = NamidaPlatformBuilder.getExecutablesPath();
    final ffmpegExePath = p.join(executablesPath, 'ffmpeg.exe');
    final waveformExePath = p.join(executablesPath, 'audiowaveform.exe');

    const supportedFormats = <String>{
      'wav', 'flac', 'mp3', 'ogg', 'opus', 'webm', //
    };

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      p as List;
      final token = p[0] as int;
      final source = p[1] as String;
      final samplesPerSecond = p[2] as int?;
      final cacheFile = p[3] as File?;
      final appCacheDir = p[4] as String;

      if (!File(source).existsSync()) {
        sendPort.send([token, []]);
        return;
      }

      final extension = source.getExtension.toLowerCase();
      const multiplier = 0.05;
      final waveformOutputOptions = [
        '--output-format',
        'json',
        '-b',
        '8',
        if (samplesPerSecond != null) ...[
          '--pixels-per-second',
          '${samplesPerSecond * 0.5}',
        ],
      ];
      List<dynamic>? extractDataListFromProcess(ProcessResult result) {
        try {
          return jsonDecode(result.stdout)?['data'] as List?;
        } catch (_) {
          return null;
        }
      }

      List<dynamic>? data;
      String? convertedFilePath;

      final probablyGoodFormat = supportedFormats.contains(extension);
      if (probablyGoodFormat) {
        try {
          final audioWaveformGenerate1 = Process.runSync(
            waveformExePath,
            ['-i', source, '--input-format', extension, ...waveformOutputOptions],
            runInShell: true,
          );
          data = extractDataListFromProcess(audioWaveformGenerate1);
        } catch (_) {}
      }

      if (data == null || data.isEmpty) {
        convertedFilePath = FileParts.joinPath(appCacheDir, '${source.toFastHashKey()}.wav');
        ProcessResult? ffmpegConvert;
        try {
          ffmpegConvert = Process.runSync(
            ffmpegExePath,
            ['-i', source, '-f', 'wav', convertedFilePath],
            runInShell: true,
          );
        } catch (_) {}
        if (ffmpegConvert == null || ffmpegConvert.exitCode != 0) {
          sendPort.send([token, []]);
          return;
        }
      }
      if (data == null || data.isEmpty) {
        final audioWaveformGenerate2 = Process.runSync(
          waveformExePath,
          ['-i', convertedFilePath ?? source, '--input-format', 'wav', ...waveformOutputOptions],
          runInShell: true,
        );
        data = extractDataListFromProcess(audioWaveformGenerate2);
      }
      if (convertedFilePath != null) File(convertedFilePath).delete().catchError((_) => File(''));

      final cacheFileSink = cacheFile?.openWrite(mode: FileMode.writeOnly);

      try {
        final finalList = data?.cast<num>() ?? [];
        final combinedList = <num>[];
        final maxLength = finalList.length % 2 == 0 ? finalList.length : finalList.length - 1; // ensure even number for pair combination

        for (int i = 0; i < maxLength; i += 2) {
          final left = finalList[i].abs();
          final right = finalList[i + 1].abs();
          final combined = left > right ? left : right;
          final finalnumber = combined * multiplier;
          combinedList.add(finalnumber);
          cacheFileSink?.writeln(finalnumber);
        }
        sendPort.send([token, combinedList]);
      } catch (e) {
        sendPort.send([token, <num>[], e]);
      } finally {
        await cacheFileSink?.flush();
        await cacheFileSink?.close();
      }
    });

    sendPort.send(null); // prepared
  }

  @override
  void onResult(result) {
    result as List;
    final token = result[0] as int;
    final completer = _completers[token];
    if (completer != null && completer.isCompleted == false) {
      completer.complete(result[1]);
      _completers.remove(token); // dereferencing
    }
    if (result.length > 2) {
      final error = result[2];
      logger.error('_WaveformWindowsIsolateManager.onResult', e: error);
    }
  }
}
