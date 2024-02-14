import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:namida/core/extensions.dart';

mixin SettingsFileWriter {
  String get filePath;
  Object get jsonToWrite;
  Duration get delay => const Duration(seconds: 2);

  @protected
  Future<dynamic> prepareSettingsFile_() async {
    final file = await File(filePath).create(recursive: true);
    try {
      return await file.readAsJson();
    } catch (e) {
      printy(e, isError: true);
    }
  }

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
    await File(path).writeAsJson(jsonToWrite);
    printy("Setting File Write: ${path.getFilenameWOExt}");
  }

  Timer? _writeTimer;
  bool _canWriteSettings = true;

  @protected
  Map<K, V>? getEnumMap_<K, V>(dynamic jsonMap, List<K> enumKeys, K defaultKey, List<V> enumValues, V defaultValue) {
    return ((jsonMap as Map?)?.map(
      (key, value) => MapEntry(enumKeys.getEnum(key) ?? defaultKey, enumValues.getEnum(value) ?? defaultValue),
    ));
  }
}
