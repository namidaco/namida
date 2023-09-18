import 'dart:async';
import 'dart:io';

import 'package:newpipeextractor_dart/models/videoInfo.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class YoutubeID implements Playable {
  final String id;
  final DateTime? addedDate;
  DateTime get _date => addedDate ?? DateTime.now();

  const YoutubeID({
    required this.id,
    this.addedDate,
  });

  factory YoutubeID.fromJson(Map<String, dynamic> json) {
    return YoutubeID(
      id: json['id'] ?? '',
      addedDate: DateTime.fromMillisecondsSinceEpoch(json['addedDate'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "addedDate": _date.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(other) {
    if (other is YoutubeID) {
      return id == other.id && _date.millisecondsSinceEpoch == other._date.millisecondsSinceEpoch;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => "YoutubeID(id: $id, addedDate: $_date)";
}

extension YoutubeIDUtils on YoutubeID {
  Future<VideoInfo?> toVideoInfo() async {
    return await YoutubeController.inst.fetchVideoDetails(id);
  }

  VideoInfo? toVideoInfoSync() {
    return YoutubeController.inst.fetchVideoDetailsFromCacheSync(id);
  }

  Future<File?> getThumbnail() async {
    return await VideoController.inst.getYoutubeThumbnailAndCache(id: id);
  }

  File? getThumbnailSync() {
    return VideoController.inst.getYoutubeThumbnailFromCacheSync(id: id);
  }
}
