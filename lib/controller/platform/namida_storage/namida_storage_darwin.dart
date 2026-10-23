part of 'namida_storage.dart';

// by claude
class _NamidaStorageIOS extends NamidaStorage {
  _NamidaStorageIOS._init() : super(null);

  static const _channel = MethodChannel('namida/storage');

  /// no extension, the migration only rewrites json & db files and must never touch these.
  static const _kStoragePathsStateFilename = '.storage_paths';
  static const _kStorageOriginFilename = '.storage_origin';

  late final _documentsDirectoryFuture = pp.getApplicationDocumentsDirectory();
  late final _pickedDirectoriesFuture = _fetchPickedDirectories();

  @override
  String getUserDataDirectory(List<String> appDataDirectories) => appDataDirectories.first;

  @override
  Future<List<String>> getStorageDirectoriesAppData() async {
    final dir = await pp.getApplicationSupportDirectory();
    return [FileParts.joinPath(dir.path, 'namida')];
  }

  @override
  Future<List<String>> getStorageDirectoriesAppCache() async {
    final dir = await pp.getApplicationCacheDirectory();
    return [dir.path];
  }

  /// documents first, the only folder of namida the files app shows, then the folders picked outside of it.
  @override
  Future<List<String>> getStorageDirectories() async {
    final documents = await _documentsDirectoryFuture;
    final picked = await _pickedDirectoriesFuture;
    return [
      documents.path,
      ...?picked?.paths,
    ];
  }

  /// a file provider that hangs can't hold the startup, its moves are taken the next launch.
  static const _kPickedDirectoriesTimeout = Duration(seconds: 5);

  Future<_PickedDirectories?> _fetchPickedDirectories() async {
    try {
      final resFuture = _channel.invokeMapMethod<String, Object?>('getPickedDirectories');
      final res = await resFuture.timeout(_kPickedDirectoriesTimeout, onTimeout: () => null);
      if (res == null) return null;
      return _PickedDirectories.fromMap(res);
    } catch (e, st) {
      logger.error('getPickedDirectories', e: e, st: st);
      return null;
    }
  }

  @override
  Future<String?> getRealPath(String? contentUri) async => contentUri;

  /// the system picker reaches every location the files app has, picked folders stay accessible across launches.
  @override
  Future<String?> pickDirectory({String? note, String? initialDirectory}) async {
    try {
      return await _channel.invokeMethod<String>('pickDirectory', {'initialDirectory': initialDirectory});
    } on PlatformException catch (e) {
      final message = e.message ?? e.code;
      snackyy(title: lang.error, message: message, isError: true);
      return null;
    }
  }

  @override
  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    NamidaStorageFileMemeType? memetype = NamidaStorageFileMemeType.any,
    String? initialDirectory,
  }) {
    return _pickFilesDarwin(
      note: note,
      multiple: multiple,
      allowedExtensions: allowedExtensions,
      memetype: memetype,
      initialDirectory: initialDirectory,
    );
  }

  Set<String> _libraryPaths = const {};

  @override
  Future<void> initPickedDirectories() async {
    _libraryPaths = _getLocalLibraryPaths();
    settings.directoriesToScan.addListener(_onLibraryChanged);
    await _keepDirectoriesOffline(_libraryPaths);
  }

  void _onLibraryChanged() {
    final libraryPaths = _getLocalLibraryPaths();
    final addedPaths = libraryPaths.difference(_libraryPaths);
    _libraryPaths = libraryPaths;
    if (addedPaths.isNotEmpty) _keepDirectoriesOffline(addedPaths).ignoreError();
  }

  static Set<String> _getLocalLibraryPaths() {
    return settings.directoriesToScan.value.where((e) => e.type == DirectoryIndexType.local).map((e) => e.sourceRaw).toSet();
  }

  /// icloud keeps placeholders of the files it evicted, a library has to be on the device to play offline.
  static Future<void> _keepDirectoriesOffline(Set<String> paths) {
    final pathsList = paths.toFixedList();
    return _channel.invokeMethod('keepDirectoriesOffline', {'paths': pathsList});
  }

  /// only from the user's own removal, a library replaced by a restore or a sync keeps the access it had.
  @override
  Future<void> releaseLibraryDirectory(String path) {
    final usedPaths = _getPathsInUse();
    return _channel.invokeMethod('releasePickedDirectories', {
      'removed': [path],
      'used': usedPaths,
    });
  }

  static List<String> _getPathsInUse() {
    final backupLocation = settings.defaultBackupLocation.value;
    final startupLocation = settings.defaultFolderStartupLocation.value;
    final videosStartupLocation = settings.defaultFolderStartupLocationVideos.value;
    return [
      ..._getLocalLibraryPaths(),
      ...settings.lyricsFolders.value,
      ...PlaylistController.inst.getLinkedM3UPaths(),
      ?backupLocation,
      ?startupLocation,
      ?videosStartupLocation,
      settings.youtube.ytDownloadLocation.value,
    ];
  }

  /// the container moves on every reinstall or update (every sideload refresh), picked folders can be moved too.
  /// a picked folder's move is acknowledged once stored, until then it's reported again every launch.
  /// a file that fails is retried once on the next launch, with the moves it missed.
  @override
  Future<void> prepareUserData() async {
    _channel.invokeMethod('excludeFromBackup', {'paths': AppDirs.regenerableCaches}).ignoreError();

    final documents = await _documentsDirectoryFuture;
    final containerRoot = documents.parent.path;
    final stateFile = FileParts.join(AppDirs.USER_DATA, _kStoragePathsStateFilename);
    final stateJson = await stateFile.readAsJson(ensureExists: false);
    final previousState = _StoragePathsState.fromJson(stateJson);
    final previousContainerRoot = previousState?.containerRoot;
    final picked = await _pickedDirectoriesFuture;
    final reportedPickedMoves = picked?.moved ?? const <String, String>{};
    // -- unknown this launch (a timeout), what was applied but not acknowledged yet still has to be kept
    final appliedPickedMovesToStore = picked == null ? previousState?.appliedPickedMoves : reportedPickedMoves;
    // -- still reported after a kill or a failed acknowledgment, chained moves (a -> b, c -> a) can't be applied twice
    final appliedPickedMoves = previousState?.appliedPickedMoves;
    final wasPickedMovesApplied = appliedPickedMoves != null && mapEquals(appliedPickedMoves, reportedPickedMoves);

    final moves = <String, String>{
      if (!wasPickedMovesApplied) ...reportedPickedMoves,
    };
    if (previousContainerRoot != null && previousContainerRoot != containerRoot) {
      moves[previousContainerRoot] = containerRoot;
      moves['/private$previousContainerRoot'] = containerRoot;
    }
    final retryFiles = previousState?.retryFiles ?? const <String>[];
    final hasWork = moves.isNotEmpty || retryFiles.isNotEmpty;
    final isStateCurrent = !hasWork && previousContainerRoot == containerRoot;

    var stateRetryMoves = previousState?.retryMoves ?? const <String, String>{};
    var stateRetryFiles = retryFiles;
    if (!isStateCurrent) {
      var failedFiles = const <String>[];
      if (hasWork) {
        final retryMoves = previousState?.retryMoves ?? const <String, String>{};
        final params = (
          directory: AppDirs.USER_DATA,
          skippedDirectories: _getDirectoriesWithoutPaths(),
          moves: moves,
          retryMoves: retryMoves,
          retryFiles: retryFiles,
        );
        final result = await _migrateIsolate.thready(params);
        failedFiles = result.failedFiles;
        printo('migrated ${result.changedCount} files after storage moved: $moves');
        if (failedFiles.isNotEmpty) logger.error('storage paths migration failed, retried next launch: $failedFiles');
        if (result.droppedFiles.isNotEmpty) logger.error('storage paths migration failed twice, left as is: ${result.droppedFiles}');
      }
      stateRetryMoves = failedFiles.isEmpty ? const {} : moves;
      stateRetryFiles = failedFiles;
      final state = _StoragePathsState(
        containerRoot: containerRoot,
        appliedPickedMoves: appliedPickedMovesToStore ?? const {},
        retryMoves: stateRetryMoves,
        retryFiles: stateRetryFiles,
      );
      final didWriteState = await state.writeAtomic(stateFile);
      if (!didWriteState) return;
    }
    if (reportedPickedMoves.isEmpty) return;
    await _channel.invokeMethod('acknowledgeMovedPickedDirectories', {'moved': reportedPickedMoves});
    // -- acknowledged, the same moves reported again later would be new ones
    final acknowledgedState = _StoragePathsState(
      containerRoot: containerRoot,
      appliedPickedMoves: const {},
      retryMoves: stateRetryMoves,
      retryFiles: stateRetryFiles,
    );
    await acknowledgedState.writeAtomic(stateFile);
  }

  @override
  Future<File?> writeBackupStorageOrigin(String directoryPath) async {
    final documents = await _documentsDirectoryFuture;
    final containerRoot = documents.parent.path;
    final originFile = FileParts.join(directoryPath, _kStorageOriginFilename);
    return originFile.writeAsJson({'containerRoot': containerRoot});
  }

  /// only the container the backup was made in moves, paths into other apps' containers (folders picked there) stay.
  /// a backup without its origin is left as is.
  @override
  Future<void> prepareRestoredUserData(String directoryPath) async {
    final originFile = FileParts.join(directoryPath, _kStorageOriginFilename);
    final originJson = await originFile.readAsJson(ensureExists: false);
    await originFile.tryDeleting();
    final origin = _StoragePathsState.fromJson(originJson);
    final originContainerRoot = origin?.containerRoot;
    final documents = await _documentsDirectoryFuture;
    final containerRoot = documents.parent.path;
    if (originContainerRoot == null || originContainerRoot == containerRoot) return;

    final userDataPath = AppDirs.USER_DATA;
    final skippedDirectories = _getDirectoriesWithoutPaths().map((e) => '$directoryPath${e.substring(userDataPath.length)}').toSet();
    final params = (
      directory: directoryPath,
      skippedDirectories: skippedDirectories,
      moves: {originContainerRoot: containerRoot, '/private$originContainerRoot': containerRoot},
      retryMoves: const <String, String>{},
      retryFiles: const <String>[],
    );
    final result = await _migrateIsolate.thready(params);
    if (result.failedFiles.isNotEmpty) logger.error('restored paths migration failed: ${result.failedFiles}');
  }

  /// retry & failed files are relative to the user data folder, which moves with the container.
  static ({int changedCount, List<String> failedFiles, List<String> droppedFiles}) _migrateIsolate(_StoragePathsMigrationParams params) {
    final directory = params.directory;
    final droppedFiles = <String>[];
    final retryMigrator = _StoragePathsMigrator.create(params.retryMoves);
    if (retryMigrator != null) {
      for (final relativePath in params.retryFiles) {
        try {
          final path = FileParts.joinPath(directory, relativePath);
          retryMigrator.migrateFileSync(path);
        } catch (_) {
          droppedFiles.add(relativePath);
        }
      }
    }
    final migrator = _StoragePathsMigrator.create(params.moves);
    final result = migrator?.migrateDirectorySync(directory, skippedDirectories: params.skippedDirectories);
    final changedCount = result?.changedCount ?? 0;
    final failedFiles = result?.failedFiles.map((path) => p.relative(path, from: directory)).toFixedList();
    return (changedCount: changedCount, failedFiles: failedFiles ?? const [], droppedFiles: droppedFiles);
  }

  /// skipped by the migration, they only hold images, media and youtube data.
  static Set<String> _getDirectoriesWithoutPaths() {
    return {
      ...AppDirs.regenerableCaches,
      AppDirs.ARTWORKS_ARTISTS, AppDirs.ARTWORKS_ALBUMS, AppDirs.PLAYLISTS_ARTWORKS, AppDirs.SMART_PLAYLISTS_ARTWORKS, //
      AppDirs.YT_PLAYLISTS_ARTWORKS, AppDirs.WALLPAPERS, AppDirs.YOUTIPIE_CACHE, //
    };
  }
}

class _NamidaStorageMacOS extends NamidaStorage {
  const _NamidaStorageMacOS() : super('/');

  @override
  String getUserDataDirectory(List<String> appDataDirectories) {
    return NamidaPlatformBuilder.unixNamidaHome ?? appDataDirectories.firstOrNull ?? '';
  }

  @override
  Future<List<String>> getStorageDirectoriesAppData() async {
    final dir = await pp.getApplicationSupportDirectory();
    return [dir.path];
  }

  @override
  Future<List<String>> getStorageDirectoriesAppCache() async {
    final dir = await pp.getApplicationCacheDirectory();
    return [dir.path];
  }

  /// only home, reading a removable or network volume asks for permission (and a dead network mount blocks).
  /// other folders are added through the system picker.
  @override
  Future<List<String>> getStorageDirectories() async {
    final home = NamidaPlatformBuilder.unixUserHome;
    return [?home];
  }

  @override
  Future<String?> getRealPath(String? contentUri) async => contentUri;

  @override
  Future<String?> pickDirectory({String? note, String? initialDirectory}) {
    return FilePicker.getDirectoryPath(
      dialogTitle: note,
      initialDirectory: initialDirectory,
    );
  }

  @override
  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    NamidaStorageFileMemeType? memetype = NamidaStorageFileMemeType.any,
    String? initialDirectory,
  }) {
    return _pickFilesDarwin(
      note: note,
      multiple: multiple,
      allowedExtensions: allowedExtensions,
      memetype: memetype,
      initialDirectory: initialDirectory,
    );
  }
}

/// file_picker's audio type opens the apple music library on ios, every media type goes by extension instead.
Future<List<String>> _pickFilesDarwin({
  required String? note,
  required bool multiple,
  required List<NamidaFileExtensionsWrapper>? allowedExtensions,
  required NamidaStorageFileMemeType? memetype,
  required String? initialDirectory,
}) async {
  final extensionsWrappers =
      allowedExtensions ??
      switch (memetype) {
        NamidaStorageFileMemeType.audio => [NamidaFileExtensionsWrapper.audio],
        NamidaStorageFileMemeType.video => [NamidaFileExtensionsWrapper.video],
        NamidaStorageFileMemeType.media => [NamidaFileExtensionsWrapper.audio, NamidaFileExtensionsWrapper.video],
        NamidaStorageFileMemeType.image || NamidaStorageFileMemeType.any || null => null,
      };
  final extensions = extensionsWrappers?.expand((e) => e.extensions).toFixedList();
  final hasExtensions = extensions != null && extensions.isNotEmpty;
  final FileType fileType;
  if (hasExtensions) {
    fileType = FileType.custom;
  } else if (memetype == NamidaStorageFileMemeType.image) {
    fileType = FileType.image;
  } else {
    fileType = FileType.any;
  }
  final customExtensions = hasExtensions ? extensions : null;
  if (!multiple) {
    final file = await FilePicker.pickFile(
      dialogTitle: note,
      type: fileType,
      allowedExtensions: customExtensions,
      initialDirectory: initialDirectory,
    );
    final path = file?.path;
    return path == null ? <String>[] : [path];
  }
  final res = await FilePicker.pickFiles(
    dialogTitle: note,
    type: fileType,
    allowedExtensions: customExtensions,
    initialDirectory: initialDirectory,
  );
  return res?.paths.whereType<String>().toFixedList() ?? <String>[];
}

class _PickedDirectories {
  final List<String> paths;

  /// path dart last acknowledged -> where the folder is now.
  final Map<String, String> moved;

  const _PickedDirectories({required this.paths, required this.moved});

  factory _PickedDirectories.fromMap(Map<String, Object?> map) {
    final paths = map['paths'] as List?;
    final moved = map['moved'] as Map?;
    final pathsList = paths?.cast<String>();
    final movedMap = moved?.cast<String, String>();
    return _PickedDirectories(
      paths: pathsList ?? const [],
      moved: movedMap ?? const {},
    );
  }
}

class _StoragePathsState {
  final String containerRoot;
  final Map<String, String> appliedPickedMoves;
  final Map<String, String> retryMoves;

  /// relative to the user data folder.
  final List<String> retryFiles;

  const _StoragePathsState({
    required this.containerRoot,
    required this.appliedPickedMoves,
    required this.retryMoves,
    required this.retryFiles,
  });

  /// null when missing or invalid, a root that isn't absolute would rewrite paths that were never there.
  static _StoragePathsState? fromJson(Object? json) {
    if (json is! Map) return null;
    final containerRoot = json['containerRoot'];
    if (containerRoot is! String || !containerRoot.startsWith('/')) return null;
    return _StoragePathsState(
      containerRoot: containerRoot,
      appliedPickedMoves: _toStringsMap(json['appliedPickedMoves']),
      retryMoves: _toStringsMap(json['retryMoves']),
      retryFiles: _toStringsList(json['retryFiles']),
    );
  }

  static Map<String, String> _toStringsMap(Object? value) {
    final map = <String, String>{};
    if (value is! Map) return map;
    for (final entry in value.entries) {
      final key = entry.key;
      final entryValue = entry.value;
      if (key is String && entryValue is String) map[key] = entryValue;
    }
    return map;
  }

  static List<String> _toStringsList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toFixedList();
  }

  Map<String, Object> toJson() => {
    'containerRoot': containerRoot,
    if (appliedPickedMoves.isNotEmpty) 'appliedPickedMoves': appliedPickedMoves,
    if (retryFiles.isNotEmpty) 'retryMoves': retryMoves,
    if (retryFiles.isNotEmpty) 'retryFiles': retryFiles,
  };

  /// written aside then renamed, a kill midway keeps the previous state whole.
  Future<bool> writeAtomic(File file) async {
    final tempFile = File('${file.path}.tmp');
    final writtenFile = await tempFile.writeAsJson(toJson(), flush: true);
    if (writtenFile == null) return false;
    try {
      await writtenFile.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}

typedef _StoragePathsMigrationParams = ({
  String directory,
  Set<String> skippedDirectories,
  Map<String, String> moves,
  Map<String, String> retryMoves,
  List<String> retryFiles,
});
