import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
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

  Future<void> deleteCachedVideos(List<Selectable> tracks) async {
    final videosToDelete = <NamidaVideo>[];
    tracks.loop((e, index) {
      videosToDelete.addAll(VideoController.inst.getNVFromID(e.track.youtubeID));
    });
    await Indexer.inst.clearVideoCache(videosToDelete);
    await Player.inst.updateVideoPlayingState();
  }

  Future<void> deleteWaveFormData(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      final file = File("$k_DIR_WAVEFORMS${track.track.filename}.wave");
      await Indexer.inst.updateWaveformSizeInStorage(file, true);
      await file.delete();
    });
  }

  Future<void> deleteLyrics(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      await File("$k_DIR_LYRICS${track.track.filename}.txt").delete();
    });
  }

  Future<void> deleteArtwork(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      final file = File(track.track.pathToImage);
      await Indexer.inst.updateImageSizeInStorage(file, true);
      await file.delete();
    });

    await deleteExtractedColor(tracks);
  }

  Future<void> deleteExtractedColor(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      await File("$k_DIR_PALETTES${track.track.filename}.palette").delete();
    });
  }

  /// returns save directory path if saved successfully
  Future<String?> saveArtworkToStorage(Track track) async {
    if (!await requestManageStoragePermission()) {
      return null;
    }
    final saveDirPath = SettingsController.inst.defaultBackupLocation.value;
    final newPath = "$saveDirPath${Platform.pathSeparator}${track.filenameWOExt}.png";
    final imgFile = await Indexer.inst.extractOneArtwork(track.path);
    if (imgFile != null) {
      try {
        // try copying
        await imgFile.copy(newPath);
        return saveDirPath;
      } catch (e) {
        printy(e, isError: true);
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

extension HasCachedFiles on List<Selectable> {
  bool get hasWaveformCached => _doesAnyPathExist(k_DIR_WAVEFORMS, 'wave');
  bool get hasArtworkCached => _doesAnyPathExist(k_DIR_ARTWORKS, 'png');
  bool get hasLyricsCached => _doesAnyPathExist(k_DIR_LYRICS, 'txt');
  bool get hasColorCached => _doesAnyPathExist(k_DIR_PALETTES, 'palette');
  bool get hasVideoCached {
    for (int i = 0; i < length; i++) {
      final tr = this[i];
      if (VideoController.inst.doesVideoExistsInCache(tr.track.youtubeID)) {
        return true;
      }
    }
    return false;
  }

  bool get hasAnythingCached => hasWaveformCached || hasArtworkCached || hasLyricsCached /* || hasColorCached */;

  bool _doesAnyPathExist(String directory, String extension) {
    for (int i = 0; i < length; i++) {
      final track = this[i];
      if (File("$directory${track.track.filename}.$extension").existsSync()) {
        return true;
      }
    }
    return false;
  }
}
