part of 'namida_channel.dart';

class _NamidaChannelWindows extends NamidaChannel {
  _NamidaChannelWindows._internal();

  @override
  bool get canOpenFileInExplorer => true;

  @override
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false}) {
    return Process.start(
      'explorer.exe',
      isDirectory ? [filePath] : ['/select,', filePath],
      runInShell: true,
      mode: ProcessStartMode.normal,
    );
  }
}
