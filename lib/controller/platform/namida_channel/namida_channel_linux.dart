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
}
