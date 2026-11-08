import 'dart:io';
import 'dart:isolate';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/platform/tags_extractor/tags_extractor.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/main.dart';

class EditDeleteController {
  static EditDeleteController get inst => _instance;
  static final EditDeleteController _instance = EditDeleteController._internal();
  EditDeleteController._internal();

  Future<void> deleteTracksFromStoragePermanently(List<Selectable> tracksToDelete) async {
    if (!await requestManageStoragePermission()) return;
    final files = tracksToDelete.map((e) => e.track).mapPhysicalOrError((tr) => tr.path);
    if (files.isEmpty) return;
    await Isolate.run(() => _deleteAllIsolate(files));
    await Indexer.inst.removeTracksFromLibrary(tracksToDelete, isFromDelete: true);
    final deleteLyricsIn = settings.lyricsDeleteWithTrackIn.value;
    if (deleteLyricsIn.isNotEmpty) {
      final libraryPaths = Indexer.inst.allTracksMappedByPath.keys.toFixedList();
      await LrcSearchUtilsSelectable.deleteLyricsOfDeletedTracks(files, libraryPaths, deleteLyricsIn);
    }
  }

  /// returns failed deletes.
  static int _deleteAllIsolate(List<String> files) {
    int failed = 0;
    for (var e in files) {
      try {
        File(e).deleteSync();
      } catch (_) {
        failed++;
      }
    }
    return failed;
  }

  /// returns save file if saved successfully
  Future<String?> saveTrackArtworkToStorage(Track track) async {
    final saveDirPath = AppDirs.SAVED_ARTWORKS;
    if (!await requestManageStoragePermission(directoryToCreate: saveDirPath)) {
      return null;
    }
    final info = await Indexer.inst.getArtwork(
      compressed: false,
      imagePath: track.pathToImage,
      track: track,
    );
    final fileToCopy = info.file;
    final bytesToCopy = info.bytes;
    if (fileToCopy != null || bytesToCopy != null) {
      final trExt = track.toTrackExtOrNull();
      final filename = TagsExtractor.buildImageFilenameFromTrack(
        track: track,
        trExt: trExt,
        parentDirPath: saveDirPath,
      );
      final newImgFilePath = FileParts.joinPath(saveDirPath, filename);
      if (fileToCopy != null) {
        await fileToCopy.copy(newImgFilePath);
        NamidaChannel.inst.scanMediaFilesTry([newImgFilePath]);
        return newImgFilePath;
      } else if (bytesToCopy != null) {
        final f = File(newImgFilePath);
        await f.create(recursive: true);
        await f.writeAsBytes(bytesToCopy);
        NamidaChannel.inst.scanMediaFilesTry([newImgFilePath]);
        return newImgFilePath;
      }
    }

    return null;
  }

  /// returns save path if saved successfully
  Future<String?> saveImageToStorage(File imageFile) async {
    final saveDirPath = AppDirs.SAVED_ARTWORKS;
    if (!await requestManageStoragePermission(directoryToCreate: saveDirPath)) {
      return null;
    }
    final newPath = FileParts.joinPath(saveDirPath, "${imageFile.path.getFilenameWOExt}.png");
    try {
      await imageFile.copy(newPath);
      NamidaChannel.inst.scanMediaFilesTry([newPath]);
      return newPath;
    } catch (e) {
      printy(e, isError: true);
      return null;
    }
  }

  Future<void> updateTrackPathInEveryPartOfNamidaBulk<T extends Track>(Map<String, String> oldNewPathPre, {bool removeOldTracksFromLibrary = false}) async {
    // -- paths should still be remapped even if new ones not found
    await Indexer.inst.convertPathsToTracksAndAddToLists(oldNewPathPre.values);
    final oldNewTrack = <T, T>{};
    for (final on in oldNewPathPre.entries) {
      final oldTr = Track.orVideo(on.key);
      final newTr = Track.orVideo(on.value);
      if (on.key == on.value) continue; // same path why update
      oldNewTrack[oldTr as T] = newTr as T;
    }

    await Future.wait([
      HistoryController.inst.replaceTheseTracksInHistoryBulk(oldNewTrack),
      PlaylistController.inst.replaceTrackInAllPlaylistsBulk(oldNewTrack),
      Indexer.inst.moveStatsPath(oldNewTrack),
      Player.audioConfigs.movePaths(oldNewTrack),
      QueueController.inst.replaceTrackInAllQueues(oldNewTrack),
      Player.inst.replaceAllTracksInQueueBulk(oldNewTrack),
      QueueController.latestPlayedForSourceManager.movePaths(oldNewTrack),
    ]);

    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
      for (final oldNewTrack in oldNewTrack.entries) {
        SelectedTracksController.inst.replaceThisTrack(oldNewTrack.key, oldNewTrack.value);
      }
    }

    if (removeOldTracksFromLibrary) {
      await Indexer.inst.removeTracksFromLibrary(oldNewTrack.keys, isFromDelete: false);
    }
  }

  Future<void> updateTrackPathInEveryPartOfNamida(Track oldTrack, String newPath) async {
    final newtrlist = await Indexer.inst.convertPathsToTracksAndAddToLists([newPath]);
    if (newtrlist.isEmpty) return;
    final newTrack = newtrlist.first;
    final oldNewMap = {oldTrack: newTrack};

    await Future.wait([
      HistoryController.inst.replaceAllTracksInsideHistory(oldTrack, newTrack),
      PlaylistController.inst.replaceTrackInAllPlaylists(oldTrack, newTrack),
      Indexer.inst.moveStatsPath(oldNewMap),
      Player.audioConfigs.movePaths(oldNewMap),
      QueueController.inst.replaceTrackInAllQueues(oldNewMap),
      Player.inst.replaceAllTracksInQueueBulk(oldNewMap),
      QueueController.latestPlayedForSourceManager.movePaths(oldNewMap),
    ]);

    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
      SelectedTracksController.inst.replaceThisTrack(oldTrack, newTrack);
    }
  }

  Future<void> updateDirectoryInEveryPartOfNamida(
    String oldDirPre,
    String newDirPre,
    DirectoryIndexType? newDirType, {
    Iterable<String>? forThesePathsOnly,
    bool ensureNewFileExists = false,
  }) async {
    if (!settings.directoriesToScan.value.any((dir) => newDirPre.startsWith(dir.sourceRaw))) settings.directoriesToScan.update((list) => list.addNoDuplicates(DirectoryIndex.guess(newDirPre, newDirType)));

    var normalizedOldDir = replaceFunctionNormalizePath(oldDirPre);
    var normalizedNewDir = replaceFunctionNormalizePath(newDirPre);
    if (!normalizedOldDir.endsWith('/')) normalizedOldDir += '/';
    if (!normalizedNewDir.endsWith('/')) normalizedNewDir += '/';

    await Future.wait([
      HistoryController.inst.replaceTracksDirectoryInHistory(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      PlaylistController.inst.replaceTracksDirectory(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      Indexer.inst.moveStatsDirectory(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      Player.audioConfigs.moveDirectory(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      QueueController.inst.replaceTracksDirectoryInQueues(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
      Player.inst.replaceTracksDirectoryInQueue(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists),
    ]);

    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
      SelectedTracksController.inst.replaceTrackDirectory(normalizedOldDir, normalizedNewDir, forThesePathsOnly: forThesePathsOnly, ensureNewFileExists: ensureNewFileExists);
    }
  }
}
