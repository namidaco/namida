part of 'ffmpeg_executer.dart';

/// -- stats for 238 files
/// await Process.run() => 0:00:14:615057 | 0:00:10.506741
/// Process.runSync() => 0:00:07.040127 | 0:00:06.651405
class _FFMPEGExecuterWindows extends FFMPEGExecuter {
  @override
  void init() {
    _isolateExecuter.initialize();
  }

  final _isolateExecuter = _FFmpegWindowsIsolateManager();

  @override
  Future<bool> ffmpegExecute(List<String> args) async {
    final res = await _isolateExecuter.executeIsolate(args, ffprobe: false);
    return res as bool;
  }

  /// Automatically appends `-loglevel quiet -v quiet` for fast execution
  @override
  Future<String?> ffprobeExecute(List<String> args) async {
    final res = await _isolateExecuter.executeIsolate(args, ffprobe: true);
    return res as String?;
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

class _FFmpegWindowsIsolateManager with PortsProvider<SendPort> {
  _FFmpegWindowsIsolateManager();

  final _completers = <int, Completer<dynamic>?>{};
  final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

  void dispose() => disposePort();

  Future<dynamic> executeIsolate(List<String> args, {required bool ffprobe}) async {
    if (!isInitialized) await initialize();
    final token = _messageTokenWrapper.getToken();
    _completers[token]?.complete(null); // useless but anyways
    final completer = _completers[token] = Completer<dynamic>();
    sendPort([args, ffprobe, token]);
    var res = await completer.future;
    return res;
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, port);
  }

  static void _prepareResourcesAndListen(SendPort sendPort) async {
    final executablesPath = NamidaPlatformBuilder.getExecutablesPath();
    final ffmpegExePath = p.join(executablesPath, 'ffmpeg.exe');
    final ffprobeExePath = p.join(executablesPath, 'ffprobe.exe');

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      p as List;
      final args = p[0] as List<String>;
      final isFFprobe = p[1] as bool;
      final token = p[2] as int;

      if (isFFprobe) {
        String? output;
        try {
          final res = Process.runSync(ffprobeExePath, [
            "-loglevel",
            "quiet",
            "-v",
            "quiet",
            ...args,
          ]);

          if (res.exitCode == 0) {
            final stdout = res.stdout;
            final isDummy = stdout == null || stdout is! String || stdout.isEmpty;
            if (!isDummy) {
              output = stdout.toString();
            }
          }
        } catch (_) {}
        sendPort.send([token, output]);
      } else {
        bool success = false;
        try {
          final res = Process.runSync(ffmpegExePath, [
            "-hide_banner",
            "-loglevel",
            "quiet",
            ...args,
          ]);
          final rc = res.exitCode;
          success = rc == 0;
        } catch (_) {}
        sendPort.send([token, success]);
      }
    });

    sendPort.send(null); // prepared
  }

  @override
  void onResult(result) {
    final token = result[0] as int;
    final completer = _completers[token];
    if (completer != null && completer.isCompleted == false) {
      completer.complete(result[1]);
      _completers.remove(token); // dereferencing
    }
  }
}
