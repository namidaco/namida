import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

final logger = _Log();

class _Log {
  late Logger _logger = updateLogger(Level.all);

  void updateLoggerPath() => updateLogger(Level.all);

  Logger updateLogger(Level? level) {
    final filter = kDebugMode ? DevelopmentFilter() : ProductionFilter();
    return _logger = Logger(
      level: level,
      filter: filter,
      printer: PrettyPrinter(
        colors: kDebugMode ? true : false,
        printEmojis: true,
        methodCount: 4,
        errorMethodCount: 24,
      ),
      output: _FileOutput(file: File(AppPaths.LOGS), fileClean: File(AppPaths.LOGS_CLEAN)),
    );
  }

  void error(
    dynamic message, {
    Object? e,
    StackTrace? st,
  }) {
    printo('$e => $message\n=> $st', isError: true);
    _logger.e(message, error: e, stackTrace: st);
  }
}

class _FileOutput extends LogOutput {
  _FileOutput({required this.file, required this.fileClean});
  final File file;
  final File fileClean;

  late final IOSink _sink;

  final _cleanLogsMap = <String?, Map<String, int>>{}; // <stackTrace, <error, count>{}>{}

  @override
  Future<void> init() async {
    try {
      await file.create();
      _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
      if (await file.length() <= 2) {
        _sink.write(await _getDeviceInfo());
        _sink.write("\n===============================\n");
        await _sink.flush();
      }
    } catch (_) {}
    try {
      await fileClean.create();
    } catch (_) {}
    return await super.init();
  }

  void _writeMainFile(OutputEvent event) async {
    // -- chronological logs
    try {
      for (final line in event.lines) {
        _sink.write("\n$line");
      }
      _sink.write("\n-------------------------------");
      await _sink.flush();
    } catch (_) {}
  }

  void _writeCleanFile(OutputEvent event) {
    // -- clean logs
    final stackString = event.origin.stackTrace.toString();
    _cleanLogsMap[stackString] ??= <String, int>{};
    _cleanLogsMap[stackString]!.update("${event.origin.error} => ${event.origin.message}", (value) => value + 1, ifAbsent: () => 1);
    fileClean.writeAsJson(_cleanLogsMap);
  }

  @override
  void output(OutputEvent event) async {
    _writeMainFile(event);
    _writeCleanFile(event);
  }

  @override
  Future<void> destroy() async {
    await _sink.flush();
    await _sink.close();
  }

  Future<String> _getDeviceInfo() async {
    final android = await NamidaDeviceInfo.androidInfoCompleter.future;
    final package = await NamidaDeviceInfo.packageInfoCompleter.future;
    final androidMap = android.data;
    final packageMap = package.data;
    androidMap.remove('supported32BitAbis');
    androidMap.remove('supported64BitAbis');
    androidMap.remove('systemFeatures');

    const encoder = JsonEncoder.withIndent("  ");
    final infoMap = {
      'android': androidMap,
      'package': packageMap,
    };
    return encoder.convert(infoMap);
  }
}
