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
      final convertedFilePath = FileParts.joinPath(AppDirs.APP_CACHE, '${source.toFastHashKey()}.wav');
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
    return data ?? <num>[];
  }
}
