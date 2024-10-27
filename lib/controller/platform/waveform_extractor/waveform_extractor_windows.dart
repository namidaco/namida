part of 'waveform_extractor.dart';

class _WaveformExtractorWindows extends WaveformExtractor {
  final NamidaFFMPEG ffmpegController;
  _WaveformExtractorWindows._internal(this.ffmpegController);

  late String ffmpegExePath;
  late String waveformExePath;

  static const _supportedFormats = <String>{
    'wav', 'flac', 'mp3', 'ogg', 'opus', 'webm', //
    'WAV', 'FLAC', 'MP3', 'OGG', 'OPUS', 'WEBM',
  };

  @override
  void init() {
    final executablesPath = NamidaPlatformBuilder.getExecutablesPath();
    ffmpegExePath = p.join(executablesPath, 'ffmpeg.exe');
    waveformExePath = p.join(executablesPath, 'audiowaveform.exe');
  }

  @override
  Future<List<num>> extractWaveformData(
    String source, {
    bool useCache = true,
    String? cacheKey,
    int? sampleRate,
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
    final wavelist = await _extractWaveformNew(
      source,
      cacheFile: cacheFile,
      sampleRate: sampleRate,
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

  Future<List<num>> _extractWaveformNew(
    String source, {
    File? cacheFile,
    int? sampleRate,
    int? samplesPerSecond,
  }) async {
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
    final probablyGoodFormat = _supportedFormats.contains(extension);
    if (probablyGoodFormat) {
      try {
        audioWaveformGenerate = await Process.run(waveformExePath, ['-i', source, '--input-format', extension, ...waveformOutputOptions]);
        needsConversion = false;
      } catch (_) {}
    }
    if (needsConversion) {
      convertedFilePath = FileParts.joinPath(AppDirs.APP_CACHE, '${source.hashCode}.wav');
      final ffmpegConvert = await Process.run(
        ffmpegExePath,
        ['-i', source, '-f', 'wav', convertedFilePath],
      );
      if (ffmpegConvert.exitCode != 0) return <num>[];
    }

    audioWaveformGenerate = await Process.run(
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
    return combinedList;
  }
}
