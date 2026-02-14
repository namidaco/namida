import 'dart:async';
import 'dart:io';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/video.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';

enum _YTPlaylistVisibility { public, unlisted, private, unknown }

class _YTPlaylistEntry {
  final String name;
  final _YTPlaylistDetails? details;

  const _YTPlaylistEntry({
    required this.name,
    required this.details,
  });
}

class _YTPlaylistDetails {
  final String playlistID;
  final String channelID;
  final DateTime? timeCreated;
  final DateTime? timeUpdated;
  final String name;
  final String description;
  final _YTPlaylistVisibility visibility;

  const _YTPlaylistDetails({
    required this.playlistID,
    required this.channelID,
    required this.timeCreated,
    required this.timeUpdated,
    required this.name,
    required this.description,
    required this.visibility,
  });

  static _YTPlaylistDetails merge(_YTPlaylistDetails current, _YTPlaylistDetails other) {
    final _YTPlaylistDetails latestUpdatedPlaylist;
    final _YTPlaylistDetails otherPlaylist;

    if (current.timeUpdated != null && other.timeUpdated != null) {
      if (current.timeUpdated!.isAfter(other.timeUpdated!)) {
        latestUpdatedPlaylist = current;
        otherPlaylist = other;
      } else {
        latestUpdatedPlaylist = other;
        otherPlaylist = current;
      }
    } else if (current.timeUpdated != null) {
      latestUpdatedPlaylist = current;
      otherPlaylist = other;
    } else {
      latestUpdatedPlaylist = other;
      otherPlaylist = current;
    }

    return _YTPlaylistDetails(
      playlistID: latestUpdatedPlaylist.playlistID.isNotEmpty ? latestUpdatedPlaylist.playlistID : otherPlaylist.playlistID,
      channelID: latestUpdatedPlaylist.channelID.isNotEmpty ? latestUpdatedPlaylist.channelID : otherPlaylist.channelID,
      timeCreated: latestUpdatedPlaylist.timeCreated ?? otherPlaylist.timeCreated,
      timeUpdated: latestUpdatedPlaylist.timeUpdated ?? otherPlaylist.timeUpdated,
      name: latestUpdatedPlaylist.name.isNotEmpty ? latestUpdatedPlaylist.name : otherPlaylist.name,
      description: latestUpdatedPlaylist.description.isNotEmpty ? latestUpdatedPlaylist.description : otherPlaylist.description,
      visibility: latestUpdatedPlaylist.visibility != _YTPlaylistVisibility.unknown ? latestUpdatedPlaylist.visibility : otherPlaylist.visibility,
    );
  }
}

class _VideoEntry {
  final String id;
  final DateTime? dateAdded;

  _VideoEntry({
    required String id,
    required this.dateAdded,
  }) : this.id = id.replaceFirst(' ', '');
}

class YoutubePlaylistImportDetails {
  int get mergedCount => totalCount - countAfterMerging;

  final int totalCount;
  final int countAfterMerging;
  final List<String> playlistsNames;
  final List<(_YTPlaylistEntry, List<_VideoEntry>)> _data;

  const YoutubePlaylistImportDetails._(
    this._data, {
    required this.totalCount,
    required this.countAfterMerging,
    required this.playlistsNames,
  });
}

class YoutubeImportController {
  static final YoutubeImportController inst = YoutubeImportController._internal();
  YoutubeImportController._internal();

  final isImportingPlaylists = false.obs;
  final isImportingSubscriptions = false.obs;

  Future<YoutubePlaylistImportDetails?> importPlaylists(String directoryPath) async {
    isImportingPlaylists.value = true;
    final resDetails = await _scanAllPlaylistTakeoutDirectoriesCompute.thready(directoryPath);
    final res = resDetails._data;
    if (res.isEmpty) {
      isImportingPlaylists.value = false;
      return resDetails;
    }

    final actionIfPlaylistsExist = await NamidaOnTaps.inst.showDuplicatedDialogAction(
      PlaylistAddDuplicateAction.values,
      displayTitle: false,
      initiallySelected: PlaylistAddDuplicateAction.mergeAndSortByAddedDate,
    );
    if (actionIfPlaylistsExist == null) {
      isImportingPlaylists.value = false;
      return null;
    }

    final completer = Completer<void>();
    res.loopAdv((playlist, index) {
      final details = playlist.$1.details;
      final plID = details != null ? PlaylistID(id: details.playlistID) : null;
      final newTracks = <String>[];
      final newTracksDates = <String, int?>{};
      playlist.$2.loop((e) {
        newTracks.add(e.id);
        newTracksDates[e.id] = e.dateAdded?.millisecondsSinceEpoch;
      });
      YoutubePlaylistController.inst
          .addNewPlaylistRaw(
            playlist.$1.name,
            creationDate: details?.timeCreated?.millisecondsSinceEpoch,
            modifiedDate: details?.timeUpdated?.millisecondsSinceEpoch,
            playlistID: plID,
            comment: details?.description ?? '',
            tracks: newTracks,
            convertItem: (id, dateAddedFallback, playlistID) => YoutubeID(
              id: id,
              source: TrackSource.youtube,
              watchNull: YTWatch(
                dateMSNull: newTracksDates[id] ?? dateAddedFallback,
                isYTMusic: false,
              ),
              playlistID: playlistID,
            ),
            actionIfAlreadyExists: () => actionIfPlaylistsExist,
          )
          .then((value) {
            if (index == res.length - 1) completer.complete();
          });
    });

    await completer.future;
    YoutubePlaylistController.inst.playlistsMap.refresh();
    isImportingPlaylists.value = false;
    return resDetails;
  }

  Future<int> importSubscriptions(String subscriptionsFilePath) async {
    isImportingSubscriptions.value = true;
    final res = await _parseSubscriptions.thready(subscriptionsFilePath);
    res.loop((e) {
      final valInMap = YoutubeSubscriptionsController.inst.availableChannels.value[e.id];
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

  static DateTime? parseDate(String dateText) {
    return DateTime.tryParse(dateText) ?? DateTime.tryParse(dateText.replaceFirst(' ', 'T').replaceFirst(' Z', 'Z').replaceFirst(' UTC', 'Z')); // fixes weird date format
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
          if (parts.length >= 2) videos.add(_VideoEntry(id: parts[0], dateAdded: parseDate(parts[1]))); // should be only 2, but maybe more stuff will be appended in future
        } catch (_) {}
      });
      return videos;
    }

    _YTPlaylistDetails getPlaylistDetailsOld(List<String> header, List<String> split) {
      final map = <String, String>{};
      header.loopAdv((part, index) => map[part.toLowerCase()] ??= split[index]);

      return _YTPlaylistDetails(
        playlistID: map['playlist id'] ?? '',
        channelID: map['channel id'] ?? '',
        timeCreated: parseDate(map['time created'] ?? ''),
        timeUpdated: parseDate(map['time updated'] ?? ''),
        name: map['title'] ?? '',
        description: map['description'] ?? '',
        visibility: _YTPlaylistVisibility.values.getEnumLoose(map['visibility']) ?? _YTPlaylistVisibility.unknown,
      );
    }

    final plHeaderNormalizeRegex = RegExp('.*playlist', caseSensitive: false);
    _YTPlaylistDetails getPlaylistDetailsNew(List<String> header, List<String> split) {
      final map = <String, String>{};
      header.loopAdv((part, index) => map[part.toLowerCase().replaceFirst(plHeaderNormalizeRegex, '').splitFirst('(').trim()] ??= split[index]);
      return _YTPlaylistDetails(
        playlistID: map['id'] ?? map['playlist id'] ?? '',
        channelID: map['channel id'] ?? '',
        timeCreated: parseDate(map['create timestamp'] ?? ''),
        timeUpdated: parseDate(map['update timestamp'] ?? ''),
        name: map['title'] ?? '',
        description: map['description'] ?? '',
        visibility: _YTPlaylistVisibility.values.getEnumLoose(map['visibility']) ?? _YTPlaylistVisibility.unknown,
      );
    }

    final playlistsMetadata = <String, _YTPlaylistDetails>{};

    // final plMetaFile = File("$dirPath/playlists.csv");
    final plMetaFileIndex = files.indexWhere((element) => element.path.endsWith('${Platform.pathSeparator}playlists.csv'));
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
              final videosStartIndex = lines.indexWhere((element) => element.toLowerCase().startsWith('video id,'));
              lines.removeRange(0, videosStartIndex + 1);
              playlists.add((_YTPlaylistEntry(name: playlistName, details: pld), getVideos(lines)));
            } else {
              // -- new method, doesnt contain playlist header.
              lines.removeAt(0);
              playlists.add((_YTPlaylistEntry(name: playlistName, details: playlistsMetadata[playlistName]), getVideos(lines)));
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

  static YoutubePlaylistImportDetails _scanAllPlaylistTakeoutDirectoriesCompute(String mainDir) {
    final playlistsMap = <String, List<List<_VideoEntry>>>{};
    final playlistsDetailsMap = <String, _YTPlaylistDetails?>{};

    bool isPlaylistDirectory(String dirPath) {
      return dirPath.splitLast(Platform.pathSeparator) == 'playlists';
    }

    void onDirMatch(String plsdirPath) {
      final details = _parsePlaylistsFiles(plsdirPath);
      details.loop(
        (pl) {
          final playlistName = pl.$1.name;
          final existingDetails = playlistsDetailsMap[playlistName];
          final newDetails = pl.$1.details;
          final finalDetails = existingDetails != null && newDetails != null ? _YTPlaylistDetails.merge(newDetails, existingDetails) : newDetails ?? existingDetails;
          playlistsDetailsMap[playlistName] = finalDetails;
          playlistsMap[playlistName] ??= [];
          playlistsMap[playlistName]!.add(pl.$2);
        },
      );
    }

    if (isPlaylistDirectory(mainDir)) {
      onDirMatch(mainDir);
    } else {
      Directory(mainDir).listSync(recursive: true).loop(
        (plsdir) {
          final plsDirPath = plsdir.path;
          if (plsdir is Directory && isPlaylistDirectory(plsDirPath)) {
            onDirMatch(plsDirPath);
          }
        },
      );
    }

    final playlistsListMerged = <(_YTPlaylistEntry, List<_VideoEntry>)>[];
    for (final entries in playlistsMap.entries) {
      final mainList = <_VideoEntry>[];
      entries.value.loop(mainList.addAll);
      mainList.removeDuplicates((element) => '${element.id}${element.dateAdded}');
      mainList.sortBy((e) => e.dateAdded ?? DateTime(0));
      playlistsListMerged.add((_YTPlaylistEntry(name: entries.key, details: playlistsDetailsMap[entries.key]), mainList));
    }

    int totalCount = playlistsMap.values.fold(0, (previousValue, element) => previousValue + element.length);
    int countAfterMerging = playlistsListMerged.length;
    final playlistsNames = playlistsMap.keys.toList();

    final details = YoutubePlaylistImportDetails._(
      playlistsListMerged,
      totalCount: totalCount,
      countAfterMerging: countAfterMerging,
      playlistsNames: playlistsNames,
    );
    return details;
  }
}
