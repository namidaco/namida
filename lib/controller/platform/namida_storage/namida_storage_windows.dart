part of 'namida_storage.dart';

class _NamidaStorageWindows extends NamidaStorage {
  const _NamidaStorageWindows() : super(null);

  @override
  Future<String?> getRealPath(String? contentUri) async {
    return contentUri;
  }

  @override
  Future<List<String>> getStorageDirectories() async {
    final paths = <String>[];
    try {
      final res = await Process.run('wmic', ['logicaldisk', 'get', 'caption']);
      final volumesFiltered = LineSplitter.split(res.stdout as String).map((e) => e.trim()).where((element) => element.isNotEmpty).skip(1); // skip C volume
      return volumesFiltered.toList();
    } catch (_) {}
    return paths;
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
  Future<String?> pickDirectory({String? note}) async {
    final options = DirectoryPicker()..title = 'Select a directory';
    return options.getDirectory()?.path;
  }

  @override
  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    String? memetype = NamidaStorageFileMemeType.any,
  }) async {
    final extensionsMap = <String, String>{};
    if (allowedExtensions != null) {
      allowedExtensions.loop(
        (item) {
          final extstring = item.extensions.map((e) => '*.$e').join(';');
          extensionsMap['($extstring)'] = extstring;
        },
      );
    } else {
      extensionsMap['All Files'] = '*.*';
    }

    final options = OpenFilePicker()
      ..filterSpecification = extensionsMap
      ..title = note ?? '';

    if (multiple) {
      final files = options.getFiles();
      return files.whereType<File>().map((e) => e.path).toList();
    } else {
      final path = options.getFile()?.path;
      return [if (path != null) path];
    }
  }
}
