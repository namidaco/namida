import 'dart:io';

import 'package:namida/class/track.dart';
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
    final idsToDelete = tracks.map((e) => e.youtubeID);
    await for (final v in Directory(k_DIR_VIDEOS_CACHE).list()) {
      for (final id in idsToDelete) {
        if (v.path.getFilename.startsWith(id)) {
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

  /// returns true if saved successfully
  Future<bool> saveArtworkToStorage(Track track) async {
    if (!await requestManageStoragePermission()) {
      return false;
    }
    final newPath = "${SettingsController.inst.defaultBackupLocation.value}${Platform.pathSeparator}${track.filenameWOExt}.png";
    final imgFile = File(track.pathToImage);
    try {
      await imgFile.copy(newPath);
      return true;
    } catch (e) {
      imgFile.tryDeleting();

      try {
        final img = await Indexer.inst.extractOneArtwork(track.path);
        if (img != null) {
          final newImgFile = await File(newPath).create();
          await newImgFile.writeAsBytes(img);
          return true;
        }
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future<void> updateTrackPathInEveryPartOfNamida(Track oldTrack, String newPath) async {
    final newtr = await Indexer.inst.convertPathToTrack(newPath);
    if (newtr == null) return;
    // void loopPlaylists(List<Playlist> playlists) {
    //   for (final pl in playlists) {
    //     for (final tr in pl.tracks) {
    //       if (tr.track.path == oldTrack.path) {
    //         final index = pl.tracks.indexOf(tr);
    //         PlaylistController.inst.removeTrackFromPlaylist(pl.name, index);
    //         PlaylistController.inst.insertTracksInPlaylist(pl.name, [TrackWithDate(tr.dateAdded, newtr, tr.source)], index);
    //       }
    //     }
    //   }
    // }

    void loopQueues() {
      for (final queue in QueueController.inst.queueList.toList()) {
        for (final tr in queue.tracks) {
          if (tr.path == oldTrack.path) {
            final index = queue.tracks.indexOf(tr);
            QueueController.inst.removeTrackFromQueue(queue, index);
            QueueController.inst.insertTracksQueue(queue, [newtr], index);
          }
        }
      }
    }

    void loopPlayerQueue() async {
      for (final tr in Player.inst.currentQueue.toList()) {
        if (tr.path == oldTrack.path) {
          final index = Player.inst.currentQueue.toList().indexOf(tr);
          await Player.inst.removeFromQueue(index);
          Player.inst.insertInQueue([newtr], index);
        }
      }
    }

    // all playlists
    for (final pl in PlaylistController.inst.playlistList.toList()) {
      for (final tr in pl.tracks) {
        if (tr.track.path == oldTrack.path) {
          final index = pl.tracks.indexOf(tr);
          PlaylistController.inst.removeTrackFromPlaylist(pl, index);
          PlaylistController.inst.insertTracksInPlaylist(pl, [TrackWithDate(tr.dateAdded, newtr, tr.source)], index);
        }
      }
    }

    // default playlist
    final historyTracks = namidaHistoryPlaylist.tracks;
    for (final tr in historyTracks) {
      if (tr.track.path == oldTrack.path) {
        final index = historyTracks.indexOf(tr);
        PlaylistController.inst.removeFromHistory(index);
        PlaylistController.inst.addTrackToHistory([TrackWithDate(tr.dateAdded, newtr, tr.source)]);
      }
    }
    final favTracks = namidaFavouritePlaylist.tracks;
    for (final tr in favTracks) {
      if (tr.track.path == oldTrack.path) {
        PlaylistController.inst.favouriteButtonOnPressed(tr.track, updatedTrack: newtr);
      }
    }
    PlaylistController.inst.updateMostPlayedPlaylist();

    // Queues
    loopQueues();

    // player queue
    loopPlayerQueue();

    // Selected Tracks
    for (final tr in SelectedTracksController.inst.selectedTracks.toList()) {
      if (tr.path == oldTrack.path) {
        final index = SelectedTracksController.inst.selectedTracks.toList().indexOf(tr);
        SelectedTracksController.inst.selectedTracks.removeAt(index);
        SelectedTracksController.inst.selectedTracks.insertSafe(index, tr);
      }
    }
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
