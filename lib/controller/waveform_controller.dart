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

class WaveformController extends GetxController {
  static final WaveformController inst = WaveformController();

  final RxList<double> curentWaveform = kDefaultWaveFormData.obs;
  final RxList<double> curentScaleList = kDefaultScaleList.obs;
  final RxBool generatingAllWaveforms = false.obs;

  int retryNumber = 0;

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [curentWaveform].
  ///
  /// Has a timeout of 3 minutes, otherwise it will assign [kDefaultWaveFormData] permanently.
  ///
  /// <br>
  Future<void> generateWaveform(Track track) async {
    final wavePath = "$kWaveformDirPath${track.path.getFilename}.wave";
    final waveFile = File(wavePath);
    final waveFileStat = await waveFile.stat();

    // If Waveform file exists in storage
    if (await waveFile.exists() && waveFileStat.size > 10) {
      try {
        String content = await waveFile.readAsString();
        final waveform = List<double>.from(json.decode(content));

        // A Delay to prevent glitches caused by theme change
        Future.delayed(const Duration(milliseconds: 400), () async {
          curentWaveform.assignAll(increaseListToMax(waveform)); //
          curentScaleList.assignAll(changeListSize(waveform, track.duration ~/ 50 - 1)); // each 50ms
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
        curentScaleList.assignAll(changeListSize(kDefaultScaleList, track.duration ~/ 50 - 1));
      });

      // no await since extraction process will take time anyway, hope this doesnt make problems
      waveFile.create();

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
        curentWaveform.assignAll(increaseListToMax(waveformData)); //
        curentScaleList.assignAll(changeListSize(waveformData, track.duration ~/ 50)); // each 50ms
      }

      await waveFile.writeAsString(waveformData.toString());
      Indexer.inst.updateWaveformSizeInStorage();
    }

    Indexer.inst.waveformsInStorage.refresh();
  }

  Future<void> generateAllWaveforms() async {
    if (!await Directory(kWaveformDirPath).exists()) {
      Directory(kWaveformDirPath).create();
    }
    generatingAllWaveforms.value = true;

    for (final tr in Indexer.inst.tracksInfoList) {
      if (!generatingAllWaveforms.value) {
        break;
      }
      await generateWaveform(tr);
    }
    generatingAllWaveforms.value = false;
  }

  double getAnimatingScale(List<double> curentScaleList) {
    final scaleList = WaveformController.inst.curentScaleList;
    final bitScale = Player.inst.nowPlayingPosition.value ~/ 50;
    final dynamicScale = scaleList.asMap().containsKey(bitScale) ? scaleList[bitScale] : 0.01;
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

  List<double> interpolateList(List<double> list, int m) {
    final interpolatedList = <double>[];
    for (int i = 0; i < list.length - 1; i++) {
      final start = list[i];
      final end = list[i + 1];
      final step = (end - start) / (m + 1);
      for (int j = 1; j <= m; j++) {
        final value = start + j * step;
        interpolatedList.add(value);
      }
    }
    return interpolatedList;
  }

  List<double> increaseListToMax(List<double> list, [double max = 0.0]) {
    final max = list.reduce((a, b) => a > b ? a : b);
    return list.map((value) => value / max / 2.0).toList();
  }

  List<double> upscaleList(List<double> originalList, int newLength) {
    double scaleFactor = newLength / originalList.length + 1;
    List<double> newList = [];
    for (int i = 0; i < newLength; i++) {
      int originalIndex = (i / scaleFactor).floor();
      double fraction = (i / scaleFactor) - originalIndex;
      double newValue = originalList[originalIndex] * (1 - fraction) + originalList[originalIndex + 1] * fraction;
      newList.add(newValue);
    }
    return newList;
  }

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
