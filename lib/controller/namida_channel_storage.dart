import 'dart:async';

import 'package:flutter/services.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

class NamidaStorage {
  static final NamidaStorage inst = NamidaStorage._internal();

  late final MethodChannel _channel;

  NamidaStorage._internal() {
    _channel = const MethodChannel('namida/storage');
  }

  Future<List<String>> getStorageDirectories() async {
    final res = await _channel.invokeMethod<List<Object?>?>('getStorageDirs');
    return res?.cast() ?? [];
  }

  Future<List<String>> getStorageDirectoriesAppData() async {
    final res = await _channel.invokeMethod<List<Object?>?>('getStorageDirsData');
    return res?.cast() ?? [];
  }

  Future<List<String>> getStorageDirectoriesAppCache() async {
    final res = await _channel.invokeMethod<List<Object?>?>('getStorageDirsCache');
    return res?.cast() ?? [];
  }

  Future<String?> getRealPath(String? contentUri) async {
    if (contentUri == null) return null;
    return await _channel.invokeMethod<String?>('getRealPath', {'contentUri': contentUri});
  }

  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<String>? allowedExtensions,
    String? memetype = NamidaStorageFileMemeType.any,
  }) async {
    try {
      final res = await _channel.invokeListMethod<String?>('pickFile', {
        'note': note,
        'type': memetype,
        'multiple': multiple,
        'allowedExtensions': allowedExtensions,
      });

      final files = res?.cast<String>() ?? <String>[];

      if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
        for (final f in files) {
          if (!allowedExtensions.any((ext) => f.endsWith(ext))) {
            snackyy(title: lang.ERROR, message: "${lang.EXTENSION}: $allowedExtensions", isError: true);
            return [];
          }
        }
      }

      return files;
    } catch (e) {
      snackyy(title: lang.ERROR, message: e.toString(), isError: true);
      return [];
    }
  }

  Future<String?> pickDirectory({String? note}) async {
    try {
      final res = await _channel.invokeListMethod<String?>('pickDirectory', {'note': note});
      return res?.firstOrNull;
    } catch (e) {
      snackyy(title: lang.ERROR, message: e.toString(), isError: true);
    }
    return null;
  }
}

class NamidaStorageFileMemeType {
  static const image = "image/*";
  static const audio = "audio/*";
  static const video = "video/*";
  static const media = "$audio,$video";
  static const any = "*/*";
}
