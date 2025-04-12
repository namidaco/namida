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
    File? cacheFile;
    if (useCache) {
      final cacheDir = AppDirs.APP_CACHE;
      cacheKey ??= source.hashCode.toString();
      cacheFile = FileParts.join(cacheDir, '$cacheKey.txt');
      final cachedWaveform = _parseWaveformFile(cacheFile);
      if (cachedWaveform != null && cachedWaveform.isNotEmpty) return cachedWaveform;
    }
    final wavelist = await _extractWaveformRaw(
      source,
      samplesPerSecond: samplesPerSecond,
    );
    if (cacheFile != null) _encodeWaveformFile(cacheFile, wavelist);
    return wavelist;
  }

  List<num>? _parseWaveformFile(File cacheFile) {
    if (cacheFile.existsSync()) return LineSplitter.split(cacheFile.readAsStringSync()).map((e) => num.parse(e)).toList();
    return null;
  }

  void _encodeWaveformFile(File cacheFile, List<num> list) {
    if (list.isNotEmpty) cacheFile.writeAsStringSync(list.join('\n'));
  }

  Future<List<num>> _extractWaveformRaw(
    String source, {
    int? samplesPerSecond,
  }) async {
    final res = await _isolateExecuter.executeIsolate(
      source,
      samplesPerSecond: samplesPerSecond,
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
  }) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    _completers[token]?.complete(null); // useless but anyways
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([token, source, samplesPerSecond]);
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
      'WAV', 'FLAC', 'MP3', 'OGG', 'OPUS', 'WEBM',
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

      final extension = source.getExtension;
      const multiplier = 0.05;
      final waveformOutputOptions = [
        '--output-format',
        'json',
        '-b',
        '8',
        if (samplesPerSecond != null) ...[
          '--pixels-per-second',
          '$samplesPerSecond',
        ],
      ];
      ProcessResult audioWaveformGenerate;
      bool needsConversion = true;
      String? convertedFilePath;
      final probablyGoodFormat = supportedFormats.contains(extension);
      if (probablyGoodFormat) {
        try {
          audioWaveformGenerate = Process.runSync(waveformExePath, ['-i', source, '--input-format', extension, ...waveformOutputOptions]);
          needsConversion = false;
        } catch (_) {}
      }
      if (needsConversion) {
        convertedFilePath = FileParts.joinPath(AppDirs.APP_CACHE, '${source.hashCode}.wav');
        final ffmpegConvert = Process.runSync(
          ffmpegExePath,
          ['-i', source, '-f', 'wav', convertedFilePath],
        );
        if (ffmpegConvert.exitCode != 0) {
          sendPort.send([token, []]);
          return;
        }
      }

      audioWaveformGenerate = Process.runSync(
        waveformExePath,
        ['-i', convertedFilePath ?? source, '--input-format', 'wav', ...waveformOutputOptions],
      );
      if (convertedFilePath != null) File(convertedFilePath).delete().catchError((_) => File(''));

      final data = jsonDecode(audioWaveformGenerate.stdout)?['data'] as List?;
      final finalList = data?.cast<num>() ?? [];

      final combinedList = <num>[];
      final maxLength = finalList.length % 2 == 0 ? finalList.length : finalList.length - 1; // ensure even number for pair combination
      for (int i = 0; i < maxLength; i += 2) {
        final left = finalList[i].abs();
        final right = finalList[i + 1].abs();
        final combined = left > right ? left : right;
        final finalnumber = combined * multiplier;
        combinedList.add(finalnumber);
      }

      sendPort.send([token, combinedList]);
    });

    sendPort.send(null); // prepared
  }

  @override
  void onResult(result) {
    final token = result[0] as int;
    final completer = _completers[token];
    if (completer != null && completer.isCompleted == false) {
      completer.complete(result[1]);
      _completers.remove(token); // dereferencing
    }
  }
}
