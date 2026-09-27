import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:namida/core/extensions.dart';

mixin SettingsFileWriter {
  String get filePath;
  Map<String, dynamic> buildJson();
  Future<void> prepareSettingsFile();
  Map<String, dynamic>? syncDelta(int sinceMS);
  void applySyncDelta(Map delta);
  Duration get delay => const Duration(seconds: 2);

  @visibleForTesting
  Map<String, dynamic> debugFullJson();

  @protected
  Future<dynamic> prepareSettingsFile_() => File(filePath).readAsJson();

  @protected
  Future<void> writeToStorage() async {
    if (_canWriteSettings) {
      _canWriteSettings = false;
      _writeToStorageRaw();
    } else {
      _canWriteSettings = false;
      _writeTimer ??= Timer(delay, () {
        _writeToStorageRaw();
        _canWriteSettings = true;
        _writeTimer = null;
      });
    }
  }

  Future<void> _writeToStorageRaw() async {
    final path = filePath;
    final writtenFile = await File(path).writeAsJson(buildJson());
    if (writtenFile == null) {
      printy("Setting file write failed: ${path.getFilenameWOExt}", isError: true);
    } else {
      printy("Setting file write: $path");
    }
  }

  Timer? _writeTimer;
  bool _canWriteSettings = true;

  static const kRedactedValue = '<redacted>';

  Set<String> get sensitiveKeys => const {};

  Map<String, dynamic> redactedJson();

  @protected
  Map<String, dynamic> redactSensitive_(Map<String, dynamic> json) {
    for (final key in sensitiveKeys) {
      if (json.containsKey(key)) json[key] = kRedactedValue;
    }
    return json;
  }
}
