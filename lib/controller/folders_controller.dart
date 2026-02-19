import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class FoldersController<T extends Folder, E extends Track> {
  static final FoldersController<Folder, Track> tracksAndVideos = FoldersController<Folder, Track>._(
    Indexer.inst.mainMapFoldersTracksAndVideos,
    LibraryTab.folders,
    FoldersPageConfig.tracksAndVideos(),
  );
  static final FoldersController<Folder, Track> tracks = FoldersController<Folder, Track>._(
    Indexer.inst.mainMapFoldersTracks,
    LibraryTab.foldersMusic,
    FoldersPageConfig.tracks(),
  );
  static final FoldersController<VideoFolder, Video> videos = FoldersController<VideoFolder, Video>._(
    Indexer.inst.mainMapFoldersVideos,
    LibraryTab.foldersVideos,
    FoldersPageConfig.videos(),
  );
  FoldersController._(this._foldersMap, this._tab, this._config);

  RxBaseCore<Map<T, List<E>>> get foldersMap => _foldersMap;
  LibraryTab get libraryTab => _tab;
  QueueSource get queueSource => _config.queueSource;

  String getCurrentFolderToBookmark() {
    if (isHome.value) return '';
    return currentFolder.value?.path ?? '';
  }

  final RxMap<T, List<E>> _foldersMap;
  final LibraryTab _tab;
  final FoldersPageConfig _config;

  final Rxn<T> currentFolder = Rxn<T>();

  final RxList<T> currentFolderslist = <T>[].obs;
  List<E>? get currentFolderTracksList => folderToTracks(currentFolder.value);

  List<E>? folderToTracks(T? folder) {
    return folder == null ? null : _foldersMap.value[folder];
  }

  int? currentNodeFoldersCount(T folder, {bool recursive = false, bool preferRecursiveForRootFolders = false}) {
    if (preferRecursiveForRootFolders) {
      final isRoot = isHome.value; // yeah whatever for now
      if (isRoot) recursive = true;
    }
    return _pathsTreeMapCurrent?.getFoldersCountInsideFolder(folder, recursive: recursive) ?? //
        _pathsTreeMapRoot.getFoldersCountInsideFolder(folder, recursive: recursive);
  }

  List<E> getNodeTracks(T folder, {bool recursive = false}) {
    return _pathsTreeMapCurrent?.getTracksCountInsideFolder(folder, recursive: recursive).nullifyEmpty() ?? //
        _pathsTreeMapRoot.getTracksCountInsideFolder(folder, recursive: recursive).nullifyEmpty() ??
        [];
  }

  late var _pathsTreeMapRoot = _FolderNode<T, E>(null, null, folderToTracks);
  _FolderNode<T, E>? _pathsTreeMapCurrent;

  /// Even with this logic, root paths are invincible.
  final isHome = true.obs;

  /// Used for non-hierarchy.
  final isInside = false.obs;

  /// Highlights the track that is meant to be navigated to after calling [stepIn].
  final indexToScrollTo = Rxn<int>();
  E? _trackToScrollTo;

  final _latestScrollOffset = <T?, double>{};

  void refreshAfterSorting() {
    currentFolderslist.refresh(); // refreshes folders
    currentFolder.refresh(); // refreshes tracks
    if (_trackToScrollTo != null && currentFolder.value != null) {
      indexToScrollTo.value = folderToTracks(currentFolder.value as T)?.indexOf(_trackToScrollTo!);
    }
  }

  /// Indicates wether the navigator can go back at this point.
  /// Returns true only if at home, otherwise will call [stepOut] and return false.
  bool onBackButton() {
    return !stepOut();
  }

  void stepIn(T? folder, {E? trackToScrollTo, double jumpTo = 0, bool isFromStepOut = false}) {
    if (folder == null || folder.path == '') {
      isHome.value = true;
      _pathsTreeMapCurrent = null;
    }

    final treeMap = _pathsTreeMapCurrent ??= _pathsTreeMapRoot;

    _FolderNode<T, E>? nextNode;
    if (folder != null) {
      nextNode = treeMap.children[folder] ?? _pathsTreeMapRoot.lookup(folder);
    }

    bool isInitialNodeNested = false;
    if (nextNode == null) {
      isHome.value = true;
      isInitialNodeNested = true;
      nextNode = _pathsTreeMapRoot;
      if (nextNode.children.keys.length == 1) {
        nextNode = nextNode.children.values.first;
      }
    }

    if (!isInitialNodeNested && !isFromStepOut) {
      isInside.value = true;
      isHome.value = false;
    }

    final upcomingFolders = nextNode.foldersList;

    _pathsTreeMapCurrent = nextNode;

    if (!isFromStepOut) {
      if (upcomingFolders.length == 1 && folderToTracks(folder)?.isEmpty == true) {
        stepIn(upcomingFolders.first);
        return;
      }
    }

    _saveScrollOffset(currentFolder.value);

    currentFolderslist.value = upcomingFolders;
    currentFolder.value = folder;

    if (trackToScrollTo != null) {
      indexToScrollTo.value = folderToTracks(folder)?.indexOf(trackToScrollTo);
      _trackToScrollTo = trackToScrollTo;
    } else {
      indexToScrollTo.value = null;
      _trackToScrollTo = null;
    }

    _scrollJump(jumpTo);
  }

  bool stepOut() {
    isInside.value = false;
    if (currentFolder.value == null) {
      return false;
    }

    T? folderToStepIn;
    if (_config.enableFoldersHierarchy.value) {
      do {
        folderToStepIn = _pathsTreeMapCurrent?.parent;
        _pathsTreeMapCurrent = _pathsTreeMapCurrent?.parentNode;
      } while (_pathsTreeMapCurrent != null && _pathsTreeMapCurrent?.children.keys.length == 1 && (folderToTracks(folderToStepIn?.parent)?.isEmpty != false));
    }

    folderToStepIn = _pathsTreeMapCurrent?.parent;
    _pathsTreeMapCurrent = _pathsTreeMapCurrent?.parentNode;

    if (folderToStepIn == currentFolder.value || _pathsTreeMapCurrent == _pathsTreeMapRoot) {
      folderToStepIn = null;
      _pathsTreeMapCurrent = null;
    }

    indexToScrollTo.value = null;
    stepIn(folderToStepIn, jumpTo: _latestScrollOffset[folderToStepIn] ?? 0, isFromStepOut: true);

    return true;
  }

  void onFirstLoad() {
    if (_config.enableFoldersHierarchy.value) {
      final startupPath = _config.defaultFolderStartupLocation.value;
      if (startupPath != null) stepIn(Folder.fromType<T>(startupPath));
    }
  }

  void onFoldersHierarchyChanged(bool enabled) {
    isHome.value = true;
    isInside.value = false;
    stepIn(null);
  }

  void _saveScrollOffset(T? folder) {
    if (folder == null) return;
    try {
      _latestScrollOffset[folder] = _tab.scrollController.offset;
    } catch (_) {
      _latestScrollOffset[folder] = 0;
    }
  }

  void _scrollJump(double to) {
    if (_tab.scrollController.hasClients) {
      try {
        _tab.scrollController.jumpTo(to);
      } catch (_) {}
    }
  }

  /// Generates missing folders in between
  void onMapChanged(Map<T, List<E>> map) {
    _pathsTreeMapRoot = _FolderNode<T, E>(null, null, folderToTracks); // -- vip to properly refill nodes in new sort order
    final res = _buildAdvancedPathTree(_pathsTreeMapRoot, map.keys);
    _pathsTreeMapRoot = res.$1;
    _pathsTreeMapCurrent ??= _pathsTreeMapRoot;
    for (final folder in res.$2) {
      map[folder] ??= <E>[]; // adding missing/new folders
    }
    _sortMap(map, _pathsTreeMapRoot);
    if (_config.enableFoldersHierarchy.value) stepIn(_pathsTreeMapCurrent?.parent);
  }

  void _sortMap(Map<T, List<dynamic>> map, _FolderNode<T, E> rootNode) {
    final folderToNameCompare = settings.ignoreCommonPrefixForTypes.value.contains(TrackSearchFilter.folder)
        ? (T folder) => folder.folderName.toLowerCase().ignoreCommonPrefixes()
        : (T folder) => folder.folderName.toLowerCase();

    final parsedMap = _buildParsedMap(map.keys.map((e) => folderToNameCompare(e)));

    int compare(MapEntry<T, dynamic> entryA, MapEntry<T, dynamic> entryB) {
      final a = folderToNameCompare(entryA.key);
      final b = folderToNameCompare(entryB.key);
      final parsedA = parsedMap[a];
      final parsedB = parsedMap[b];
      if (parsedA != null && parsedB != null) {
        final numbersCompare = parsedA.compare(parsedB);
        if (numbersCompare != null && numbersCompare != 0) return numbersCompare;
      }
      return a.compareTo(b);
    }

    final sorted = map.entries.toList()..sort(compare);
    map.assignAllEntries(sorted); // we clear after building new sorted one

    _FolderNode._walkChildrenRescursive(rootNode, (map) => map.sort(compare));

    refreshAfterSorting();
  }

  (_FolderNode<T, E>, List<T>) _buildAdvancedPathTree(_FolderNode<T, E> root, Iterable<T> folders) {
    final allFolders = <T>[];
    for (final folder in folders) {
      var current = root;
      folder.performInbetweenFoldersBuild(
        (f) {
          allFolders.add(f);
          final newNode = current.children.putIfAbsent(f, () => _FolderNode<T, E>(current, f, folderToTracks));
          current = newNode;
        },
      );
    }

    return (root, allFolders);
  }

  Map<String, _ParsedResult?> _buildParsedMap(Iterable<String> names) {
    final parsedMap = <String, _ParsedResult?>{};
    for (final n in names) {
      parsedMap[n] = _numberInFilename(n) ?? _parseNumberAtEnd(n);
    }
    return parsedMap;
  }

  static final _numberInFilenameRegex = RegExp(r'(.*music\W*)(\d+(\.\d+)?)', caseSensitive: false);
  static _ParsedResult? _numberInFilename(String text) {
    final m = _numberInFilenameRegex.firstMatch(text);
    if (m != null) {
      final nmbrtxt = m.group(2);
      if (nmbrtxt != null) {
        final parsednmbr = num.tryParse(nmbrtxt);
        if (parsednmbr != null) {
          int numberStartIndex = m[0]?.indexOf(nmbrtxt) ?? 0;
          if (numberStartIndex < 0) numberStartIndex = 0;
          return _ParsedResult(
            extractedNumber: parsednmbr,
            charactersCount: nmbrtxt.length,
            startAtIndex: numberStartIndex,
            textPart: m.group(1) ?? text.substring(0, numberStartIndex),
          );
        }
      }
    }

    return null;
  }

  static _ParsedResult? _parseNumberAtEnd(String text) {
    final codes = text.codeUnits;
    final codesL = codes.length;
    bool wasAddingNumber = false;
    final charCodes = <int>[];
    for (int i = codesL - 1; i >= 0; i--) {
      final code = codes[i];
      if (code >= 0x0030 && code <= 0x0039) {
        // -- from 0 to 9
        wasAddingNumber = true;
        charCodes.add(code);
      } else {
        if (wasAddingNumber) break;
      }
    }
    if (charCodes.isNotEmpty) {
      final startIndex = codes.length - charCodes.length;
      try {
        return _ParsedResult(
          extractedNumber: num.parse(String.fromCharCodes(charCodes.reversed)),
          charactersCount: charCodes.length,
          startAtIndex: startIndex,
          textPart: text.substring(0, startIndex),
        );
      } catch (_) {
        // -- big numbers and format exception
      }
    }
    return null;
  }
}

class _ParsedResult {
  final num extractedNumber;
  final int charactersCount;
  final int startAtIndex;
  final String textPart;

  const _ParsedResult({
    required this.extractedNumber,
    required this.charactersCount,
    required this.startAtIndex,
    required this.textPart,
  });

  int? compare(_ParsedResult parsedB) {
    final parsedA = this;
    if (parsedA.startAtIndex == parsedB.startAtIndex) {
      // -- basically checking textPart is enough to know but we check startAtIndex to speed things up.
      if (parsedA.textPart == parsedB.textPart) {
        final numbersCompare = parsedA.extractedNumber.compareTo(parsedB.extractedNumber);
        if (numbersCompare != 0) return numbersCompare;
      }
    }
    return null;
  }
}

class FoldersPageConfig {
  final QueueSource queueSource;
  final Rx<String?> defaultFolderStartupLocation;
  final Rx<bool> enableFoldersHierarchy;
  final void Function() toggleFoldersHierarchy;
  final void Function() onDefaultStartupFolderChanged;

  const FoldersPageConfig._({
    required this.queueSource,
    required this.defaultFolderStartupLocation,
    required this.enableFoldersHierarchy,
    required this.toggleFoldersHierarchy,
    required this.onDefaultStartupFolderChanged,
  });

  factory FoldersPageConfig.tracksAndVideos() {
    return FoldersPageConfig._(
      queueSource: QueueSource.folder,
      defaultFolderStartupLocation: settings.defaultFolderStartupLocation, // same settings
      enableFoldersHierarchy: settings.enableFoldersHierarchy, // same settings
      toggleFoldersHierarchy: () {
        final newValue = !settings.enableFoldersHierarchy.value;
        settings.save(enableFoldersHierarchy: newValue);
        FoldersController.tracksAndVideos.onFoldersHierarchyChanged(newValue);
      },
      onDefaultStartupFolderChanged: () {
        settings.save(
          defaultFolderStartupLocation: FoldersController.tracksAndVideos.getCurrentFolderToBookmark(),
        );
      },
    );
  }
  factory FoldersPageConfig.tracks() {
    return FoldersPageConfig._(
      queueSource: QueueSource.folderMusic,
      defaultFolderStartupLocation: settings.defaultFolderStartupLocation,
      enableFoldersHierarchy: settings.enableFoldersHierarchyTracks,
      toggleFoldersHierarchy: () {
        final newValue = !settings.enableFoldersHierarchyTracks.value;
        settings.save(enableFoldersHierarchyTracks: newValue);
        FoldersController.tracks.onFoldersHierarchyChanged(newValue);
      },
      onDefaultStartupFolderChanged: () {
        settings.save(
          defaultFolderStartupLocation: FoldersController.tracks.getCurrentFolderToBookmark(),
        );
      },
    );
  }
  factory FoldersPageConfig.videos() {
    return FoldersPageConfig._(
      queueSource: QueueSource.folderVideos,
      defaultFolderStartupLocation: settings.defaultFolderStartupLocationVideos,
      enableFoldersHierarchy: settings.enableFoldersHierarchyVideos,
      toggleFoldersHierarchy: () {
        final newValue = !settings.enableFoldersHierarchyVideos.value;
        settings.save(enableFoldersHierarchyVideos: newValue);
        FoldersController.videos.onFoldersHierarchyChanged(newValue);
      },
      onDefaultStartupFolderChanged: () {
        settings.save(
          defaultFolderStartupLocationVideos: FoldersController.videos.getCurrentFolderToBookmark(),
        );
      },
    );
  }
}

class _FolderNode<T extends Folder, E extends Track> {
  final _FolderNode<T, E>? parentNode;
  final T? parent;
  final List<E>? Function(T? folder) folderToTracks;
  _FolderNode(this.parentNode, this.parent, this.folderToTracks);

  final children = <T, _FolderNode<T, E>>{};

  late final foldersList = children.keys.toList();

  /// Efficient lookup for a folder. this operation is O(n) where n is the folder path splits count.
  _FolderNode<T, E>? lookup(T folder) {
    _FolderNode<T, E> current = this;
    final mainInMap = children[folder];
    if (mainInMap != null) return current;

    final res =
        folder.performInbetweenFoldersBuild(
          (f) {
            final newNode = current.children[f];
            if (newNode == null) return current;
            current = newNode;
            return null; // continue recursive
          },
        ) ??
        current;
    // -- vip, we use current as a dummy node once the initial check is done
    return (identical(this, current) ? null : res);
  }

  int? getFoldersCountInsideFolder(T folder, {bool recursive = false}) {
    final parentNode = lookup(folder);

    final node = parentNode?.children[folder];

    if (node != null) {
      if (recursive) {
        int totalCount = -1; // bcz recursive counts current
        _walkKeysRescursive<Null, T, E>(node, (_) {
          totalCount++;
          return null;
        });
        return totalCount;
      } else {
        return node.children.keys.length;
      }
    }
    return null;
  }

  List<E> getTracksCountInsideFolder(T folder, {bool recursive = false}) {
    if (!recursive) return folderToTracks(folder) ?? [];

    final parentNode = lookup(folder);

    final node = parentNode?.children[folder];

    if (node == null) return [];

    final allTracks = <E>[];
    allTracks.addAll(folderToTracks(folder) ?? []);
    _walkKeysRescursive<Null, T, E>(node, (folder) {
      allTracks.addAll(folderToTracks(folder) ?? []);
      return null;
    });

    return allTracks;
  }

  static R? _walkKeysRescursive<R, T extends Folder, E extends Track>(_FolderNode<T, E> node, R? Function(T item) callback) {
    for (final subNodeEntry in node.children.entries) {
      R? res = callback(subNodeEntry.key);
      res ??= _walkKeysRescursive<R, T, E>(subNodeEntry.value, callback);
      if (res != null) return res;
    }
    return null;
  }

  static R? _walkChildrenRescursive<R, T extends Folder, E extends Track>(_FolderNode<T, E> node, R? Function(Map<T, _FolderNode<T, E>> children) callback) {
    R? resMain = callback(node.children);
    if (resMain != null) return resMain;

    for (final subNodeEntry in node.children.values) {
      final res = _walkChildrenRescursive<R, T, E>(subNodeEntry, callback);
      if (res != null) return res;
    }
    return null;
  }

  @override
  String toString() => '_FolderNode(children: $children)';
}

extension<T> on List<T> {
  List<T>? nullifyEmpty() {
    return this.isEmpty ? null : this;
  }
}
