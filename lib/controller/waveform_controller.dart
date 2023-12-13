import 'dart:math';

import 'package:get/get.dart';
import 'package:waveform_extractor/waveform_extractor.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class WaveformController {
  static WaveformController get inst => _instance;
  static final WaveformController _instance = WaveformController._internal();
  WaveformController._internal();

  /// Trying to update [currentWaveformUI] while this is false will have no effect.
  bool canModifyUIWaveform = false;

  List<double> _currentWaveform = kDefaultWaveFormData;
  final currentWaveformUI = kDefaultWaveFormData.obs;

  final RxMap<int, double> _currentScaleMap = <int, double>{}.obs;

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [_currentWaveform].
  Future<void> generateWaveform(Track track) async {
    _currentWaveform = kDefaultWaveFormData;
    calculateUIWaveform(dummy: true);

    const maxSampleRate = 400;
    final scaledDuration = 0.4 * track.duration;
    final scaledSampleRate = maxSampleRate * (exp(-scaledDuration / 100));

    final samplePerSecond = scaledSampleRate.toInt().clamp(1, maxSampleRate);

    List<int> waveformData = [];
    await Future.wait([
      _waveformExtractor.extractWaveformDataOnly(track.path, samplePerSecond: samplePerSecond).then((value) {
        waveformData = value;
      }),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (track == Player.inst.nowPlayingTrack) {
      // ----- Updating [_currentWaveform]
      const maxWaveformCount = 2000;
      final numberOfScales = (track.duration * 1000) ~/ 50;
      final downscaledLists = await _downscaledWaveformLists.thready((
        targetSizes: [maxWaveformCount, numberOfScales],
        original: waveformData,
      ));

      _currentWaveform = downscaledLists[maxWaveformCount]!;
      calculateUIWaveform();

      // ----- Updating [currentScale]
      _updateScaleMap(downscaledLists[numberOfScales]!);
    }
  }

  void calculateUIWaveform({bool dummy = false}) async {
    if (!canModifyUIWaveform) return;
    final userBars = settings.waveformTotalBars.value;
    final waveform = await _calculateUIWaveformIsolate.thready((
      targetSize: userBars,
      original: dummy ? kDefaultWaveFormData : _currentWaveform,
    ));
    if (!canModifyUIWaveform) return;
    currentWaveformUI.value = waveform;
  }

  static List<double> _calculateUIWaveformIsolate(({List<double> original, int targetSize}) params) {
    final clamping = params.original.isEqualTo(kDefaultWaveFormData) ? null : 64.0;
    final downscaled = params.original.changeListSize(
      targetSize: params.targetSize,
      multiplier: 0.9,
      clampToMax: clamping,
      enforceClampToMax: false,
    );
    return downscaled;
  }

  static Map<int, List<double>> _downscaledWaveformLists(({List<int> original, List<int> targetSizes}) params) {
    final newLists = <int, List<double>>{};
    params.targetSizes.loop((targetSize, index) {
      final isLast = index == params.targetSizes.length - 1;
      newLists[targetSize] = params.original.changeListSize(targetSize: targetSize, multiplier: isLast ? 0.003 : 1.0);
    });
    return newLists;
  }

  void _updateScaleMap(List<double> doubleList) {
    _currentScaleMap.value = doubleList.asMap();
  }

  double getCurrentAnimatingScale(int positionInMs) {
    final posInMap = positionInMs ~/ 50;
    final dynamicScale = _currentScaleMap[posInMap] ?? 0.01;
    final intensity = settings.animatingThumbnailIntensity.value;
    final finalScale = dynamicScale * intensity * 0.02;

    return finalScale.isNaN ? 0.01 : finalScale;
  }

  final _waveformExtractor = WaveformExtractor();
}
