part of 'zip_manager.dart';

class _ZipManagerNative extends ZipManager {
  @override
  Future<void> createZip({
    required Directory sourceDir,
    required List<File> files,
    required File zipFile,
    bool includeBaseDirectory = false,
  }) => ZipFile.createFromFiles(
    sourceDir: sourceDir,
    files: files,
    zipFile: zipFile,
    includeBaseDirectory: includeBaseDirectory,
  );

  @override
  Future<void> createZipFromDirectory({
    required Directory sourceDir,
    required File zipFile,
  }) => ZipFile.createFromDirectory(
    sourceDir: sourceDir,
    zipFile: zipFile,
    recurseSubDirs: true,
    includeBaseDirectory: false,
  );

  @override
  Future<void> extractZip({
    required File zipFile,
    required Directory destinationDir,
  }) => ZipFile.extractToDirectory(
    zipFile: zipFile,
    destinationDir: destinationDir,
  );
}
