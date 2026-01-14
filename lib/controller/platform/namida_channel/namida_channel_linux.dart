part of 'namida_channel.dart';

class _NamidaChannelLinux extends NamidaChannel {
  _NamidaChannelLinux._internal();

  @override
  bool get canOpenFileInExplorer => true;

  @override
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false}) async {
    final fileManagers = <({String command, List<String> args})>[
      // KDE Dolphin
      (command: 'dolphin', args: ['--select', filePath]),
      // GNOME Files (Nautilus)
      (command: 'nautilus', args: ['--select', filePath]),
      // Nemo (Cinnamon)
      (command: 'nemo', args: [filePath]),
      // Thunar (XFCE)
      (command: 'thunar', args: [filePath]),
      // PCManFM (LXDE)
      (command: 'pcmanfm', args: [filePath]),
      // Fallback: xdg-open (opens parent directory)
      (command: 'xdg-open', args: [File(filePath).parent.path]),
    ];

    for (final fm in fileManagers) {
      try {
        // Check if command exists
        final which = await Process.run('which', [fm.command]);
        if (which.exitCode == 0) {
          await Process.start(
            fm.command,
            fm.args,
            mode: ProcessStartMode.detached,
          );
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  @override
  bool get supportsAppIcons => false;
  @override
  Future<bool?> isAppIconEnabled(NamidaAppIcons type) async {
    // -- unsupported
    return false;
  }

  @override
  Future<void> changeAppIcon(NamidaAppIcons type) async {
    // -- unsupported
  }

  @override
  Future<void> updatePipRatio({int? width, int? height}) async {
    // -- unsupported
  }

  @override
  Future<void> setCanEnterPip(bool canEnter) async {
    // -- unsupported
  }

  @override
  Future<void> showToast({
    required String message,
    required SnackDisplayDuration duration,
  }) async {
    // -- use in-app toast
    snackyy(message: message, displayDuration: duration);
  }

  @override
  Future<int> getPlatformSdk() async {
    return 1;
  }

  @override
  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types}) async {
    // -- unsupported
    return false;
  }

  @override
  Future<bool> openSystemEqualizer(int? sessionId) async {
    // -- unsupported
    return false;
  }

  @override
  Future<bool> openNamidaSync(String backupFolder, String musicFoldersJoined) async {
    // -- unsupported natively
    return false;
  }
}
