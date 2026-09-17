part of 'zip_manager.dart';

abstract class ZipManager {
  static ZipManager platform() {
    return NamidaPlatformBuilder.init(
      android: _ZipManagerNative.new,
      ios: _ZipManagerNative.new,
      macos: _ZipManagerNative.new,
      windows: _ZipManagerGeneric.new,
      linux: _ZipManagerGeneric.new,
    );
  }

  Future<void> createZip({
    required Directory sourceDir,
    required List<File> files,
    required File zipFile,
    bool includeBaseDirectory = false,
  });

  Future<void> createZipFromDirectory({
    required Directory sourceDir,
    required File zipFile,
  });

  Future<void> extractZip({
    required File zipFile,
    required Directory destinationDir,
  });
}
