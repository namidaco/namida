import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

class NamidaPlatformBuilder {
  static T init<T>({
    required T Function() android,
    T Function()? ios,
    required T Function() windows,
  }) {
    return switch (Platform.operatingSystem) {
      'windows' => windows(),
      'android' => android(),
      'ios' when ios != null => ios(),
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
