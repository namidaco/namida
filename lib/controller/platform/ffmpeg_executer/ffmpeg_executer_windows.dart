part of 'ffmpeg_executer.dart';

/// -- stats for 238 files
/// await Process.run() => 0:00:14:615057 | 0:00:10.506741
/// Process.runSync() => 0:00:07.040127 | 0:00:06.651405
class _FFMPEGExecuterWindows extends FFMPEGExecuter {
  late String ffmpegExePath;
  late String ffprobeExePath;

  @override
  void init() {
    if (kDebugMode) {
      var processDir = p.dirname(Platform.resolvedExecutable);
      var midway = p.normalize(r'..\..\..\..\..\..\ffmpeg_build');
      ffmpegExePath = p.normalize(p.join(processDir, midway, 'ffmpeg.exe'));
      ffprobeExePath = p.normalize(p.join(processDir, midway, 'ffprobe.exe'));
    } else {
      var processDir = p.dirname(Platform.resolvedExecutable);
      ffmpegExePath = p.join(processDir, 'bin', 'ffmpeg.exe');
      ffprobeExePath = p.join(processDir, 'bin', 'ffprobe.exe');
    }
  }

  @override
  Future<bool> ffmpegExecute(List<String> args) async {
    final res = await Process.run(ffmpegExePath, [
      "-hide_banner",
      "-loglevel",
      "quiet",
      ...args,
    ]);
    final rc = res.exitCode;
    return rc == 0;
  }

  /// Automatically appends `-loglevel quiet -v quiet` for fast execution
  @override
  Future<String?> ffprobeExecute(List<String> args) async {
    final res = await Process.run(ffprobeExePath, [
      "-loglevel",
      "quiet",
      "-v",
      "quiet",
      ...args,
    ]);

    if (res.exitCode != 0) return null;

    final stdout = res.stdout;
    if (stdout == null || stdout is! String || stdout.isEmpty) return null;

    return stdout.toString();
  }

  @override
  Future<Map<dynamic, dynamic>?> getMediaInformation(String path) async {
    final stringed = await ffprobeExecute(
      [
        "-hide_banner",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        "-show_chapters",
        "-i",
        path,
      ],
    );
    return stringed == null ? null : jsonDecode(stringed) as Map;
  }
}
