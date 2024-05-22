// ignore_for_file: unnecessary_this

import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';

final _pathSeparator = Platform.pathSeparator;

class Folder {
  final String path;
  late final String folderName;

  Folder(this.path) : folderName = path.pathReverseSplitter(_pathSeparator);

  @override
  bool operator ==(other) {
    if (other is Folder) {
      return path == other.path;
    }
    return false;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => "Folder(path: $path, tracks: ${tracks.length})";
}

extension FolderUtils on Folder {
  String get parentPath => path.withoutLast(Platform.pathSeparator);

  /// Checks if any other folders inside library have the same name.
  ///
  /// Can be heplful to display full path in such case.
  bool get hasSimilarFolderNames {
    int count = 0;
    for (final k in Indexer.inst.mainMapFolders.keys) {
      if (k.folderName == folderName) {
        count++;
        if (count > 1) return true;
      }
    }
    return false;
  }

  List<Track> get tracks => Indexer.inst.mainMapFolders[this] ?? [];
  Iterable<Track> get tracksRecusive sync* {
    for (final e in Indexer.inst.mainMapFolders.entries) {
      if (e.key.path.startsWith(this.path)) {
        yield* e.value;
      }
    }
  }

  /// checks for the first parent folder that exists in [Indexer.mainMapFolders].
  Folder? getParentFolder() {
    final parts = path.split(Platform.pathSeparator);
    parts.removeLast();

    while (parts.isNotEmpty) {
      final f = Folder(parts.join(Platform.pathSeparator));
      if (Indexer.inst.mainMapFolders[f] != null) return f;
      parts.removeLast();
    }

    return null;
  }

  /// Gets directories inside [this] folder, automatically handles nested folders.
  List<Folder> getDirectoriesInside() {
    final foldersMap = Indexer.inst.mainMapFolders;
    final allInside = <Folder>[];

    final splitsCount = this.path.split(Platform.pathSeparator).length;

    for (final folder in foldersMap.keys) {
      if (folder.path.startsWith(this.path)) {
        final folderSplitsCount = folder.path.split(Platform.pathSeparator).length;
        if (folderSplitsCount == splitsCount + 1) {
          allInside.add(folder);
        }
      }
    }

    return allInside;
  }
}
