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
import 'package:namida/controller/tagger_controller.dart';
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
  }

  Future<void> deleteLyrics(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      await File("${AppDirs.LYRICS}${track.track.filename}.txt").deleteIfExists();
    });
  }

  Future<void> deleteArtwork(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      final file = File(track.track.pathToImage);
      await Indexer.inst.updateImageSizeInStorage(oldDeletedFile: file);
      await file.deleteIfExists();
    });

    await deleteExtractedColor(tracks);
  }

  Future<void> deleteExtractedColor(List<Selectable> tracks) async {
    await tracks.loopFuture((track, index) async {
      await File("${AppDirs.PALETTES}${track.track.filename}.palette").deleteIfExists();
    });
  }

  /// returns save directory path if saved successfully
  Future<String?> saveArtworkToStorage(Track track) async {
    if (!await requestManageStoragePermission()) {
      return null;
    }
    final saveDir = await Directory(AppDirs.SAVED_ARTWORKS).create(recursive: true);
    final saveDirPath = saveDir.path;
    final info = await FAudioTaggerController.inst.extractMetadata(
      trackPath: track.path,
      cacheDirectoryPath: saveDirPath,
    );
    final imgFile = info.tags.artwork.file;
    if (imgFile != null) return saveDirPath;
    return null;
  }

  /// returns save directory path if saved successfully
  Future<String?> saveImageToStorage(File imageFile) async {
    if (!await requestManageStoragePermission()) {
      return null;
    }
    final saveDir = await Directory(AppDirs.SAVED_ARTWORKS).create(recursive: true);
    final saveDirPath = saveDir.path;
    final newPath = "$saveDirPath${Platform.pathSeparator}${imageFile.path.getFilenameWOExt}.png";
    try {
      await imageFile.copy(newPath);
      return saveDirPath;
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }

  Future<void> updateTrackPathInEveryPartOfNamida(Track oldTrack, String newPath) async {
    final newtrlist = await Indexer.inst.convertPathToTrack([newPath]);
    if (newtrlist.isEmpty) return;
    final newTrack = newtrlist.first;
    await Future.wait([
      // --- Queues ---
      QueueController.inst.replaceTrackInAllQueues(oldTrack, newTrack),

      // --- Player Queue ---
      Player.inst.replaceAllTracksInQueue(oldTrack, newTrack),

      // --- Playlists & Favourites---
      PlaylistController.inst.replaceTrackInAllPlaylists(oldTrack, newTrack),

      // --- History---
      HistoryController.inst.replaceAllTracksInsideHistory(oldTrack, newTrack),
    ]);
    // --- Selected Tracks ---
    SelectedTracksController.inst.replaceThisTrack(oldTrack, newTrack);
  }

  Future<void> updateDirectoryInEveryPartOfNamida(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    settings.save(directoriesToScan: [newDir]);
    await Future.wait([
      PlaylistController.inst.replaceTracksDirectory(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      QueueController.inst.replaceTracksDirectoryInQueues(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      Player.inst.replaceTracksDirectoryInQueue(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      HistoryController.inst.replaceTracksDirectoryInHistory(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
    ]);
    SelectedTracksController.inst.replaceTrackDirectory(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists);
  }
}

extension HasCachedFiles on List<Selectable> {
  // we use [pathToImage] to ensure when [settings.groupArtworksByAlbum] is enabled
  bool get hasArtworkCached => _doesAnyPathExist(AppDirs.ARTWORKS, 'png', fullPath: (tr) => tr.track.pathToImage);

  bool get hasLyricsCached => _doesAnyPathExist(AppDirs.LYRICS, 'txt');
  bool get hasColorCached => _doesAnyPathExist(AppDirs.PALETTES, 'palette');
  bool get hasVideoCached {
    for (int i = 0; i < length; i++) {
      final tr = this[i];
      if (VideoController.inst.doesVideoExistsInCache(tr.track.youtubeID)) {
        return true;
      }
    }
    return false;
  }

  bool get hasAnythingCached => hasArtworkCached || hasLyricsCached /* || hasColorCached */;

  bool _doesAnyPathExist(String directory, String extension, {String Function(Selectable tr)? fullPath}) {
    for (int i = 0; i < length; i++) {
      final track = this[i];
      if (File(fullPath != null ? fullPath(track) : "$directory${track.track.filename}.$extension").existsSync()) {
        return true;
      }
    }
    return false;
  }
}
