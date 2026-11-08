import 'dart:typed_data';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/spectrum_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/controller/waveform_extractor.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida_waveform/namida_waveform.dart';

class WaveformController {
  static WaveformController get inst => _instance;
  static final WaveformController _instance = WaveformController._internal();
  WaveformController._internal();

  int get _defaultUserBarsCount => settings.waveformTotalBars.value;

  RxBaseCore<bool> get isWaveformUIEnabled => _isWaveformUIEnabled;
  final _isWaveformUIEnabled = false.obso;

  late final currentWaveformUIRx = List<double>.filled(_defaultUserBarsCount, -1, growable: false).obs;

  Float32List _currentWaveform = _emptyWaveformData;

  Float32List _currentScaleLookup = _emptyWaveformData;
  int _currentScaleMaxIndex = -1;

  bool get isDummy => _currentWaveform.isEmpty;

  void resetWaveform() {
    _currentWaveform = _emptyWaveformData;
    _currentScaleLookup = _emptyWaveformData;
    _currentScaleMaxIndex = -1;
    _isWaveformUIEnabled.value = false;
    SpectrumController.inst.reset();
  }

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [_currentWaveform].
  Future<void> generateWaveform({required String path, required Duration duration, required bool Function(String path) stillPlaying}) async {
    final samplePerSecond = NamidaWaveform.sampleRateForDuration(
      audioDuration: duration,
      maxSampleRate: 400,
      scaleFactor: 0.4,
    );

    const maxWaveformCount = 2000;
    final numberOfScales = duration.inMilliseconds ~/ _positionDividor;
    final targetSizes = [maxWaveformCount, numberOfScales];

    List<Float32List> waveforms = const [];
    await Future.wait([
      _waveformExtractor
          .extractDownscaledWaveforms(path, samplesPerSecond: samplePerSecond, targetSizes: targetSizes)
          .then((value) => waveforms = value) //
          .catchError((_) => waveforms = const <Float32List>[]),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (waveforms.isNotEmpty && stillPlaying(path)) {
      _currentWaveform = waveforms[0];
      _currentScaleLookup = waveforms[1];
      _currentScaleMaxIndex = _currentScaleLookup.length - 1;

      calculateUIWaveform();
      _ensureHapticListener();
      SpectrumController.inst.onSourceReady(path: path, duration: duration);
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

  static const _positionDividor = 50;

  double getCurrentAnimatingScale(int positionInMs) {
    return _getCurrentAnimatingScaleGeneral(positionInMs, settings.animatingThumbnailIntensity.value);
  }

  double getCurrentAnimatingScaleLyrics(int positionInMs) {
    return _getCurrentAnimatingScaleGeneral(positionInMs, settings.animatingThumbnailIntensityLyrics.value);
  }

  double getCurrentAnimatingScaleMinimized(int positionInMs) {
    return _getCurrentAnimatingScaleGeneral(positionInMs, settings.animatingThumbnailIntensityMinimized.value);
  }

  double getCurrentLevel(double positionInMs) {
    final posInMap = positionInMs ~/ _positionDividor;
    if (posInMap < 0 || posInMap > _currentScaleMaxIndex) return 0.0;
    return (_currentScaleLookup[posInMap] / 64.0).clampDouble(0.0, 1.0);
  }

  double _getCurrentAnimatingScaleGeneral(int positionInMs, int intensity) {
    if (intensity > 0) {
      final posInMap = positionInMs ~/ _positionDividor;
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
    if (!settings.mediaWaveHaptic.value) return;
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
