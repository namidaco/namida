import 'package:tray_manager/tray_manager.dart';

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

  static final instance = TrayIcons.platform();

  static TrayIcons? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => TrayIcons.windows,
      linux: () => TrayIcons.linux,
      macos: () => null,
    );
  }

  static String _getWindowsIco(String name) => 'assets/icons/media_ico/$name.ico';
  static final windows = TrayIcons(
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
