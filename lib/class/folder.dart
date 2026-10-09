// ignore_for_file: unnecessary_this

import 'dart:io';

import 'package:namida/class/file_parts.dart';
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
  bool get isNetwork => path.startsWith('http');
  bool get isNetworkRoot => isNetwork && !path.contains(_kNetworkFolderSeparator);

  final String path;
  final String folderNameRaw;
  final String _key;

  late final parts = splitParts();
  late final folderNameLower = folderNameRaw.toLowerCase();

  Folder.explicit(this.path) : folderNameRaw = nameOf(path), _key = _computeKey(path);

  static const _kNetworkFolderSeparator = '#';

  static String networkPathOf(String serverKey, String? serverFolder) {
    return serverFolder == null ? serverKey : '$serverKey$_kNetworkFolderSeparator$serverFolder';
  }

  static String nameOf(String path) {
    if (path.startsWith('http')) {
      final serverFolderStart = path.indexOf(_kNetworkFolderSeparator) + 1;
      if (serverFolderStart > 0) {
        final lastSlash = path.lastIndexOf('/');
        final nameStart = lastSlash >= serverFolderStart ? lastSlash + 1 : serverFolderStart;
        return path.substring(nameStart);
      }
    }
    return path.pathReverseSplitter(_pathSeparator);
  }

  static final _nameCountsTracks = _FolderNameCounts();
  static final _nameCountsVideos = _FolderNameCounts();
  static final _extraInfoCache = <Folder, String>{};

  static void invalidateCaches() {
    _nameCountsTracks.invalidate();
    _nameCountsVideos.invalidate();
    _extraInfoCache.clear();
  }

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

  String folderNameAvoidingConflicts() {
    Folder folder = this;
    int retries = 0;
    String folderName = folder.folderNameTryFormatNetwork();
    while (folder.hasSimilarFolderNames) {
      final newParent = folder.parent;
      if (newParent.path == folder.path) {
        break;
      }
      folder = newParent;
      final parentName = folder.isNetworkRoot ? folder.formattedPath() : folder.folderNameRaw;
      final separator = folder.isNetwork ? '/' : Platform.pathSeparator;
      folderName = '$parentName$separator$folderName';

      retries++;
      if (retries >= 3) {
        // -- more than 3 duplicates, return full path
        return formattedPath();
      }
    }
    return folderName;
  }

  String folderNameTryFormatNetwork() {
    final parts = folderNameTryFormatNetworkAsParts();
    if (parts != null && parts.isNotEmpty) {
      return parts.join('\n');
    }
    return folderNameRaw;
  }

  List<String>? folderNameTryFormatNetworkAsParts() {
    if (isNetworkRoot) {
      try {
        final server = DirectoryIndexServer.parseFromEncodedUrlPath(path);
        return [
          server.toSourceInfo(),
          server.toTypeAndUserInfo(),
        ];
      } catch (_) {}
    }
    return null;
  }

  DirectoryIndexServer? parseNetworkServer() => isNetwork ? _parseNetworkServer() : null;

  DirectoryIndexServer _parseNetworkServer() {
    final serverFolderSeparatorIndex = path.indexOf(_kNetworkFolderSeparator);
    final serverKey = serverFolderSeparatorIndex == -1 ? path : path.substring(0, serverFolderSeparatorIndex);
    return DirectoryIndexServer.parseFromEncodedUrlPath(serverKey);
  }

  String formattedPath() {
    if (!isNetwork) return path.formatPath();
    final sourceInfo = _parseNetworkServer().toSourceInfo();
    final serverFolderStart = path.indexOf(_kNetworkFolderSeparator) + 1;
    if (serverFolderStart == 0) return sourceInfo;
    final serverFolder = path.substring(serverFolderStart);
    return '$sourceInfo/$serverFolder';
  }

  String formattedParentPath() {
    if (isNetwork) {
      if (isNetworkRoot) return '';
      final parentPath = this.parent.formattedPath();
      return '$parentPath/';
    }
    final nameStart = path.lastIndexOf(folderNameRaw);
    return nameStart <= 0 ? '' : path.substring(0, nameStart).formatPath();
  }

  String? getExtraInfoOrFetch(void Function() onFetched) {
    if (isNetwork) return null;
    final cached = _extraInfoCache[this];
    if (cached != null) return cached;
    _fetchExtraInfo().then(
      (value) {
        _extraInfoCache[this] = value;
        if (value.isNotEmpty) onFetched();
      },
    );
    return null;
  }

  Future<String> _fetchExtraInfo() async {
    final file = FileParts.join(path, '.info.txt');
    if (await file.exists()) {
      try {
        return await file.readAsString();
      } catch (_) {}
    }
    return '';
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
    if (isNetwork) {
      final serverFolderStart = path.indexOf(Folder._kNetworkFolderSeparator) + 1;
      if (serverFolderStart == 0) return this;
      final lastSlash = path.lastIndexOf('/');
      final parentEnd = lastSlash >= serverFolderStart ? lastSlash : serverFolderStart - 1;
      final networkParentPath = path.substring(0, parentEnd);
      return Folder.fromTypeParameter<T>(this.runtimeType, networkParentPath);
    }
    final parentPath = FileSystemEntity.parentOf(path);
    return Folder.fromTypeParameter(this.runtimeType, parentPath) as T;
  }

  /// Checks if any other folders inside library have the same name.
  ///
  /// Can be heplful to display full path in such case.
  bool get hasSimilarFolderNames {
    final counts = this is VideoFolder ? Folder._nameCountsVideos : Folder._nameCountsTracks;
    return (counts.of(_mainFoldersMapDedicated)[folderNameLower] ?? 0) > 1;
  }

  bool hasSamePathAs(String path) {
    final f = Folder.explicit(path);
    return f._key == this._key;
  }

  R? performInbetweenFoldersBuild<R>(R? Function(T folder) callback) {
    if (isNetwork) {
      final serverFolderStart = path.indexOf(Folder._kNetworkFolderSeparator) + 1;
      if (serverFolderStart == 0) return callback(this);
      final serverKey = path.substring(0, serverFolderStart - 1);
      final rootRes = callback(Folder.fromType<T>(serverKey));
      if (rootRes != null) return rootRes;
      int searchFrom = serverFolderStart;
      while (true) {
        final slashIndex = path.indexOf('/', searchFrom);
        if (slashIndex == -1) return callback(this);
        final partPath = path.substring(0, slashIndex);
        final res = callback(Folder.fromType<T>(partPath));
        if (res != null) return res;
        searchFrom = slashIndex + 1;
      }
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

// by claude
class _FolderNameCounts {
  Map<Folder, Object?>? _mapRef;
  int _mapLength = -1;
  Map<String, int> _counts = const {};

  void invalidate() => _mapRef = null;

  Map<String, int> of(Map<Folder, Object?> map) {
    if (!identical(map, _mapRef) || map.length != _mapLength) {
      final counts = <String, int>{};
      for (final k in map.keys) {
        counts.update(k.folderNameLower, (v) => v + 1, ifAbsent: () => 1);
      }
      _counts = counts;
      _mapRef = map;
      _mapLength = map.length;
    }
    return _counts;
  }
}
