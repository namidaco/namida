import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/controller/namida_channel_storage.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

enum _SortType {
  name,
  dateModified,
  type, // extension
  size,
}

const _defaultMemeType = NamidaStorageFileMemeType.any;

class NamidaFileBrowser {
  static Future<File?> pickFile({
    String note = '',
    String memeType = _defaultMemeType,
    String? initialDirectory,
    List<String> allowedExtensions = const [],
  }) async {
    return _NamidaFileBrowserBase.pickFile(
      note: note,
      allowedExtensions: allowedExtensions,
      memeType: memeType,
      initialDirectory: initialDirectory,
      onNavigate: _onNavigate,
    );
  }

  static Future<List<File>> pickFiles({
    String note = '',
    String memeType = _defaultMemeType,
    String? initialDirectory,
    List<String> allowedExtensions = const [],
  }) async {
    return _NamidaFileBrowserBase.pickFiles(
      note: note,
      allowedExtensions: allowedExtensions,
      memeType: memeType,
      initialDirectory: initialDirectory,
      onNavigate: _onNavigate,
    );
  }

  static Future<Directory?> pickDirectory({
    String note = '',
    String? initialDirectory,
  }) async {
    return _NamidaFileBrowserBase.pickDirectory(
      note: note,
      initialDirectory: initialDirectory,
      onNavigate: _onNavigate,
    );
  }

  static Future<List<Directory>> pickDirectories({
    String note = '',
    String? initialDirectory,
  }) async {
    return _NamidaFileBrowserBase.pickDirectories(
      note: note,
      initialDirectory: initialDirectory,
      onNavigate: _onNavigate,
    );
  }

  static Future<String?> getDirectory({String note = ''}) async {
    return pickDirectory(note: note).then((value) => value?.path);
  }

  static Future<List<String>> getDirectories({String note = ''}) async {
    return pickDirectories(note: note).then((value) => value.map((e) => e.path).toList());
  }

  static void _onNavigate(_NamidaFileBrowserBase widget) {
    Get.to(
      () => widget,
      id: null,
      preventDuplicates: false,
      transition: Transition.native,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 300),
      opaque: true,
      fullscreenDialog: false,
    );
  }
}

typedef _NamidaFileBrowserNavigationCallback = void Function(_NamidaFileBrowserBase options);

class _NamidaFileBrowserBase<T extends FileSystemEntity> extends StatefulWidget {
  final String note;
  final String? initialDirectory;
  final Completer<List<T>> onSelect;
  final List<String> allowedExtensions;
  final String memeType;
  final bool allowMultiple;

  const _NamidaFileBrowserBase({
    super.key,
    required this.note,
    this.initialDirectory,
    required this.onSelect,
    this.allowedExtensions = const [],
    this.memeType = _defaultMemeType,
    required this.allowMultiple,
  });

  static Future<File?> pickFile({
    String note = '',
    List<String> allowedExtensions = const [],
    String memeType = _defaultMemeType,
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
  }) async {
    final completer = Completer<List<File>>();
    onNavigate(
      _NamidaFileBrowserBase<File>(
        note: note,
        initialDirectory: initialDirectory,
        allowedExtensions: allowedExtensions,
        memeType: memeType,
        onSelect: completer,
        allowMultiple: false,
      ),
    );
    final all = await completer.future;
    return all.firstOrNull;
  }

  static Future<List<File>> pickFiles({
    String note = '',
    List<String> allowedExtensions = const [],
    String memeType = _defaultMemeType,
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
  }) async {
    final completer = Completer<List<File>>();
    onNavigate(
      _NamidaFileBrowserBase<File>(
        note: note,
        initialDirectory: initialDirectory,
        allowedExtensions: allowedExtensions,
        memeType: memeType,
        onSelect: completer,
        allowMultiple: true,
      ),
    );
    return completer.future;
  }

  static Future<Directory?> pickDirectory({
    String note = '',
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
  }) async {
    final completer = Completer<List<Directory>>();
    onNavigate(
      _NamidaFileBrowserBase<Directory>(
        note: note,
        initialDirectory: initialDirectory,
        onSelect: completer,
        allowMultiple: false,
      ),
    );
    final all = await completer.future;
    if (all.isEmpty) return null;
    return _fixSDCardDirectory(all[0]);
  }

  static Future<List<Directory>> pickDirectories({
    String note = '',
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
  }) async {
    final completer = Completer<List<Directory>>();
    onNavigate(
      _NamidaFileBrowserBase<Directory>(
        note: note,
        initialDirectory: initialDirectory,
        onSelect: completer,
        allowMultiple: true,
      ),
    );
    final res = await completer.future;
    return res.map((e) => _fixSDCardDirectory(e)).toList();
  }

  static final _sdDirRegex = RegExp(r'/tree/(\w{4}-\w{4}):');
  static Directory _fixSDCardDirectory(Directory dir) {
    final replaced = dir.path.replaceFirstMapped(_sdDirRegex, (match) => '/storage/${match.group(1)}/');
    return Directory(replaced);
  }

  @override
  State<_NamidaFileBrowserBase> createState() => _NamidaFileBrowserState<T>();
}

class _NamidaFileBrowserState<T extends FileSystemEntity> extends State<_NamidaFileBrowserBase<T>> with TickerProviderStateMixin, PullToRefreshMixin {
  final _mainStoragePaths = <String>{};
  String _currentFolderPath = '';
  var _currentFiles = <File>[];
  var _currentFolders = <Directory>[];
  bool _isFetching = true;
  final _sortType = _SortType.name.obs;
  final _sortReversed = false.obs;

  final _sortTypeToName = {
    _SortType.name: lang.NAME,
    _SortType.dateModified: lang.DATE,
    _SortType.type: lang.EXTENSION,
    _SortType.size: lang.SIZE,
  };

  void _sortItems(_SortType? type, bool? reversed, {bool refresh = true}) {
    type ??= _sortType.value;
    reversed ??= _sortReversed.value;

    void sorterFnFiles(Comparable<dynamic> Function(File item) fn) {
      reversed! ? _currentFiles.sortByReverse(fn) : _currentFiles.sortBy(fn);
    }

    void sorterFnFolder(Comparable<dynamic> Function(Directory item) fn) {
      reversed! ? _currentFolders.sortByReverse(fn) : _currentFolders.sortBy(fn);
    }

    switch (type) {
      case _SortType.name:
        sorterFnFiles((item) => _pathToName(item.path));
        sorterFnFolder((item) => _pathToName(item.path));
      case _SortType.dateModified:
        sorterFnFiles((item) => _currentInfoFiles[item.path]?.modified ?? DateTime(0));
        sorterFnFolder((item) => _currentInfoDirs[item.path]?.modified ?? DateTime(0));
      case _SortType.type:
        sorterFnFiles((item) => _pathToExtension(item.path));
        sorterFnFolder((item) => _pathToExtension(item.path));
      case _SortType.size:
        sorterFnFiles((item) => _currentInfoFiles[item.path]?.size ?? 0);
        sorterFnFolder((item) => _currentInfoDirs[item.path]?.size ?? 0);
    }
    _sortType.value = type;
    _sortReversed.value = reversed;

    if (refresh) setState(() {});
  }

  final _showHiddenFiles = false.obs;
  bool _showEmptyFolders = false;

  static final _pathSeparator = Platform.pathSeparator;
  late final _scrollController = ScrollController();
  late final _pathSplitsScrollController = ScrollController();

  static String _pathReverseSplitter(String path, String until) {
    String extension = ''; // represents the latest part
    int latestIndex = path.length - 1;

    while (latestIndex > 0) {
      final char = path[latestIndex];
      if (char == until) break;
      extension = char + extension;
      latestIndex--;
    }
    return extension;
  }

  static String _pathToName(String path) {
    return _pathReverseSplitter(path, _pathSeparator);
  }

  static String _pathToExtension(String path) {
    return _pathReverseSplitter(path, '.').toLowerCase();
  }

  Isolate? _isolate;
  ReceivePort? _resultPort;

  Isolate? _infoIsolate;
  ReceivePort? _infoPort;

  void _stopMainIsolates() {
    try {
      _resultPort?.close();
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _resultPort = null;
    } catch (_) {}
  }

  void _stopInfoIsolates() {
    try {
      _infoPort?.close();
      _infoIsolate?.kill(priority: Isolate.immediate);
      _infoIsolate = null;
      _infoPort = null;
    } catch (_) {}
  }

  Future<void> _fetchFiles(Directory dir, {bool clearPrevious = true}) async {
    final dirPath = dir.path;

    _currentFolderPath = dirPath;
    if (clearPrevious) {
      setState(() {
        _isFetching = true;
        _currentFiles = [];
        _currentFolders = [];
      });
    }

    (List<File>, List<Directory>, Object?) isolateRes = ([], [], null);
    try {
      _stopMainIsolates();
      _resultPort = ReceivePort();
      final params = (dir: dirPath, showHiddenFiles: _showHiddenFiles.value, allowedExtensions: _effectiveAllowedExtensions, resultPort: _resultPort!.sendPort);
      _isolate = await Isolate.spawn(_fetchFilesIsolate, params);
      isolateRes = await _resultPort!.first as (List<File>, List<Directory>, Object?);
      // _fetchInfo(dirPath, isolateRes.$1, isolateRes.$2);

      _stopMainIsolates();
    } catch (e) {
      snackyy(title: lang.ERROR, message: "$e", isError: true);
    }
    if (dirPath == _currentFolderPath) {
      setState(() {
        _isFetching = false;
        if (isolateRes.$1.isNotEmpty) _currentFiles = isolateRes.$1;
        if (isolateRes.$2.isNotEmpty) _currentFolders = isolateRes.$2;
        _sortItems(null, null, refresh: false);
      });
      if (isolateRes.$3 != null) {
        snackyy(title: lang.ERROR, message: isolateRes.$3!.toString(), isError: true);
      }
    }
  }

  var _currentInfoFiles = <String, NamidaFileStat>{};
  var _currentInfoDirs = <String, NamidaDirStat>{};
  bool _fetchingInfo = false;

  Future<void> _fetchInfo(Set<String> rootPaths) async {
    _fetchingInfo = true;
    try {
      _infoPort = ReceivePort();
      final params = (rootPaths, _infoPort!.sendPort);
      _infoIsolate = await Isolate.spawn(_fetchInfoIsolate, params);
      final res = await _infoPort!.first as (Map<String, NamidaFileStat>, Map<String, NamidaDirStat>);
      if (mounted) {
        setState(() {
          _currentInfoFiles = res.$1;
          _currentInfoDirs = res.$2;
        });
      }
      _stopInfoIsolates();
    } catch (_) {}
    _fetchingInfo = false;
  }

  static void _fetchInfoIsolate((Set<String>, SendPort) params) {
    final infoFiles = <String, NamidaFileStat>{}; // <------
    final directoryForFiles = <String, List<String>>{}; // --^
    final directoryForFolders = <String, List<String>>{}; // --^
    final infoDirSize = <String, int>{};

    int onFileAdd(Directory dir, File f) {
      try {
        final stats = f.statSync();
        infoFiles[f.path] = NamidaFileStat(
          size: stats.size,
          accessed: stats.accessed,
          changed: stats.changed,
          modified: stats.modified,
        );
        directoryForFiles.addForce(dir.path, f.path);
        return stats.size;
      } catch (_) {
        return 0;
      }
    }

    void dirToParentsWalker(Directory dir, void Function(String parent) execute) {
      final dirPieces = dir.path.split(_pathSeparator);
      while (dirPieces.isNotEmpty) {
        final parentDirPath = dirPieces.join(_pathSeparator);
        execute(parentDirPath);
        dirPieces.removeLast();
      }
    }

    final infoDirs = <String, NamidaDirStat>{};
    void markDirAndParentAsInaccurate(Directory dir) {
      dirToParentsWalker(dir, (parent) {
        final currentInfo = infoDirs[parent];
        if (currentInfo?.accurate == false) return; // already marked
        infoDirs[parent] = currentInfo != null
            ? NamidaDirStat(
                accurate: false,
                filesCount: currentInfo.filesCount,
                foldersCount: currentInfo.foldersCount,
                size: currentInfo.size,
                accessed: currentInfo.accessed,
                changed: currentInfo.changed,
                modified: currentInfo.modified,
              )
            : NamidaDirStat(
                accurate: false,
                filesCount: 0,
                foldersCount: 0,
                size: 0,
                accessed: DateTime(0),
                changed: DateTime(0),
                modified: DateTime(0),
              );
      });
    }

    int dirSafeRecursiveListSync(Directory dir) {
      try {
        int totalSize = 0;
        final subDir = <Directory>[];
        final items = dir.listSync(recursive: false);
        items.loop((e, _) {
          if (e is File) {
            totalSize += onFileAdd(dir, e);
          } else if (e is Directory) {
            subDir.add(e);
            directoryForFolders.addForce(dir.path, e.path);
          }
        });
        subDir.loop((sub, _) {
          totalSize += dirSafeRecursiveListSync(
            sub,
          );
        });
        infoDirSize[dir.path] = totalSize;
        return totalSize;
      } catch (_) {
        markDirAndParentAsInaccurate(dir);
        return 0;
      }
    }

    for (final rootPath in params.$1) {
      dirSafeRecursiveListSync(Directory(rootPath));
    }

    void onDirInfo(MapEntry<String, List<String>> dirEntry, int size) {
      final dir = Directory(dirEntry.key);
      try {
        final dirStat = dir.statSync();
        infoDirs[dir.path] = NamidaDirStat(
          accurate: infoDirs[dir.path]?.accurate ?? true, // check if was marked innaccurate before.
          filesCount: directoryForFiles[dir.path]?.length ?? 0,
          foldersCount: directoryForFolders[dir.path]?.length ?? 0,
          size: size,
          accessed: dirStat.accessed,
          changed: dirStat.changed,
          modified: dirStat.modified,
        );
      } catch (_) {}
    }

    for (final fileEntry in directoryForFiles.entries) {
      int totalSize = 0;
      fileEntry.value.loop((e, _) => totalSize += infoFiles[e]?.size ?? 0);
      onDirInfo(fileEntry, totalSize);
    }
    for (final dirEntry in directoryForFolders.entries) {
      onDirInfo(dirEntry, infoDirSize[dirEntry.key] ?? 0);
    }

    params.$2.send((infoFiles, infoDirs));
  }

  // Future<void> _fetchInfo(String forPath, List<File> files, List<Directory> dirs) async {
  //   final infoPort = await preparePortRaw(
  //     onResult: (result) {
  //       final res = result as (String, Map, Type);

  //       if (res.$1 != _currentFolderPath) return;
  //       setState(() {
  //         if (res.$2 is Map<String, NamidaFileStat>) {
  //           _currentInfoFiles = res.$2 as Map<String, NamidaFileStat>;
  //         } else if (res.$3 is Map<String, NamidaDirStat>) {
  //           _currentInfoDirs = res.$2 as Map<String, NamidaDirStat>;
  //         }
  //       });
  //     },
  //     isolateFunction: (itemsSendPort) async {
  //       await Isolate.spawn(_fetchInfoIsolate, itemsSendPort);
  //     },
  //   );
  //   final params = (forPath, files, dirs);
  //   infoPort.send(params);
  // }

  // static void _fetchInfoIsolate(SendPort sendPort) {
  //   final allFilesStats = <String, NamidaFileStat>{};
  //   final allDirsStats = <String, NamidaDirStat>{};

  //   final recievePort = ReceivePort();
  //   sendPort.send(recievePort.sendPort);

  //   StreamSubscription? streamSub;
  //   streamSub = recievePort.listen((p) async {
  //     if (PortsProvider.isDisposeMessage(p)) {
  //       recievePort.close();
  //       streamSub?.cancel();
  //       return;
  //     }
  //     p as (String forPath, List<File> files, List<Directory>);

  //     // -- files
  //     if (p.$2.isNotEmpty) {
  //       final newMapFiles = <String, NamidaFileStat>{};
  //       p.$2.loop((e, index) {
  //         try {
  //           if (allFilesStats[e.path] == null) {
  //             final stats = e.statSync();
  //             allFilesStats[e.path] = NamidaFileStat(
  //               size: stats.size,
  //               accessed: stats.accessed,
  //               changed: stats.changed,
  //               modified: stats.modified,
  //             );
  //           }
  //           newMapFiles[e.path] = allFilesStats[e.path]!;
  //         } catch (_) {}
  //       });
  //       sendPort.send((p.$1, newMapFiles, File));
  //     }

  //     // -- dirs
  //     if (p.$3.isNotEmpty) {
  //       final newMapDirs = <String, NamidaDirStat>{};
  //       p.$3.loop((dir, index) {
  //         try {
  //           int totalSize = 0;
  //           if (allDirsStats[dir.path] == null) {
  //             final dirStats = dir.statSync();
  //             var itemsInside = <FileSystemEntity>[];
  //             try {
  //               itemsInside = dir.listSync(recursive: true);
  //             } catch (e) {
  //               itemsInside = dir.listSync(recursive: false);
  //             }
  //             int filesCount = 0;
  //             int foldersCount = 0;
  //             itemsInside.loop((file, _) {
  //               if (file is File) {
  //                 // -- file stats inside each dir
  //                 final stats = file.statSync();
  //                 allFilesStats[file.path] ??= NamidaFileStat(
  //                   size: stats.size,
  //                   accessed: stats.accessed,
  //                   changed: stats.changed,
  //                   modified: stats.modified,
  //                 );
  //                 totalSize += stats.size;
  //                 filesCount++;
  //               } else {
  //                 foldersCount++;
  //               }
  //             });
  //             allDirsStats[dir.path] = NamidaDirStat(
  //               filesCount: filesCount,
  //               foldersCount: foldersCount,
  //               size: totalSize,
  //               accessed: dirStats.accessed,
  //               changed: dirStats.changed,
  //               modified: dirStats.modified,
  //             );
  //           }

  //           newMapDirs[dir.path] = allDirsStats[dir.path]!;
  //         } catch (_) {}
  //       });
  //       sendPort.send((p.$1, newMapDirs, Directory));
  //     }
  //   });
  // }

  static void _fetchFilesIsolate(({String dir, List<String> allowedExtensions, bool showHiddenFiles, SendPort resultPort}) params) {
    List<FileSystemEntity> items;
    try {
      items = Directory(params.dir).listSync();
    } catch (e) {
      params.resultPort.send((<File>[], <Directory>[], e));
      return;
    }
    final files = <File>[];
    final dirs = <Directory>[];

    void onAdd(FileSystemEntity e) {
      if (e is File) {
        files.add(e);
      } else if (e is Directory) {
        dirs.add(e);
      }
    }

    final excludeHidden = params.showHiddenFiles == false;
    final extensions = params.allowedExtensions;

    if (excludeHidden && extensions.isNotEmpty) {
      items.loop((e, _) {
        final filename = e.path.split(_pathSeparator).last;
        if (e is Directory) {
          if (!filename.startsWith('.')) onAdd(e);
        } else {
          if (!filename.startsWith('.') && extensions.any((ext) => filename.endsWith(ext))) onAdd(e);
        }
      });
    } else if (excludeHidden) {
      items.loop((e, _) {
        final fileorDirName = e.path.split(_pathSeparator).last;
        if (!fileorDirName.startsWith('.')) onAdd(e);
      });
    } else if (extensions.isNotEmpty) {
      items.loop((e, _) {
        if (e is File) {
          final filename = e.path.split(_pathSeparator).last;
          if (extensions.any((ext) => filename.endsWith(ext))) onAdd(e);
        } else {
          onAdd(e);
        }
      });
    } else {
      items.loop((e, _) => onAdd(e));
    }

    files.sortBy((e) => _pathToName(e.path));
    dirs.sortBy((e) => _pathToName(e.path));
    params.resultPort.send((files, dirs, null));
  }

  final _effectiveAllowedExtensions = <String>[];

  @override
  void initState() {
    NamidaStorage.inst.getStorageDirectories().then((paths) {
      _mainStoragePaths.addAll(paths);
      _fetchFiles(Directory(widget.initialDirectory ?? paths.first));
      _fetchInfo(_mainStoragePaths);
    });
    _effectiveAllowedExtensions.addAll(widget.allowedExtensions);
    if (widget.memeType != NamidaStorageFileMemeType.any) {
      switch (widget.memeType) {
        case NamidaStorageFileMemeType.audio:
          _effectiveAllowedExtensions.addAll(kAudioFileExtensions);
        case NamidaStorageFileMemeType.video:
          _effectiveAllowedExtensions.addAll(kVideoFilesExtensions);
        case NamidaStorageFileMemeType.image:
          _effectiveAllowedExtensions.addAll(kImageFilesExtensions);
        case NamidaStorageFileMemeType.media:
          _effectiveAllowedExtensions
            ..addAll(kAudioFileExtensions)
            ..addAll(kVideoFilesExtensions);
      }
    }
    _initIconsLookup();

    super.initState();
  }

  @override
  void dispose() {
    _stopMainIsolates();
    _stopInfoIsolates();
    _scrollController.dispose();
    _pathSplitsScrollController.dispose();
    _showHiddenFiles.close();
    _sortType.close();
    _sortReversed.close();
    super.dispose();
  }

  bool isPathRoot(String path) {
    return _mainStoragePaths.any(
      (element) {
        if (element == path) return true;
        if (!element.endsWith(_pathSeparator)) element += _pathSeparator;
        if (!path.endsWith(_pathSeparator)) path += _pathSeparator;
        return element == path;
      },
    );
  }

  final _scrollPositionsSaved = <String, double>{}; // path: offset

  void _navigateTo(Directory dir, {double? scrollOffset}) {
    try {
      _scrollPositionsSaved[_currentFolderPath] = _scrollController.offset; // saving current offset.
    } catch (_) {}
    _fetchFiles(dir);
    if (_scrollController.hasClients) _scrollController.jumpTo(scrollOffset ?? 0);
    try {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (_pathSplitsScrollController.hasClients) {
          _pathSplitsScrollController.animateTo(
            _pathSplitsScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
          );
        }
      });
    } catch (_) {}
  }

  void _navigateBack() {
    final pieces = _currentFolderPath.split(_pathSeparator);
    pieces.removeLast();
    final newPath = pieces.join(_pathSeparator);
    _navigateTo(Directory(newPath), scrollOffset: _scrollPositionsSaved[newPath]);
  }

  void _onSelectionComplete(List<T> items) {
    widget.onSelect.completeIfWasnt(items);
    context.safePop();
  }

  final _selectedFiles = <File>[];
  final _selectedFilesLookup = <String, bool>{};
  void _onFileTap(File file) {
    if (_selectedFiles.isNotEmpty) {
      _onFileLongPress(file);
    } else {
      if (T == File) {
        _onSelectionComplete([file as T]);
      }
    }
  }

  void _onFileLongPress(File file) {
    if (T != File) return;

    final alreadySelected = _selectedFilesLookup[file.path] == true;

    if (_selectedFiles.isNotEmpty && !widget.allowMultiple) {
      _selectedFiles.clear();
      _selectedFilesLookup.clear();
    }

    if (alreadySelected) {
      setState(() {
        _selectedFiles.remove(file);
        _selectedFilesLookup[file.path] = false;
      });
    } else {
      setState(() {
        _selectedFiles.add(file);
        _selectedFilesLookup[file.path] = true;
      });
    }
  }

  final _selectedFolders = <Directory>[];
  final _selectedFoldersLookup = <String, bool>{};
  void _onFolderTap(Directory dir) {
    if (_selectedFolders.isNotEmpty) {
      _onFolderLongPress(dir);
    } else {
      _navigateTo(dir);
    }
  }

  void _onFolderLongPress(Directory dir) {
    if (T != Directory) return;

    final alreadySelected = _selectedFoldersLookup[dir.path] == true;

    if (_selectedFolders.isNotEmpty && !widget.allowMultiple) {
      _selectedFolders.clear();
      _selectedFoldersLookup.clear();
    }

    if (alreadySelected) {
      setState(() {
        _selectedFolders.remove(dir);
        _selectedFoldersLookup[dir.path] = false;
      });
    } else {
      setState(() {
        _selectedFolders.add(dir);
        _selectedFoldersLookup[dir.path] = true;
      });
    }
  }

  IconData _fileToIcon(File file) {
    final extension = '.${_pathToExtension(file.path)}';
    final iconIndex = _iconsLookupPre[extension];
    if (iconIndex != null) {
      final icon = _iconsLookup[iconIndex];
      if (icon != null) return icon;
    }
    return Broken.document_1;
  }

  ArtworkWidget? _getFileImage(File file) {
    final extension = '.${_pathToExtension(file.path)}';
    final iconIndex = _iconsLookupPre[extension];
    if (iconIndex != 2) return null;
    return ArtworkWidget(
      key: Key(file.path),
      thumbnailSize: 56.0,
      path: file.path,
      borderRadius: 8.0,
      blur: 0,
      fallbackToFolderCover: false,
      icon: _iconsLookup[2] ?? Broken.gallery,
    );
  }

  void _initIconsLookup() {
    for (final e in kAudioFileExtensions) {
      _iconsLookupPre[e] = 0;
    }
    for (final e in kVideoFilesExtensions) {
      _iconsLookupPre[e] = 1;
    }
    for (final e in kImageFilesExtensions) {
      _iconsLookupPre[e] = 2;
    }
    for (final e in ['.json', '.csv']) {
      _iconsLookupPre[e] = 3;
    }
    for (final e in kM3UPlaylistsExtensions) {
      _iconsLookupPre[e] = 4;
    }
    for (final e in [".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".cab", ".iso", ".jar"]) {
      _iconsLookupPre[e] = 5;
    }

    _iconsLookup[0] = Broken.musicnote;
    _iconsLookup[1] = Broken.video;
    _iconsLookup[2] = Broken.gallery;
    _iconsLookup[3] = Broken.document_code;
    _iconsLookup[4] = Broken.music_filter;
    _iconsLookup[5] = Broken.external_drive;
  }

  final _iconsLookupPre = <String, int>{};
  final _iconsLookup = <int, IconData>{};

  Future<void> _onBackupPickerLaunch([List<String> allowedExtensions = const []]) async {
    final note = widget.note != '' ? widget.note : null;
    if (T == File) {
      final res = await NamidaStorage.inst.pickFiles(
        note: note,
        multiple: widget.allowMultiple,
        memetype: widget.memeType,
        allowedExtensions: allowedExtensions,
      );
      final files = res.map((e) => File(e)).toList();
      if (files.isNotEmpty) _onSelectionComplete(files as List<T>);
    } else if (T == Directory) {
      final res = await NamidaStorage.inst.pickDirectory(note: note);
      if (res != null) _onSelectionComplete([Directory(res) as T]);
    }
  }

  List<Widget> get _getCurrentPathsSplitsChildren {
    if (_currentFolderPath == '') return [];
    final currentRoot = _mainStoragePaths.firstWhere((element) => _currentFolderPath.startsWith(element));
    final pathWithoutRoot = _currentFolderPath.substring(currentRoot.length);
    final splits = pathWithoutRoot.split(_pathSeparator);
    final map = <int, String>{};

    if (splits.isNotEmpty) {
      final sdCardRegex = RegExp(r'\w{4}-\w{4}', caseSensitive: false);
      map[0] = sdCardRegex.hasMatch(currentRoot) ? 'SD Card' : 'Home';
      int index = 1;
      for (final part in splits.skip(1)) {
        map[index] = part;
        index++;
      }
    }

    final widgets = <Widget>[];
    for (final e in map.entries) {
      widgets.add(
        TapDetector(
          onTap: () {
            if (e.key == map.length - 1) return; // same path

            String newDirPath = currentRoot;
            for (final entry in map.entries.skip(1)) {
              if (entry.key > e.key) break;
              newDirPath += _pathSeparator + entry.value;
            }
            if (newDirPath.startsWith(currentRoot)) {
              _navigateTo(Directory(newDirPath));
            }
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.theme.cardColor,
              borderRadius: BorderRadius.circular(8.0.multipliedRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                e.value == '' ? _pathSeparator : e.value,
                style: context.textTheme.displayMedium,
              ),
            ),
          ),
        ),
      );
      widgets.add(
        const Icon(
          Broken.arrow_right_3,
          size: 16.0,
        ),
      );
    }
    widgets.removeLast();
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = context.theme.cardColor;
    final pathSplitsChildren = _getCurrentPathsSplitsChildren;
    return WillPopScope(
      onWillPop: () async {
        if (isPathRoot(_currentFolderPath)) {
          _onSelectionComplete(<T>[]);
        } else {
          _navigateBack();
        }
        return false;
      },
      child: BackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      context.safePop(rootNavigator: true);
                    },
                    icon: const Icon(
                      Broken.arrow_left_2,
                      size: 24.0,
                    ),
                  ),
                  Expanded(
                    child: widget.note != ''
                        ? Text(
                            widget.note.addDQuotation(),
                            style: context.textTheme.displayMedium?.copyWith(
                              fontSize: 16.0.multipliedFontScale,
                            ),
                          )
                        : const SizedBox(),
                  ),
                  if (T == Directory)
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () {
                        final dirController = TextEditingController();
                        final formKey = GlobalKey<FormState>();
                        NamidaNavigator.inst.navigateDialog(
                          onDisposing: () {
                            dirController.dispose();
                          },
                          dialogBuilder: (theme) => Form(
                            key: formKey,
                            child: CustomBlurryDialog(
                              title: lang.NEW_DIRECTORY,
                              actions: [
                                const CancelButton(),
                                NamidaButton(
                                  text: lang.CHOOSE,
                                  onPressed: () {
                                    if (dirController.text.length > 2) {
                                      NamidaNavigator.inst.closeDialog();
                                      _onSelectionComplete([Directory(dirController.text) as T]);
                                    }
                                  },
                                )
                              ],
                              child: Column(
                                children: [
                                  const SizedBox(height: 12.0),
                                  CustomTagTextField(
                                    controller: dirController,
                                    hintText: '',
                                    labelText: lang.NEW_DIRECTORY,
                                    validatorMode: AutovalidateMode.always,
                                    validator: (value) {
                                      value ??= '';
                                      if (value.isEmpty) {
                                        return lang.PLEASE_ENTER_A_NAME;
                                      }
                                      if (!Directory(value).existsSync()) {
                                        return lang.DIRECTORY_DOESNT_EXIST;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Broken.add_circle,
                        size: 20.0,
                        color: _showHiddenFiles.value ? null : context.defaultIconColor(),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Show empty folders',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () {
                      setState(() => _showEmptyFolders = !_showEmptyFolders);
                    },
                    icon: StackedIcon(
                      baseIcon: Broken.folder,
                      secondaryIcon: _showEmptyFolders ? Broken.eye : Broken.eye_slash,
                      iconSize: 20.0,
                      secondaryIconSize: 12.0,
                      disableColor: _showEmptyFolders,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Show hidden files/folders',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () {
                      _showHiddenFiles.value = !_showHiddenFiles.value;
                      _fetchFiles(Directory(_currentFolderPath));
                    },
                    icon: Obx(
                      () => Icon(
                        _showHiddenFiles.value ? Broken.eye : Broken.eye_slash,
                        size: 20.0,
                        color: _showHiddenFiles.value ? null : context.defaultIconColor(),
                      ),
                    ),
                  ),
                  LongPressDetector(
                    onLongPress: () => _onBackupPickerLaunch(), // launching without extensions filter
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => _onBackupPickerLaunch(_effectiveAllowedExtensions),
                      icon: Icon(
                        Broken.export_1,
                        size: 20.0,
                        color: context.defaultIconColor(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                ],
              ),
              if (_mainStoragePaths.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: SizedBox(
                    width: context.width,
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runAlignment: WrapAlignment.start,
                      runSpacing: 6.0,
                      children: _mainStoragePaths
                          .map(
                            (e) => NamidaInkWell(
                              animationDurationMS: 200,
                              borderRadius: 8.0,
                              bgColor: _currentFolderPath.startsWith(e) ? context.theme.colorScheme.secondaryContainer : context.theme.cardColor,
                              onTap: () => _fetchFiles(Directory(e)),
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Text(
                                e,
                                style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              if (pathSplitsChildren.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: SizedBox(
                      width: context.width,
                      child: SingleChildScrollView(
                        controller: _pathSplitsScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: pathSplitsChildren,
                        ),
                      ),
                    )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Row(
                  children: [
                    if (_currentFolders.isNotEmpty || _currentFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                        child: Text(
                          [
                            if (_currentFolders.isNotEmpty) _currentFolders.length.displayFolderKeyword,
                            if (_currentFiles.isNotEmpty) _currentFiles.length.displayFilesKeyword,
                          ].join(' | '),
                          style: context.textTheme.displayMedium,
                        ),
                      ),
                    const Spacer(),
                    Obx(
                      () => SortByMenu(
                        title: _sortTypeToName[_sortType.value] ?? '',
                        popupMenuChild: () {
                          Widget getTile(IconData icon, String title, _SortType sort) {
                            return SmallListTile(
                              visualDensity: const VisualDensity(horizontal: -4, vertical: -3.5),
                              trailing: Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Icon(icon, size: 20.0),
                              ),
                              title: title,
                              active: _sortType.value == sort,
                              onTap: () => _sortItems(sort, null),
                            );
                          }

                          return Obx(
                            () => Column(
                              children: [
                                ListTileWithCheckMark(
                                  active: _sortReversed.value,
                                  onTap: () => _sortItems(null, !_sortReversed.value),
                                ),
                                const SizedBox(height: 8.0),
                                getTile(Broken.text, lang.FILE_NAME, _SortType.name),
                                getTile(Broken.calendar, lang.DATE, _SortType.dateModified),
                                getTile(Broken.document_code, lang.EXTENSION, _SortType.type),
                                getTile(Broken.math, lang.SIZE, _SortType.size),
                              ],
                            ),
                          );
                        },
                        isCurrentlyReversed: _sortReversed.value,
                        onReverseIconTap: () => _sortItems(null, !_sortReversed.value),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Listener(
                      onPointerMove: (event) {
                        onPointerMove(_scrollController, event);
                      },
                      onPointerUp: (event) async {
                        onRefresh(() async => await _fetchFiles(Directory(_currentFolderPath), clearPrevious: false));
                      },
                      onPointerCancel: (event) => onVerticalDragFinish(),
                      child: _isFetching
                          ? Center(
                              key: const Key('loading'),
                              child: ThreeArchedCircle(
                                color: context.theme.colorScheme.primary.withOpacity(0.5),
                                size: 56.0,
                              ),
                            )
                          : _currentFolders.isEmpty && _currentFiles.isEmpty
                              ? SizedBox(
                                  width: context.width,
                                  child: Column(
                                    key: const Key('empty'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Broken.emoji_sad,
                                        size: 42.0,
                                      ),
                                      const SizedBox(height: 12.0),
                                      Text(
                                        "0 ${lang.FILES}",
                                        style: context.textTheme.displayLarge,
                                      ),
                                    ],
                                  ),
                                )
                              : AnimationLimiter(
                                  key: const Key('items'),
                                  child: NamidaScrollbar(
                                    controller: _scrollController,
                                    child: CustomScrollView(
                                      controller: _scrollController,
                                      slivers: [
                                        SliverList.builder(
                                          itemCount: _currentFolders.length,
                                          itemBuilder: (context, index) {
                                            final folder = _currentFolders[index];
                                            final info = _currentInfoDirs[folder.path];
                                            if (info == null && !_fetchingInfo && !_showEmptyFolders) return const SizedBox();
                                            return _FileSystemChip(
                                              position: index,
                                              bgColor: chipColor,
                                              onTap: () => _onFolderTap(folder),
                                              onLongPress: () => _onFolderLongPress(folder),
                                              displayCheckMark: _selectedFolders.isNotEmpty,
                                              selected: _selectedFoldersLookup[folder.path] == true,
                                              icon: Broken.folder,
                                              title: _pathToName(folder.path),
                                              subtitle: info == null
                                                  ? 0.fileSizeFormatted
                                                  : [
                                                      "${info.size.fileSizeFormatted}${info.accurate ? '' : '?'}",
                                                      if (info.filesCount > 0) "${info.filesCount.displayFilesKeyword}${info.accurate ? '' : '?'}",
                                                      if (info.foldersCount > 0) "${info.foldersCount.displayFolderKeyword}${info.accurate ? '' : '?'}",
                                                    ].join(' | '),
                                            );
                                          },
                                        ),
                                        if (_currentFolders.isNotEmpty && _currentFiles.isNotEmpty)
                                          const SliverToBoxAdapter(
                                            child: NamidaContainerDivider(
                                              margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                            ),
                                          ),
                                        SliverList.builder(
                                          itemCount: _currentFiles.length,
                                          itemBuilder: (context, index) {
                                            final file = _currentFiles[index];
                                            final info = _currentInfoFiles[file.path];
                                            final image = _getFileImage(file);
                                            return _FileSystemChip(
                                              position: index + _currentFolders.length,
                                              bgColor: chipColor,
                                              onTap: () => _onFileTap(file),
                                              onLongPress: () => _onFileLongPress(file),
                                              displayCheckMark: _selectedFiles.isNotEmpty,
                                              selected: _selectedFilesLookup[file.path] == true,
                                              icon: image == null ? _fileToIcon(file) : null,
                                              leading: image != null ? _getFileImage(file) : null,
                                              title: _pathToName(file.path),
                                              subtitle:
                                                  info == null ? '' : "${info.size.fileSizeFormatted} | ${info.modified.millisecondsSinceEpoch.dateAndClockFormattedOriginal}",
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                    ),
                    pullToRefreshWidget,
                    Positioned(
                      bottom: 12.0,
                      right: 12.0,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: T == File && _selectedFiles.isNotEmpty
                            ? FloatingActionButton.extended(
                                extendedPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                                onPressed: () => _onSelectionComplete(_selectedFiles as List<T>),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Broken.tick_square,
                                      size: 24.0,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Text(_selectedFiles.length.displayFilesKeyword),
                                  ],
                                ),
                              )
                            : T == Directory && (_selectedFolders.isNotEmpty || !isPathRoot(_currentFolderPath))
                                ? FloatingActionButton(
                                    heroTag: 'file_browser_fab_hero',
                                    onPressed: () => _onSelectionComplete(
                                      _selectedFolders.isNotEmpty ? _selectedFolders as List<T> : [Directory(_currentFolderPath) as T],
                                    ),
                                    child: const Icon(
                                      Broken.tick_square,
                                      size: 32.0,
                                    ),
                                  )
                                : const SizedBox(),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileSystemChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color bgColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int position;
  final bool displayCheckMark;
  final bool selected;
  final Widget? leading;

  const _FileSystemChip({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
    required this.onTap,
    required this.onLongPress,
    required this.position,
    required this.displayCheckMark,
    required this.selected,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaInkWell(
      borderRadius: 8.0,
      bgColor: bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          leading ?? Icon(icon),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontSize: 13.0.multipliedFontScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontSize: 12.0.multipliedFontScale,
                    fontWeight: FontWeight.w400,
                    // color: context.theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4.0),
          NamidaCheckMark(
            size: 16.0,
            active: selected,
          ).animateEntrance(
            showWhen: displayCheckMark,
            durationMS: 200,
          ),
        ],
      ),
    );
  }
}

class NamidaFileStat {
  final int size;
  final DateTime accessed;
  final DateTime changed;
  final DateTime modified;

  const NamidaFileStat({
    required this.size,
    required this.accessed,
    required this.changed,
    required this.modified,
  });
}

class NamidaDirStat {
  final bool accurate;
  final int filesCount;
  final int foldersCount;
  final int size;
  final DateTime accessed;
  final DateTime changed;
  final DateTime modified;

  const NamidaDirStat({
    required this.accurate,
    required this.filesCount,
    required this.foldersCount,
    required this.size,
    required this.accessed,
    required this.changed,
    required this.modified,
  });
}
