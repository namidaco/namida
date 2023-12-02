import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

class YoutubeItemDownloadConfig {
  final String id;
  String filename; // filename can be changed after deciding quality/codec, or manually.
  final Map<String, String?> ffmpegTags;
  DateTime? fileDate;
  VideoStream? videoStream;
  AudioOnlyStream? audioStream;
  final String? prefferedVideoQualityID;
  final String? prefferedAudioQualityID;
  final bool fetchMissingStreams;

  YoutubeItemDownloadConfig({
    required this.id,
    required this.filename,
    required this.ffmpegTags,
    required this.fileDate,
    required this.videoStream,
    required this.audioStream,
    required this.prefferedVideoQualityID,
    required this.prefferedAudioQualityID,
    required this.fetchMissingStreams,
  });

  factory YoutubeItemDownloadConfig.fromJson(Map<String, dynamic> map) {
    return YoutubeItemDownloadConfig(
      id: map['id'] ?? 'UNKNOWN_ID',
      filename: map['filename'] ?? 'UNKNOWN_FILENAME',
      fileDate: DateTime.fromMillisecondsSinceEpoch(map['fileDate'] ?? 0),
      ffmpegTags: (map['ffmpegTags'] as Map<String, dynamic>?)?.cast() ?? {},
      videoStream: map['videoStream'] == null ? null : VideoStream.fromMap(map['videoStream']),
      audioStream: map['audioStream'] == null ? null : AudioOnlyStream.fromMap(map['audioStream']),
      prefferedVideoQualityID: map['prefferedVideoQualityID'],
      prefferedAudioQualityID: map['prefferedAudioQualityID'],
      fetchMissingStreams: map['fetchMissingStreams'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'ffmpegTags': ffmpegTags,
      'fileDate': fileDate?.millisecondsSinceEpoch,
      'videoStream': videoStream?.toMap()?..remove('url'),
      'audioStream': audioStream?.toMap()?..remove('url'),
      'prefferedVideoQualityID': prefferedVideoQualityID,
      'prefferedAudioQualityID': prefferedAudioQualityID,
      'fetchMissingStreams': fetchMissingStreams,
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
