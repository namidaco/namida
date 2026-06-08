part of 'namida_storage.dart';

class _NamidaStorageWindows extends NamidaStorage {
  const _NamidaStorageWindows() : super(r'C:\');

  @override
  String getUserDataDirectory(List<String> appDataDirectories) {
    return NamidaPlatformBuilder.windowsNamidaHome ?? appDataDirectories.firstOrNull ?? '';
  }

  @override
  Future<String?> getRealPath(String? contentUri) async {
    return contentUri;
  }

  @override
  Future<List<String>> getStorageDirectories() async {
    for (final fn in [
      _getStorageDirectoriesPowershell,
      _getStorageDirectoriesWMIC,
    ]) {
      try {
        final res = await fn();
        if (res.isNotEmpty) return res;
      } catch (_) {}
    }
    return [];
  }

  Future<List<String>> _getStorageDirectoriesWMIC() async {
    final res = await Process.run(
      'wmic',
      ['logicaldisk', 'get', 'caption'],
    );
    return _refinedCMDStorageDirectoriesResult(res);
  }

  Future<List<String>> _getStorageDirectoriesPowershell() async {
    final res = await Process.run(
      'powershell',
      ['-Command', "Get-PSDrive -PSProvider 'FileSystem' | Select-Object -ExpandProperty Root"],
    );
    return _refinedCMDStorageDirectoriesResult(res);
  }

  List<String> _refinedCMDStorageDirectoriesResult(ProcessResult res) {
    return LineSplitter.split(res.stdout as String)
        .map((line) => line.trim())
        .where(
          (line) => line.isNotEmpty,
        )
        // .skip(1) // skip C volume
        .toList();
  }

  @override
  Future<List<String>> getStorageDirectoriesAppCache() async {
    Directory dir;
    try {
      dir = await pp.getApplicationCacheDirectory();
    } on pp.MissingPlatformDirectoryException catch (_) {
      dir = await pp.getTemporaryDirectory();
    }
    return [dir.path];
  }

  @override
  Future<List<String>> getStorageDirectoriesAppData() async {
    Directory dir;
    try {
      dir = await pp.getApplicationSupportDirectory();
    } on pp.MissingPlatformDirectoryException catch (_) {
      dir = Directory.current;
    }
    return [dir.path];
  }

  @override
  Future<String?> pickDirectory({String? note, String? initialDirectory}) async {
    final options = DirectoryPicker()
      ..title = 'Select a directory'
      ..initialDirectory = initialDirectory;
    return options.getDirectory()?.path;
  }

  @override
  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    NamidaStorageFileMemeType? memetype = NamidaStorageFileMemeType.any,
    String? initialDirectory,
  }) async {
    final extensionsMap = <String, String>{};
    if (allowedExtensions != null) {
      for (var item in allowedExtensions) {
        final extstring = item.extensions.map((e) => '*.$e').join(';');
        extensionsMap['($extstring)'] = extstring;
      }
    } else {
      extensionsMap['All Files'] = '*.*';
    }

    final options = OpenFilePicker()
      ..filterSpecification = extensionsMap
      ..title = note ?? ''
      ..initialDirectory = initialDirectory;

    if (multiple) {
      final files = options.getFiles();
      return files.whereType<File>().map((e) => e.path).toList();
    } else {
      final path = options.getFile()?.path;
      return [?path];
    }
  }
}
