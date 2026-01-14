import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:logger/logger.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

final logger = _Log();

class _Log {
  Level? _defaultLevel;

  Logger? _logger;

  static Future<Logger> _createNewLogger(Level? level) async {
    final filter = kDebugMode ? DevelopmentFilter() : ProductionFilter();
    final logsFile = AppDirs.USER_DATA.isEmpty ? File(AppPaths.LOGS_FALLBACK) : File(AppPaths.LOGS);
    final res = Logger(
      level: level ?? Level.all,
      filter: filter,
      printer: PrettyPrinter(
        colors: kDebugMode ? true : false,
        printEmojis: true,
        methodCount: 48,
        errorMethodCount: 48,
      ),
      output: _FileOutput(file: logsFile),
    );
    await res.init.ignoreError();
    return res;
  }

  void updateLoggerPath() => updateLogger(null);

  void updateLogger(Level? level) {
    _defaultLevel = level;
    _logger?.close();
    _logger = null;
  }

  Future<void> dispose() async {
    await _logger?.close();
    _logger = null;
  }

  void error(
    dynamic message, {
    Object? e,
    StackTrace? st,
  }) async {
    printo('$e => $message\n=> $st', isError: true);

    final loggerEffective = _logger ??= await _createNewLogger(_defaultLevel);
    loggerEffective.e(message, error: e, stackTrace: st);
  }

  void report(Object? e, StackTrace? st) => error('', e: e, st: st);
}

class _FileOutput extends LogOutput {
  _FileOutput({required this.file});
  final File file;

  IOSink? _sink;

  @override
  Future<void> init() async {
    try {
      await file.create();
      if (await file.length() <= 2) {
        final sink = _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
        sink.write(await _getDeviceInfo());
        sink.write("\n===============================\n");
        await sink.flush();
      }
    } catch (_) {}
    return await super.init();
  }

  Future<void> _writeMainFile(OutputEvent event) async {
    // -- chronological logs
    try {
      final sink = _sink;
      if (sink == null) return;
      final length = event.lines.length;
      for (int i = 0; i < length; i++) {
        sink.write("\n${event.lines[i]}");
      }
      sink.write("\n-------------------------------");
      await sink.flush();
    } catch (_) {}
  }

  @override
  void output(OutputEvent event) {
    _writeMainFile(event);
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush().ignoreError();
    await _sink?.close().ignoreError();
  }

  Future<String> _getDeviceInfo() async {
    final device = await NamidaDeviceInfo.deviceInfoCompleter.future;
    final package = await NamidaDeviceInfo.packageInfoCompleter.future;
    final deviceMap = device?.data;
    final packageMap = package?.data;

    // -- android
    deviceMap?.remove('supported32BitAbis');
    deviceMap?.remove('supported64BitAbis');
    deviceMap?.remove('systemFeatures');
    // -----------

    // -- windows
    deviceMap?.remove('digitalProductId');
    // -----------

    final encoder = JsonEncoder.withIndent(
      "  ",
      (object) {
        if (object is DateTime) {
          return object.toString();
        }
        try {
          return object.toJson();
        } catch (_) {
          return object.toString();
        }
      },
    );
    final infoMap = {
      'device': deviceMap,
      'package': packageMap,
    };
    return encoder.convert(infoMap);
  }
}
