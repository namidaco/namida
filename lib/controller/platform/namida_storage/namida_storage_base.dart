part of 'namida_storage.dart';

abstract class NamidaStorage {
  const NamidaStorage(this.defaultFallbackStoragePath);

  static final NamidaStorage inst = NamidaStorage._platform();

  static NamidaStorage _platform() {
    return NamidaPlatformBuilder.init(
      android: _NamidaStorageAndroid._init,
      windows: () => isWindowsPortable ? _NamidaStorageWindowsPortable() : const _NamidaStorageWindowsInstallation(),
      linux: () => const _NamidaStorageLinux(),
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
