part of 'namida_storage.dart';

abstract class NamidaStorage {
  const NamidaStorage(this.defaultFallbackStoragePath);

  static final NamidaStorage inst = NamidaStorage._platform();

  static NamidaStorage _platform() {
    return NamidaPlatformBuilder.init(
      android: _NamidaStorageAndroid._init,
      ios: _NamidaStorageIOS._init,
      windows: () => isWindowsPortable ? _NamidaStorageWindowsPortable() : const _NamidaStorageWindowsInstallation(),
      linux: () => const _NamidaStorageLinux(),
      macos: () => const _NamidaStorageMacOS(),
    );
  }

  final String? defaultFallbackStoragePath;

  String getUserDataDirectory(List<String> appDataDirectories);

  Future<List<String>> getStorageDirectories();

  Future<List<String>> getStorageDirectoriesAppData();

  Future<List<String>> getStorageDirectoriesAppCache();

  Future<String?> getRealPath(String? contentUri);

  Future<List<String>> pickFiles({
    String? note,
    bool multiple = false,
    List<NamidaFileExtensionsWrapper>? allowedExtensions,
    NamidaStorageFileMemeType? memetype = NamidaStorageFileMemeType.any,
    String? initialDirectory,
  });

  Future<String?> pickDirectory({String? note, String? initialDirectory});

  /// runs once the user data folders exist, before anything reads them. ex: rewrites stored paths whose folder moved since the last launch.
  Future<void> prepareUserData() async {}

  /// written next to a backup's entries, tells [prepareRestoredUserData] where the backed up paths lived.
  Future<File?> writeBackupStorageOrigin(String directoryPath) async => null;

  /// runs on restored user data before it's merged in. ex: rewrites the paths of the container the backup was made in.
  Future<void> prepareRestoredUserData(String directoryPath) async {}

  /// once settings are ready: keeps the library folders downloaded.
  Future<void> initPickedDirectories() async {}

  /// a folder the user removed from the library, its access goes unless something else still points into it.
  Future<void> releaseLibraryDirectory(String path) async {}

  @visibleForTesting
  static String? debugRewriteMovedPaths(String text, Map<String, String> moves) {
    final migrator = _StoragePathsMigrator.create(moves);
    return migrator?.rewriteText(text);
  }

  @visibleForTesting
  static ({int changedCount, List<String> failedFiles}) debugMigrateMovedPaths(String directoryPath, Map<String, String> moves, {Set<String> skippedDirectories = const {}}) {
    final migrator = _StoragePathsMigrator.create(moves);
    final result = migrator?.migrateDirectorySync(directoryPath, skippedDirectories: skippedDirectories);
    final changedCount = result?.changedCount ?? 0;
    final failedFiles = result?.failedFiles ?? const <String>[];
    return (changedCount: changedCount, failedFiles: failedFiles);
  }

  Future<bool> safHasAccess(String path) async => false;
  Future<bool> safRequestAccess(String path, {String? note}) async => false;
  Future<String?> safCopyFile(String sourcePath, String destPath) async => 'SAF is not supported on this platform';

  Future<String?> safPickTree({String? note}) async => null;
  Future<bool> safTreeHasAccess(String treeUri) async => false;
  Future<SafTreeListing?> safListTree(String treeUri) async => null;
  Future<String?> safCopyDocument(String documentUri, String destPath) async => 'SAF is not supported on this platform';
}

/// files under a document tree as parallel lists, [dirIndices] point into [dirs] (parent document ids) and [dirPaths] (their `/` separated paths inside the tree).
class SafTreeListing {
  final List<String> ids;
  final List<String> names;
  final List<int> sizes;
  final List<int> modifiedMS;
  final List<int> dirIndices;
  final List<String> dirs;
  final List<String> dirPaths;

  const SafTreeListing({
    required this.ids,
    required this.names,
    required this.sizes,
    required this.modifiedMS,
    required this.dirIndices,
    required this.dirs,
    required this.dirPaths,
  });

  factory SafTreeListing.fromMap(Map<String, Object?> map) => SafTreeListing(
    ids: List<String>.from(map['ids'] as List, growable: false),
    names: List<String>.from(map['names'] as List, growable: false),
    sizes: List<int>.from(map['sizes'] as List, growable: false),
    modifiedMS: List<int>.from(map['modified'] as List, growable: false),
    dirIndices: List<int>.from(map['dirIndices'] as List, growable: false),
    dirs: List<String>.from(map['dirs'] as List, growable: false),
    dirPaths: List<String>.from(map['dirPaths'] as List, growable: false),
  );

  int get length => ids.length;
}

enum NamidaStorageFileMemeType {
  image("image/*"),
  audio("audio/*"),
  video("video/*"),
  media("audio/*,video/*"),
  any("*/*"),
  ;

  final String type;
  const NamidaStorageFileMemeType(this.type);
}
