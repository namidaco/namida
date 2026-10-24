part of 'ffmpeg_executer.dart';

/// replaces `ffmpeg_executer_obsolete/` (ffmpeg-kit on android, a process per call on windows & linux), 8-20x faster.
class _FFMPEGExecuterFFI extends FFMPEGExecuter {
  static const _kTimeout = Duration(seconds: 10);

  /// above the queue's parallelism, so the plugin never queues a session itself, which would count against the timeout.
  static const _kMaxConcurrentSessions = 12;

  static Future<void>? _initializeFuture;

  final _queue = Queue(parallel: 10);

  static Future<void> _initialize() async {
    await FFmpegKitExtended.initialize();
    FFmpegKitConfig.setMaxConcurrentSessions(_kMaxConcurrentSessions);
    // -- every command passes its own -loglevel, this one covers the logs fftools print before parsing it
    FFmpegKitConfig.setLogLevel(LogLevel.quiet);
    // -- output is read from the session, printing every line to the console/logcat is wasted work
    FFmpegKitConfig.setLogRedirectionStrategy(LogRedirectionStrategy.neverPrintLogs);
  }

  @override
  Future<void> init() => _initializeFuture ??= _initialize();

  @override
  Future<void> dispose() async {}

  /// false when the session ran past [_kTimeout], which cancels it.
  Future<bool> _awaitSession(Session session, Future<Object> execution, {required bool noTimeout}) async {
    if (noTimeout) {
      await execution;
      return true;
    }
    try {
      await execution.timeout(_kTimeout);
      return true;
    } on TimeoutException {
      session.cancel();
      return false;
    }
  }

  /// openssl (android & linux) finds no ca store there, and ffmpeg verifies https peers by default.
  static final _caFile = Platform.isAndroid || Platform.isLinux ? _resolveCaFile() : null;

  static const _kLinuxCaBundles = [
    '/etc/ssl/certs/ca-certificates.crt', '/etc/pki/tls/certs/ca-bundle.crt', '/etc/ssl/ca-bundle.pem', //
    '/etc/pki/tls/cacert.pem', '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem', '/etc/ssl/cert.pem', //
  ];
  static const _kAndroidCaDirectories = ['/apex/com.android.conscrypt/cacerts', '/system/etc/security/cacerts'];
  static const _kPemStart = '-----BEGIN CERTIFICATE-----';
  static const _kPemEnd = '-----END CERTIFICATE-----';

  static Future<String?> _resolveCaFile() async {
    if (Platform.isAndroid) return _buildAndroidCaFile().ignoreError();
    // -- openssl reads it on its own
    if (Platform.environment.containsKey('SSL_CERT_FILE')) return null;
    for (final path in _kLinuxCaBundles) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  /// android keeps a file per certificate, which openssl can't look up, so they are joined into one bundle.
  static Future<String?> _buildAndroidCaFile() async {
    final bundlePath = FileParts.joinPath(Directory.systemTemp.path, 'ffmpeg_cacerts.pem');
    final bundleFile = File(bundlePath);
    final bundleStat = await bundleFile.stat();
    for (final directoryPath in _kAndroidCaDirectories) {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) continue;
      final directoryStat = await directory.stat();
      final isBundleUpToDate = bundleStat.type == FileSystemEntityType.file && bundleStat.modified.isAfter(directoryStat.modified);
      if (isBundleUpToDate) return bundlePath;
      final files = await directory.list().where((e) => e is File).cast<File>().toList();
      final reads = files.map((e) => e.readAsString().ignoreError());
      final contents = await Future.wait(reads);
      final bundle = StringBuffer();
      for (final content in contents) {
        if (content == null) continue;
        final start = content.indexOf(_kPemStart);
        if (start == -1) continue;
        final end = content.indexOf(_kPemEnd, start);
        if (end == -1) continue;
        final pem = content.substring(start, end + _kPemEnd.length);
        bundle.writeln(pem);
      }
      if (bundle.isEmpty) continue;
      final bundleText = bundle.toString();
      await bundleFile.writeAsString(bundleText);
      return bundlePath;
    }
    return null;
  }

  /// `-ca_file` goes in front of https inputs only, ffmpeg & ffprobe reject it on inputs that don't use tls.
  static Future<List<String>> _withCaFile(List<String> args) async {
    final caFileFuture = _caFile;
    if (caFileFuture == null) return args;
    final hasHttpsInput = args.any((e) => e.startsWith('https://'));
    if (!hasHttpsInput) return args;
    final caFile = await caFileFuture;
    if (caFile == null) return args;
    final result = <String>[];
    for (final arg in args) {
      if (arg.startsWith('https://')) {
        final isAfterInputFlag = result.isNotEmpty && result.last == '-i';
        if (isAfterInputFlag) result.removeLast();
        result.addAll(['-ca_file', caFile]);
        if (isAfterInputFlag) result.add('-i');
      }
      result.add(arg);
    }
    return result;
  }

  @override
  Future<bool> ffmpegExecute(List<String> args, {bool noTimeout = false}) async {
    await init();
    final sessionArgs = await _withCaFile([
      "-hide_banner",
      "-loglevel",
      "quiet",
      ...args,
    ]);
    return await _queue.add(() async {
      final session = FFmpegKit.createSessionFromArguments(sessionArgs);
      final didFinish = await _awaitSession(session, session.executeAsync(), noTimeout: noTimeout);
      if (!didFinish) return false;
      return ReturnCode.isSuccess(session.getReturnCode());
    });
  }

  Future<String?> _probe(List<String> args) async {
    await init();
    final sessionArgs = await _withCaFile(args);
    return await _queue.add(() async {
      final session = FFprobeKit.createSessionFromArguments(sessionArgs);
      final didFinish = await _awaitSession(session, session.executeAsync(), noTimeout: false);
      if (!didFinish) return null;
      return session.getOutput();
    });
  }

  /// Automatically appends `-loglevel quiet -v quiet ` for fast execution
  @override
  Future<String?> ffprobeExecute(List<String> args) {
    return _probe([
      "-loglevel",
      "quiet",
      "-v",
      "quiet",
      ...args,
    ]);
  }

  @override
  Future<Map<String, dynamic>?> getMediaInformation(String path) async {
    final output = await _probe([
      "-v",
      "quiet",
      "-hide_banner",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      "-show_chapters",
      "-i",
      path,
    ]);
    return FFMPEGExecuter.parseFFprobeOutput(output);
  }

  @override
  Future<bool> supportsWebDAV({required bool isHttps}) async {
    await init();
    final protocols = FFmpegKitExtended.getRegisteredProtocols();
    return FFMPEGExecuter.testWebDAVProtocol(protocols, isHttps: isHttps);
  }

  @override
  Future<bool> supportsSMB() async {
    await init();
    final protocols = FFmpegKitExtended.getRegisteredProtocols();
    return FFMPEGExecuter.testSMBProtocol(protocols);
  }
}
