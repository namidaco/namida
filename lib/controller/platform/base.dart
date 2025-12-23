import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

import 'package:namida/class/file_parts.dart';

class NamidaPlatformBuilder {
  static T init<T>({
    required T Function() android,
    required T Function() windows,
    T Function()? linux,
    T Function()? ios,
    T Function()? macos,
  }) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android(),
      TargetPlatform.windows => windows(),
      TargetPlatform.linux when linux != null => linux(),
      TargetPlatform.iOS when ios != null => ios(),
      TargetPlatform.macOS when macos != null => macos(),
      _ => throw UnimplementedError(),
    };
  }

  static String getExecutablesPath() {
    var processDir = p.dirname(Platform.resolvedExecutable);
    if (kDebugMode) {
      var midway = r'../../../../../ffmpeg_build/windows';
      return p.normalize(p.join(processDir, midway));
    } else {
      return p.join(processDir, 'bin');
    }
  }

  static String? get windowsUserHome => Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  static String? get windowsNamidaHome {
    final home = windowsUserHome;
    if (home == null) return null;
    return FileParts.joinPath(home, '.namida');
  }
}
