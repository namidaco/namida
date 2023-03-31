import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class DeleteController {
  static final DeleteController inst = DeleteController();

  Future<void> deleteCachedVideos(List<Track> tracks) async {
    final allvideo = Directory(kVideosCachePath).listSync();

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
      await File("$kWaveformDirPath${track.filename}.wave").delete();
    }
  }

  Future<void> deleteLyrics(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$kLyricsDirPath${track.filename}.txt").delete();
    }
  }

  Future<void> deleteArtwork(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$kArtworksDirPath${track.filename}.png").delete();
    }
    await deleteExtractedColor(tracks);
  }

  Future<void> deleteExtractedColor(List<Track> tracks) async {
    for (final track in tracks) {
      await File("$kPaletteDirPath${track.filename}.palette").delete();
    }
  }
}
