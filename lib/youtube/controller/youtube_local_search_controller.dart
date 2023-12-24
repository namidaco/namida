import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/video.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

enum YTLocalSearchSortType {
  mostPlayed,
  latestPlayed,
}

class YTLocalSearchController {
  static final YTLocalSearchController inst = YTLocalSearchController._internal();
  YTLocalSearchController._internal();

  bool enableFuzzySearch = true;

  ScrollController? scrollController;

  List<StreamInfoItem>? _lookupListStreamInfo; // 1
  List<Map>? _lookupListStreamInfoMap; // 2
  List<Map<String, dynamic>>? _lookupListVideoInfoMap; // 3
  List<YoutubeVideoHistory>? _lookupListYTVH; // 4

  final _lookupItemAvailable = <String, ({int list, int index})>{};

  String _latestSearch = '';

  YTLocalSearchSortType _sortType = YTLocalSearchSortType.mostPlayed;
  YTLocalSearchSortType get sortType => _sortType;
  set sortType(YTLocalSearchSortType t) {
    _sortType = t;
    search(_latestSearch);
  }

  final searchResults = <StreamInfoItem>[];

  List<Map> _getAllInfoFromCache(String directoryPath) {
    final list = <Map>[];
    Directory(directoryPath).listSyncSafe().loop((file, _) {
      try {
        final res = (file as File).readAsJsonSync();
        if (res != null) list.add(res);
      } catch (_) {}
    });
    return list;
  }

  Future<void> initializeLookupMap() async {
    if (_lookupListStreamInfo != null && _lookupListStreamInfoMap != null && _lookupListVideoInfoMap != null && _lookupListYTVH != null) {
      // prevent doing it again if resources werent disposed
      return;
    }
    final start = DateTime.now();

    _lookupItemAvailable.clear();

    _lookupListStreamInfo = <StreamInfoItem>[];
    _lookupListStreamInfoMap = <Map>[];
    _lookupListVideoInfoMap = <Map<String, dynamic>>[];
    _lookupListYTVH = <YoutubeVideoHistory>[];

    for (final id in YoutubeController.inst.tempVideoInfosFromStreams.keys) {
      final val = YoutubeController.inst.tempVideoInfosFromStreams[id]!;
      _lookupListStreamInfo!.add(val);
      _lookupItemAvailable[id] = (list: 1, index: _lookupListStreamInfo!.length - 1);
    }

    await Future.wait([
      _getAllInfoFromCache.thready(AppDirs.YT_METADATA_TEMP).then(
        (value) {
          value.loop((e, index) {
            final id = e['id'];
            if (id != null && _lookupItemAvailable[id] == null) {
              _lookupListStreamInfoMap!.add(e);
              _lookupItemAvailable[id] = (list: 2, index: _lookupListStreamInfoMap!.length - 1);
            }
          });
        },
      ),
      _getAllInfoFromCache.thready(AppDirs.YT_METADATA).then(
        (value) {
          value.loop((e, index) {
            final id = e['id'];
            if (id != null && _lookupItemAvailable[id] == null) {
              _lookupListVideoInfoMap!.add(e.cast());
              _lookupItemAvailable[id] = (list: 3, index: _lookupListVideoInfoMap!.length - 1);
            }
          });
        },
      ),
    ]);

    for (final id in YoutubeController.inst.tempBackupVideoInfo.keys) {
      if (_lookupItemAvailable[id] == null) {
        final val = YoutubeController.inst.tempBackupVideoInfo[id]!;
        _lookupListYTVH!.add(val);
        _lookupItemAvailable[id] = (list: 4, index: _lookupListYTVH!.length - 1);
      }
    }

    final end = DateTime.now();
    final durationTaken = start.difference(end);
    printo('Initialized 4 Lists in $durationTaken');
    printo(
        'Initialized _lookupListStreamInfo: ${_lookupListStreamInfo?.length} | _lookupListStreamInfoMap: ${_lookupListStreamInfoMap?.length} | _lookupListVideoInfoMap: ${_lookupListVideoInfoMap?.length} | _lookupListYTVH: ${_lookupListYTVH?.length}');
  }

  void search(String text, {int? maxResults}) {
    searchResults.clear();
    _latestSearch = text;
    if (scrollController?.hasClients ?? false) scrollController?.jumpTo(0);
    if (text == '') return;
    final possibleID = text.getYoutubeID;
    if (possibleID != '') {
      _matchByID(possibleID);
    } else {
      _loopAndSearch(text, maxResults: maxResults);
    }

    switch (_sortType) {
      case YTLocalSearchSortType.mostPlayed:
        searchResults.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.length ?? 0);
      case YTLocalSearchSortType.latestPlayed:
        searchResults.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.lastOrNull ?? 0);
      default:
        null;
    }
  }

  void _matchByID(String videoID) {
    try {
      final res = _lookupItemAvailable[videoID];
      if (res != null) {
        switch (res.list) {
          case 1:
            final vid = _lookupListStreamInfo?[res.index];
            if (vid != null) searchResults.add(vid);
            break;
          case 2:
            final info = _lookupListStreamInfoMap?[res.index];
            if (info != null) searchResults.add(StreamInfoItem.fromMap(info));
            break;
          case 3:
            final info = _lookupListVideoInfoMap?[res.index];
            if (info != null) searchResults.add(VideoInfo.fromMap(info).toStreamInfo());
            break;
          case 4:
            final info = _lookupListYTVH?[res.index];
            if (info != null) searchResults.add(info.toStreamInfo());
            break;
        }
      }
    } catch (_) {}
  }

  // List<int> _getTotalListensForID(String? id) {
  //   final finalListens = <int>[];
  //   final correspondingTrack = _localIdTrackMap![id];
  //   if (correspondingTrack != null) {
  //     final l = HistoryController.inst.topTracksMapListens[correspondingTrack];
  //     if (l != null) finalListens.addAll(l);
  //   }

  //   final yt = YoutubeHistoryController.inst.topTracksMapListens[id] ?? [];

  //   finalListens.addAll(yt);
  //   finalListens.sortByReverse((e) => e);
  //   return finalListens;
  // }

  bool _isMatchStrict(String textCleaned, String? title, String? channel) {
    return (title?.cleanUpForComparison.contains(textCleaned) ?? false) || (channel?.cleanUpForComparison.contains(textCleaned) ?? false);
  }

  bool _isMatchFuzzy(String textPre, String? title, String? channel) {
    final splittedText = textPre.split(' ').map((e) => e.cleanUpForComparison);
    final titleC = title?.cleanUpForComparison;
    final channelC = channel?.cleanUpForComparison;
    if (titleC != null) {
      final titleMatch = splittedText.every((element) => titleC.contains(element));
      if (titleMatch) return true;
    }
    if (channelC != null) {
      final channelMatch = splittedText.every((element) => channelC.contains(element));
      if (channelMatch) return true;
    }
    return false;
  }

  void _loopAndSearch(String textPre, {int? maxResults}) {
    final textCleaned = textPre.cleanUpForComparison;

    bool isMatch(String? title, String? channel) {
      return enableFuzzySearch ? _isMatchFuzzy(textPre, title, channel) : _isMatchStrict(textCleaned, title, channel);
    }

    // -----------------------------------
    final list1 = _lookupListStreamInfo;
    if (list1 != null) {
      final l = list1.length;
      for (int i = 0; i < l; i++) {
        final info = list1[i];
        if (isMatch(info.name, info.uploaderName)) {
          searchResults.add(info);
          if (maxResults != null && searchResults.length >= maxResults) return;
        }
      }
    }
    // -----------------------------------
    final list2 = _lookupListStreamInfoMap;
    if (list2 != null) {
      final l = list2.length;
      for (int i = 0; i < l; i++) {
        final info = list2[i];
        if (isMatch(info['name'], info['uploaderName'])) {
          searchResults.add(StreamInfoItem.fromMap(info));
          if (maxResults != null && searchResults.length >= maxResults) return;
        }
      }
    }

    // -----------------------------------
    final list3 = _lookupListVideoInfoMap;
    if (list3 != null) {
      final l = list3.length;
      for (int i = 0; i < l; i++) {
        final info = list3[i];
        if (isMatch(info['name'], info['uploaderName'])) {
          searchResults.add(VideoInfo.fromMap(info).toStreamInfo());
          if (maxResults != null && searchResults.length >= maxResults) return;
        }
      }
    }
    // -----------------------------------
    final list4 = _lookupListYTVH;
    if (list4 != null) {
      final l = list4.length;
      for (int i = 0; i < l; i++) {
        final info = list4[i];
        if (isMatch(info.title, info.channel)) {
          searchResults.add(info.toStreamInfo());
          if (maxResults != null && searchResults.length >= maxResults) return;
        }
      }
    }
  }

  void cleanResources() {
    _lookupListStreamInfo?.clear();
    _lookupListStreamInfo = null;
    _lookupListYTVH?.clear();
    _lookupListYTVH = null;
    _lookupListStreamInfoMap?.clear();
    _lookupListStreamInfoMap = null;
    _lookupListVideoInfoMap?.clear();
    _lookupListVideoInfoMap = null;

    _lookupItemAvailable.clear();

    scrollController?.dispose();
    scrollController = null;
  }
}

extension _VideoInfoUtils on VideoInfo {
  StreamInfoItem toStreamInfo() {
    return StreamInfoItem(
      url: url,
      id: id,
      name: name,
      uploaderName: uploaderName,
      uploaderUrl: uploaderUrl,
      uploaderAvatarUrl: uploaderAvatarUrl,
      thumbnailUrl: thumbnailUrl,
      date: date,
      textualUploadDate: date == null ? textualUploadDate : Jiffy.parseFromDateTime(date!).fromNow(),
      isDateApproximation: isDateApproximation,
      duration: duration,
      viewCount: viewCount,
      isUploaderVerified: isUploaderVerified,
      isShortFormContent: isShortFormContent,
      shortDescription: description,
    );
  }
}

extension _YTVHToVideoInfo on YoutubeVideoHistory {
  StreamInfoItem toStreamInfo() {
    return StreamInfoItem(
      url: null,
      id: id,
      name: title,
      uploaderName: channel,
      uploaderUrl: channelUrl,
      uploaderAvatarUrl: null,
      thumbnailUrl: null,
      date: null,
      textualUploadDate: null,
      isDateApproximation: null,
      duration: null,
      viewCount: null,
      isUploaderVerified: null,
      isShortFormContent: null,
      shortDescription: null,
    );
  }
}
