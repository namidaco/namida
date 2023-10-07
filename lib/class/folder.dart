import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class Folder {
  final String path;

  const Folder(this.path);

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
  String get folderNameRaw => path.split(Platform.pathSeparator).last;

  /// Checks if any other folders inside library have the same name.
  ///
  /// Can be heplful to display full path in such case.
  bool get hasSimilarFolderNames {
    return Indexer.inst.mainMapFolders.keys.where((element) => element.folderNameRaw == folderNameRaw).length > 1;
  }

  String get folderName {
    if (kStoragePaths.contains(path)) {
      return path.formatPath();
    }

    final parentFolder = getParentFolder()?.path;
    if (parentFolder != null) {
      final parts = path.replaceFirst(parentFolder, '').split(Platform.pathSeparator);
      parts.removeWhere((element) => element == '');
      final isNested = parts.length > 1;
      if (isNested) {
        final nestedPath = parts.join(Platform.pathSeparator);
        return nestedPath.formatPath();
      }
    }

    return folderNameRaw;
  }

  List<Track> get tracks => Indexer.inst.mainMapFolders[this] ?? [];

  /// [fullyFunctional] returns the first parent folder that has different subfolders obtained by [getDirectoriesInside].
  ///
  /// Otherwise, it checks for the first parent folder that exists in [Indexer.inst.mainMapFolders].
  /// less accurate but more performant, since its being used by [folderName].
  Folder? getParentFolder({bool fullyFunctional = false}) {
    final parts = path.split(Platform.pathSeparator);

    while (parts.isNotEmpty) {
      parts.removeLast();
      final f = Folder(parts.join(Platform.pathSeparator));
      if (f.tracks.isNotEmpty) return f;
    }
    if (fullyFunctional) {
      if (!kStoragePaths.contains(path)) {
        if (Folder(parentPath).getDirectoriesInside().length > 1) {
          return Folder(parentPath);
        }
      }
    }

    // if (fullyFunctional) {
    //   final newParts = path.split(Platform.pathSeparator);
    //   final currentDirs = getDirectoriesInside();

    //   while (newParts.isNotEmpty) {
    //     newParts.removeLast();
    //     final f = Folder(newParts.join(Platform.pathSeparator));

    //     if (!f.getDirectoriesInside().isEqualTo(currentDirs)) {
    //       return f;
    //     }
    //   }
    // }

    return null;
  }

  /// Gets directories inside [this] folder, automatically handles nested folders.
  List<Folder> getDirectoriesInside() {
    final allFolders = Indexer.inst.mainMapFolders.keys;
    final allInside = <Folder>[];

    allInside.addAll(
      allFolders.where((key) {
        final f = key.path.split(Platform.pathSeparator);
        f.removeLast();
        String newPath() => f.join(Platform.pathSeparator);
        bool isSamePath() => newPath() == path;

        /// maintains nested loops (folder doesnt exist in library but subfolder exists).
        while (f.isNotEmpty && !isSamePath() && Folder(newPath()).tracks.isEmpty) {
          f.removeLast();
        }

        return isSamePath();
      }),
    );

    allInside.sortBy((e) => e.folderName.toLowerCase());

    return allInside;
  }
}
