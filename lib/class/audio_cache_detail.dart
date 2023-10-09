import 'dart:io';

class AudioCacheDetails {
  final String youtubeId;
  final int? bitrate;
  final String? langaugeCode;
  final String? langaugeName;
  final File file;

  const AudioCacheDetails({
    required this.youtubeId,
    required this.bitrate,
    required this.langaugeCode,
    required this.langaugeName,
    required this.file,
  });
}
