part of 'namida_storage.dart';

abstract class NamidaStorage {
  const NamidaStorage(this.defaultFallbackStoragePath);

  static final NamidaStorage inst = NamidaStorage._platform();

  static NamidaStorage _platform() {
    return NamidaPlatformBuilder.init(
      android: () => _NamidaStorageAndroid._init(),
      windows: () => const _NamidaStorageWindows(),
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
  });

  Future<String?> pickDirectory({String? note});
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
