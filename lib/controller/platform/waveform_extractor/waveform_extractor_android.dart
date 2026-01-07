part of 'waveform_extractor.dart';

class _WaveformExtractorAndroid extends WaveformExtractor {
  final NamidaFFMPEG ffmpegController;
  _WaveformExtractorAndroid._internal(this.ffmpegController);

  final _extractor = pkgwaveform.WaveformExtractor();

  @override
  void init() {}

  @override
  Future<List<num>> extractWaveformData(
    String source, {
    bool useCache = true,
    String? cacheKey,
    int? samplesPerSecond,
  }) async {
    List<int>? data;
    try {
      data = await _extractor.extractWaveformDataOnly(
        source,
        useCache: useCache,
        cacheKey: cacheKey,
        samplePerSecond: samplesPerSecond,
      );
    } catch (_) {}

    if (data == null || data.isEmpty) {
      final hashKey = 'custom_${source.toFastHashKey()}';
      cacheKey ??= hashKey; // ensure consistent key from now on
      try {
        // -- try extract previous cache before converting
        data = await _extractor.extractWaveformDataOnly(
          source,
          useCache: useCache,
          cacheKey: cacheKey,
          samplePerSecond: samplesPerSecond,
        );
      } catch (_) {}
      if (data == null || data.isEmpty) {
        // -- convert to wav and re-extract (with consistent cacheKey)
        final convertedFilePath = FileParts.joinPath(AppDirs.APP_CACHE, '$hashKey.wav');
        try {
          final ffmpegConvertDone = await ffmpegController.convertToWav(
            audioPath: source,
            outputPath: convertedFilePath,
          );
          if (ffmpegConvertDone) {
            data = await _extractor.extractWaveformDataOnly(
              convertedFilePath,
              useCache: useCache,
              cacheKey: cacheKey,
              samplePerSecond: samplesPerSecond,
            );
          }
        } catch (_) {
        } finally {
          File(convertedFilePath).tryDeleting();
        }
      }
    }
    return data ?? <num>[];
  }
}
