import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

import 'package:namida/class/file_parts.dart';

class NamidaPlatformBuilder {
  static T init<T>({
    required T Function() android,
    required T Function() windows,
    required T Function()? linux,
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

  static String getExecutablesDirectoryPath() {
    return NamidaPlatformBuilder.init(
      android: () => '',
      windows: () {
        var processDir = p.dirname(Platform.resolvedExecutable);
        if (kDebugMode) {
          var midway = r'../../../../../ffmpeg_build/windows';
          return p.normalize(p.join(processDir, midway));
        } else {
          return p.join(processDir, 'bin');
        }
      },
      linux: () {
        final appDir = Platform.environment['APPDIR'];
        if (appDir != null && appDir.isNotEmpty) {
          // for AppImage
          return p.join(appDir, 'bin');
        }
        var processDir = p.dirname(Platform.resolvedExecutable);
        if (kDebugMode) {
          var midway = r'../../../../../ffmpeg_build/linux';
          return p.normalize(p.join(processDir, midway));
        } else {
          return p.join(processDir, 'bin');
        }
      },
    );
  }

  static String _getExecutablePath(String executablesDirPath, String name) {
    final exeName = NamidaPlatformBuilder.init(
      android: () => '',
      windows: () => '$name.exe',
      linux: () => name,
    );
    final fullPath = p.join(executablesDirPath, exeName);
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        // -- ensure permissions given
        Process.runSync('chmod', ['+x', fullPath]);
      } catch (_) {}
    }
    return fullPath;
  }

  static String getFFmpegExecutablePath(String executablesDirPath) {
    return _getExecutablePath(executablesDirPath, 'ffmpeg');
  }

  static String getFFprobeExecutablePath(String executablesDirPath) {
    return _getExecutablePath(executablesDirPath, 'ffprobe');
  }

  static String getAudioWaveformExecutablePath(String executablesDirPath) {
    return _getExecutablePath(executablesDirPath, 'audiowaveform');
  }

  static String? get windowsUserHome => Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  static String? get windowsNamidaHome {
    final home = windowsUserHome;
    if (home == null) return null;
    return FileParts.joinPath(home, '.namida');
  }

  static String? get linuxUserHome => Platform.environment['HOME'] ?? Platform.environment['XDG_DATA_HOME'];
  static String? get linuxNamidaHome {
    final home = linuxUserHome;
    if (home == null) return null;
    return FileParts.joinPath(home, '.namida');
  }
}
