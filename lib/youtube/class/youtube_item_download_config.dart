import 'package:flutter/foundation.dart';

import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';

import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/download_task_base.dart';

class YoutubeItemDownloadConfig {
  DownloadTaskFilename get filename => _filename.value;
  // ignore: avoid_rx_value_getter_outside_obx
  DownloadTaskFilename get filenameR => _filename.valueR;

  final DownloadTaskVideoId id;
  final DownloadTaskGroupName groupName;
  final Rx<DownloadTaskFilename> _filename; // filename can be changed after deciding quality/codec, or manually.
  final Map<String, String?> ffmpegTags;
  DateTime? fileDate;
  VideoStream? videoStream;
  AudioStream? audioStream;
  final StreamInfoItem? streamInfoItem;
  final String? prefferedVideoQualityID;
  final String? prefferedAudioQualityID;
  final bool? fetchMissingAudio;
  final bool? fetchMissingVideo;
  final int? index;
  final int? totalLength;
  final String? playlistId;

  YoutubeItemDownloadConfig({
    required this.id,
    required this.groupName,
    required DownloadTaskFilename filename,
    required this.ffmpegTags,
    required this.fileDate,
    required this.videoStream,
    required this.audioStream,
    required this.streamInfoItem,
    required this.prefferedVideoQualityID,
    required this.prefferedAudioQualityID,
    required this.fetchMissingAudio,
    required this.fetchMissingVideo,
    required this.index,
    required this.totalLength,
    required this.playlistId,
  }) : _filename = filename.obs;

  /// Using this method is restricted only for the function that will rename all the other instances in other parts.
  @protected
  void rename(String newName) {
    _filename.value.filename = newName;
    _filename.refresh();
  }

  factory YoutubeItemDownloadConfig.fromJson(Map<String, dynamic> map) {
    VideoStream? vids;
    AudioStream? auds;
    StreamInfoItem? streamInfoItem;
    try {
      vids = VideoStream.fromMap(map['videoStream']);
    } catch (_) {}
    try {
      auds = AudioStream.fromMap(map['audioStream']);
    } catch (_) {}
    try {
      streamInfoItem = StreamInfoItem.fromMap(map['streamInfoItem']);
    } catch (_) {}
    return YoutubeItemDownloadConfig(
      id: DownloadTaskVideoId(videoId: map['id'] ?? 'UNKNOWN_ID'),
      filename: DownloadTaskFilename.create(initialFilename: map['filename'] ?? 'UNKNOWN_FILENAME'),
      groupName: DownloadTaskGroupName(groupName: map['groupName'] ?? ''),
      fileDate: DateTime.fromMillisecondsSinceEpoch(map['fileDate'] ?? 0),
      ffmpegTags: (map['ffmpegTags'] as Map<String, dynamic>?)?.cast() ?? {},
      videoStream: vids,
      audioStream: auds,
      streamInfoItem: streamInfoItem,
      prefferedVideoQualityID: map['prefferedVideoQualityID'],
      prefferedAudioQualityID: map['prefferedAudioQualityID'],
      fetchMissingAudio: map['fetchMissingAudio'],
      fetchMissingVideo: map['fetchMissingVideo'],
      index: map['index'],
      totalLength: map['totalLength'],
      playlistId: map['playlistId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.videoId,
      'groupName': groupName.groupName,
      'filename': filename.filename,
      'ffmpegTags': ffmpegTags,
      'fileDate': fileDate?.millisecondsSinceEpoch,
      'videoStream': videoStream?.toMap(),
      'audioStream': audioStream?.toMap(),
      'streamInfoItem': streamInfoItem?.toMap(),
      'prefferedVideoQualityID': prefferedVideoQualityID,
      'prefferedAudioQualityID': prefferedAudioQualityID,
      'fetchMissingAudio': fetchMissingAudio,
      'fetchMissingVideo': fetchMissingVideo,
      'index': index,
      'totalLength': totalLength,
      'playlistId': playlistId,
    };
  }

  @override
  bool operator ==(other) {
    if (other is YoutubeItemDownloadConfig) {
      return id == other.id && groupName == other.groupName && filename == other.filename;
    }
    return false;
  }

  /// only [id], [groupName] && [filename] are matched, since map lookup will
  /// recognize this and update accordingly
  @override
  int get hashCode => id.videoId.hashCode ^ groupName.hashCode ^ filename.hashCode;
}
