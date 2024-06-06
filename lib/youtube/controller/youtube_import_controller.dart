import 'dart:async';
import 'dart:io';

import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/video.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
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
    res.loopAdv((playlist, index) {
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
    res.loop((e) {
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
      lines.loop((e) {
        try {
          final parts = e.split(','); // id, dateAdded
          if (parts.length >= 2) videos.add((id: parts[0], dateAdded: DateTime.tryParse(parts[1]))); // should be only 2, but maybe more stuff will be appended in future
        } catch (_) {}
      });
      return videos;
    }

    _YTPlaylistDetails getPlaylistDetailsOld(List<String> header, List<String> split) {
      final map = <String, String>{};
      header.loopAdv((part, index) => map[part.toLowerCase()] ??= split[index]);

      return (
        playlistID: map['playlist id'] ?? '',
        channelID: map['channel id'] ?? '',
        timeCreated: DateTime.tryParse(map['time created'] ?? ''),
        timeUpdated: DateTime.tryParse(map['time updated'] ?? ''),
        name: map['title'] ?? '',
        description: map['description'] ?? '',
        visibility: _YTPlaylistVisibility.values.getEnumLoose(map['visibility']) ?? _YTPlaylistVisibility.unknown,
      );
    }

    _YTPlaylistDetails getPlaylistDetailsNew(List<String> header, List<String> split) {
      final map = <String, String>{};
      header.loopAdv((part, index) => map[part.toLowerCase().split('playlist').last.split('(').first] ??= split[index]);
      return (
        playlistID: map['playlist id'] ?? '',
        channelID: map['channel id'] ?? '',
        timeCreated: DateTime.tryParse(map['create timestamp'] ?? ''),
        timeUpdated: DateTime.tryParse(map['update timestamp'] ?? ''),
        name: map['title'] ?? '',
        description: map['description'] ?? '',
        visibility: _YTPlaylistVisibility.values.getEnumLoose(map['visibility']) ?? _YTPlaylistVisibility.unknown,
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
        final header = plLines.removeAt(0);
        final headerParts = header.split(',');
        plLines.loop((line) {
          final splitted = line.split(',');
          final details = getPlaylistDetailsNew(headerParts, splitted);
          playlistsMetadata[details.name] = details;
        });
      } catch (_) {}
    }

    files.loop((e) {
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
              final header = lines.removeAt(0);
              final headerParts = header.split(',');
              final pld = getPlaylistDetailsOld(headerParts, lines[0].split(','));
              final videosStartIndex = lines.indexWhere((element) => element.toLowerCase().startsWith('video id,time added'));
              lines.removeRange(0, videosStartIndex + 1);
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
      final header = lines.removeAt(0);
      final list = <({String id, String title})>[];
      if (header.split(',').length < 3) return list;
      lines.loop((e) {
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
