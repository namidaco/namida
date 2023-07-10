import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/main.dart';

class EditDeleteController {
  static EditDeleteController get inst => _instance;
  static final EditDeleteController _instance = EditDeleteController._internal();
  EditDeleteController._internal();

  Future<void> deleteCachedVideos(List<Track> tracks) async {
    final idsToDelete = tracks.mapped((e) => e.youtubeID);
    await for (final v in Directory(k_DIR_VIDEOS_CACHE).list()) {
      if (v is File) {
        await idsToDelete.loopFuture((id, index) async {
          if (v.path.getFilename.startsWith(id)) {
            await Indexer.inst.updateVideosSizeInStorage(v, true);
            await v.delete();
          }
        });
      }
    }

    VideoController.inst.resetEverything();
    await Player.inst.updateVideoPlayingState();
  }

  Future<void> deleteWaveFormData(List<Track> tracks) async {
    await tracks.loopFuture((track, index) async {
      final file = File("$k_DIR_WAVEFORMS${track.filename}.wave");
      await Indexer.inst.updateWaveformSizeInStorage(file, true);
      await file.delete();
    });
  }

  Future<void> deleteLyrics(List<Track> tracks) async {
    await tracks.loopFuture((track, index) async {
      await File("$k_DIR_LYRICS${track.filename}.txt").delete();
    });
  }

  Future<void> deleteArtwork(List<Track> tracks) async {
    await tracks.loopFuture((track, index) async {
      final file = File("$k_DIR_ARTWORKS${track.filename}.png");
      await Indexer.inst.updateImageSizeInStorage(file, true);
      await file.delete();
    });

    await deleteExtractedColor(tracks);
  }

  Future<void> deleteExtractedColor(List<Track> tracks) async {
    await tracks.loopFuture((track, index) async {
      await File("$k_DIR_PALETTES${track.filename}.palette").delete();
    });
  }

  /// returns save directory path if saved successfully
  Future<String?> saveArtworkToStorage(Track track) async {
    if (!await requestManageStoragePermission()) {
      return null;
    }
    final saveDirPath = SettingsController.inst.defaultBackupLocation.value;
    final newPath = "$saveDirPath${Platform.pathSeparator}${track.filenameWOExt}.png";
    final imgFile = File(track.pathToImage);

    try {
      // try coping
      await imgFile.copy(newPath);
      return saveDirPath;
    } catch (e) {
      imgFile.tryDeleting();

      // try extracting artwork
      try {
        final img = await Indexer.inst.extractOneArtwork(track.path);
        if (img != null) {
          final newImgFile = await File(newPath).create();
          await newImgFile.writeAsBytes(img);
          return saveDirPath;
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> updateTrackPathInEveryPartOfNamida(Track oldTrack, String newPath) async {
    final newtrlist = await Indexer.inst.convertPathToTrack([newPath]);
    if (newtrlist.isEmpty) return;
    final newTrack = newtrlist.first;

    // --- Queues ---
    QueueController.inst.replaceTrackInAllQueues(oldTrack, newTrack);

    // --- Player Queue ---
    Player.inst.replaceAllTracksInQueue(oldTrack, newTrack);

    // --- Playlists & Favourites---
    PlaylistController.inst.replaceTrackInAllPlaylists(oldTrack, newTrack);

    // --- History---
    HistoryController.inst.replaceAllTracksInsideHistory(oldTrack, newTrack);

    // --- Selected Tracks ---
    SelectedTracksController.inst.replaceThisTrack(oldTrack, newTrack);
  }
}

extension HasCachedFiles on List<Track> {
  bool get hasWaveformCached => doesAnyPathExist(this, k_DIR_WAVEFORMS, 'wave');
  bool get hasArtworkCached => doesAnyPathExist(this, k_DIR_ARTWORKS, 'png');
  bool get hasLyricsCached => doesAnyPathExist(this, k_DIR_LYRICS, 'txt');
  bool get hasColorCached => doesAnyPathExist(this, k_DIR_PALETTES, 'palette');
  bool get hasVideoCached {
    final allvideos = Directory(k_DIR_VIDEOS_CACHE).listSync();
    for (final track in this) {
      for (final v in allvideos) {
        if (v.path.getFilename.startsWith(track.youtubeID)) {
          return true;
        }
      }
    }
    return false;
  }

  bool get hasAnythingCached => hasWaveformCached || hasArtworkCached || hasLyricsCached /* || hasColorCached */;
}

bool doesAnyPathExist(List<Track> tracks, String directory, String extension) {
  for (final track in tracks) {
    if (File("$directory${track.filename}.$extension").existsSync()) {
      return true;
    }
  }
  return false;
}
