part of 'zip_manager.dart';

class _ZipManagerGeneric extends ZipManager {
  @override
  Future<void> createZip({
    required Directory sourceDir,
    required List<File> files,
    required File zipFile,
    bool includeBaseDirectory = false,
  }) async {
    final entriesRootPath = includeBaseDirectory ? sourceDir.parent.path : sourceDir.path;
    return Isolate.run(
      () {
        final encoder = ZipFileEncoder();
        try {
          encoder.create(zipFile.path);
          for (var file in files) {
            final entryName = path.relative(file.path, from: entriesRootPath);
            _addFileSkippingDeleted(encoder, file, entryName);
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
      () {
        final encoder = ZipFileEncoder();
        try {
          encoder.create(zipFile.path);
          final sourceDirPath = sourceDir.path;
          for (final entity in sourceDir.listSync(recursive: true)) {
            final relativePath = path.relative(entity.path, from: sourceDirPath);
            if (entity is File) {
              _addFileSkippingDeleted(encoder, entity, relativePath);
            } else if (entity is Directory) {
              final relativeUri = path.toUri(relativePath);
              final entryName = path.posix.fromUri(relativeUri);
              final directoryEntry = ArchiveFile.directory(entryName);
              encoder.addArchiveFile(directoryEntry);
            }
          }
        } finally {
          encoder.closeSync();
        }
      },
    );
  }

  static void _addFileSkippingDeleted(ZipFileEncoder encoder, File file, String entryName) {
    try {
      encoder.addFileSync(file, entryName);
    } on PathNotFoundException catch (_) {}
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
