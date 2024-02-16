import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/video.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

enum _YTPlaylistVisibility { public, unlisted, private, unknown }

typedef _YTPlaylistEntry = ({String name, _YTPlaylistDetails? details});

typedef _YTPlaylistDetails = ({
  String playlistID,
  String channelID,
  DateTime? timeCreated,
  DateTime? timeUpdated,
  String name,
  String description,
  _YTPlaylistVisibility visibility,
});

typedef _VideoEntry = ({String id, DateTime? dateAdded});

class YoutubeImportController {
  static final YoutubeImportController inst = YoutubeImportController._internal();
  YoutubeImportController._internal();

  final isImportingPlaylists = false.obs;
  final isImportingSubscriptions = false.obs;

  Future<int> importPlaylists(String playlistsDirectoryPath) async {
    isImportingPlaylists.value = true;
    final res = await _parsePlaylistsFiles.thready(playlistsDirectoryPath);
    if (res.isEmpty) {
      isImportingPlaylists.value = false;
      return 0;
    }

    final completer = Completer<void>();
    res.loop((playlist, index) {
      final details = playlist.$1.details;
      final plID = details != null ? PlaylistID(id: details.playlistID) : null;
      YoutubePlaylistController.inst.addNewPlaylistRaw(
        playlist.$1.name,
        creationDate: details?.timeCreated?.millisecondsSinceEpoch,
        modifiedDate: details?.timeUpdated?.millisecondsSinceEpoch,
        playlistID: plID,
        comment: details?.description ?? '',
        tracks: (playlistID) {
          return playlist.$2
              .map(
                (e) => YoutubeID(
                  id: e.id,
                  watchNull: YTWatch(
                    dateNull: e.dateAdded,
                    isYTMusic: false,
                  ),
                  playlistID: playlistID,
                ),
              )
              .toList();
        },
      ).then((value) {
        if (index == res.length - 1) completer.complete();
      });
    });
    await completer.future;
    isImportingPlaylists.value = false;
    return res.length;
  }

  Future<int> importSubscriptions(String subscriptionsFilePath) async {
    isImportingSubscriptions.value = true;
    final res = await _parseSubscriptions.thready(subscriptionsFilePath);
    res.loop((e, index) {
      final valInMap = YoutubeSubscriptionsController.inst.getChannel(e.id);
      YoutubeSubscriptionsController.inst.setChannel(
        e.id,
        YoutubeSubscription(
          title: valInMap != null && valInMap.title == '' ? e.title : valInMap?.title ?? e.title,
          channelID: e.id,
          subscribed: true,
          lastFetched: valInMap?.lastFetched,
        ),
      );
    });
    YoutubeSubscriptionsController.inst.sortByLastFetched();
    await YoutubeSubscriptionsController.inst.saveFile();
    isImportingSubscriptions.value = false;
    return res.length;
  }

  /// there are 2 types of takeouts for playlists as encountered:
  /// - old takeouts: playlist file that contains playlist metadata as header, and the second part is the actual videos
  /// - new takeouts: playlist file that contains the actual videos only. metadata is inside a separate `playlists.csv` file
  ///
  /// both are being handled severally, some playlist data is present in old but not in new, and vice versa.
  /// new behaviour was introduced somewhere between `08/6/2023` & `04/12/2023`
  static List<(_YTPlaylistEntry, List<_VideoEntry>)> _parsePlaylistsFiles(String dirPath) {
    final dir = Directory(dirPath);
    final files = dir.listSyncSafe();
    final playlists = <(_YTPlaylistEntry, List<_VideoEntry>)>[];

    List<_VideoEntry> getVideos(List<String> lines) {
      final videos = <_VideoEntry>[];
      lines.loop((e, _) {
        try {
          final parts = e.split(','); // id, dateAdded
          if (parts.length >= 2) videos.add((id: parts[0], dateAdded: DateTime.tryParse(parts[1]))); // should be only 2, but maybe more stuff will be appended in future
        } catch (_) {}
      });
      return videos;
    }

    /// Must be of length 7 or more.
    _YTPlaylistDetails getPlaylistDetailsOld(List<String> split) {
      return (
        playlistID: split[0],
        channelID: split[1],
        timeCreated: DateTime.tryParse(split[2]),
        timeUpdated: DateTime.tryParse(split[3]),
        name: split[4],
        description: split[5],
        visibility: _YTPlaylistVisibility.values.getEnumLoose(split[6]) ?? _YTPlaylistVisibility.unknown,
      );
    }

    /// Must be of length 25 or more.
    _YTPlaylistDetails getPlaylistDetailsNew(List<String> split) {
      return (
        playlistID: split[0],
        channelID: '',
        description: split[2],
        name: split[19],
        timeCreated: DateTime.tryParse(split[21]),
        timeUpdated: DateTime.tryParse(split[22]),
        visibility: _YTPlaylistVisibility.values.getEnumLoose(split[24]) ?? _YTPlaylistVisibility.unknown,
      );
    }

    final playlistsMetadata = <String, _YTPlaylistDetails>{};

    // final plMetaFile = File("$dirPath/playlists.csv");
    final plMetaFileIndex = files.indexWhere((element) => element.path.endsWith('/playlists.csv'));
    final plMetaFile = plMetaFileIndex == -1 ? null : files[plMetaFileIndex];

    if (plMetaFile != null && plMetaFile is File) {
      files.removeAt(plMetaFileIndex);
      try {
        final plLines = plMetaFile.readAsLinesSync();
        plLines.removeAt(0);
        plLines.loop((line, _) {
          final splitted = line.split(',');
          if (splitted.length >= 25) {
            final details = getPlaylistDetailsNew(splitted);
            playlistsMetadata[details.name] = details;
          }
        });
      } catch (_) {}
    }

    files.loop((e, _) {
      if (e is File) {
        try {
          String playlistName = e.path.getFilenameWOExt;
          const extra = '-videos';
          if (playlistName.endsWith(extra)) playlistName = playlistName.substring(0, playlistName.length - extra.length);
          final lines = e.readAsLinesSync();
          if (lines.isNotEmpty) {
            final header = lines[0];
            final splitted = header.split(',');
            if (header.startsWith('Playlist Id') && splitted.length >= 7) {
              // -- old method
              final pld = getPlaylistDetailsOld(lines[1].split(','));
              lines.removeRange(0, 8);
              playlists.add(((name: playlistName, details: pld), getVideos(lines)));
            } else {
              // -- new method, doesnt contain playlist header.
              lines.removeAt(0);
              playlists.add(((name: playlistName, details: playlistsMetadata[playlistName]), getVideos(lines)));
            }
          }
        } catch (_) {}
      }
    });
    return playlists;
  }

  static List<({String id, String title})> _parseSubscriptions(String filePath) {
    final file = File(filePath);
    try {
      final lines = file.readAsLinesSync();
      lines.removeAt(0);
      final list = <({String id, String title})>[];
      lines.loop((e, _) {
        try {
          final parts = e.split(','); // id, url, name
          if (parts.length >= 3) list.add((id: parts[0], title: parts[2])); // should be only 3, but maybe more stuff will be appended in future
        } catch (_) {}
      });
      return list;
    } catch (e) {
      return [];
    }
  }
}
