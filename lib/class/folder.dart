// ignore_for_file: unnecessary_this

import 'dart:io';

import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';

final _pathSeparator = Platform.pathSeparator;

class VideoFolder extends Folder {
  VideoFolder.explicit(super.path) : super.explicit();

  @override
  String toString() => "VideoFolder(path: $path, tracks: ${tracksDedicated().length})";
}

class Folder {
  bool get isNetwork => folderNameRaw.startsWith('http') || folderNameRaw.contains('namida_t=');

  final String path;
  final String folderNameRaw;
  final String _key;

  late final parts = splitParts();

  Folder.explicit(this.path) : folderNameRaw = path.pathReverseSplitter(_pathSeparator), _key = _computeKey(path);

  static T fromType<T extends Folder>(String path) {
    return T == VideoFolder ? VideoFolder.explicit(path) as T : Folder.explicit(path) as T;
  }

  static T fromTypeParameter<T extends Folder>(Type type, String path) {
    return type == VideoFolder ? VideoFolder.explicit(path) as T : Folder.explicit(path) as T;
  }

  static String _computeKey(String path) {
    final addAtFirst = !path.startsWith(_pathSeparator);
    final addAtLast = !path.endsWith(_pathSeparator);
    return "${addAtFirst ? _pathSeparator : ''}$path${addAtLast ? _pathSeparator : ''}";
  }

  // bool isParentOf(Folder child) {
  //   if (child._key.startsWith(this._key)) {
  //     return true;
  //   }
  //   return false;
  // }

  // /// [parentSplitsCount] can be obtained by [splitParts].
  // bool isDirectParentOf(Folder child, int parentSplitsCount) {
  //   if (isParentOf(child)) {
  //     final folderSplitsCount = child.splitParts().length;
  //     if (folderSplitsCount == parentSplitsCount + 1) {
  //       return true;
  //     }
  //   }
  //   return false;
  // }

  List<String> splitParts() => _key.split(_pathSeparator);

  String folderNameAvoidingConflicts() => hasSimilarFolderNames ? formattedPath() : folderNameTryFormatNetwork();

  String folderNameTryFormatNetwork() {
    final parts = folderNameTryFormatNetworkAsParts();
    if (parts != null && parts.isNotEmpty) {
      return parts.join('\n');
    }
    return folderNameRaw;
  }

  List<String>? folderNameTryFormatNetworkAsParts() {
    if (isNetwork) {
      try {
        final server = DirectoryIndexServer.parseFromEncodedUrlPath(folderNameRaw);
        return [
          server.toSourceInfo(),
          [
            server.type.toText(),
            server.username,
          ].join(' - '),
        ];
      } catch (_) {}
    }
    return null;
  }

  String formattedPath() {
    // -- aint no formatting hehe
    return path;
  }

  @override
  bool operator ==(other) {
    return other is Folder && _key == other._key;
  }

  @override
  int get hashCode => _key.hashCode;

  @override
  String toString() => "Folder(path: $path)";
}

extension FolderUtils<T extends Folder, E extends Track> on T {
  Map<T, List<E>> get _mainFoldersMapDedicated {
    return this is VideoFolder ? Indexer.inst.mainMapFoldersVideos.value as Map<T, List<E>> : Indexer.inst.mainMapFoldersTracks.value as Map<T, List<E>>;
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
    var thisfolderLower = folderNameRaw.toLowerCase();
    for (final k in _mainFoldersMapDedicated.keys) {
      if (k.folderNameRaw.toLowerCase() == thisfolderLower) {
        count++;
        if (count > 1) return true;
      }
    }
    return false;
  }

  bool hasSamePathAs(String path) {
    final f = Folder.explicit(path);
    return f._key == this._key;
  }

  R? performInbetweenFoldersBuild<R>(R? Function(T folder) callback) {
    if (isNetwork) {
      return callback(Folder.fromType<T>(path));
    }
    final bufferPathSoFar = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) continue;
      bufferPathSoFar.write(part);
      bufferPathSoFar.write(Platform.pathSeparator);
      final f = Folder.fromType<T>(bufferPathSoFar.toString());
      final res = callback(f);
      if (res != null) return res;
    }
    return null;
  }

  List<E> tracksDedicated() => _mainFoldersMapDedicated[this] ?? [];
}
