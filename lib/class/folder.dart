// ignore_for_file: unnecessary_this

import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';

final _pathSeparator = Platform.pathSeparator;

class Folder {
  final String path;
  late final String folderName;
  late final String _key;

  Folder(this.path)
      : folderName = path.pathReverseSplitter(_pathSeparator),
        _key = _computeKey(path);

  static String _computeKey(String path) {
    final addAtFirst = !path.startsWith(_pathSeparator);
    if (!path.endsWith(_pathSeparator)) path += _pathSeparator;
    return addAtFirst ? "$_pathSeparator$path" : path;
  }

  bool isParentOf(Folder child) {
    if (child._key.startsWith(this._key)) {
      return true;
    }
    return false;
  }

  /// [parentSplitsCount] can be obtained by [splitParts].
  bool isDirectParentOf(Folder child, int parentSplitsCount) {
    if (isParentOf(child)) {
      final folderSplitsCount = child.splitParts().length;
      if (folderSplitsCount == parentSplitsCount + 1) {
        return true;
      }
    }
    return false;
  }

  List<String> splitParts() => _key.split(_pathSeparator);

  @override
  bool operator ==(other) {
    if (other is Folder) {
      return _key == other._key;
    }
    return false;
  }

  @override
  int get hashCode => _key.hashCode;

  @override
  String toString() => "Folder(path: $path, tracks: ${tracks().length})";
}

extension FolderUtils on Folder {
  Folder get parent {
    final parentPath = FileSystemEntity.parentOf(path);
    return Folder(parentPath);
  }

  /// Checks if any other folders inside library have the same name.
  ///
  /// Can be heplful to display full path in such case.
  bool get hasSimilarFolderNames {
    int count = 0;
    for (final k in Indexer.inst.mainMapFolders.value.keys) {
      if (k.folderName == folderName) {
        count++;
        if (count > 1) return true;
      }
    }
    return false;
  }

  List<Track> tracks() => Indexer.inst.mainMapFolders.value[this] ?? [];

  Iterable<Track> tracksRecusive() sync* {
    for (final e in Indexer.inst.mainMapFolders.value.entries) {
      if (this.isParentOf(e.key)) {
        yield* e.value;
      }
    }
  }

  /// checks for the first parent folder that exists in [Indexer.mainMapFolders].
  Folder? getParentFolder() {
    final parts = path.split(_pathSeparator);
    parts.removeLast();

    while (parts.isNotEmpty) {
      final f = Folder(parts.join(_pathSeparator));
      if (Indexer.inst.mainMapFolders.value[f] != null) return f;
      parts.removeLast();
    }

    return null;
  }

  /// Gets directories inside [this] folder, automatically handles nested folders.
  List<Folder> getDirectoriesInside() {
    final foldersMap = Indexer.inst.mainMapFolders;
    final allInside = <Folder>[];

    final splitsCount = this.splitParts().length;

    for (final folder in foldersMap.value.keys) {
      if (this.isDirectParentOf(folder, splitsCount)) allInside.add(folder);
    }

    return allInside;
  }
}
