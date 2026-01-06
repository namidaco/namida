part of 'waveform_extractor.dart';

abstract class WaveformExtractor {
  static WaveformExtractor platform() {
    return NamidaPlatformBuilder.init(
      android: () => _WaveformExtractorAndroid._internal(NamidaFFMPEG.inst),
      windows: () => _WaveformExtractorWindows._internal(NamidaFFMPEG.inst),
    );
  }

  void init();

  Future<List<num>> extractWaveformData(
    String source, {
    bool useCache = true,
    String? cacheKey,
    int? samplesPerSecond,
  });

  int getSampleRateFromDuration({
    required Duration audioDuration,
    int maxSampleRate = 400,
    double scaleFactor = 0.4,
  }) {
    return pkgwaveform.WaveformExtractor.getSampleRateFromDuration(
      audioDuration: audioDuration,
      maxSampleRate: maxSampleRate,
      scaleFactor: scaleFactor,
    );
  }
}
