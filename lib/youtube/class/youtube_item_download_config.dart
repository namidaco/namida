import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';

class YoutubeItemDownloadConfig {
  final String id;
  String filename; // filename can be changed after deciding quality/codec, or manually.
  final Map<String, String?> ffmpegTags;
  DateTime? fileDate;
  VideoStream? videoStream;
  AudioStream? audioStream;
  final String? prefferedVideoQualityID;
  final String? prefferedAudioQualityID;
  final bool? fetchMissingAudio;
  final bool? fetchMissingVideo;

  YoutubeItemDownloadConfig({
    required this.id,
    required this.filename,
    required this.ffmpegTags,
    required this.fileDate,
    required this.videoStream,
    required this.audioStream,
    required this.prefferedVideoQualityID,
    required this.prefferedAudioQualityID,
    required this.fetchMissingAudio,
    required this.fetchMissingVideo,
  });

  factory YoutubeItemDownloadConfig.fromJson(Map<String, dynamic> map) {
    VideoStream? vids;
    AudioStream? auds;
    try {
      vids = VideoStream.fromMap(map['videoStream']);
    } catch (_) {}
    try {
      auds = AudioStream.fromMap(map['audioStream']);
    } catch (_) {}
    return YoutubeItemDownloadConfig(
      id: map['id'] ?? 'UNKNOWN_ID',
      filename: map['filename'] ?? 'UNKNOWN_FILENAME',
      fileDate: DateTime.fromMillisecondsSinceEpoch(map['fileDate'] ?? 0),
      ffmpegTags: (map['ffmpegTags'] as Map<String, dynamic>?)?.cast() ?? {},
      videoStream: vids,
      audioStream: auds,
      prefferedVideoQualityID: map['prefferedVideoQualityID'],
      prefferedAudioQualityID: map['prefferedAudioQualityID'],
      fetchMissingAudio: map['fetchMissingAudio'],
      fetchMissingVideo: map['fetchMissingVideo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'ffmpegTags': ffmpegTags,
      'fileDate': fileDate?.millisecondsSinceEpoch,
      'videoStream': videoStream?.toMap(),
      'audioStream': audioStream?.toMap(),
      'prefferedVideoQualityID': prefferedVideoQualityID,
      'prefferedAudioQualityID': prefferedAudioQualityID,
      'fetchMissingAudio': fetchMissingAudio,
      'fetchMissingVideo': fetchMissingVideo,
    };
  }

  @override
  bool operator ==(other) {
    if (other is YoutubeItemDownloadConfig) {
      return id == other.id && filename == other.filename;
    }
    return false;
  }

  /// only [id] && [filename] are matched, since map lookup will
  /// recognize this and update accordingly
  @override
  int get hashCode => "$id$filename".hashCode;
}
