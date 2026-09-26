import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';

enum FileBrowserSortType {
  name,
  dateModified,
  type, // extension
  size,
}

const _defaultMemeType = NamidaStorageFileMemeType.any;

final _pathSeparator = Platform.pathSeparator;
final _pathSeparatorCodeUnit = _pathSeparator.codeUnitAt(0);

class NamidaFileBrowser {
  static Future<File?> pickFile({
    String note = '',
    NamidaStorageFileMemeType memeType = _defaultMemeType,
    String? initialDirectory,
    NamidaFileExtensionsWrapper? allowedExtensions,
  }) async {
    return _NamidaFileBrowserBase.pickFile(
      note: note,
      allowedExtensions: allowedExtensions,
      memeType: memeType,
      initialDirectory: initialDirectory,
      onNavigate: _onNavigate,
      onPop: _onPop,
    );
  }

  static Future<List<File>> pickFiles({
    String note = '',
    NamidaStorageFileMemeType memeType = _defaultMemeType,
    String? initialDirectory,
    NamidaFileExtensionsWrapper? allowedExtensions,
  }) async {
    return _NamidaFileBrowserBase.pickFiles(
      note: note,
      allowedExtensions: allowedExtensions,
      memeType: memeType,
      initialDirectory: initialDirectory,
      onNavigate: _onNavigate,
      onPop: _onPop,
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
      onPop: _onPop,
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
      onPop: _onPop,
    );
  }

  static Future<String?> getDirectory({String note = ''}) async {
    return pickDirectory(note: note).then((value) => value?.path);
  }

  static Future<List<String>> getDirectories({String note = ''}) async {
    return pickDirectories(note: note).then((value) => value.map((e) => e.path).toList());
  }

  static void _onNavigate(_NamidaFileBrowserBase widget) {
    NamidaNavigator.inst.navigateToRoot(
      widget,
      transition: Transition.native,
    );
  }

  static void _onPop() {
    NamidaNavigator.inst.popRoot();
  }
}

typedef _NamidaFileBrowserNavigationCallback = void Function(_NamidaFileBrowserBase options);
typedef _NamidaFileBrowserPopCallback = void Function();

class _NamidaFileBrowserBase<T extends FileSystemEntity> extends StatefulWidget {
  final String note;
  final String? initialDirectory;
  final Completer<List<T>> onSelect;
  final NamidaFileExtensionsWrapper? allowedExtensions;
  final NamidaStorageFileMemeType memeType;
  final bool allowMultiple;
  final _NamidaFileBrowserPopCallback onPop;

  const _NamidaFileBrowserBase({
    super.key,
    required this.note,
    this.initialDirectory,
    required this.onSelect,
    this.allowedExtensions,
    this.memeType = _defaultMemeType,
    required this.allowMultiple,
    required this.onPop,
  });

  static Future<File?> pickFile({
    String note = '',
    NamidaFileExtensionsWrapper? allowedExtensions,
    NamidaStorageFileMemeType memeType = _defaultMemeType,
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
    required _NamidaFileBrowserPopCallback onPop,
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
        onPop: onPop,
      ),
    );
    final all = await completer.future;
    return all.firstOrNull;
  }

  static Future<List<File>> pickFiles({
    String note = '',
    NamidaFileExtensionsWrapper? allowedExtensions,
    NamidaStorageFileMemeType memeType = _defaultMemeType,
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
    required _NamidaFileBrowserPopCallback onPop,
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
        onPop: onPop,
      ),
    );
    return completer.future;
  }

  static Future<Directory?> pickDirectory({
    String note = '',
    String? initialDirectory,
    required _NamidaFileBrowserNavigationCallback onNavigate,
    required _NamidaFileBrowserPopCallback onPop,
  }) async {
    final completer = Completer<List<Directory>>();
    onNavigate(
      _NamidaFileBrowserBase<Directory>(
        note: note,
        initialDirectory: initialDirectory,
        onSelect: completer,
        allowMultiple: false,
        onPop: onPop,
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
    required _NamidaFileBrowserPopCallback onPop,
  }) async {
    final completer = Completer<List<Directory>>();
    onNavigate(
      _NamidaFileBrowserBase<Directory>(
        note: note,
        initialDirectory: initialDirectory,
        onSelect: completer,
        allowMultiple: true,
        onPop: onPop,
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

// logic rewritten by claude, lists one folder at a time with its stats, folder sizes come from a cancellable background walker with a subtree cache
class _NamidaFileBrowserState<T extends FileSystemEntity> extends State<_NamidaFileBrowserBase<T>> with TickerProviderStateMixin, PullToRefreshMixin {
  final _mainStoragePaths = <String>{};
  String _currentFolderPath = '';
  var _currentFiles = <_FileEntry>[];
  var _currentFolders = <_DirEntry>[];
  var _currentFoldersLookup = <String, _DirEntry>{};
  var _visibleFolders = <_DirEntry>[];
  bool _isFetching = true;

  final _sortTypeToName = {
    FileBrowserSortType.name: lang.name,
    FileBrowserSortType.dateModified: lang.date,
    FileBrowserSortType.type: lang.extension,
    FileBrowserSortType.size: lang.size,
  };

  void _sortItems(FileBrowserSortType? type, bool? reversed) {
    type ??= settings.fileBrowserSort.value;
    reversed ??= settings.fileBrowserSortReversed.value;

    if (type != settings.fileBrowserSort.value || reversed != settings.fileBrowserSortReversed.value) {
      settings.save(
        fileBrowserSort: type,
        fileBrowserSortReversed: reversed,
      );
    }

    setState(() {
      _sortFiles(type!, reversed!);
      _sortFolders(type, reversed);
      _refreshVisibleFolders();
    });
  }

  void _sortFiles(FileBrowserSortType type, bool reversed) {
    if (_currentFiles.length < 2) return;
    _currentFiles.sort(_FileEntry.comparatorOf(type, reversed));
  }

  void _sortFolders(FileBrowserSortType type, bool reversed) {
    if (_currentFolders.length < 2) return;
    _currentFolders.sort(_DirEntry.comparatorOf(type, reversed));
  }

  final _showHiddenFiles = false.obs;
  bool _showEmptyFolders = false;

  void _refreshVisibleFolders() {
    if (_showEmptyFolders) {
      _visibleFolders = _currentFolders;
      return;
    }
    _visibleFolders = [
      for (final folder in _currentFolders)
        if (folder.stats?.isEmpty != true) folder,
    ];
  }

  late final _scrollController = NamidaScrollController.create();
  late final _pathSplitsScrollController = NamidaScrollController.create();

  Future<void> _fetchFiles(String dirPath, {bool clearPrevious = true, String? invalidateStatsDirPath}) async {
    _currentFolderPath = dirPath;
    if (invalidateStatsDirPath != null) _dirStatsCache.removeWhere((path, _) => _arePathsRelated(path, invalidateStatsDirPath));
    if (clearPrevious) {
      setState(() {
        _isFetching = true;
        _currentFiles = [];
        _currentFolders = [];
        _currentFoldersLookup = {};
        _visibleFolders = [];
      });
    }

    final params = _ListParams(
      dirPath: dirPath,
      showHiddenFiles: _showHiddenFiles.value,
      allowedExtensions: _effectiveAllowedExtensions,
      sortType: settings.fileBrowserSort.value,
      reversed: settings.fileBrowserSortReversed.value,
    );
    _ListResult result;
    try {
      result = await _listDirectory(params);
    } catch (e) {
      result = _ListResult(files: [], folders: [], error: e);
    }
    if (!mounted || dirPath != _currentFolderPath) return;

    final folders = result.folders;
    final missingStatsPaths = <String>[];
    bool didAttachCachedStats = false;
    for (final folder in folders) {
      final cached = _dirStatsCache[folder.path];
      if (cached == null) {
        missingStatsPaths.add(folder.path);
      } else {
        folder.stats = cached;
        didAttachCachedStats = true;
      }
    }

    setState(() {
      _isFetching = false;
      _currentFiles = result.files;
      _currentFolders = folders;
      _currentFoldersLookup = {for (final folder in folders) folder.path: folder};
      if (didAttachCachedStats && params.sortType == FileBrowserSortType.size) _sortFolders(params.sortType, params.reversed);
      _refreshVisibleFolders();
    });

    final error = result.error;
    if (error != null) snackyy(title: lang.error, message: error.toString(), isError: true);

    _dirStatsWorker.request(missingStatsPaths, invalidateDirPath: invalidateStatsDirPath);
  }

  // -- static so the closure's context holds only [params], an instance method would drag `this` into the isolate message.
  static Future<_ListResult> _listDirectory(_ListParams params) {
    return Isolate.run(() => _listDirectorySync(params));
  }

  static _ListResult _listDirectorySync(_ListParams params) {
    final List<FileSystemEntity> items;
    try {
      items = Directory(params.dirPath).listSync();
    } catch (e) {
      return _ListResult(files: [], folders: [], error: e);
    }

    final files = <_FileEntry>[];
    final folders = <_DirEntry>[];
    final excludeHidden = !params.showHiddenFiles;
    final extensionsWrappers = params.allowedExtensions;
    final hasExtensionsFilter = extensionsWrappers.isNotEmpty;

    for (final e in items) {
      final path = e.path;
      final name = path.splitLast(_pathSeparator);
      if (excludeHidden && name.startsWith('.')) continue;
      if (e is File) {
        final extension = _extensionOf(name);
        if (hasExtensionsFilter && !_isExtensionAllowed(extensionsWrappers, extension)) continue;
        final stat = e.statSync();
        files.add(
          _FileEntry(
            path: path,
            name: name,
            nameLower: name.toLowerCase(),
            extension: extension,
            size: stat.size,
            modifiedMS: stat.modified.millisecondsSinceEpoch,
          ),
        );
      } else if (e is Directory) {
        final stat = e.statSync();
        folders.add(
          _DirEntry(
            path: path,
            name: name,
            nameLower: name.toLowerCase(),
            modifiedMS: stat.modified.millisecondsSinceEpoch,
          ),
        );
      }
    }

    if (files.length > 1) files.sort(_FileEntry.comparatorOf(params.sortType, params.reversed));
    if (folders.length > 1) folders.sort(_DirEntry.comparatorOf(params.sortType, params.reversed));
    return _ListResult(files: files, folders: folders, error: null);
  }

  static String _extensionOf(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  static bool _isExtensionAllowed(List<NamidaFileExtensionsWrapper> wrappers, String extension) {
    for (final wrapper in wrappers) {
      if (wrapper.extensions.contains(extension)) return true;
    }
    return false;
  }

  final _dirStatsCache = <String, _DirStats>{};
  late final _dirStatsWorker = _DirStatsWorker(onStats: _onDirStats);

  void _onDirStats(List<_DirStatsResult> results) {
    bool didChangeCurrent = false;
    for (final result in results) {
      _dirStatsCache[result.dirPath] = result.stats;
      final folder = _currentFoldersLookup[result.dirPath];
      if (folder == null) continue;
      folder.stats = result.stats;
      didChangeCurrent = true;
    }
    if (didChangeCurrent) _scheduleStatsRefresh();
  }

  Timer? _statsRefreshTimer;
  bool _isStatsRefreshPending = false;

  // -- refreshes right away, then batches whatever lands within the window.
  void _scheduleStatsRefresh() {
    if (_statsRefreshTimer != null) {
      _isStatsRefreshPending = true;
      return;
    }
    _applyStatsRefresh();
    _statsRefreshTimer = Timer(const Duration(milliseconds: 150), () {
      _statsRefreshTimer = null;
      if (!_isStatsRefreshPending) return;
      _isStatsRefreshPending = false;
      _scheduleStatsRefresh();
    });
  }

  void _applyStatsRefresh() {
    if (!mounted) return;
    setState(() {
      final sortType = settings.fileBrowserSort.value;
      if (sortType == FileBrowserSortType.size) _sortFolders(sortType, settings.fileBrowserSortReversed.value);
      _refreshVisibleFolders();
    });
  }

  Future<void> _refreshCurrentFolder() {
    final dirPath = _currentFolderPath;
    return _fetchFiles(dirPath, clearPrevious: false, invalidateStatsDirPath: dirPath);
  }

  final _effectiveAllowedExtensions = <NamidaFileExtensionsWrapper>[];

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
    NamidaStorage.inst.getStorageDirectories().then((paths) {
      if (!mounted) return;
      _mainStoragePaths.addAll(paths);
      final initialDirectory = widget.initialDirectory ?? paths.firstOrNull;
      if (initialDirectory == null) {
        setState(() => _isFetching = false);
        return;
      }
      _fetchFiles(initialDirectory);
    });
    final allowedExtensions = widget.allowedExtensions;
    if (allowedExtensions != null) _effectiveAllowedExtensions.add(allowedExtensions);
    if (widget.memeType != NamidaStorageFileMemeType.any) {
      switch (widget.memeType) {
        case NamidaStorageFileMemeType.audio:
          _effectiveAllowedExtensions.add(NamidaFileExtensionsWrapper.audio);
        case NamidaStorageFileMemeType.video:
          _effectiveAllowedExtensions.add(NamidaFileExtensionsWrapper.video);
        case NamidaStorageFileMemeType.image:
          _effectiveAllowedExtensions.add(NamidaFileExtensionsWrapper.image);
        case NamidaStorageFileMemeType.media:
          _effectiveAllowedExtensions
            ..add(NamidaFileExtensionsWrapper.audio)
            ..add(NamidaFileExtensionsWrapper.video);
        case NamidaStorageFileMemeType.any:
      }
    }
    _initIconsLookup();

    if (isDesktop) {
      Timer(
        const Duration(milliseconds: 200), // give time for ui to layout to avoid hittest errors
        () => _onBackupPickerLaunch(_effectiveAllowedExtensions),
      );
    }
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
    _dirStatsWorker.dispose();
    _scrollController.dispose();
    _pathSplitsScrollController.dispose();
    _showHiddenFiles.close();
    _hasPermissionRx.close();
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

  void _navigateTo(String dirPath, {double? scrollOffset, String? invalidateStatsDirPath}) {
    try {
      _scrollPositionsSaved[_currentFolderPath] = _scrollController.offset; // saving current offset.
    } catch (_) {}
    _fetchFiles(dirPath, invalidateStatsDirPath: invalidateStatsDirPath);
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
    String newPath = pieces.join(_pathSeparator);
    // -- never climb above the root, ex: `C:\Users` -> `C:` would list the drive's working directory.
    final currentRoot = _mainStoragePaths.firstWhereEff((root) => _currentFolderPath.startsWith(root));
    if (currentRoot != null && newPath.length < currentRoot.length) newPath = currentRoot;
    _navigateTo(newPath, scrollOffset: _scrollPositionsSaved[newPath]);
  }

  void _onSelectionComplete(List<T> items) {
    widget.onSelect.completeIfWasnt(items);
    widget.onPop();
  }

  void _onFilesSelected(List<_FileEntry> entries) {
    final files = [for (final e in entries) File(e.path)];
    _onSelectionComplete(files as List<T>);
  }

  void _onDirectoriesSelected(List<String> dirPaths) {
    final dirs = [for (final path in dirPaths) Directory(path)];
    _onSelectionComplete(dirs as List<T>);
  }

  final _selectedFiles = <_FileEntry>[];
  final _selectedFilePaths = <String>{};
  void _onFileTap(_FileEntry file) {
    if (_selectedFiles.isNotEmpty) {
      _onFileLongPress(file);
    } else {
      if (T == File) _onFilesSelected([file]);
    }
  }

  void _onFileLongPress(_FileEntry file) {
    if (T != File) return;

    final alreadySelected = _selectedFilePaths.contains(file.path);

    if (_selectedFiles.isNotEmpty && !widget.allowMultiple) {
      _selectedFiles.clear();
      _selectedFilePaths.clear();
    }

    setState(() {
      if (alreadySelected) {
        _selectedFiles.removeWhere((e) => e.path == file.path);
        _selectedFilePaths.remove(file.path);
      } else {
        _selectedFiles.add(file);
        _selectedFilePaths.add(file.path);
      }
    });
  }

  final _selectedFolderPaths = <String>[];
  final _selectedFolderPathsLookup = <String>{};
  void _onFolderTap(_DirEntry dir) {
    if (_selectedFolderPaths.isNotEmpty) {
      _onFolderLongPress(dir);
    } else {
      _navigateTo(dir.path);
    }
  }

  void _onFolderLongPress(_DirEntry dir) {
    if (T != Directory) return;

    final alreadySelected = _selectedFolderPathsLookup.contains(dir.path);

    if (_selectedFolderPaths.isNotEmpty && !widget.allowMultiple) {
      _selectedFolderPaths.clear();
      _selectedFolderPathsLookup.clear();
    }

    setState(() {
      if (alreadySelected) {
        _selectedFolderPaths.remove(dir.path);
        _selectedFolderPathsLookup.remove(dir.path);
      } else {
        _selectedFolderPaths.add(dir.path);
        _selectedFolderPathsLookup.add(dir.path);
      }
    });
  }

  IconData _fileToIcon(_FileEntry file) {
    final iconIndex = _iconsLookupPre[file.extension];
    if (iconIndex != null) {
      final icon = _iconsLookup[iconIndex];
      if (icon != null) return icon;
    }
    return Broken.document_1;
  }

  ArtworkWidget? _getFileImage(_FileEntry file) {
    final iconIndex = _iconsLookupPre[file.extension];
    if (iconIndex != 2) return null;
    return ArtworkWidget(
      key: Key(file.path),
      thumbnailSize: 56.0,
      path: file.path,
      borderRadius: 8.0,
      blur: 4.0,
      disableBlurBgSizeShrink: true,
      fallbackToFolderCover: false,
      icon: _iconsLookup[2] ?? Broken.gallery,
    );
  }

  void _initIconsLookup() {
    for (final e in NamidaFileExtensionsWrapper.audio.extensions) {
      _iconsLookupPre[e] = 0;
    }
    for (final e in NamidaFileExtensionsWrapper.video.extensions) {
      _iconsLookupPre[e] = 1;
    }
    for (final e in NamidaFileExtensionsWrapper.image.extensions) {
      _iconsLookupPre[e] = 2;
    }
    for (final e in [...NamidaFileExtensionsWrapper.json.extensions, ...NamidaFileExtensionsWrapper.csv.extensions]) {
      _iconsLookupPre[e] = 3;
    }
    for (final e in NamidaFileExtensionsWrapper.m3u.extensions) {
      _iconsLookupPre[e] = 4;
    }
    for (final e in NamidaFileExtensionsWrapper.compressed.extensions) {
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

  Future<void> _onBackupPickerLaunch([List<NamidaFileExtensionsWrapper>? allowedExtensions]) async {
    final note = widget.note != '' ? widget.note : null;
    if (T == File) {
      final res = await NamidaStorage.inst.pickFiles(
        note: note,
        multiple: widget.allowMultiple,
        memetype: widget.memeType,
        allowedExtensions: allowedExtensions,
        initialDirectory: widget.initialDirectory,
      );
      final files = res.map((e) => File(e)).toList();
      if (files.isNotEmpty) _onSelectionComplete(files as List<T>);
    } else if (T == Directory) {
      final res = await NamidaStorage.inst.pickDirectory(
        note: note,
        initialDirectory: widget.initialDirectory,
      );
      if (res != null) _onSelectionComplete([Directory(res) as T]);
    }
  }

  List<Widget> get _getCurrentPathsSplitsChildren {
    if (_currentFolderPath == '') return [];
    // -- can be outside every known root (network mount, symlink, a drive added after the roots were fetched)
    final currentRoot = _mainStoragePaths.firstWhereEff((element) => _currentFolderPath.startsWith(element)) ?? '';
    final pathWithoutRoot = _currentFolderPath.substring(currentRoot.length);
    final splits = pathWithoutRoot.split(_pathSeparator);
    final map = <int, String>{};

    if (splits.isNotEmpty) {
      final sdCardRegex = RegExp(r'\w{4}-\w{4}', caseSensitive: false);
      map[0] = sdCardRegex.hasMatch(currentRoot) ? 'SD Card' : 'Home';
      int index = 1;
      final splitsSkipped = Platform.isWindows ? splits.skip(0) : splits.skip(1);
      for (final part in splitsSkipped) {
        if (part.isNotEmpty) {
          map[index] = part;
        }
        index++;
      }
    }

    final textTheme = context.textTheme;
    final widgets = <Widget>[];
    for (final e in map.entries) {
      widgets.add(
        TapDetector(
          onTap: () {
            if (e.key == map.length - 1) return; // same path

            String newDirPath = currentRoot;
            if (newDirPath.endsWith(_pathSeparator)) newDirPath = currentRoot.substring(0, currentRoot.length - 1);
            for (final entry in map.entries.skip(1)) {
              if (entry.key > e.key) break;
              newDirPath += _pathSeparator + entry.value;
            }
            if (newDirPath.startsWith(currentRoot)) {
              _navigateTo(newDirPath);
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
                style: textTheme.displayMedium,
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

  final _hasPermissionRx = true.obs; // assume yes until confirmed
  void _refreshPermissionStatus() async {
    _hasPermissionRx.value = await requestManageStoragePermission();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final chipColor = theme.cardColor;
    final pathSplitsChildren = _getCurrentPathsSplitsChildren;
    return NamidaPopScope(
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
              ObxO(
                rx: _hasPermissionRx,
                builder: (context, hasPermission) => hasPermission
                    ? const SizedBox()
                    : NamidaInkWell(
                        onTap: _refreshPermissionStatus,
                        borderRadius: 8.0,
                        bgColor: Colors.red.withOpacityExt(0.1),
                        margin: EdgeInsets.symmetric(horizontal: 8.0),
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            SizedBox(width: 8.0),
                            Icon(
                              Broken.warning_2,
                              size: 24.0,
                            ),
                            SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                lang.grantStoragePermission,
                                style: textTheme.displayMedium?.copyWith(
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.0),
                            NamidaInkWellButton(
                              onTap: _refreshPermissionStatus,
                              borderRadius: 6.0,
                              icon: null,
                              text: lang.manage,
                            ),
                            SizedBox(width: 8.0),
                          ],
                        ),
                      ),
              ),
              Row(
                children: [
                  const SizedBox(width: 4.0),
                  IconButton(
                    onPressed: () {
                      _onSelectionComplete(<T>[]);
                    },
                    icon: const Icon(
                      Broken.arrow_left_2,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Expanded(
                    child: widget.note != ''
                        ? Text(
                            widget.note.addDQuotation(),
                            style: textTheme.displayMedium?.copyWith(
                              fontSize: 16.0,
                            ),
                          )
                        : const SizedBox(),
                  ),
                  if (T == Directory)
                    IconButton(
                      tooltip: lang.folder,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () {
                        final dirController = TextEditingController();
                        NamidaNavigator.inst.navigateDialog(
                          onDisposing: () {
                            dirController.dispose();
                          },
                          dialogBuilder: (theme) => CustomBlurryDialog(
                            title: lang.folder,
                            actions: [
                              const CancelButton(),
                              NamidaButton(
                                text: lang.confirm,
                                onTap: () {
                                  final text = dirController.text;
                                  if (text.length > 2) {
                                    NamidaNavigator.inst.closeDialog();
                                    _onDirectoriesSelected([text]);
                                  }
                                },
                              ),
                            ],
                            child: Column(
                              children: [
                                const SizedBox(height: 12.0),
                                CustomTagTextField(
                                  controller: dirController,
                                  hintText: '',
                                  labelText: lang.folder,
                                  validatorMode: AutovalidateMode.always,
                                  validator: (value) {
                                    value ??= '';
                                    if (value.isEmpty) {
                                      return lang.emptyValue;
                                    }
                                    try {
                                      if (!DirectoryIndexLocal(value).existsSync()) {
                                        return lang.directoryDoesntExist;
                                      }
                                    } catch (e) {
                                      return e.toString();
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12.0),
                              ],
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Broken.wallet_1,
                        size: 20.0,
                        color: context.defaultIconColor(),
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
                              bgColor: _currentFolderPath.startsWith(e) ? theme.colorScheme.secondaryContainer : theme.cardColor,
                              onTap: () => _navigateTo(e),
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Text(
                                e,
                                style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toFixedList(),
                    ),
                  ),
                ),
              if (pathSplitsChildren.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: SizedBox(
                    width: context.width,
                    child: SmoothSingleChildScrollView(
                      controller: _pathSplitsScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: pathSplitsChildren,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: .end,
                  children: [
                    if (_visibleFolders.isNotEmpty || _currentFiles.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                          child: Text(
                            [
                              if (_visibleFolders.isNotEmpty) _visibleFolders.length.displayFolderKeyword,
                              if (_currentFiles.isNotEmpty) _currentFiles.length.displayFilesKeyword,
                            ].join(' | '),
                            style: textTheme.displayMedium,
                          ),
                        ),
                      ),
                    if (T == Directory)
                      IconButton(
                        tooltip: lang.newDirectory,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () {
                          final dirController = TextEditingController();
                          NamidaNavigator.inst.navigateDialog(
                            onDisposing: () {
                              dirController.dispose();
                            },
                            dialogBuilder: (theme) => CustomBlurryDialog(
                              title: lang.newDirectory,
                              actions: [
                                const CancelButton(),
                                NamidaButton(
                                  text: lang.create,
                                  onTap: () {
                                    final name = dirController.text;
                                    final fullPath = FileParts.joinPath(_currentFolderPath, name);
                                    try {
                                      Directory(fullPath).createSync(recursive: true);
                                      _navigateTo(fullPath, invalidateStatsDirPath: fullPath);
                                    } catch (e) {
                                      snackyy(title: lang.error, message: e.toString(), isError: true);
                                    }
                                    NamidaNavigator.inst.closeDialog();
                                  },
                                ),
                              ],
                              child: Column(
                                children: [
                                  const SizedBox(height: 12.0),
                                  CustomTagTextField(
                                    controller: dirController,
                                    hintText: '',
                                    labelText: lang.newDirectory,
                                    validatorMode: AutovalidateMode.always,
                                    validator: (name) {
                                      name ??= '';
                                      if (name.isEmpty) {
                                        return lang.pleaseEnterAName;
                                      }
                                      try {
                                        final fullPath = FileParts.joinPath(_currentFolderPath, name);
                                        if (DirectoryIndexLocal(fullPath).existsSync()) {
                                          return lang.alreadyExists;
                                        }
                                      } catch (e) {
                                        return e.toString();
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12.0),
                                ],
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Broken.add_circle,
                          size: 20.0,
                          color: context.defaultIconColor(),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Show empty folders',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () {
                        setState(() {
                          _showEmptyFolders = !_showEmptyFolders;
                          _refreshVisibleFolders();
                        });
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
                        _fetchFiles(_currentFolderPath);
                      },
                      icon: Obx(
                        (context) => Icon(
                          _showHiddenFiles.valueR ? Broken.eye : Broken.eye_slash,
                          size: 20.0,
                          color: _showHiddenFiles.valueR ? null : context.defaultIconColor(),
                        ),
                      ),
                    ),
                    Obx(
                      (context) => SortByMenu(
                        title: _sortTypeToName[settings.fileBrowserSort.valueR] ?? '',
                        popupMenuChild: SortByMenuCustom(
                          childrenCallback: (context) {
                            Widget getTile(IconData icon, String title, FileBrowserSortType sort) {
                              return ObxO(
                                rx: settings.fileBrowserSort,
                                builder: (context, currentSort) => SmallListTile(
                                  borderRadius: 12.0,
                                  visualDensity: const VisualDensity(horizontal: -4, vertical: -3.5),
                                  trailing: Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Icon(icon, size: 20.0),
                                  ),
                                  title: title,
                                  active: currentSort == sort,
                                  onTap: () => _sortItems(sort, null),
                                ),
                              );
                            }

                            return [
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
                                child: ListTileWithCheckMark(
                                  borderRadius: 10.0,
                                  activeRx: settings.fileBrowserSortReversed,
                                  onTap: () => _sortItems(null, !settings.fileBrowserSortReversed.value),
                                ),
                              ),
                              getTile(Broken.text, lang.fileName, FileBrowserSortType.name),
                              getTile(Broken.calendar, lang.date, FileBrowserSortType.dateModified),
                              getTile(Broken.document_code, lang.extension, FileBrowserSortType.type),
                              getTile(Broken.math, lang.size, FileBrowserSortType.size),
                            ];
                          },
                        ),
                        isCurrentlyReversed: settings.fileBrowserSortReversed.valueR,
                        onReverseIconTap: () => _sortItems(null, !settings.fileBrowserSortReversed.value),
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
                        onRefresh(_refreshCurrentFolder);
                      },
                      onPointerCancel: (event) => onVerticalDragFinish(),
                      child: _isFetching
                          ? Center(
                              key: const Key('loading'),
                              child: ThreeArchedCircle(
                                color: theme.colorScheme.primary.withOpacityExt(0.5),
                                size: 56.0,
                              ),
                            )
                          : _visibleFolders.isEmpty && _currentFiles.isEmpty
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
                                    "0 ${lang.files}",
                                    style: textTheme.displayLarge,
                                  ),
                                ],
                              ),
                            )
                          : AnimationLimiter(
                              key: const Key('items'),
                              child: NamidaScrollbar(
                                controller: _scrollController,
                                child: SmoothCustomScrollView(
                                  controller: _scrollController,
                                  slivers: [
                                    SuperSliverList.builder(
                                      itemCount: _visibleFolders.length,
                                      itemBuilder: (context, index) {
                                        final folder = _visibleFolders[index];
                                        final stats = folder.stats;
                                        final subtitle = stats == null ? '…' : stats.toSubtitle();
                                        return _FileSystemChip(
                                          position: index,
                                          bgColor: chipColor,
                                          onTap: () => _onFolderTap(folder),
                                          onLongPress: () => _onFolderLongPress(folder),
                                          displayCheckMark: _selectedFolderPaths.isNotEmpty,
                                          selected: _selectedFolderPathsLookup.contains(folder.path),
                                          icon: Broken.folder,
                                          title: folder.name,
                                          subtitle: subtitle,
                                        );
                                      },
                                    ),
                                    if (_visibleFolders.isNotEmpty && _currentFiles.isNotEmpty)
                                      const SliverToBoxAdapter(
                                        child: NamidaContainerDivider(
                                          margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                                        ),
                                      ),
                                    SuperSliverList.builder(
                                      itemCount: _currentFiles.length,
                                      itemBuilder: (context, index) {
                                        final file = _currentFiles[index];
                                        final image = _getFileImage(file);
                                        return _FileSystemChip(
                                          position: index + _visibleFolders.length + 1,
                                          bgColor: chipColor,
                                          onTap: () => _onFileTap(file),
                                          onLongPress: () => _onFileLongPress(file),
                                          displayCheckMark: _selectedFiles.isNotEmpty,
                                          selected: _selectedFilePaths.contains(file.path),
                                          icon: image == null ? _fileToIcon(file) : null,
                                          leading: image,
                                          title: file.name,
                                          subtitle: "${file.size.fileSizeFormatted} | ${file.modifiedMS.dateAndClockFormattedOriginal}",
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
                      child: CustomAnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: T == File && _selectedFiles.isNotEmpty
                            ? NamidaFABButton(
                                big: true,
                                icon: Broken.tick_square,
                                text: _selectedFiles.length.displayFilesKeyword,
                                onTap: () => _onFilesSelected(_selectedFiles),
                              )
                            : T == Directory && (_selectedFolderPaths.isNotEmpty || !isPathRoot(_currentFolderPath))
                            ? NamidaFABButton(
                                big: true,
                                icon: Broken.tick_square,
                                onTap: () => _onDirectoriesSelected(_selectedFolderPaths.isNotEmpty ? _selectedFolderPaths : [_currentFolderPath]),
                              )
                            : const SizedBox(),
                      ),
                    ),
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

/// main-isolate side of the folder sizes worker, results come in as they finish, cached ones first.
///
/// by claude
class _DirStatsWorker with PortsProvider<SendPort> {
  final void Function(List<_DirStatsResult> results) onStats;

  _DirStatsWorker({required this.onStats});

  Future<void>? _ready;

  /// replaces the walker's queue, [invalidateDirPath] first drops that folder, its subtree and its ancestors from the cache.
  Future<void> request(List<String> dirPaths, {String? invalidateDirPath}) async {
    final ready = _ready ??= initialize();
    await ready;
    await sendPort(_DirStatsRequest(dirPaths, invalidateDirPath: invalidateDirPath));
  }

  Future<void> dispose() async {
    final ready = _ready;
    if (ready == null) return;
    await ready;
    await disposePort();
  }

  @override
  void onResult(dynamic result) {
    onStats(result as List<_DirStatsResult>);
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) => IsolateFunctionReturnBuild(_isolateEntry, port);

  static void _isolateEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    final walker = _DirStatsWalker(sendPort);

    StreamSubscription? streamSub;
    streamSub = receivePort.listen((p) {
      if (p == PortsProviderMessages.disposed) {
        walker.dispose();
        receivePort.close();
        streamSub?.cancel();
        return;
      }
      p as _DirStatsRequest;
      walker.enqueue(p.dirPaths, invalidateDirPath: p.invalidateDirPath);
    });

    sendPort.send(PortsProviderMessages.prepared);
  }
}

/// every fully walked directory is cached, so a parent walk reuses its children and an aborted walk keeps what it finished.
/// the walk yields to the event loop regularly, which is how a newer request gets to abort it.
///
/// by claude
class _DirStatsWalker {
  static const _kYieldEveryMS = 8;
  static const _kYieldCheckFilesMask = 511;

  final SendPort _resultsPort;
  final _cache = <String, _DirStats>{};
  List<String> _queue = const [];
  int _queueIndex = 0;
  String? _walkingPath;
  bool _shouldAbortWalk = false;
  bool _isWorking = false;

  _DirStatsWalker(this._resultsPort);

  void enqueue(List<String> dirPaths, {String? invalidateDirPath}) {
    if (invalidateDirPath != null) _cache.removeWhere((path, _) => _arePathsRelated(path, invalidateDirPath));

    final cachedResults = <_DirStatsResult>[];
    final missing = <String>[];
    for (final path in dirPaths) {
      final cached = _cache[path];
      if (cached == null) {
        missing.add(path);
      } else {
        cachedResults.add(_DirStatsResult(path, cached));
      }
    }
    if (cachedResults.isNotEmpty) _resultsPort.send(cachedResults);

    final walkingPath = _walkingPath;
    if (walkingPath != null) {
      final isWalkStale = invalidateDirPath != null && _arePathsRelated(walkingPath, invalidateDirPath);
      final walkingIndex = missing.indexOf(walkingPath);
      final isStillWanted = walkingIndex != -1;
      if (isStillWanted && !isWalkStale && !_shouldAbortWalk) {
        missing.removeAt(walkingIndex); // -- the running walk delivers it
      } else {
        _shouldAbortWalk = true;
      }
    }

    _queue = missing;
    _queueIndex = 0;
    if (!_isWorking) _work();
  }

  void dispose() {
    _shouldAbortWalk = true;
    _queue = const [];
    _queueIndex = 0;
  }

  Future<void> _work() async {
    _isWorking = true;
    while (_queueIndex < _queue.length) {
      final path = _queue[_queueIndex++];
      final cached = _cache[path];
      if (cached != null) {
        _resultsPort.send([_DirStatsResult(path, cached)]);
        continue;
      }
      _walkingPath = path;
      _shouldAbortWalk = false;
      final stats = await _walk(path);
      _walkingPath = null;
      if (stats != null) _resultsPort.send([_DirStatsResult(path, stats)]);
    }
    _isWorking = false;
  }

  /// null when aborted.
  Future<_DirStats?> _walk(String rootPath) async {
    final stopwatch = Stopwatch()..start();
    final rootFrame = _WalkFrame(rootPath);
    final didListRoot = await _listFrame(rootFrame, stopwatch);
    if (!didListRoot) return null;

    final stack = <_WalkFrame>[rootFrame];
    while (true) {
      final frame = stack.last;
      if (frame.nextSubDirIndex < frame.subDirPaths.length) {
        final subDirPath = frame.subDirPaths[frame.nextSubDirIndex++];
        final cached = _cache[subDirPath];
        if (cached != null) {
          frame.addSubDir(cached);
        } else {
          final subFrame = _WalkFrame(subDirPath);
          final didList = await _listFrame(subFrame, stopwatch);
          if (!didList) return null;
          stack.add(subFrame);
        }
      } else {
        stack.removeLast();
        final stats = frame.toStats();
        _cache[frame.path] = stats;
        if (stack.isEmpty) return stats;
        stack.last.addSubDir(stats);
      }

      if (stopwatch.elapsedMilliseconds >= _kYieldEveryMS) {
        await _yield(stopwatch);
        if (_shouldAbortWalk) return null;
      }
    }
  }

  /// false when aborted midway.
  Future<bool> _listFrame(_WalkFrame frame, Stopwatch stopwatch) async {
    final List<FileSystemEntity> items;
    try {
      items = Directory(frame.path).listSync(followLinks: false);
    } catch (_) {
      frame.isAccurate = false;
      return true;
    }

    final subDirPaths = <String>[];
    final itemsLength = items.length;
    for (int i = 0; i < itemsLength; i++) {
      final e = items[i];
      if (e is File) {
        frame.size += e.statSync().size;
        frame.filesCount++;
      } else if (e is Directory) {
        subDirPaths.add(e.path);
      }
      final shouldCheckYield = (i & _kYieldCheckFilesMask) == _kYieldCheckFilesMask;
      if (shouldCheckYield && stopwatch.elapsedMilliseconds >= _kYieldEveryMS) {
        await _yield(stopwatch);
        if (_shouldAbortWalk) return false;
      }
    }
    frame.subDirPaths = subDirPaths;
    return true;
  }

  Future<void> _yield(Stopwatch stopwatch) async {
    await Future.delayed(Duration.zero);
    stopwatch.reset();
  }
}

/// same path, inside it, or one of its ancestors.
bool _arePathsRelated(String a, String b) {
  if (a == b) return true;
  return _isPathInside(a, b) || _isPathInside(b, a);
}

bool _isPathInside(String child, String parent) {
  final parentLength = parent.length;
  if (child.length <= parentLength) return false;
  if (!child.startsWith(parent)) return false;
  if (parent.codeUnitAt(parentLength - 1) == _pathSeparatorCodeUnit) return true;
  return child.codeUnitAt(parentLength) == _pathSeparatorCodeUnit;
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
    final textTheme = context.textTheme;
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
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w400,
                    // color: theme.colorScheme.onSurface.withOpacityExt(0.7),
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

class _FileEntry {
  final String path;
  final String name;
  final String nameLower;
  final String extension;
  final int size;
  final int modifiedMS;

  const _FileEntry({
    required this.path,
    required this.name,
    required this.nameLower,
    required this.extension,
    required this.size,
    required this.modifiedMS,
  });

  static Comparator<_FileEntry> comparatorOf(FileBrowserSortType type, bool reversed) {
    final compare = switch (type) {
      FileBrowserSortType.name => _compareByName,
      FileBrowserSortType.dateModified => _compareByDate,
      FileBrowserSortType.type => _compareByExtension,
      FileBrowserSortType.size => _compareBySize,
    };
    return reversed ? (a, b) => compare(b, a) : compare;
  }

  static int _compareByName(_FileEntry a, _FileEntry b) => a.nameLower.compareTo(b.nameLower);

  static int _compareByDate(_FileEntry a, _FileEntry b) {
    final compare = a.modifiedMS.compareTo(b.modifiedMS);
    return compare != 0 ? compare : _compareByName(a, b);
  }

  static int _compareByExtension(_FileEntry a, _FileEntry b) {
    final compare = a.extension.compareTo(b.extension);
    return compare != 0 ? compare : _compareByName(a, b);
  }

  static int _compareBySize(_FileEntry a, _FileEntry b) {
    final compare = a.size.compareTo(b.size);
    return compare != 0 ? compare : _compareByName(a, b);
  }
}

class _DirEntry {
  final String path;
  final String name;
  final String nameLower;
  final int modifiedMS;
  _DirStats? stats;

  _DirEntry({
    required this.path,
    required this.name,
    required this.nameLower,
    required this.modifiedMS,
  });

  static Comparator<_DirEntry> comparatorOf(FileBrowserSortType type, bool reversed) {
    final compare = switch (type) {
      FileBrowserSortType.name || FileBrowserSortType.type => _compareByName,
      FileBrowserSortType.dateModified => _compareByDate,
      FileBrowserSortType.size => _compareBySize,
    };
    return reversed ? (a, b) => compare(b, a) : compare;
  }

  static int _compareByName(_DirEntry a, _DirEntry b) => a.nameLower.compareTo(b.nameLower);

  static int _compareByDate(_DirEntry a, _DirEntry b) {
    final compare = a.modifiedMS.compareTo(b.modifiedMS);
    return compare != 0 ? compare : _compareByName(a, b);
  }

  static int _compareBySize(_DirEntry a, _DirEntry b) {
    final sizeA = a.stats?.size ?? -1;
    final sizeB = b.stats?.size ?? -1;
    final compare = sizeA.compareTo(sizeB);
    return compare != 0 ? compare : _compareByName(a, b);
  }
}

class _DirStats {
  final int size;
  final int filesCount;
  final int foldersCount;
  final bool isAccurate;

  const _DirStats({
    required this.size,
    required this.filesCount,
    required this.foldersCount,
    required this.isAccurate,
  });

  bool get isEmpty => isAccurate && filesCount == 0 && foldersCount == 0;

  String toSubtitle() {
    final marker = isAccurate ? '' : '?';
    return [
      "${size.fileSizeFormatted}$marker",
      if (filesCount > 0) "${filesCount.displayFilesKeyword}$marker",
      if (foldersCount > 0) "${foldersCount.displayFolderKeyword}$marker",
    ].join(' | ');
  }
}

class _WalkFrame {
  final String path;
  List<String> subDirPaths = const [];
  int nextSubDirIndex = 0;
  int size = 0;
  int filesCount = 0;
  bool isAccurate = true;

  _WalkFrame(this.path);

  void addSubDir(_DirStats stats) {
    size += stats.size;
    if (!stats.isAccurate) isAccurate = false;
  }

  _DirStats toStats() => _DirStats(
    size: size,
    filesCount: filesCount,
    foldersCount: subDirPaths.length,
    isAccurate: isAccurate,
  );
}

class _DirStatsRequest {
  final List<String> dirPaths;
  final String? invalidateDirPath;

  const _DirStatsRequest(this.dirPaths, {this.invalidateDirPath});
}

class _DirStatsResult {
  final String dirPath;
  final _DirStats stats;

  const _DirStatsResult(this.dirPath, this.stats);
}

class _ListParams {
  final String dirPath;
  final bool showHiddenFiles;
  final List<NamidaFileExtensionsWrapper> allowedExtensions;
  final FileBrowserSortType sortType;
  final bool reversed;

  const _ListParams({
    required this.dirPath,
    required this.showHiddenFiles,
    required this.allowedExtensions,
    required this.sortType,
    required this.reversed,
  });
}

class _ListResult {
  final List<_FileEntry> files;
  final List<_DirEntry> folders;
  final Object? error;

  const _ListResult({
    required this.files,
    required this.folders,
    required this.error,
  });
}
