import 'dart:convert';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:get/get.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:path/path.dart' as p;

class WaveformController extends GetxController {
  static final WaveformController inst = WaveformController();

  RxList<double> curentWaveform = kDefaultWaveFormData.obs;
  RxBool generatingAllWaveforms = false.obs;

  int retryNumber = 0;

  /// Extracts waveform data from a given track, or immediately read from .wave file if exists, then assigns wavedata to [curentWaveform].
  /// Has a timeout of 3 minutes, otherwise it will assign [kDefaultWaveFormData] permanently.
  Future<void> generateWaveform(Track track) async {
    final wavePath = "$kWaveformDirPath${p.basename(track.path)}.wave";
    final waveFile = File(wavePath);
    final waveFileStat = await waveFile.stat();

    // If Waveform file exists in storage
    if (await waveFile.exists() && waveFileStat.size != 0) {
      try {
        String content = await waveFile.readAsString();
        final waveform = List<double>.from(json.decode(content));

        // A Delay to prevent glitches caused by theme change
        Future.delayed(const Duration(milliseconds: 400), () async {
          curentWaveform.assignAll(waveform);
        });
        retryNumber = 0;
      } catch (e) {
        printInfo(info: e.toString());
      }
    }
    // If Waveform file does NOT exist in storage
    else {
      /// A Delay to prevent glitches caused by theme change
      Future.delayed(const Duration(milliseconds: 400), () async {
        curentWaveform.assignAll(kDefaultWaveFormData);
      });

      // no await since extraction process will take time anyway, hope this doesnt make problems
      waveFile.create();

      List<double> waveformData = kDefaultWaveFormData;
      // creates a new instance to prevent extracting from the same file.
      // currently this won't be performant when the user plays multiple files at once
      try {
        waveformData = await PlayerController().extractWaveformData(path: track.path, noOfSamples: 500).timeout(const Duration(minutes: 3));
      } catch (e) {
        retryNumber++;
        if (retryNumber < 3) {
          await waveFile.delete();
          await generateWaveform(track);
        }
        printError(info: e.toString());
      }

      if (track == Player.inst.nowPlayingTrack.value) {
        curentWaveform.assignAll(waveformData);
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

    for (var tr in Indexer.inst.tracksInfoList) {
      if (!generatingAllWaveforms.value) {
        break;
      }
      await generateWaveform(tr);
    }
    generatingAllWaveforms.value = false;
  }

  List<double> downscaleList(List<double> originalList, int newLength) {
    List<double> downscaledList = [];
    int scaleFactor = originalList.length ~/ newLength;
    for (int i = 0; i < newLength; i++) {
      double average = 0;
      for (int j = i * scaleFactor; j < (i + 1) * scaleFactor; j++) {
        average += originalList[j];
      }
      average /= scaleFactor;
      downscaledList.add(average);
    }
    return downscaledList;
  }

  // List<double> upscaleList(List<double> originalList, int newLength) {
  //   double scaleFactor = newLength / originalList.length + 1;
  //   List<double> newList = [];
  //   for (int i = 0; i < newLength; i++) {
  //     int originalIndex = (i / scaleFactor).floor();
  //     double fraction = (i / scaleFactor) - originalIndex;
  //     double newValue = originalList[originalIndex] * (1 - fraction) + originalList[originalIndex + 1] * fraction;
  //     newList.add(newValue);
  //   }
  //   return newList;
  // }

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
