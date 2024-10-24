part of 'waveform_extractor.dart';

class _WaveformExtractorAndroid extends WaveformExtractor {
  _WaveformExtractorAndroid._internal();

  final _extractor = pkgwaveform.WaveformExtractor();

  @override
  void init() {}

  @override
  Future<List<num>> extractWaveformData(
    String source, {
    bool useCache = true,
    String? cacheKey,
    int? samplesPerSecond,
  }) {
    return _extractor.extractWaveformDataOnly(
      source,
      useCache: useCache,
      cacheKey: cacheKey,
      samplePerSecond: samplesPerSecond,
    );
  }
}
