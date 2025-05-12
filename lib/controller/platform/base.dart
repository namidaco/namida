import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

class NamidaPlatformBuilder {
  static T init<T>({
    required T Function() android,
    required T Function() windows,
    T Function()? linux,
    T Function()? ios,
    T Function()? macos,
  }) {
    return switch (Platform.operatingSystem) {
      'android' => android(),
      'windows' => windows(),
      'linux' when linux != null => linux(),
      'ios' when ios != null => ios(),
      'macos' when macos != null => macos(),
      _ => throw UnimplementedError(),
    };
  }

  static String getExecutablesPath() {
    var processDir = p.dirname(Platform.resolvedExecutable);
    if (kDebugMode) {
      var midway = r'..\..\..\..\..\..\ffmpeg_build';
      return p.normalize(p.join(processDir, midway));
    } else {
      return p.join(processDir, 'bin');
    }
  }
}
