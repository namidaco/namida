import 'dart:io';
import 'dart:isolate';

import 'package:namida/class/file_parts.dart';
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

  Future<void> deleteTracksFromStoragePermanently(List<Selectable> tracksToDelete) async {
    if (!await requestManageStoragePermission()) return;
    final files = tracksToDelete.map((e) => e.track.path).toList();
    await Isolate.run(() => _deleteAllIsolate(files));
    await Indexer.inst.onDeleteTracksFromStoragePermanently(tracksToDelete);
  }

  Future<void> deleteCachedVideos(List<Selectable> tracks) async {
    for (final e in tracks) {
      var ytid = e.track.youtubeID;
      await VideoController.inst.deleteAllVideosForVideoId(ytid);
    }
  }

  Future<void> deleteCachedAudios(List<Selectable> tracks) async {
    return tracks.loopAsync((e) async {
      var ytid = e.track.youtubeID;
      final audios = Player.inst.audioCacheMap[ytid];
      await audios?.loopAsync((item) => item.file.delete());
      Player.inst.audioCacheMap.remove(ytid);
    });
  }

  Future<void> deleteTXTLyrics(List<Selectable> tracks) async {
    await _deleteAll(AppDirs.LYRICS, 'txt', tracks);
  }

  Future<void> deleteLRCLyrics(List<Selectable> tracks) async {
    await _deleteAll(AppDirs.LYRICS, 'lrc', tracks);
  }

  Future<void> deleteArtwork(List<Selectable> tracks) async {
    final files = tracks.map((e) => e.track.pathToImage).toList();
    final details = await Isolate.run(() => _deleteAllWithDetailsIsolate(files));
    Indexer.inst.updateImageSizesInStorage(removedCount: details.deletedCount, removedSize: details.sizeOfDeleted);
    await deleteExtractedColor(tracks);
  }

  Future<void> deleteExtractedColor(List<Selectable> tracks) async {
    await _deleteAll(AppDirs.PALETTES, 'palette', tracks);
  }

  Future<void> _deleteAll(String dir, String extension, List<Selectable> tracks) async {
    final files = tracks.map((e) => FileParts.joinPath(dir, "${e.track.filename}.$extension")).toList();
    await Isolate.run(() => _deleteAllIsolate(files));
  }

  /// returns failed deletes.
  static int _deleteAllIsolate(List<String> files) {
    int failed = 0;
    files.loop((e) {
      try {
        File(e).deleteSync();
      } catch (_) {
        failed++;
      }
    });
    return failed;
  }

  /// returns size & count of deleted file.
  static ({int deletedCount, int sizeOfDeleted}) _deleteAllWithDetailsIsolate(List<String> files) {
    int deleted = 0;
    int size = 0;
    files.loop((e) {
      final file = File(e);
      int s = 0;
      try {
        s = file.lengthSync();
      } catch (_) {}
      try {
        file.deleteSync();
        deleted++;
        size += s;
      } catch (_) {}
    });
    return (deletedCount: deleted, sizeOfDeleted: size);
  }

  /// returns save directory path if saved successfully
  Future<String?> saveArtworkToStorage(Track track) async {
    if (!await requestManageStoragePermission()) {
      return null;
    }
    final saveDir = await Directory(AppDirs.SAVED_ARTWORKS).create(recursive: true);
    final saveDirPath = saveDir.path;
    final info = await NamidaTaggerController.inst.extractMetadata(
      trackPath: track.path,
      cacheDirectoryPath: saveDirPath,
      isVideo: track is Video,
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
    final newPath = FileParts.joinPath(saveDirPath, "${imageFile.path.getFilenameWOExt}.png");
    try {
      await imageFile.copy(newPath);
      return saveDirPath;
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }

  Future<void> updateTrackPathInEveryPartOfNamidaBulk<T extends Track>(Map<String, String> oldNewPath) async {
    final newtrlist = await Indexer.inst.convertPathsToTracksAndAddToLists(oldNewPath.values);
    if (newtrlist.isEmpty) return;
    final oldNewTrack = <T, T>{};
    for (final on in oldNewPath.entries) {
      final oldTr = Track.orVideo(on.key);
      final newTr = Track.orVideo(on.value);
      oldNewTrack[oldTr as T] = newTr as T;
    }

    // -- Player Queue
    Player.inst.replaceAllTracksInQueueBulk(oldNewTrack); // no need to await

    // -- History
    final daysToSave = <int>[];
    final allHistory = HistoryController.inst.historyMap.value.entries.toList();

    for (final oldNewTrack in oldNewTrack.entries) {
      allHistory.loop((entry) {
        final day = entry.key;
        final trs = entry.value;
        trs.replaceWhere(
          (e) => e.track == oldNewTrack.key,
          (old) => TrackWithDate(
            dateAdded: old.dateAdded,
            track: oldNewTrack.value,
            source: old.source,
          ),
          onMatch: () => daysToSave.add(day),
        );
      });
    }
    HistoryController.inst.historyMap.refresh();
    await Future.wait([
      HistoryController.inst.saveHistoryToStorage(daysToSave).then((value) => HistoryController.inst.updateMostPlayedPlaylist()),
      QueueController.inst.replaceTrackInAllQueues(oldNewTrack), // -- Queues
      PlaylistController.inst.replaceTrackInAllPlaylistsBulk(oldNewTrack), // -- Playlists
    ]);
    // -- Selected Tracks
    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
      for (final oldNewTrack in oldNewTrack.entries) {
        SelectedTracksController.inst.replaceThisTrack(oldNewTrack.key, oldNewTrack.value);
      }
    }
  }

  Future<void> updateTrackPathInEveryPartOfNamida(Track oldTrack, String newPath) async {
    final newtrlist = await Indexer.inst.convertPathsToTracksAndAddToLists([newPath]);
    if (newtrlist.isEmpty) return;
    final newTrack = newtrlist.first;
    await Future.wait([
      QueueController.inst.replaceTrackInAllQueues({oldTrack: newTrack}), // Queues
      Player.inst.replaceAllTracksInQueueBulk({oldTrack: newTrack}), // Player Queue
      PlaylistController.inst.replaceTrackInAllPlaylists(oldTrack, newTrack), // Playlists & Favourites
      HistoryController.inst.replaceAllTracksInsideHistory(oldTrack, newTrack), // History
    ]);
    // --- Selected Tracks ---
    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
      SelectedTracksController.inst.replaceThisTrack(oldTrack, newTrack);
    }
  }

  Future<void> updateDirectoryInEveryPartOfNamida(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    if (!settings.directoriesToScan.value.any((dirPath) => newDir.startsWith(dirPath))) settings.save(directoriesToScan: [newDir]);
    final pathSeparator = Platform.pathSeparator;
    if (!oldDir.endsWith(pathSeparator)) oldDir += pathSeparator;
    if (!newDir.endsWith(pathSeparator)) newDir += pathSeparator;
    await Future.wait([
      PlaylistController.inst.replaceTracksDirectory(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      QueueController.inst.replaceTracksDirectoryInQueues(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      Player.inst.replaceTracksDirectoryInQueue(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      HistoryController.inst.replaceTracksDirectoryInHistory(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
    ]);
    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
      SelectedTracksController.inst.replaceTrackDirectory(oldDir, newDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists);
    }
  }
}

extension HasCachedFiles on List<Selectable> {
  // we use [pathToImage] to ensure when [settings.groupArtworksByAlbum] is enabled
  Future<bool> get hasArtworkCached => _doesAnyPathExist(AppDirs.ARTWORKS, 'png', fullPath: (tr) => tr.track.pathToImage);

  Future<bool> get hasTXTLyricsCached => _doesAnyPathExist(AppDirs.LYRICS, 'txt');
  Future<bool> get hasLRCLyricsCached => _doesAnyPathExist(AppDirs.LYRICS, 'lrc');
  Future<bool> get hasColorCached => _doesAnyPathExist(AppDirs.PALETTES, 'palette');
  bool get hasVideoCached {
    for (int i = 0; i < length; i++) {
      final tr = this[i];
      if (VideoController.inst.doesVideoExistsInCache(tr.track.youtubeID)) {
        return true;
      }
    }
    return false;
  }

  bool get hasAudioCached {
    for (int i = 0; i < length; i++) {
      final tr = this[i];
      var vidId = tr.track.youtubeID;
      if (vidId.isNotEmpty) {
        final cachedAudios = Player.inst.audioCacheMap[vidId];
        if (cachedAudios != null) return true;
      }
    }
    return false;
  }

  Future<bool> get hasAnythingCached async => await hasArtworkCached || await hasTXTLyricsCached || await hasLRCLyricsCached /* || await hasColorCached */;

  Future<bool> _doesAnyPathExist(String directory, String extension, {String Function(Selectable tr)? fullPath}) async {
    for (int i = 0; i < length; i++) {
      final track = this[i];
      if (await File(fullPath != null ? fullPath(track) : "$directory${track.track.filename}.$extension").exists()) {
        return true;
      }
    }
    return false;
  }
}
