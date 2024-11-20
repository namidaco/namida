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

  late List<double> currentWaveformUI = List<double>.filled(_defaultUserBarsCount, -1, growable: false);

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
      final downscaledLists = await _downscaledWaveformLists.thready((
        targetSizes: [maxWaveformCount, numberOfScales],
        original: waveformData,
      ));

      _currentWaveform = downscaledLists[maxWaveformCount] ?? [];
      _currentScaleLookup = downscaledLists[numberOfScales] ?? [];
      _currentScaleMaxIndex = _currentScaleLookup.length - 1;

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

  static Map<num, List<double>> _downscaledWaveformLists(({List<num> original, List<int> targetSizes}) params) {
    final newLists = <num, List<double>>{};
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

  static const _positionDividor = 50;
  static const _positionDividorWithOffset = isKuru ? _positionDividor - 3.58 : 50;

  double getCurrentAnimatingScale(int positionInMs) {
    final posInMap = positionInMs ~/ _positionDividorWithOffset;
    final dynamicScale = posInMap > _currentScaleMaxIndex ? 0.01 : _currentScaleLookup[posInMap];
    final intensity = settings.animatingThumbnailIntensity.value;
    final finalScale = dynamicScale * intensity * 0.00005;
    if (finalScale.isNaN || finalScale > 0.3) return 0.01;
    return finalScale;
  }

  final _waveformExtractor = WaveformExtractor.platform()..init();
}
