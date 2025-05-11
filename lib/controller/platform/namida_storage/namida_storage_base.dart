part of 'namida_storage.dart';

abstract class NamidaStorage {
  const NamidaStorage(this.defaultFallbackStoragePath);

  static final NamidaStorage inst = NamidaStorage._platform();

  static NamidaStorage _platform() {
    return NamidaPlatformBuilder.init(
      android: () => _NamidaStorageAndroid._init(),
      windows: () => const _NamidaStorageWindows(),
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
    String? memetype = NamidaStorageFileMemeType.any,
  });

  Future<String?> pickDirectory({String? note});
}

class NamidaStorageFileMemeType {
  static const image = "image/*";
  static const audio = "audio/*";
  static const video = "video/*";
  static const media = "$audio,$video";
  static const any = "*/*";
}
