import 'dart:async';
import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';
import 'package:youtipie/core/url_utils.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YoutubeID with ItemWithDate implements Playable<Map<String, dynamic>>, PlaylistItemWithDate {
  final String id;
  final YTWatch? watchNull;
  final PlaylistID? playlistID;

  @override
  final TrackSource? sourceNull;

  @override
  int get dateAddedMS => watchNull?.dateMSNull ?? 0;

  YTWatch get watch => watchNull ?? const YTWatch(dateMSNull: null, isYTMusic: false);

  const YoutubeID({
    required this.id,
    TrackSource? source,
    this.watchNull,
    required this.playlistID,
  }) : sourceNull = source;

  factory YoutubeID.fromJson(Map<String, dynamic> json) {
    return YoutubeID(
      id: json['id'] ?? '',
      source: json['source'] == null ? null : TrackSource.values.getEnum(json['source']),
      watchNull: YTWatch.fromJson(json['watch']),
      playlistID: json['playlistID'] == null ? null : PlaylistID.fromJson(json['playlistID']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "watch": watch.toJson(),
      if (sourceNull != null) "source": sourceNull!.name,
      if (playlistID != null) "playlistID": playlistID?.toJson(),
    };
  }

  @override
  bool operator ==(other) {
    return other is YoutubeID && id == other.id && dateAddedMS == other.dateAddedMS && sourceNull == other.sourceNull;
  }

  @override
  int get hashCode => id.hashCode ^ dateAddedMS.hashCode ^ sourceNull.hashCode;

  @override
  String toString() => "YoutubeID(id: $id, dateAddedMS: $dateAddedMS, playlistID: $playlistID)";
}

extension YoutubeIDUtils on YoutubeID {
  Future<File?> getThumbnail({required bool temp}) {
    return ThumbnailManager.inst.getYoutubeThumbnailFromCache(id: id, isTemp: temp, type: ThumbnailType.video);
  }
}

extension YoutubeIDSUtils on List<YoutubeID> {
  Future<void> shareVideos() async {
    await NamidaUtils.shareText(map((e) => "${YTUrlUtils.buildVideoUrl(e.id)} - ${e.dateAddedMS.dateAndClockFormattedOriginal}\n").join());
  }

  int getTotalListenCount() {
    int total = 0;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final video = this[i];
      final e = video.id;
      final c = YoutubeHistoryController.inst.topTracksMapListens.value[e]?.length ?? 0;
      total += c;
    }
    return total;
  }

  int? getFirstListen() {
    int? generalFirstListen;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final video = this[i];
      final e = video.id;
      final firstListen = YoutubeHistoryController.inst.topTracksMapListens.value[e]?.firstOrNull;
      if (firstListen != null && (generalFirstListen == null || firstListen < generalFirstListen)) {
        generalFirstListen = firstListen;
      }
    }
    return generalFirstListen;
  }

  int? getLatestListen() {
    int? generalLastListen;
    final int length = this.length;
    for (int i = 0; i < length; i++) {
      final video = this[i];
      final e = video.id;
      final lastListen = YoutubeHistoryController.inst.topTracksMapListens.value[e]?.lastOrNull;
      if (lastListen != null && (generalLastListen == null || lastListen > generalLastListen)) {
        generalLastListen = lastListen;
      }
    }
    return generalLastListen;
  }
}
