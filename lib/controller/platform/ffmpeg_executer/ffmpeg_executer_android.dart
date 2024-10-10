part of 'ffmpeg_executer.dart';

class _FFMPEGExecuterAndroid extends FFMPEGExecuter {
  @override
  void init() {
    FFmpegKitConfig.disableLogs();
    FFmpegKitConfig.setSessionHistorySize(99);
  }

  @override
  Future<bool> ffmpegExecute(List<String> args) async {
    final res = await FFmpegKit.executeWithArguments([
      "-hide_banner",
      "-loglevel",
      "quiet",
      ...args,
    ]);
    final rc = await res.getReturnCode();
    return rc?.isValueSuccess() ?? false;
  }

  /// Automatically appends `-loglevel quiet -v quiet ` for fast execution
  @override
  Future<String?> ffprobeExecute(List<String> args) async {
    final res = await FFprobeKit.executeWithArguments([
      "-loglevel",
      "quiet",
      "-v",
      "quiet",
      ...args,
    ]);
    return await res.getOutput();
  }

  @override
  Future<Map<dynamic, dynamic>?> getMediaInformation(String path) async {
    final mediaInfo = await FFprobeKit.getMediaInformation(path);
    final information = mediaInfo.getMediaInformation();
    final map = information?.getAllProperties();
    return map;
  }
}
