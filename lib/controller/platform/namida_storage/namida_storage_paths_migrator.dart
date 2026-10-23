part of 'namida_storage.dart';

// by claude
/// rewrites the absolute paths namida stored after the folder holding them moved.
/// ex: the ios app container, its path changes when the app is reinstalled or updated (every sideload refresh).
class _StoragePathsMigrator {
  final Map<String, String> _moves;
  final List<String> _oldPaths;
  final RegExp _movedPathRegex;

  _StoragePathsMigrator._(this._moves, this._oldPaths, this._movedPathRegex);

  /// matches a path only up to where it ends: a separator, a closing quote, an escape or a line break.
  static const _kPathEndLookahead = r'(?=[/"\\\n\r]|$)';

  /// null when no move is valid. both sides have to be absolute folder paths without a trailing separator.
  static _StoragePathsMigrator? create(Map<String, String> moves) {
    final validMoves = <String, String>{};
    for (final move in moves.entries) {
      final oldPath = move.key;
      final newPath = move.value;
      final isValid = _isFolderPath(oldPath) && _isFolderPath(newPath) && oldPath != newPath;
      if (!isValid) continue;
      validMoves[oldPath] = newPath;
    }
    if (validMoves.isEmpty) return null;
    final oldPaths = validMoves.keys.toFixedList()..sortByReverse((e) => e.length);
    final alternatives = oldPaths.map(RegExp.escape).join('|');
    // -- longest first so a moved folder inside another moved one matches whole, `/Music` never matches inside `/Music Videos`
    final regex = RegExp('(?:$alternatives)$_kPathEndLookahead');
    return _StoragePathsMigrator._(validMoves, oldPaths, regex);
  }

  static bool _isFolderPath(String path) => path.length > 1 && path.startsWith('/') && !path.endsWith('/');

  static const _kTextExtensions = {'json', 'm3u', 'm3u8'};
  static const _kDatabaseExtension = 'db';
  static const _kTempFileSuffix = '.tmp';
  static const _kMarkMovedFunctionName = 'namida_mark_moved_paths';

  /// moved values carry it between the two passes, it can't be part of a real value.
  static const _kMovedMarker = '\u0001namida-moved\u0001';

  /// null when nothing changed.
  String? rewriteText(String text) {
    bool didRewrite = false;
    final rewritten = text.replaceAllMapped(_movedPathRegex, (match) {
      didRewrite = true;
      return _moves[match[0]]!;
    });
    return didRewrite ? rewritten : null;
  }

  /// [skippedDirectories] are folders holding no paths (artworks, caches), ending with a separator like [AppDirs] has them.
  _StoragePathsMigrationResult migrateDirectorySync(String directoryPath, {required Set<String> skippedDirectories}) {
    final result = _StoragePathsMigrationResult();
    _migrateDirectoryRecursiveSync(Directory(directoryPath), skippedDirectories, result);
    return result;
  }

  void _migrateDirectoryRecursiveSync(Directory directory, Set<String> skippedDirectories, _StoragePathsMigrationResult result) {
    for (final entity in directory.listSyncSafe(followLinks: false)) {
      final path = entity.path;
      if (entity is Directory) {
        final isSkipped = skippedDirectories.contains('$path${Platform.pathSeparator}');
        if (!isSkipped) _migrateDirectoryRecursiveSync(entity, skippedDirectories, result);
        continue;
      }
      if (entity is! File) continue;
      try {
        final didChange = migrateFileSync(path);
        if (didChange) result.changedCount++;
      } catch (_) {
        result.failedFiles.add(path);
      }
    }
  }

  /// encrypted dbs have no extension and hold no paths, everything else namida keeps is json.
  /// throws when the file couldn't be read or written.
  bool migrateFileSync(String path) {
    final extension = path.getExtension.toLowerCase();
    if (extension == _kDatabaseExtension) return _migrateDatabaseSync(path);
    if (_kTextExtensions.contains(extension)) return _migrateTextFileSync(File(path));
    return false;
  }

  bool _migrateTextFileSync(File file) {
    final text = file.readAsStringSync();
    final rewritten = rewriteText(text);
    if (rewritten == null) return false;
    final tempFile = File('${file.path}$_kTempFileSuffix');
    tempFile.writeAsStringSync(rewritten, flush: true);
    tempFile.renameSync(file.path);
    return true;
  }

  /// rows move in two passes: marked first, then unmarked. in one pass a swap (a -> b while c -> a) would replace a row before it moved away.
  bool _migrateDatabaseSync(String path) {
    final db = sqlite3.open(path);
    try {
      int changedCount = 0;
      db.createFunction(
        functionName: _kMarkMovedFunctionName,
        argumentCount: const AllowedArgumentCount(1),
        function: (args) {
          final value = args[0];
          if (value is! String) return value;
          final rewritten = rewriteText(value);
          if (rewritten == null) return value;
          changedCount++;
          return '$_kMovedMarker$rewritten';
        },
      );
      const markerLength = _kMovedMarker.length;
      final tables = db.select("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
      db.execute('BEGIN');
      for (final tableRow in tables) {
        final table = tableRow['name'] as String;
        final columns = db.select('PRAGMA table_info("$table")');
        for (final columnRow in columns) {
          final type = (columnRow['type'] as String).toUpperCase();
          final isTextColumn = type.isEmpty || type.contains('TEXT') || type.contains('CHAR') || type.contains('CLOB');
          if (!isTextColumn) continue;
          final column = columnRow['name'] as String;
          final changedCountBefore = changedCount;
          final containsOldPath = List.filled(_oldPaths.length, 'instr("$column", ?) > 0').join(' OR ');
          // -- `/private/x` & `/x` both move to the same path, the same file can be stored under both
          db.execute('UPDATE OR REPLACE "$table" SET "$column" = $_kMarkMovedFunctionName("$column") WHERE $containsOldPath', _oldPaths);
          if (changedCount == changedCountBefore) continue;
          // -- the moved row wins a conflict, a row already at the new path can only be a re-index of the same file
          db.execute(
            'UPDATE OR REPLACE "$table" SET "$column" = substr("$column", ?) WHERE substr("$column", 1, ?) = ?',
            [markerLength + 1, markerLength, _kMovedMarker],
          );
        }
      }
      db.execute('COMMIT');
      return changedCount > 0;
    } catch (_) {
      if (!db.autocommit) db.execute('ROLLBACK');
      rethrow;
    } finally {
      db.close();
    }
  }
}

class _StoragePathsMigrationResult {
  int changedCount = 0;
  final failedFiles = <String>[];
}
