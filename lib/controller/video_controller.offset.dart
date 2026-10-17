part of 'video_controller.dart';

// by claude
/// Lines a local track up against the audio of its youtube video, the shift where both loudness curves match best
/// is where the track starts inside the video.
class _VideoOffsetDetector {
  static const _kSamplesPerSecond = 100;
  static const _kWindowSamples = 45 * _kSamplesPerSecond;
  static const _kMinWindowSamples = 5 * _kSamplesPerSecond;
  static const _kMaxNegativeSamples = 10 * _kSamplesPerSecond;
  static const _kExtraPositiveSamples = 10 * _kSamplesPerSecond;
  static const _kHighPassHalfSamples = _kSamplesPerSecond ~/ 2;
  static const _kMinScore = 0.4;
  static const _kMinScoreMargin = 0.08;
  static const _kNegligibleOffsetMS = 50;

  static Future<int?> detect({required String trackPath, required String videoId}) async {
    final cachedAudio = await AudioCacheController.inst.getCachedAudioForId(videoId, includeLocalTracks: false);
    if (cachedAudio != null) return _computeOffsetMS(trackPath, cachedAudio.file.path);

    final tempFile = await _downloadLightestAudio(videoId);
    try {
      return await _computeOffsetMS(trackPath, tempFile.path);
    } finally {
      tempFile.tryDeleting();
    }
  }

  static Future<File> _downloadLightestAudio(String videoId) async {
    final streamsResult = await YoutubeInfoController.video.fetchVideoStreams(videoId);
    final audioStreams = streamsResult?.audioStreams;
    if (audioStreams == null || audioStreams.isEmpty) throw Exception('No audio streams available for $videoId');

    // -- dubbed tracks don't line up with the original
    final originalStreams = audioStreams.where((e) => e.audioTrack?.isDefault != false).toFixedList();
    final candidates = originalStreams.isEmpty ? audioStreams : originalStreams;
    final lightest = candidates.reduce((a, b) => b.bitrate < a.bitrate ? b : a);

    if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();
    final tempFile = File(FileParts.joinPath(Directory.systemTemp.path, 'offset_${videoId}_${lightest.itag}'));
    final downloadError = await FilesDownloadManager.inst.download(
      url: lightest.buildUrl(),
      file: tempFile,
      totalBytes: lightest.sizeInBytes,
      threads: settings.youtube.downloadThreadsCount.value,
      downloadingStream: (_) {},
    );
    if (downloadError != null) {
      tempFile.tryDeleting();
      throw downloadError;
    }
    return tempFile;
  }

  static Future<int?> _computeOffsetMS(String trackPath, String ytAudioPath) {
    return _computeOffsetMSSync.thready((trackPath: trackPath, ytAudioPath: ytAudioPath));
  }

  static int? _computeOffsetMSSync(({String trackPath, String ytAudioPath}) params) {
    final trackLoudness = NamidaWaveform.extract(params.trackPath, samplesPerSecond: _kSamplesPerSecond).values;
    final ytLoudness = NamidaWaveform.extract(params.ytAudioPath, samplesPerSecond: _kSamplesPerSecond).values;
    if (trackLoudness.isEmpty || ytLoudness.isEmpty) return null;

    final trackCurve = _toHighPassedLogCurve(trackLoudness);
    final ytCurve = _toHighPassedLogCurve(ytLoudness);
    final offsetMS = _findBestOffsetMS(trackCurve, ytCurve);
    if (offsetMS == null) return null;
    return offsetMS.abs() < _kNegligibleOffsetMS ? 0 : offsetMS;
  }

  /// log loudness minus its 1 second moving average, keeps the rhythm and drops gain and mastering differences.
  static Float32List _toHighPassedLogCurve(Float32List loudness) {
    final length = loudness.length;
    final logPrefix = Float64List(length + 1);
    final logLoudness = Float32List(length);
    for (int i = 0; i < length; i++) {
      final logValue = math.log(loudness[i] + 1.0);
      logLoudness[i] = logValue;
      logPrefix[i + 1] = logPrefix[i] + logValue;
    }

    final curve = Float32List(length);
    for (int i = 0; i < length; i++) {
      final from = (i - _kHighPassHalfSamples).withMinimum(0);
      final to = (i + _kHighPassHalfSamples + 1).withMaximum(length);
      final average = (logPrefix[to] - logPrefix[from]) / (to - from);
      curve[i] = logLoudness[i] - average;
    }
    return curve;
  }

  /// normalized cross correlation of the track's first [_kWindowSamples] against every allowed shift in [yt].
  /// the track is a subset of the video, so shifts are capped by the length difference.
  static int? _findBestOffsetMS(Float32List track, Float32List yt) {
    final trackLength = track.length;
    final ytLength = yt.length;
    final windowLength = (trackLength - _kMaxNegativeSamples ~/ 2).withMaximum(_kWindowSamples);
    if (windowLength < _kMinWindowSamples || ytLength < windowLength) return null;

    final minLag = -(trackLength - windowLength).withMaximum(_kMaxNegativeSamples);
    final lengthDifference = ytLength - trackLength;
    final maxLag = (lengthDifference.withMinimum(0) + _kExtraPositiveSamples).withMaximum(ytLength - windowLength);

    final trackPrefix = _buildPrefixSums(track);
    final ytPrefix = _buildPrefixSums(yt);

    final lagsCount = maxLag - minLag + 1;
    final scores = Float64List(lagsCount);
    for (int k = 0; k < lagsCount; k++) {
      final lag = minLag + k;
      final trackStart = lag < 0 ? -lag : 0;
      final ytStart = trackStart + lag;
      double dot = 0;
      for (int i = 0; i < windowLength; i++) {
        dot += track[trackStart + i] * yt[ytStart + i];
      }
      scores[k] = _normalizedScore(dot, trackPrefix, trackStart, ytPrefix, ytStart, windowLength);
    }

    int bestK = 0;
    for (int k = 1; k < lagsCount; k++) {
      if (scores[k] > scores[bestK]) bestK = k;
    }
    final bestScore = scores[bestK];
    if (bestScore < _kMinScore) return null;

    // -- repeated sections give several close peaks, too ambiguous to pick one
    double secondScore = -1;
    for (int k = 0; k < lagsCount; k++) {
      if ((k - bestK).abs() > _kSamplesPerSecond && scores[k] > secondScore) secondScore = scores[k];
    }
    if (bestScore - secondScore < _kMinScoreMargin) return null;

    double fraction = 0;
    if (bestK > 0 && bestK < lagsCount - 1) {
      final before = scores[bestK - 1];
      final after = scores[bestK + 1];
      final curvature = before - 2 * bestScore + after;
      if (curvature != 0) fraction = 0.5 * (before - after) / curvature;
    }
    final bestLag = minLag + bestK + fraction;
    return (bestLag * 1000 / _kSamplesPerSecond).round();
  }

  static double _normalizedScore(double dot, _PrefixSums trackPrefix, int trackStart, _PrefixSums ytPrefix, int ytStart, int length) {
    final trackSum = trackPrefix.sums[trackStart + length] - trackPrefix.sums[trackStart];
    final trackSquaresSum = trackPrefix.squares[trackStart + length] - trackPrefix.squares[trackStart];
    final ytSum = ytPrefix.sums[ytStart + length] - ytPrefix.sums[ytStart];
    final ytSquaresSum = ytPrefix.squares[ytStart + length] - ytPrefix.squares[ytStart];
    final covariance = dot - trackSum * ytSum / length;
    final trackVariance = trackSquaresSum - trackSum * trackSum / length;
    final ytVariance = ytSquaresSum - ytSum * ytSum / length;
    final denominator = math.sqrt(trackVariance * ytVariance);
    return denominator > 0 ? covariance / denominator : 0;
  }

  static _PrefixSums _buildPrefixSums(Float32List values) {
    final length = values.length;
    final sums = Float64List(length + 1);
    final squares = Float64List(length + 1);
    for (int i = 0; i < length; i++) {
      final value = values[i];
      sums[i + 1] = sums[i] + value;
      squares[i + 1] = squares[i] + value * value;
    }
    return (sums: sums, squares: squares);
  }
}

typedef _PrefixSums = ({Float64List sums, Float64List squares});
