import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:logger/logger.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

final logger = _Log();

class _Log {
  Level? _defaultLevel;

  Future<Logger>? _logger;

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

  void updateLogger(Level? level) async {
    _defaultLevel = level;
    (await _logger)?.close();
    _logger = null;
  }

  Future<void> dispose() async {
    (await _logger)?.close();
    _logger = null;
  }

  void error(
    dynamic message, {
    Object? e,
    StackTrace? st,
  }) async {
    printo('$e => $message\n=> $st', isError: true);
    final loggerEffective = await (_logger ??= _createNewLogger(_defaultLevel));
    loggerEffective.e(message, error: e, stackTrace: st);
  }

  void report(Object? e, StackTrace? st) => error('', e: e, st: st);
}

class _FileOutput extends LogOutput {
  _FileOutput({required this.file});
  final File file;

  @override
  Future<void> init() async {
    try {
      await file.create();
    } catch (_) {}
    return await super.init();
  }

  Future<void> _writeMainFile(OutputEvent event) async {
    // -- chronological logs
    try {
      await file.writeAsString(
        "${event.lines.join('\n')}\n\n",
        mode: FileMode.writeOnlyAppend,
        flush: true,
      );
    } catch (_) {}
  }

  @override
  void output(OutputEvent event) {
    _writeMainFile(event);
  }
}
