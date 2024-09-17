// ignore_for_file: unnecessary_this

import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';

final _pathSeparator = Platform.pathSeparator;

class VideoFolder extends Folder {
  VideoFolder.explicit(super.path) : super.explicit();

  @override
  String toString() => "VideoFolder(path: $path, tracks: ${tracks().length})";
}

class Folder {
  final String path;
  final String folderName;
  final String _key;

  Folder.explicit(this.path)
      : folderName = path.pathReverseSplitter(_pathSeparator),
        _key = _computeKey(path);

  static T fromType<T extends Folder>(String path) {
    return T == VideoFolder ? VideoFolder.explicit(path) as T : Folder.explicit(path) as T;
  }

  static T fromTypeParameter<T extends Folder>(Type type, String path) {
    return type == VideoFolder ? VideoFolder.explicit(path) as T : Folder.explicit(path) as T;
  }

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

  String folderNameAvoidingConflicts() => hasSimilarFolderNames ? path.formatPath() : folderName;

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

extension FolderUtils<T extends Folder, E extends Track> on Folder {
  Map<T, List<E>> get _mainFoldersMap {
    return this is VideoFolder ? Indexer.inst.mainMapFoldersVideos.value as Map<T, List<E>> : Indexer.inst.mainMapFolders.value as Map<T, List<E>>;
  }

  Folders get _controller {
    return this is VideoFolder ? Folders.videos : Folders.tracks;
  }

  void navigate() {
    _controller.stepIn(this);
  }

  T get parent {
    final parentPath = FileSystemEntity.parentOf(path);
    return Folder.fromTypeParameter(this.runtimeType, parentPath) as T;
  }

  /// Checks if any other folders inside library have the same name.
  ///
  /// Can be heplful to display full path in such case.
  bool get hasSimilarFolderNames {
    int count = 0;
    var thisfolderLower = folderName.toLowerCase();
    for (final k in _mainFoldersMap.keys) {
      if (k.folderName.toLowerCase() == thisfolderLower) {
        count++;
        if (count > 1) return true;
      }
    }
    return false;
  }

  List<E> tracks() => _mainFoldersMap[this] ?? [];

  Iterable<E> tracksRecusive() sync* {
    for (final e in _mainFoldersMap.entries) {
      if (this.isParentOf(e.key)) {
        yield* e.value;
      }
    }
  }

  /// checks for the first parent folder that exists in [Indexer.mainMapFolders].
  T? getParentFolder() {
    final parts = path.split(_pathSeparator);
    parts.removeLast();

    while (parts.isNotEmpty) {
      final f = Folder.fromTypeParameter(this.runtimeType, parts.join(_pathSeparator));
      if (_mainFoldersMap[f] != null) return f as T;
      parts.removeLast();
    }

    return null;
  }

  /// Gets directories inside [this] folder, automatically handles nested folders.
  List<F> getDirectoriesInside<F extends Folder>() {
    final allInside = <F>[];

    final splitsCount = this.splitParts().length;

    for (final folder in _mainFoldersMap.keys) {
      if (this.isDirectParentOf(folder, splitsCount)) allInside.add(folder as F);
    }

    return allInside;
  }
}
