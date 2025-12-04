import 'package:namida/controller/platform/waveform_extractor/waveform_extractor.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class WaveformController {
  static WaveformController get inst => _instance;
  static final WaveformController _instance = WaveformController._internal();
  WaveformController._internal();

  int get _defaultUserBarsCount => settings.waveformTotalBars.value;

  RxBaseCore<bool> get isWaveformUIEnabled => _isWaveformUIEnabled;
  final _isWaveformUIEnabled = false.obso;

  late final currentWaveformUIRx = List<double>.filled(_defaultUserBarsCount, -1, growable: false).obs;

  List<double> _currentWaveform = [];

  var _currentScaleLookup = <double>[];
  int _currentScaleMaxIndex = -1;

  bool get isDummy => _currentWaveform.isEmpty;

  void resetWaveform() {
    _currentWaveform = [];
    _currentScaleLookup = [];
    _currentScaleMaxIndex = -1;
    _isWaveformUIEnabled.value = false;
  }

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [_currentWaveform].
  Future<void> generateWaveform({required String path, required Duration duration, required bool Function(String path) stillPlaying}) async {
    final samplePerSecond = _waveformExtractor.getSampleRateFromDuration(
      audioDuration: duration,
      maxSampleRate: 400,
      scaleFactor: 0.4,
    );

    List<num> waveformData = [];
    await Future.wait([
      _waveformExtractor.extractWaveformData(path, samplesPerSecond: samplePerSecond).catchError((_) => <num>[]).then((value) async {
        if (value.isNotEmpty) {
          waveformData = value;
        } else if (stillPlaying(path)) {
          waveformData = await _waveformExtractor.extractWaveformData(path).catchError((_) => <num>[]); // re-extracting without samples (out of boundaries error)
        }
      }),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (waveformData.isNotEmpty && stillPlaying(path)) {
      // ----- Updating [_currentWaveform]
      const maxWaveformCount = 2000;
      final numberOfScales = duration.inMilliseconds ~/ _positionDividor;
      final downscaledLists = _downscaledWaveformLists(
        targetSizes: [maxWaveformCount, numberOfScales],
        original: waveformData,
      );

      _currentWaveform = downscaledLists[maxWaveformCount] ?? [];
      _currentScaleLookup = downscaledLists[numberOfScales] ?? [];
      _currentScaleMaxIndex = _currentScaleLookup.length - 1;

      calculateUIWaveform();
    }
  }

  void calculateUIWaveform() async {
    if (_currentWaveform.isEmpty) return;

    final waveform = _getCalculatedUIWaveform(
      targetSize: _defaultUserBarsCount,
      original: _currentWaveform,
    );
    currentWaveformUIRx.value = waveform;
    _isWaveformUIEnabled.value = true;
  }

  static List<double> _getCalculatedUIWaveform({required List<double> original, required int targetSize}) {
    const maxClamping = 64.0;
    final clamping = original.isEmpty ? null : maxClamping;
    final downscaled = original.changeListSize(
      targetSize: targetSize,
      multiplier: 0.9,
      clampToMax: clamping,
      enforceClampToMax: (minValue, maxValue) => false,
    );
    return downscaled;
  }

  static Map<num, List<double>> _downscaledWaveformLists({required List<num> original, required List<int> targetSizes}) {
    final newLists = <num, List<double>>{};
    const maxClamping = 64.0;
    targetSizes.loop((targetSize) {
      newLists[targetSize] = original.changeListSize(
        targetSize: targetSize,
        clampToMax: maxClamping,
        enforceClampToMax: (minValue, maxValue) {
          // -- checking if max value is greater than `maxClamping`;
          // -- since clamping tries to normalize among all lists variations
          return maxValue > maxClamping * 2.0;
        },
      );
    });
    return newLists;
  }

  static const _positionDividor = 50;
  static const _positionDividorWithOffset = isKuru ? _positionDividor - 3.58 : 50;

  double getCurrentAnimatingScale(int positionInMs) {
    return _getCurrentAnimatingScaleGeneral(positionInMs, settings.animatingThumbnailIntensity.value);
  }

  double getCurrentAnimatingScaleLyrics(int positionInMs) {
    return _getCurrentAnimatingScaleGeneral(positionInMs, settings.animatingThumbnailIntensityLyrics.value);
  }

  double getCurrentAnimatingScaleMinimized(int positionInMs) {
    return _getCurrentAnimatingScaleGeneral(positionInMs, settings.animatingThumbnailIntensityMinimized.value);
  }

  double _getCurrentAnimatingScaleGeneral(int positionInMs, int intensity) {
    if (intensity == 0) return 0.01;
    final posInMap = positionInMs ~/ _positionDividorWithOffset;
    final dynamicScale = posInMap > _currentScaleMaxIndex ? 0.01 : _currentScaleLookup[posInMap];
    final finalScale = dynamicScale * intensity * 0.00005;
    if (finalScale.isNaN || finalScale > 0.3) return 0.01;
    return finalScale;
  }

  final _waveformExtractor = WaveformExtractor.platform()..init();
}
