import 'package:namida/core/utils.dart';
import 'package:waveform_extractor/waveform_extractor.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

class WaveformController {
  static WaveformController get inst => _instance;
  static final WaveformController _instance = WaveformController._internal();
  WaveformController._internal();

  int get _defaultUserBarsCount => settings.waveformTotalBars.value;

  RxBaseCore<bool> get isWaveformUIEnabled => _isWaveformUIEnabled;
  final _isWaveformUIEnabled = false.obso;

  late List<double> currentWaveformUI = List<double>.filled(_defaultUserBarsCount, -1, growable: false);

  List<double> _currentWaveform = [];

  var _currentScaleMap = <int, double>{};

  bool get isDummy => _currentWaveform.isEmpty;

  void resetWaveform() {
    _currentWaveform = [];
    _currentScaleMap = {};
    _isWaveformUIEnabled.value = false;
  }

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [_currentWaveform].
  Future<void> generateWaveform({required String path, required Duration duration, required bool Function(String path) stillPlaying}) async {
    final samplePerSecond = _waveformExtractor.getSampleRateFromDuration(
      audioDuration: duration,
      maxSampleRate: 400,
      scaleFactor: 0.4,
    );

    List<int> waveformData = [];
    await Future.wait([
      _waveformExtractor.extractWaveformDataOnly(path, samplePerSecond: samplePerSecond).catchError((_) => <int>[]).then((value) async {
        if (value.isNotEmpty) {
          waveformData = value;
        } else if (stillPlaying(path)) {
          waveformData = await _waveformExtractor.extractWaveformDataOnly(path).catchError((_) => <int>[]); // re-extracting without samples (out of boundaries error)
        }
      }),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (stillPlaying(path)) {
      // ----- Updating [_currentWaveform]
      const maxWaveformCount = 2000;
      final numberOfScales = duration.inMilliseconds ~/ 50;
      final downscaledLists = await _downscaledWaveformLists.thready((
        targetSizes: [maxWaveformCount, numberOfScales],
        original: waveformData,
      ));

      _currentWaveform = downscaledLists[maxWaveformCount] ?? [];
      _currentScaleMap = downscaledLists[numberOfScales]?.asMap() ?? {};

      calculateUIWaveform();
    }
  }

  void calculateUIWaveform() async {
    if (_currentWaveform.isEmpty) return;

    final userBars = _defaultUserBarsCount;
    final waveform = await _calculateUIWaveformIsolate.thready((
      targetSize: userBars,
      original: _currentWaveform,
    ));
    currentWaveformUI = waveform;
    _isWaveformUIEnabled.value = true;
  }

  static List<double> _calculateUIWaveformIsolate(({List<double> original, int targetSize}) params) {
    const maxClamping = 64.0;
    final clamping = params.original.isEmpty ? null : maxClamping;
    final downscaled = params.original.changeListSize(
      targetSize: params.targetSize,
      multiplier: 0.9,
      clampToMax: clamping,
      enforceClampToMax: (minValue, maxValue) => false,
    );
    return downscaled;
  }

  static Map<int, List<double>> _downscaledWaveformLists(({List<int> original, List<int> targetSizes}) params) {
    final newLists = <int, List<double>>{};
    const maxClamping = 64.0;
    params.targetSizes.loop((targetSize) {
      newLists[targetSize] = params.original.changeListSize(
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

  double getCurrentAnimatingScale(int positionInMs) {
    final posInMap = positionInMs ~/ 50;
    final dynamicScale = _currentScaleMap[posInMap] ?? 0.01;
    final intensity = settings.animatingThumbnailIntensity.value;
    final finalScale = dynamicScale * intensity * 0.00005;

    return finalScale.isNaN ? 0.01 : finalScale;
  }

  final _waveformExtractor = WaveformExtractor();
}
