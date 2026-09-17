part of 'ffmpeg_executer.dart';

abstract class FFMPEGExecuter {
  static FFMPEGExecuter platform() {
    return NamidaPlatformBuilder.init(
      android: _FFMPEGExecuterAndroid.new,
      windows: _FFMPEGExecuterDesktop.new,
      linux: _FFMPEGExecuterDesktop.new,
    );
  }

  FutureOr<void> init();
  Future<void> dispose();

  /// [noTimeout] is for long operations (ex: merging big files), where the timeout (if any) would report a still-running command as failed.
  Future<bool> ffmpegExecute(List<String> args, {bool noTimeout = false});
  Future<String?> ffprobeExecute(List<String> args);
  Future<Map<String, dynamic>?> getMediaInformation(String path);
  Future<bool> supportsWebDAV();
  Future<bool> supportsSMB();

  static bool testWebDAVProtocol(String output) {
    return output.contains('http') || output.contains('webdav');
  }

  static bool testSMBProtocol(String output) {
    return output.contains('smb');
  }

  static Map<String, dynamic>? parseFFprobeOutput(String? output) {
    if (output == null) return null;
    try {
      return jsonDecode(output) as Map<String, dynamic>?;
    } catch (_) {
      try {
        // COVERART is a giant base64 blob and breaks json pasing
        output = output.replaceFirst(RegExp(r'"COVERART".*', multiLine: false, caseSensitive: false), '');
        return jsonDecode(output) as Map<String, dynamic>?;
      } catch (_) {}
    }
    return null;
  }

  Future<MediaInfo?> extractMetadata(String path) async {
    final output = await ffprobeExecute(['-show_streams', '-show_format', '-show_entries', 'stream_tags:format_tags', '-of', 'json', path]);
    if (output != null && output != '') {
      try {
        final decoded = jsonDecode(output);
        decoded["PATH"] = path;
        final mi = MediaInfo.fromMap(decoded);
        final formatGood = (decoded['format'] as Map?)?.isNotEmpty ?? false;
        final tagsGood = (decoded['format']?['tags'] as Map?)?.isNotEmpty ?? false;
        if (formatGood && tagsGood) return mi;
      } catch (_) {}
    }

    final map = await getMediaInformation(path);
    if (map != null) {
      map["PATH"] = path;
      final miBackup = MediaInfo.fromMap(map);
      final format = miBackup.format;
      Map<String, dynamic>? tags = map['tags'] ?? map['format']?['tags'];
      if (tags == null) {
        try {
          final mainTags = (map['streams'] as List?)?.firstWhereEff((e) {
            final t = e['tags'];
            return t is Map && t.isNotEmpty;
          });
          tags = mainTags?['tags'];
        } catch (_) {}
      }
      final mi = MediaInfo(
        path: path,
        streams: miBackup.streams,
        format: MIFormat(
          bitRate: format?.bitRate ?? map['bit_rate'] ?? map['bitrate'],
          duration: format?.duration ?? (map['duration'] as String?).getDuration(),
          filename: format?.filename ?? map['filename'],
          formatName: format?.formatName ?? map['format_name'],
          nbPrograms: format?.nbPrograms,
          nbStreams: format?.nbStreams,
          probeScore: format?.probeScore,
          size: format?.size ?? (map['size'] as String?).getIntValue(),
          startTime: format?.startTime ?? map['start_time'],
          tags: tags == null ? null : MIFormatTags.fromMap(tags),
        ),
      );
      return mi;
    }

    return null;
  }
}
