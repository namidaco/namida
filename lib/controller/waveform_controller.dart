import 'dart:convert';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class WaveformController {
  static final WaveformController inst = WaveformController();

  final RxList<double> curentWaveform = kDefaultWaveFormData.obs;
  final RxBool generatingAllWaveforms = false.obs;

  final RxMap<int, double> _currentScaleMap = <int, double>{}.obs;

  int retryNumber = 0;

  int _getlistSize(int durationInMs) => durationInMs ~/ 50 - 1; // each 50ms

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [curentWaveform].
  ///
  /// Has a timeout of 3 minutes, otherwise it will assign [kDefaultWaveFormData] permanently.
  ///
  /// <br>
  Future<void> generateWaveform(Track track) async {
    final wavePath = "$k_DIR_WAVEFORMS${track.path.getFilename}.wave";
    final waveFile = File(wavePath);
    final waveFileStat = await waveFile.stat();
    final numberOfScales = _getlistSize(track.duration);

    // If Waveform file exists in storage
    if (await waveFile.exists() && waveFileStat.size > 10) {
      try {
        final content = await waveFile.readAsString();
        final waveform = List<double>.from(json.decode(content));

        // A Delay to prevent glitches caused by theme change
        Future.delayed(const Duration(milliseconds: 400), () async {
          curentWaveform.assignAll(_increaseListToMax(waveform));
          final dList = changeListSize(waveform, numberOfScales);
          _updateScaleMap(dList);
        });
      } catch (e) {
        printInfo(info: e.toString());
      }
    }
    // If Waveform file does NOT exist in storage
    else {
      /// A Delay to prevent glitches caused by theme change
      Future.delayed(const Duration(milliseconds: 400), () async {
        curentWaveform.assignAll(kDefaultWaveFormData);
        final dList = changeListSize(kDefaultScaleList, numberOfScales);
        _updateScaleMap(dList);
      });

      await waveFile.create();

      List<double> waveformData = kDefaultWaveFormData;
      // creates a new instance to prevent extracting from the same file.
      // currently this won't be performant when the user plays multiple files at once
      try {
        waveformData = await PlayerController().extractWaveformData(path: track.path, noOfSamples: 1000).timeout(const Duration(minutes: 3));
        retryNumber = 0;
      } catch (e) {
        retryNumber++;
        if (retryNumber < 3) {
          await waveFile.delete();
          await generateWaveform(track);
        }
        printError(info: e.toString());
      }

      if (track == Player.inst.nowPlayingTrack.value) {
        curentWaveform.assignAll(_increaseListToMax(waveformData));
        final dList = changeListSize(waveformData, numberOfScales);
        _updateScaleMap(dList);
      }

      await waveFile.writeAsString(waveformData.toString());
      Indexer.inst.updateWaveformSizeInStorage(waveFile);
    }
  }

  void _updateScaleMap(List<double> doubleList) {
    for (int index = 0; index < doubleList.length; index++) {
      _currentScaleMap[index] = doubleList[index];
    }
  }

  Future<void> generateAllWaveforms() async {
    if (!await Directory(k_DIR_WAVEFORMS).exists()) {
      Directory(k_DIR_WAVEFORMS).create();
    }
    generatingAllWaveforms.value = true;

    for (final tr in allTracksInLibrary) {
      if (!generatingAllWaveforms.value) {
        break;
      }
      await generateWaveform(tr);
    }
    generatingAllWaveforms.value = false;
  }

  double getCurrentAnimatingScale(int positionInMs) {
    final bitScale = positionInMs ~/ 50 - 1;
    final dynamicScale = _currentScaleMap[bitScale] ?? 0.01;
    final intensity = SettingsController.inst.animatingThumbnailIntensity.value;
    final finalScale = dynamicScale * (intensity / 100);

    return finalScale;
  }

  List<double> changeListSize(List<double> list, int n) {
    if (list.length > n) {
      // downscale
      final downscaledList = <double>[];
      final scaleFactor = (list.length / n).ceil();
      for (int i = 0; i < n; i++) {
        double sum = 0.0;
        int count = 0;
        for (int j = i * scaleFactor; j < (i + 1) * scaleFactor && j < list.length; j++) {
          sum += list[j];
          count++;
        }
        downscaledList.add(sum / count);
      }

      // removes NaN values
      downscaledList.removeWhere((value) => value.isNaN);

      return downscaledList;
    } else {
      // upscale
      final double step = (list.length - 1) / (n - 1);

      final finalList = List<double>.generate(n, (i) {
        final double index = i * step;
        final int lowerIndex = index.floor();
        final int upperIndex = index.ceil();
        if (upperIndex >= list.length) {
          return list.last;
        } else if (lowerIndex == upperIndex) {
          return list[lowerIndex];
        } else {
          final double weight = index - lowerIndex;
          return list[lowerIndex] * (1 - weight) + list[upperIndex] * weight;
        }
      });
      return finalList;
    }
  }

  List<double> _increaseListToMax(List<double> list) {
    final max = list.reduce((a, b) => a > b ? a : b);
    return list.map((value) => value / max / 2.0).toList();
  }
}
