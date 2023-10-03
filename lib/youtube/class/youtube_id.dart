import 'dart:async';
import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class YoutubeID implements Playable, ItemWithDate {
  final String id;
  final YTWatch? watch;
  final PlaylistID? playlistID;

  DateTime get addedDate => watch?.date ?? DateTime.now();

  DateTime get _date => addedDate;
  YTWatch get _watch => watch ?? YTWatch(date: addedDate, isYTMusic: false);

  const YoutubeID({
    required this.id,
    this.watch,
    required this.playlistID,
  });

  @override
  DateTime get dateTimeAdded => _date;

  factory YoutubeID.fromJson(Map<String, dynamic> json) {
    return YoutubeID(
      id: json['id'] ?? '',
      watch: YTWatch.fromJson(json['watch']),
      playlistID: json['playlistID'] == null ? null : PlaylistID.fromJson(json['playlistID']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "watch": _watch.toJson(),
      "playlistID": playlistID?.toJson(),
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
  int get hashCode => "${id}_${_date.millisecondsSinceEpoch}".hashCode;

  @override
  String toString() => "YoutubeID(id: $id, addedDate: $_date, playlistID: $playlistID)";
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

  Future<Duration?> getDuration() async {
    Duration? dur;
    final a = YoutubeController.inst.getTemporarelyVideoInfo(id);
    dur = a?.duration;

    if (dur == null) {
      final b = await YoutubeController.inst.fetchVideoDetails(id);
      dur = b?.duration;
    }
    return dur;
  }
}
