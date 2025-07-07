import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:logger/logger.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

final logger = _Log();

class _Log {
  static Logger _logger = _createLogger(Level.all);

  static Logger _createLogger(Level? level) {
    final filter = kDebugMode ? DevelopmentFilter() : ProductionFilter();
    final logsFile = File(AppPaths.LOGS);
    return _logger = Logger(
      level: level,
      filter: filter,
      printer: PrettyPrinter(
        colors: kDebugMode ? true : false,
        printEmojis: true,
        methodCount: 48,
        errorMethodCount: 48,
      ),
      output: _FileOutput(file: logsFile),
    );
  }

  void updateLoggerPath() => updateLogger(Level.all);

  Logger updateLogger(Level? level) {
    _logger.close();
    return _createLogger(level);
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
  _FileOutput({required this.file});
  final File file;

  IOSink? _sink;

  @override
  Future<void> init() async {
    try {
      await file.create();
      final sink = _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
      if (await file.length() <= 2) {
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
    final deviceMap = device.data;
    final packageMap = package.data;

    // -- android
    deviceMap.remove('supported32BitAbis');
    deviceMap.remove('supported64BitAbis');
    deviceMap.remove('systemFeatures');
    // -----------

    // -- windows
    deviceMap.remove('digitalProductId');
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
