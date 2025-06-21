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
  final int? originalIndex;
  final int? totalLength;
  final String? playlistId;
  final DateTime? addedAt;

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
    required this.originalIndex,
    required this.totalLength,
    required this.playlistId,
    required DateTime? addedAt,
  })  : _filename = filename.obs,
        this.addedAt = addedAt ?? DateTime.now();

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
      id: DownloadTaskVideoId(videoId: map['id'] ?? ''),
      filename: DownloadTaskFilename.fromMap(map['filename']),
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
      originalIndex: map['index'],
      totalLength: map['totalLength'],
      playlistId: map['playlistId'],
      addedAt: map['addedAt'] is int ? DateTime.fromMicrosecondsSinceEpoch(map['addedAt'] as int) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.videoId,
      'groupName': groupName.groupName,
      'filename': filename.toMap(),
      'ffmpegTags': ffmpegTags,
      'fileDate': fileDate?.millisecondsSinceEpoch,
      'videoStream': videoStream?.toMap(),
      'audioStream': audioStream?.toMap(),
      'streamInfoItem': streamInfoItem?.toMap(),
      'prefferedVideoQualityID': prefferedVideoQualityID,
      'prefferedAudioQualityID': prefferedAudioQualityID,
      'fetchMissingAudio': fetchMissingAudio,
      'fetchMissingVideo': fetchMissingVideo,
      'index': originalIndex,
      'totalLength': totalLength,
      'playlistId': playlistId,
      'addedAt': addedAt?.microsecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(covariant YoutubeItemDownloadConfig other) {
    return id == other.id && groupName == other.groupName && filename == other.filename;
  }

  /// only [id], [groupName] && [filename] are matched, since map lookup will
  /// recognize this and update accordingly
  @override
  int get hashCode => id.videoId.hashCode ^ groupName.hashCode ^ filename.hashCode;
}

extension YoutubeItemDownloadConfigUtils on YoutubeItemDownloadConfig {
  YoutubeItemDownloadConfig copyWith({
    DownloadTaskVideoId? id,
    DownloadTaskGroupName? groupName,
    DownloadTaskFilename? filename,
    Map<String, String?>? ffmpegTags,
    DateTime? fileDate,
    VideoStream? videoStream,
    AudioStream? audioStream,
    StreamInfoItem? streamInfoItem,
    String? prefferedVideoQualityID,
    String? prefferedAudioQualityID,
    bool? fetchMissingAudio,
    bool? fetchMissingVideo,
    int? originalIndex,
    int? totalLength,
    String? playlistId,
    DateTime? addedAt,
  }) {
    return YoutubeItemDownloadConfig(
      id: id ?? this.id,
      groupName: groupName ?? this.groupName,
      filename: filename ?? this.filename,
      ffmpegTags: ffmpegTags ?? this.ffmpegTags,
      fileDate: fileDate ?? this.fileDate,
      videoStream: videoStream ?? this.videoStream,
      audioStream: audioStream ?? this.audioStream,
      streamInfoItem: streamInfoItem ?? this.streamInfoItem,
      prefferedVideoQualityID: prefferedVideoQualityID ?? this.prefferedVideoQualityID,
      prefferedAudioQualityID: prefferedAudioQualityID ?? this.prefferedAudioQualityID,
      fetchMissingAudio: fetchMissingAudio ?? this.fetchMissingAudio,
      fetchMissingVideo: fetchMissingVideo ?? this.fetchMissingVideo,
      originalIndex: originalIndex ?? this.originalIndex,
      totalLength: totalLength ?? this.totalLength,
      playlistId: playlistId ?? this.playlistId,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
