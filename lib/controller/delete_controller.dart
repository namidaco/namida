import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class DeleteController {
  static final DeleteController inst = DeleteController();

  Future<void> deleteCachedVideos(List<Track> tracks) async {
    final allvideo = Directory(k_DIR_VIDEOS_CACHE).listSync();

    for (final track in tracks) {
      for (final v in allvideo) {
        if (v.path.getFilename.startsWith(track.youtubeID)) {
          await v.delete();
        }
      }
    }

    VideoController.inst.resetEverything();
    await Player.inst.updateVideoPlayingState();
  }

  Future<void> deleteWaveFormData(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$k_DIR_WAVEFORMS${track.filename}.wave").delete();
    }
  }

  Future<void> deleteLyrics(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$k_DIR_LYRICS${track.filename}.txt").delete();
    }
  }

  Future<void> deleteArtwork(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$k_DIR_ARTWORKS${track.filename}.png").delete();
    }
    await deleteExtractedColor(tracks);
  }

  Future<void> deleteExtractedColor(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$k_DIR_PALETTES${track.filename}.palette").delete();
    }
  }
}
