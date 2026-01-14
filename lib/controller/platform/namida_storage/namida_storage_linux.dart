part of 'namida_storage.dart';

class _NamidaStorageLinux extends NamidaStorage {
  const _NamidaStorageLinux() : super('/');

  @override
  String getUserDataDirectory(List<String> appDataDirectories) {
    return NamidaPlatformBuilder.linuxNamidaHome ?? appDataDirectories.firstOrNull ?? '';
  }

  @override
  Future<String?> getRealPath(String? contentUri) async {
    return contentUri;
  }

  @override
  Future<List<String>> getStorageDirectories() async {
    for (final fn in [
      _getStorageDirectoriesLsblk,
      _getStorageDirectoriesFindmnt,
      _getStorageDirectoriesDf,
    ]) {
      try {
        final res = await fn();
        if (res.isNotEmpty) return res;
      } catch (_) {}
    }
    return [];
  }

  Future<List<String>> _getStorageDirectoriesLsblk() async {
    final res = await Process.run(
      'lsblk',
      ['-o', 'MOUNTPOINT', '-nr'],
    );
    return await _refinedLinuxStorageDirectoriesResult(
      res,
      reverse: true, // cuz it appears reversed
    );
  }

  Future<List<String>> _getStorageDirectoriesFindmnt() async {
    final res = await Process.run(
      'bash',
      [
        '-c',
        "findmnt -rn -o TARGET | grep '^/run/media/'",
      ],
    );
    return await _refinedLinuxStorageDirectoriesResult(res);
  }

  Future<List<String>> _getStorageDirectoriesDf() async {
    final res = await Process.run(
      'bash',
      [
        '-c',
        r"df -P | awk 'NR>1 {print $NF}'",
      ],
    );
    return await _refinedLinuxStorageDirectoriesResult(res, skipHeader: true);
  }

  Future<List<String>> _refinedLinuxStorageDirectoriesResult(
    ProcessResult res, {
    bool skipHeader = false,
    bool reverse = false,
  }) async {
    final lines = LineSplitter.split(res.stdout as String).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

    var paths = skipHeader ? lines.skip(1) : lines;
    if (reverse) paths = paths.toList().reversed;

    final all = <String>{};

    final home = NamidaPlatformBuilder.linuxUserHome;
    if (home != null) all.add(home);

    for (final p in paths) {
      final isAccessible = await _isAccessibleDirectory(p);
      if (isAccessible) all.add(p);
    }

    all.remove('/');

    return all.toList();
  }

  Future<bool> _isAccessibleDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) return false;

      await for (final d in dir.list(followLinks: false)) {
        // try checking a single entry to verify access
        if (!d.existsSync()) return false;
        break;
      }
      const blackListPrefixes = <String>{
        "/bin", "/boot", "/dev", "/efi", "/etc", "/lib", "/lib64", //
        "/lost+found", "/opt", "/proc", "/recovery", "/root", "/run/user", //
        "/sbin", "/snap", "/srv", "/sys", "/tmp", "/usr", "/var", "/var/snap", //
      };
      if (blackListPrefixes.any((prefix) => path.startsWith(prefix))) {
        return false;
      }
      const blackListPaths = <String>{
        '/run', //
      };
      if (blackListPaths.any((blp) => path == blp)) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getStorageDirectoriesAppCache() async {
    String? dirPath;

    try {
      final dir = await pp.getApplicationCacheDirectory();
      dirPath = dir.path;
    } catch (_) {}

    if (dirPath == null) {
      try {
        final dir = await pp.getTemporaryDirectory();
        dirPath = dir.path;
      } catch (_) {}
    }

    if (dirPath == null) {
      final cacheHome = Platform.environment['XDG_CACHE_HOME'];
      if (cacheHome != null) {
        dirPath = '$cacheHome/com.msob7y.namida';
      } else {
        final home = Platform.environment['HOME'];
        if (home != null) {
          dirPath = '$home/.cache/com.msob7y.namida';
        }
      }
    }

    dirPath!;

    try {
      final finalDir = Directory(dirPath);
      if (!finalDir.existsSync()) finalDir.createSync(recursive: true);
    } catch (_) {}

    return [dirPath];
  }

  @override
  Future<List<String>> getStorageDirectoriesAppData() async {
    String? dirPath;

    dirPath ??= Platform.environment['XDG_DATA_HOME'];
    if (dirPath == null) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        dirPath = '$home/.local/share';
      }
    }
    if (dirPath == null) {
      try {
        final dir = await pp.getApplicationSupportDirectory();
        dirPath = dir.path;
      } catch (_) {}
    }
    return [FileParts.joinPath(dirPath!, '.namida')];
  }

  @override
  Future<String?> pickDirectory({String? note}) async {
    final res = await FilePickerLinux().getDirectoryPath(
      dialogTitle: note,
    );
    return res;
  }

  @override
  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    NamidaStorageFileMemeType? memetype = NamidaStorageFileMemeType.any,
  }) async {
    List<String>? extensionsList;
    if (allowedExtensions != null) {
      extensionsList = <String>[];
      allowedExtensions.loop((item) => extensionsList!.addAll(item.extensions));
    }
    final fileType = extensionsList != null && extensionsList.isNotEmpty
        ? FileType.custom
        : switch (memetype) {
            NamidaStorageFileMemeType.image => FileType.image,
            NamidaStorageFileMemeType.audio => FileType.audio,
            NamidaStorageFileMemeType.video => FileType.video,
            NamidaStorageFileMemeType.media => FileType.media,
            null || NamidaStorageFileMemeType.any => FileType.any,
          };
    final res = await FilePickerLinux().pickFiles(
      dialogTitle: note,
      allowMultiple: multiple,
      type: fileType,
      allowedExtensions: extensionsList,
    );
    return res?.paths.whereType<String>().toList() ?? <String>[];
  }
}
