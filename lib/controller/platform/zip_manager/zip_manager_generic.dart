part of 'zip_manager.dart';

class _ZipManagerGeneric extends ZipManager {
  @override
  Future<void> createZip({
    required Directory sourceDir,
    required List<File> files,
    required File zipFile,
    bool includeBaseDirectory = false,
  }) async {
    return Isolate.run(
      () {
        final encoder = ZipFileEncoder();
        try {
          encoder.create(zipFile.path);
          for (var file in files) {
            encoder.addFileSync(file);
          }
        } finally {
          encoder.closeSync();
        }
      },
    );
  }

  @override
  Future<void> createZipFromDirectory({
    required Directory sourceDir,
    required File zipFile,
  }) {
    return Isolate.run(
      () async {
        final encoder = ZipFileEncoder();
        try {
          encoder.create(zipFile.path);
          await encoder.addDirectory(sourceDir, includeDirName: false);
        } finally {
          encoder.closeSync();
        }
      },
    );
  }

  @override
  Future<void> extractZip({
    required File zipFile,
    required Directory destinationDir,
  }) => Isolate.run(
    () async {
      final outputPath = destinationDir.path;

      final input = InputFileStream(zipFile.path);
      final archive = ZipDecoder().decodeStream(input);
      try {
        for (final file in archive) {
          try {
            final filePath = path.join(outputPath, path.normalize(file.name));
            if (!_isWithinOutputPath(outputPath, filePath)) {
              continue;
            }

            if (file.isDirectory && !file.isSymbolicLink) {
              Directory(filePath).createSync(recursive: true);
              continue;
            }

            if (file.isFile) {
              final output = OutputFileStream(filePath);
              try {
                file.writeContent(output);
              } catch (_) {
              } finally {
                await output.close();
              }
            }
          } catch (_) {
            // file name too long for example, or contains illegal chars on this platform
          }
        }
      } finally {
        await input.close();
        await archive.clear();
      }
    },
  );

  static bool _isWithinOutputPath(String outputDir, String filePath) {
    return path.isWithin(path.canonicalize(outputDir), path.canonicalize(filePath));
  }
}
