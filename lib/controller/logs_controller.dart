import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:logger/logger.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

final logger = _Log();

class _Log {
  final _printer = PrettyPrinter(
    colors: kDebugMode ? true : false,
    printEmojis: true,
    methodCount: 48,
    errorMethodCount: 48,
  );

  final _entries = HashMap<int, _LogEntry>();

  _LogsFile? _file;

  /// origin frames only, deeper frames vary with the rebuild/call path of the same error.
  static const _keyStackFrames = 8;
  static const _fnvOffset = 0xcbf29ce484222325;
  static const _fnvPrime = 0x100000001b3;

  static File _resolveFile() => AppDirs.USER_DATA.isEmpty ? File(AppPaths.LOGS_FALLBACK) : File(AppPaths.LOGS);

  static int _fnv(String s, int hash, int maxLines) {
    var lines = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      hash = (hash ^ c) * _fnvPrime;
      if (c == 0x0A && ++lines == maxLines) break;
    }
    return hash;
  }

  void updateLoggerPath() {
    _file?.close();
    _file = null;
    _entries.clear();
  }

  Future<void> dispose() async {
    await _file?.close();
    _file = null;
  }

  void error(
    dynamic message, {
    Object? e,
    StackTrace? st,
  }) {
    final stString = st?.toString();
    if (kDebugMode) printo('$e => $message\n=> $stString', isError: true);

    var key = _fnv(e == null ? '$message' : e.toString(), _fnvOffset, -1);
    if (stString != null) key = _fnv(stString, key, _keyStackFrames);
    final file = _file ??= _LogsFile(_resolveFile());

    final existing = _entries[key];
    if (existing != null) {
      existing.count++;
      file.updateCounter(existing);
      return;
    }

    final entry = _LogEntry();
    _entries[key] = entry;
    final lines = _printer.log(
      LogEvent(
        Level.error,
        message,
        error: e,
        stackTrace: stString == null ? null : StackTrace.fromString(stString),
      ),
    );
    file.append(entry, lines);
  }

  void report(Object? e, StackTrace? st) => error('', e: e, st: st);
}

// this alient max performance logic is by claude
class _LogsFile {
  _LogsFile(File file) {
    _chain = _open(file);
  }

  static const _counterDigits = 4;
  static const _counterMax = 9999;

  RandomAccessFile? _raf;
  int _endOffset = 0;
  late Future<void> _chain;

  static String _counterText(int count) => 'x${(count > _counterMax ? _counterMax : count).toString().padLeft(_counterDigits, '0')}';

  Future<void> _open(File file) async {
    try {
      final raf = await file.open(mode: FileMode.append);
      _endOffset = await raf.length();
      _raf = raf;
    } catch (_) {}
  }

  void _enqueue(Future<void> Function() op) {
    _chain = _chain.then((_) => op());
  }

  void append(_LogEntry entry, List<String> lines) {
    _enqueue(() async {
      final raf = _raf;
      if (raf == null) return;
      final bytes = utf8.encode("${_counterText(1)}\n${lines.join('\n')}\n\n");
      entry.counterOffset = _endOffset;
      try {
        await raf.writeFrom(bytes);
        _endOffset += bytes.length;
        await raf.flush();
      } catch (_) {}
    });
  }

  void updateCounter(_LogEntry entry) {
    if (entry.dirty) return;
    entry.dirty = true;
    _enqueue(() async {
      entry.dirty = false;
      final raf = _raf;
      if (raf == null || entry.counterOffset < 0) return;
      final text = _counterText(entry.count);
      try {
        try {
          await raf.setPosition(entry.counterOffset);
          await raf.writeFrom(ascii.encode(text));
        } finally {
          await raf.setPosition(_endOffset);
        }
        await raf.flush();
      } catch (_) {}
    });
  }

  Future<void> close() {
    _enqueue(() async {
      final raf = _raf;
      _raf = null;
      try {
        await raf?.close();
      } catch (_) {}
    });
    return _chain;
  }
}

class _LogEntry {
  int count = 1;
  int counterOffset = -1;
  bool dirty = false;
}
