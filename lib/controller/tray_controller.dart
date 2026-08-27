import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:win32_registry/win32_registry.dart' as win32_registry;

import 'package:namida/controller/platform/base.dart';
import 'package:namida/controller/platform/tray_manager/tray_manager.dart';
import 'package:namida/core/enums.dart';

class TrayController with TrayListener {
  static final instance = NamidaTrayManager.platform();
}

class TrayIcons {
  final String appIcon;
  final String showWindow;
  final String icStatMusicnote;
  final String favorited;
  final String favorite;
  final String previous;
  final String pause;
  final String play;
  final String next;
  final String stop;
  final String repeatNone;
  final String repeatOne;
  final String repeatForNTimes;
  final String repeatAll;
  final String repeatAllShuffle;

  const TrayIcons({
    required this.appIcon,
    required this.showWindow,
    required this.icStatMusicnote,
    required this.favorited,
    required this.favorite,
    required this.previous,
    required this.pause,
    required this.play,
    required this.next,
    required this.stop,
    required this.repeatNone,
    required this.repeatOne,
    required this.repeatForNTimes,
    required this.repeatAll,
    required this.repeatAllShuffle,
  });

  static TrayIcons? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => TrayIcons.windows,
      linux: () => TrayIcons.linux,
      macos: () => null,
    );
  }

  static bool _isWindowsSystemThemeLight = _getSystemIsWindowsSystemThemeLight();

  static void refreshIsWindowsSystemThemeLight([bool? isLight]) {
    _isWindowsSystemThemeLight = isLight ?? _getSystemIsWindowsSystemThemeLight();
    TrayIcons.windows = _buildWindowsIcons();
  }

  static bool _getSystemIsWindowsSystemThemeLight() {
    try {
      final value = win32_registry.CURRENT_USER.getInt(
        'SystemUsesLightTheme',
        path: r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
      );
      return value == 1;
    } catch (_) {
      return false;
    }
  }

  static String _getWindowsIco(String name) {
    String parent;
    if (kDebugMode) {
      parent = '';
    } else {
      final processDir = p.dirname(Platform.resolvedExecutable);
      parent = '${p.join(processDir, 'data', 'flutter_assets').replaceAll(r'\', '/')}/';
    }
    final prefix = _isWindowsSystemThemeLight ? 'dark/' : '';
    final variant = _isWindowsSystemThemeLight ? '_dark' : '';
    return '${parent}assets/icons/media_ico/$prefix$name$variant.ico';
  }

  static TrayIcons windows = _buildWindowsIcons();
  static TrayIcons _buildWindowsIcons() => TrayIcons(
    appIcon: _getWindowsIco('app_icon'),
    showWindow: _getWindowsIco('app_icon'),
    icStatMusicnote: _getWindowsIco('ic_stat_musicnote'),
    favorited: _getWindowsIco('favorited'),
    favorite: _getWindowsIco('favorite'),
    previous: _getWindowsIco('previous'),
    pause: _getWindowsIco('pause'),
    play: _getWindowsIco('play'),
    next: _getWindowsIco('next'),
    stop: _getWindowsIco('stop'),
    repeatNone: _getWindowsIco('repeate-music'),
    repeatOne: _getWindowsIco('repeate-one'),
    repeatForNTimes: _getWindowsIco('status'),
    repeatAll: _getWindowsIco('repeat'),
    repeatAllShuffle: _getWindowsIco('shuffle'),
  );

  static const linux = TrayIcons(
    appIcon: '♫',
    showWindow: '❐',
    icStatMusicnote: '♪',
    favorited: '♥',
    favorite: '♡',
    previous: '⏮',
    pause: '⏸',
    play: '⏵',
    next: '⏭',
    stop: '✖',
    repeatNone: '➔',
    repeatOne: '🔂',
    repeatForNTimes: '#',
    repeatAll: '🔁',
    repeatAllShuffle: '🔀',
  );

  String forRepeatMode(PlayerRepeatMode repeat) {
    return switch (repeat) {
      PlayerRepeatMode.none => repeatNone,
      PlayerRepeatMode.one => repeatOne,
      PlayerRepeatMode.forNtimes => repeatForNTimes,
      PlayerRepeatMode.all => repeatAll,
      PlayerRepeatMode.allShuffle => repeatAllShuffle,
    };
  }
}
