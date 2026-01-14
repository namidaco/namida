part of 'ffmpeg_executer.dart';

class _FFMPEGExecuterAndroid extends FFMPEGExecuter {
  @override
  void init() {
    FFmpegKitConfig.disableLogs().catchError(logger.report);
    FFmpegKitConfig.setSessionHistorySize(99).catchError(logger.report);
  }

  @override
  Future<void> dispose() async {}

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

// == USE ONCE Background isolates support setMessageHandler()

// class _FFmpegAndroidIsolateManager with PortsProvider<Map> {
//   _FFmpegAndroidIsolateManager();

//   final _completers = <int, Completer<dynamic>?>{};
//   final _messageTokenWrapper = IsolateMessageTokenWrapper.create();

//   void dispose() => disposePort();

//   Future<dynamic> executeIsolate(List<String> args, {required bool ffprobe, bool? mediaInfo}) async {
//     if (!isInitialized) await initialize();
//     final token = _messageTokenWrapper.getToken();
//     _completers[token]?.complete(null); // useless but anyways
//     final completer = _completers[token] = Completer<dynamic>();
//     sendPort([token, args, ffprobe, mediaInfo]);
//     var res = await completer.future;
//     return res;
//   }

//   @override
//   IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
//     final params = {
//       'port': port,
//       'isolateToken': RootIsolateToken.instance!,
//     };
//     return IsolateFunctionReturnBuild(_prepareResourcesAndListen, params);
//   }

//   static void _prepareResourcesAndListen(Map params) async {
//     final sendPort = params['port'] as SendPort;
//     final isolateToken = params['isolateToken'] as RootIsolateToken;
//     BackgroundIsolateBinaryMessenger.ensureInitialized(isolateToken);

//     FFmpegKitConfig.disableLogs();
//     FFmpegKitConfig.setSessionHistorySize(99);

//     final recievePort = ReceivePort();
//     sendPort.send(recievePort.sendPort);

//     // -- start listening
//     StreamSubscription? streamSub;
//     streamSub = recievePort.listen((p) async {
//       if (PortsProvider.isDisposeMessage(p)) {
//         recievePort.close();
//         streamSub?.cancel();
//         return;
//       }

//       p as List;
//       final token = p[0] as int;
//       final args = p[1] as List<String>;
//       final isFFprobe = p[2] as bool;
//       final isMediaInfo = p[3] as bool?;

//       if (isFFprobe) {
//         if (isMediaInfo == true) {
//           final path = args[0];
//           final mediaInfo = await FFprobeKit.getMediaInformation(path);
//           final information = mediaInfo.getMediaInformation();
//           final map = information?.getAllProperties();
//           sendPort.send([token, map]);
//         } else {
//           final res = await FFprobeKit.executeWithArguments([
//             "-loglevel",
//             "quiet",
//             "-v",
//             "quiet",
//             ...args,
//           ]);
//           final output = await res.getOutput();
//           sendPort.send([token, output]);
//         }
//       } else {
//         final res = await FFmpegKit.executeWithArguments([
//           "-hide_banner",
//           "-loglevel",
//           "quiet",
//           ...args,
//         ]);
//         final rc = await res.getReturnCode();
//         final success = rc?.isValueSuccess() ?? false;
//         sendPort.send([token, success]);
//       }
//     });

//     sendPort.send(null); // prepared
//   }

//   @override
//   void onResult(result) {
//     final token = result[0] as int;
//     final completer = _completers[token];
//     if (completer != null && completer.isCompleted == false) {
//       completer.complete(result[1]);
//       _completers.remove(token); // dereferencing
//     }
//   }
// }
