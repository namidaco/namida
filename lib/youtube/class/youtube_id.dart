import 'dart:async';
import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/core/url_utils.dart';

class YoutubeID implements Playable<Map<String, dynamic>>, ItemWithDate, PlaylistItemWithDate {
  final String id;
  final YTWatch? watchNull;
  final PlaylistID? playlistID;

  @override
  int get dateAddedMS => watchNull?.dateMSNull ?? 0;

  YTWatch get watch => watchNull ?? const YTWatch(dateMSNull: null, isYTMusic: false);

  const YoutubeID({
    required this.id,
    this.watchNull,
    required this.playlistID,
  });

  factory YoutubeID.fromJson(Map<String, dynamic> json) {
    return YoutubeID(
      id: json['id'] ?? '',
      watchNull: YTWatch.fromJson(json['watch']),
      playlistID: json['playlistID'] == null ? null : PlaylistID.fromJson(json['playlistID']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "watch": watch.toJson(),
      if (playlistID != null) "playlistID": playlistID?.toJson(),
    };
  }

  @override
  bool operator ==(other) {
    return other is YoutubeID && id == other.id && dateAddedMS == other.dateAddedMS;
  }

  @override
  int get hashCode => id.hashCode ^ dateAddedMS.hashCode;

  @override
  String toString() => "YoutubeID(id: $id, dateAddedMS: $dateAddedMS, playlistID: $playlistID)";
}

extension YoutubeIDUtils on YoutubeID {
  File? getThumbnailSync({required bool temp}) {
    return ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: id, isTemp: temp, type: ThumbnailType.video);
  }
}

extension YoutubeIDSUtils on List<YoutubeID> {
  Future<void> shareVideos() async {
    await Share.share(map((e) => "${YTUrlUtils.buildVideoUrl(e.id)} - ${e.dateAddedMS.dateAndClockFormattedOriginal}\n").join());
  }
}
