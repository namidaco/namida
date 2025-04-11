part of 'ffmpeg_executer.dart';

abstract class FFMPEGExecuter {
  static FFMPEGExecuter platform() {
    return NamidaPlatformBuilder.init(
      android: () => _FFMPEGExecuterAndroid(),
      windows: () => _FFMPEGExecuterWindows(),
    );
  }

  void init();
  Future<bool> ffmpegExecute(List<String> args);
  Future<String?> ffprobeExecute(List<String> args);
  Future<Map<dynamic, dynamic>?> getMediaInformation(String path);
}

class _IsolateMessageToken {
  _IsolateMessageToken.create();

  int get key => hashCode;
}
