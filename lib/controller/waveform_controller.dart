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

  final RxList<double> currentWaveform = kDefaultWaveFormData.obs;
  final RxDouble barWidth = 1.0.obs;
  final RxMap<int, double> _currentScaleMap = <int, double>{}.obs;

  int retryNumber = 0;

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [currentWaveform].
  ///
  /// Has a timeout of 3 minutes, otherwise it will assign [kDefaultWaveFormData] permanently.
  Future<void> generateWaveform(Track track) async {
    currentWaveform
      ..clear()
      ..addAll(kDefaultWaveFormData);

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
      // ----- Updating [currentWaveform]
      final downscaled = waveformData.changeListSize(targetSize: 2000);
      currentWaveform
        ..clear()
        ..addAll(downscaled);

      // ----- Updating [currentScale]
      final numberOfScales = (track.duration * 1000) ~/ 50;
      final dList = waveformData.changeListSize(targetSize: numberOfScales, multiplier: 0.003);
      _updateScaleMap(dList);
    }
  }

  void _updateScaleMap(List<double> doubleList) {
    _currentScaleMap.value = doubleList.asMap();
  }

  double getCurrentAnimatingScale(int positionInMs) {
    final bitScale = positionInMs ~/ 50 + 0; // TODO: expose this 0 as a calibration
    final dynamicScale = _currentScaleMap[bitScale] ?? 0.01;
    final intensity = SettingsController.inst.animatingThumbnailIntensity.value;
    final finalScale = dynamicScale * intensity * 0.02;

    return finalScale.isNaN ? 0.01 : finalScale;
  }

  final _waveformExtractor = WaveformExtractor();
}
