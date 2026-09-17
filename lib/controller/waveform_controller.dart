import 'dart:typed_data';

import 'package:namida_waveform/namida_waveform.dart';

import 'package:namida/controller/waveform_extractor.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
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
    final samplePerSecond = NamidaWaveform.sampleRateForDuration(
      audioDuration: duration,
      maxSampleRate: 400,
      scaleFactor: 0.4,
    );

    Float32List waveformData = _emptyWaveformData;
    await Future.wait([
      _waveformExtractor
          .extractWaveformData(path, samplesPerSecond: samplePerSecond)
          .then((value) => waveformData = value)
          .catchError((_) => waveformData = _emptyWaveformData),
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
      _ensureHapticListener();
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
    for (var targetSize in targetSizes) {
      newLists[targetSize] = original.changeListSize(
        targetSize: targetSize,
        clampToMax: maxClamping,
        enforceClampToMax: (minValue, maxValue) {
          // -- checking if max value is greater than `maxClamping`;
          // -- since clamping tries to normalize among all lists variations
          return maxValue > maxClamping * 2.0;
        },
      );
    }
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
    if (intensity > 0) {
      final posInMap = positionInMs ~/ _positionDividorWithOffset;
      final dynamicScale = posInMap < 0 || posInMap > _currentScaleMaxIndex ? _defaultMinimumScale : _currentScaleLookup[posInMap];
      final finalScale = dynamicScale * intensity * 0.00005;
      if (finalScale.isNaN || finalScale > 0.35) return _defaultMinimumScale;
      return finalScale;
    }

    return _defaultMinimumScale;
  }

  bool _hapticListenerAdded = false;

  void _ensureHapticListener() {
    if (_hapticListenerAdded) return;
    _hapticListenerAdded = true;
    Player.inst.nowPlayingPosition.addListener(_onPositionChangedHaptic);
  }

  void _onPositionChangedHaptic() {
    if (_currentScaleMaxIndex < 0) return;
    if (settings.extra.mediaWaveHaptic != true) return;
    _vibrateHaptic(getCurrentAnimatingScale(Player.inst.nowPlayingPosition.value));
  }

  void _vibrateHaptic(double scale) {
    if (Player.inst.isPlaying.value == false) return;
    if (scale > _defaultMinimumScale) {
      final haptic = VibratorController.interfaceHapticIgnoreSettings;
      if (scale < 0.03) {
        haptic.light();
        haptic.light();
        haptic.light();
      } else if (scale < 0.06) {
        haptic.light();
        haptic.medium();
        haptic.medium();
        haptic.light();
      } else if (scale < 0.10) {
        haptic.medium();
        haptic.high();
        haptic.high();
        haptic.high();
        haptic.medium();
      } else {
        haptic.high();
        haptic.high();
        haptic.high();
        haptic.high();
      }
    }
  }

  static const _defaultMinimumScale = 0.01;

  static final _emptyWaveformData = Float32List(0);

  final _waveformExtractor = WaveformExtractor()..init();
}
