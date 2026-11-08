import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

part 'dirs_file_filter.windows.dart';

class DirsFileFilter {
  final NamidaFileExtensionsWrapper extensions;
  final NamidaFileExtensionsWrapper? imageExtensions;

  /// collected into [DirsFileFilterResult.m3uPaths], .nomedia and [blacklistExtensions] don't apply.
  final NamidaFileExtensionsWrapper? m3uExtensions;
  final List<String>? blacklistExtensions;
  final bool strictNoMedia;
  final bool withStats;
  final bool useNativeLister;

  final List<DirectoryIndex> _directoriesToScan;
  final List<DirectoryIndex> _directoriesToExclude;
  final bool _respectNoMedia;

  DirsFileFilter({
    required this.extensions,
    this.imageExtensions,
    this.m3uExtensions,
    this.blacklistExtensions,
    this.strictNoMedia = true,
    this.withStats = false,
    this.useNativeLister = true,
  }) : _directoriesToScan = settings.directoriesToScan.value,
       _directoriesToExclude = settings.directoriesToExclude.value,
       _respectNoMedia = settings.respectNoMedia.value;

  Future<DirsFileFilterResult> filter() async {
    return await Isolate.run(() => _filterIsolate(this));
  }

  Future<DirsFileFilterResult> filterSync() => _filterIsolate(this);

  static Future<DirsFileFilterResult> _filterIsolate(DirsFileFilter parameters) async {
    if (parameters.useNativeLister && Platform.isWindows) {
      try {
        final walker = _WindowsDirsWalker(parameters);
        return walker.walk();
      } catch (_) {}
    }
    final walker = _DartDirsWalker(parameters);
    return walker.walk();
  }
}

// by claude
/// lists every directory once, one that can't be listed is skipped without dropping the rest.
abstract class _DirsWalker {
  final DirsFileFilter _parameters;
  final _DirsFilesCollector _collector;
  final _FilesStatsBuilder? _statsBuilder;

  _DirsWalker(this._parameters) : _collector = _DirsFilesCollector(_parameters), _statsBuilder = _parameters.withStats ? _FilesStatsBuilder(1024) : null;

  static const _kNoMediaFilename = '.nomedia';

  final _pendingDirs = <_PendingDir>[];
  final _visitedDirs = <String>{};

  final _dirFilesPaths = <String>[];
  final _dirSubdirs = <_PendingDir>[];
  bool _dirHasNoMedia = false;

  /// fills [_dirFilesPaths], [_dirSubdirs] and [_dirHasNoMedia].
  void _listDir(_PendingDir dir);

  void _addFileStats(_FilesStatsBuilder statsBuilder, int dirFileIndex);

  DirsFileFilterResult walk() {
    final directoriesToScan = _parameters._directoriesToScan;
    for (int i = directoriesToScan.length - 1; i >= 0; i--) {
      final d = directoriesToScan[i];
      if (d is! DirectoryIndexLocal) continue;
      final rootDir = _PendingDir(path: d.sourceRaw, isLink: false, linksChain: null);
      _pendingDirs.add(rootDir);
    }

    final pendingDirs = _pendingDirs;
    final dirFilesPaths = _dirFilesPaths;
    final dirSubdirs = _dirSubdirs;
    final collector = _collector;
    final statsBuilder = _statsBuilder;
    final fillFolderCovers = collector.fillFolderCovers;
    final strictNoMedia = _parameters.strictNoMedia;

    while (pendingDirs.isNotEmpty) {
      final dir = pendingDirs.removeLast();
      final isNewDir = _visitedDirs.add(dir.path);
      if (!isNewDir) continue;

      _dirHasNoMedia = false;
      _listDir(dir);
      final noMediaDirPath = _dirHasNoMedia ? dir.path : dir.noMediaDirPath;

      final folder = fillFolderCovers ? Folder.explicit(dir.path) : null;
      final listedDir = _ListedDir(folder, noMediaDirPath);
      for (int i = 0; i < dirFilesPaths.length; i++) {
        final didAdd = collector.addFile(dirFilesPaths[i], listedDir);
        if (didAdd && statsBuilder != null) _addFileStats(statsBuilder, i);
      }
      dirFilesPaths.clear();

      final subdirsNoMediaDirPath = strictNoMedia ? noMediaDirPath : null;
      for (int i = dirSubdirs.length - 1; i >= 0; i--) {
        final subdir = dirSubdirs[i];
        subdir.noMediaDirPath = subdirsNoMediaDirPath;
        pendingDirs.add(subdir);
      }
      dirSubdirs.clear();
    }

    final stats = statsBuilder?.build();
    return collector.toResult(stats);
  }

  /// null when the link leads back to one of its parents.
  _LinksChain? _appendLinkTarget(Object target, _LinksChain? linksChain) {
    _LinksChain? parent = linksChain;
    while (parent != null) {
      if (parent.target == target) return null;
      parent = parent.parent;
    }
    return _LinksChain(target, linksChain);
  }

  void _addStatsOfPath(_FilesStatsBuilder statsBuilder, String path) {
    final stat = FileStat.statSync(path);
    if (stat.type == FileSystemEntityType.notFound) {
      statsBuilder.addUnknown();
      return;
    }
    final modifiedMS = stat.modified.millisecondsSinceEpoch;
    final creationMS = stat.creationDate.millisecondsSinceEpoch;
    statsBuilder.add(stat.size, modifiedMS, creationMS);
  }
}

// by claude
class _DartDirsWalker extends _DirsWalker {
  _DartDirsWalker(super._parameters);

  static const _kDot = 0x2E;

  @override
  void _listDir(_PendingDir dir) {
    final List<FileSystemEntity> entities;
    _LinksChain? linksChain = dir.linksChain;
    try {
      final directory = Directory(dir.path);
      if (dir.isLink) {
        final linkTarget = directory.resolveSymbolicLinksSync();
        linksChain = _appendLinkTarget(linkTarget, linksChain);
        if (linksChain == null) return;
      }
      entities = directory.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    final respectNoMedia = _parameters._respectNoMedia;
    for (int i = 0; i < entities.length; i++) {
      final entity = entities[i];
      final path = entity.path;
      FileSystemEntityType type;
      bool isLink = false;
      if (entity is File) {
        type = FileSystemEntityType.file;
      } else if (entity is Directory) {
        type = FileSystemEntityType.directory;
      } else {
        isLink = true;
        type = FileSystemEntity.typeSync(path);
      }

      if (type == FileSystemEntityType.directory) {
        final subdir = _PendingDir(path: path, isLink: isLink, linksChain: linksChain);
        _dirSubdirs.add(subdir);
      } else if (type == FileSystemEntityType.file) {
        final isNoMediaFile = respectNoMedia && _isNoMediaFile(path);
        if (isNoMediaFile) _dirHasNoMedia = true;
        _dirFilesPaths.add(path);
      }
    }
  }

  bool _isNoMediaFile(String path) {
    const filename = _DirsWalker._kNoMediaFilename;
    final filenameStart = path.length - filename.length;
    if (filenameStart < 1 || path.codeUnitAt(filenameStart) != _kDot) return false;
    final filenameActual = path.getFilename;
    return filenameActual.length == filename.length && filenameActual.toLowerCase() == filename;
  }

  @override
  void _addFileStats(_FilesStatsBuilder statsBuilder, int dirFileIndex) {
    final path = _dirFilesPaths[dirFileIndex];
    _addStatsOfPath(statsBuilder, path);
  }
}

class _DirsFilesCollector {
  final allPaths = <String>{};
  final excludedByNoMedia = <String, List<String>>{};
  final folderCovers = <Folder, String>{};
  final m3uPaths = <String>{};

  final List<DirectoryIndex> _directoriesToExclude;
  final NamidaFileExtensionsWrapper _extensions;
  final NamidaFileExtensionsWrapper? _imageExtensions;
  final NamidaFileExtensionsWrapper? _m3uExtensions;
  final bool _respectNoMedia;
  final bool fillFolderCovers;

  _DirsFilesCollector(DirsFileFilter parameters)
    : _directoriesToExclude = parameters._directoriesToExclude,
      _extensions = parameters.extensions.without(parameters.blacklistExtensions),
      _imageExtensions = parameters.imageExtensions,
      _m3uExtensions = parameters.m3uExtensions,
      _respectNoMedia = parameters._respectNoMedia,
      fillFolderCovers = parameters.imageExtensions?.extensions.isNotEmpty == true;

  static const _coversNames = {
    'folder', 'foldercover', 'front', 'cover', 'thumbnail', 'thumb', 'album', 'albumart', 'albumartsmall', //
  };

  bool addFile(String path, _ListedDir dir) {
    final folder = dir.folder;
    if (folder != null && !dir.hasCover) {
      if (_imageExtensions!.isPathValid(path)) {
        final filenameCleaned = path.getFilenameWOExt.toLowerCase();
        if (_coversNames.contains(filenameCleaned)) {
          dir.hasCover = true;
          folderCovers[folder] = path;
        }
        return false;
      }
    }

    // -- skips if the file is included in one of the excluded folders.
    for (final exc in _directoriesToExclude) {
      if (path.startsWith(exc.sourceRaw)) return false;
    }

    // -- skip if not in extensions
    if (!_extensions.isPathValid(path)) {
      final m3uExtensions = _m3uExtensions;
      final isM3U = m3uExtensions != null && m3uExtensions.isPathValid(path);
      if (isM3U && !path.getFilename.startsWith('.')) m3uPaths.add(path);
      return false;
    }

    // -- skip if hidden
    if (path.getFilename.startsWith('.')) return false;

    // -- skip if in nomedia folder & specified to exclude
    final noMediaDirPath = dir.noMediaDirPath;
    if (_respectNoMedia && noMediaDirPath != null) {
      excludedByNoMedia.addForce(noMediaDirPath, path);
      return false;
    }

    return allPaths.add(path);
  }

  DirsFileFilterResult toResult(FilesStats? stats) {
    return DirsFileFilterResult(
      allPaths: allPaths,
      excludedByNoMedia: excludedByNoMedia,
      folderCovers: folderCovers,
      m3uPaths: m3uPaths,
      stats: stats,
    );
  }
}

// by claude
class _FilesStatsBuilder {
  Int64List _packed;
  int _length = 0;

  _FilesStatsBuilder(int filesCount) : _packed = Int64List(filesCount * FilesStats._kSlots);

  void add(int size, int modifiedMS, int creationMS) {
    final offset = _length;
    final newLength = offset + FilesStats._kSlots;
    if (newLength > _packed.length) {
      final grown = Int64List(newLength * 2);
      grown.setRange(0, offset, _packed);
      _packed = grown;
    }
    _packed[offset] = size;
    _packed[offset + 1] = modifiedMS;
    _packed[offset + 2] = creationMS;
    _length = newLength;
  }

  void addUnknown() => add(FilesStats._kUnknownSize, 0, 0);

  FilesStats build() {
    final packed = Int64List.sublistView(_packed, 0, _length);
    return FilesStats._(packed);
  }
}

class DirsFileFilterResult {
  final Set<String> allPaths;

  /// {folder that has the .nomedia: files excluded by it}.
  final Map<String, List<String>> excludedByNoMedia;
  final Map<Folder, String> folderCovers;
  final Set<String> m3uPaths;
  final FilesStats? stats;

  const DirsFileFilterResult({
    required this.allPaths,
    required this.excludedByNoMedia,
    required this.folderCovers,
    required this.m3uPaths,
    required this.stats,
  });
}

// by claude
/// sizes and dates of [DirsFileFilterResult.allPaths], a file's index is its position in that set.
class FilesStats {
  final Int64List _packed;
  const FilesStats._(this._packed);

  static const _kSlots = 3;
  static const _kUnknownSize = -1;

  bool isKnownAt(int index) => _packed[index * _kSlots] != _kUnknownSize;
  int sizeAt(int index) => _packed[index * _kSlots];
  int modifiedMSAt(int index) => _packed[index * _kSlots + 1];

  FileStatsAdv? toStatsAt(int index) {
    final offset = index * _kSlots;
    final size = _packed[offset];
    if (size == _kUnknownSize) return null;
    return FileStatsAdv(
      creationDateMS: _packed[offset + 2],
      modifiedMS: _packed[offset + 1],
      size: size,
    );
  }
}

class _ListedDir {
  final Folder? folder;
  final String? noMediaDirPath;
  bool hasCover = false;

  _ListedDir(this.folder, this.noMediaDirPath);
}

class _PendingDir {
  final String path;
  final bool isLink;
  final _LinksChain? linksChain;
  String? noMediaDirPath;

  _PendingDir({
    required this.path,
    required this.isLink,
    required this.linksChain,
  });
}

class _LinksChain {
  final Object target;
  final _LinksChain? parent;

  const _LinksChain(this.target, this.parent);
}
