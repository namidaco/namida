import 'dart:io';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class Folders<T extends Folder> {
  static final Folders<Folder> tracks = Folders.tracks_(LibraryTab.folders, FoldersPageConfig.tracks());
  static final Folders<VideoFolder> videos = Folders.videos_(LibraryTab.foldersVideos, FoldersPageConfig.videos());
  Folders.tracks_(this._tab, this._config);
  Folders.videos_(this._tab, this._config);

  final LibraryTab _tab;
  final FoldersPageConfig _config;

  final Rxn<T> currentFolder = Rxn<T>();

  final RxList<T> currentFolderslist = <T>[].obs;

  /// Even with this logic, root paths are invincible.
  final isHome = true.obs;

  /// Used for non-hierarchy.
  final isInside = false.obs;

  /// Highlights the track that is meant to be navigated to after calling [stepIn].
  final indexToScrollTo = Rxn<int>();

  final _latestScrollOffset = <T?, double>{};

  void refreshLists() {
    currentFolderslist.refresh(); // refreshes folders
    currentFolder.refresh(); // refreshes tracks
  }

  /// Indicates wether the navigator can go back at this point.
  /// Returns true only if at home, otherwise will call [stepOut] and return false.
  bool onBackButton() {
    if (!isHome.value) {
      stepOut();
      return false;
    }
    return true;
  }

  void stepIn(T? folder, {Track? trackToScrollTo, double jumpTo = 0}) {
    if (folder == null || folder.path == '') {
      isHome.value = true;
      isInside.value = false;
      currentFolder.value = null;
      _scrollJump(jumpTo);
      return;
    }

    if (isHome.value != false) isHome.value = false;
    if (isInside.value != true) isInside.value = true;

    _saveScrollOffset(currentFolder.value);

    final List<T> dirInside = folder.getDirectoriesInside();
    currentFolderslist.value = dirInside;
    currentFolder.value = folder;

    if (trackToScrollTo != null) {
      indexToScrollTo.value = folder.tracks().indexOf(trackToScrollTo);
    } else {
      indexToScrollTo.value = null;
    }
    _scrollJump(jumpTo);
  }

  void stepOut() {
    T? folder;
    if (_config.enableFoldersHierarchy.value) {
      folder = currentFolder.value?.getParentFolder() as T?;
    }
    indexToScrollTo.value = null;
    stepIn(folder, jumpTo: _latestScrollOffset[folder] ?? 0);
  }

  void onFirstLoad() {
    if (_config.enableFoldersHierarchy.value) {
      final startupPath = _config.defaultFolderStartupLocation.value;
      stepIn(Folder.fromType<T>(startupPath));
    }
  }

  void onFoldersHierarchyChanged(bool enabled) {
    isHome.value = true;
    isInside.value = false;
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
  void onMapChanged<E extends Track>(Map<T, List<E>> map) {
    final newFolders = <MapEntry<T, List<E>>>[];

    void recursiveIf(bool Function() fn) {
      if (fn()) recursiveIf(fn);
    }

    for (final k in map.keys) {
      final f = k.path.split(Platform.pathSeparator);
      f.removeLast();

      recursiveIf(() {
        if (f.length > 3) {
          final newPath = f.join(Platform.pathSeparator);
          if (kStoragePaths.contains(newPath)) {
            f.removeLast();
            return true;
          }
          final newFolder = Folder.fromType<T>(newPath);
          if (map[newFolder] == null) {
            newFolders.add(MapEntry(newFolder, []));
            f.removeLast();
            return true;
          }
        }
        return false;
      });
    }

    map.addEntries(newFolders); // dont clear

    final parsedMap = _buildParsedMap(map.keys.map((e) => e.folderName.toLowerCase()));
    final sorted = map.entries.toList()
      ..sort(
        (entryA, entryB) {
          final a = entryA.key.folderName.toLowerCase();
          final b = entryB.key.folderName.toLowerCase();
          final parsedA = parsedMap[a];
          final parsedB = parsedMap[b];
          if (parsedA != null && parsedB != null) {
            if (parsedA.startAtIndex == parsedB.startAtIndex) {
              // -- basically checking textPart is enough to know but we check startAtIndex to speed things up.
              if (parsedA.textPart == parsedB.textPart) {
                final numbersCompare = parsedA.extractedNumber.compareTo(parsedB.extractedNumber);
                if (numbersCompare != 0) return numbersCompare;
              }
            }
          }
          return a.compareTo(b);
        },
      );

    map.assignAllEntries(sorted); // we clear after building new sorted one
    refreshLists();
  }

  Map<String, _ParsedResult?> _buildParsedMap(Iterable<String> names) {
    final parsedMap = <String, _ParsedResult?>{};
    for (final n in names) {
      parsedMap[n] = _parseNumberAtEnd(n);
    }
    return parsedMap;
  }

  _ParsedResult? _parseNumberAtEnd(String text) {
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
      return _ParsedResult(
        extractedNumber: int.parse(String.fromCharCodes(charCodes.reversed)),
        charactersCount: charCodes.length,
        startAtIndex: startIndex,
        textPart: text.substring(0, startIndex),
      );
    }
    return null;
  }
}

class _ParsedResult {
  final int extractedNumber;
  final int charactersCount;
  final int startAtIndex;
  final String textPart;

  const _ParsedResult({
    required this.extractedNumber,
    required this.charactersCount,
    required this.startAtIndex,
    required this.textPart,
  });
}

class FoldersPageConfig {
  final Rx<String> defaultFolderStartupLocation;
  final Rx<bool> enableFoldersHierarchy;
  final void Function() onDefaultStartupFolderChanged;

  const FoldersPageConfig._({
    required this.defaultFolderStartupLocation,
    required this.enableFoldersHierarchy,
    required this.onDefaultStartupFolderChanged,
  });

  factory FoldersPageConfig.tracks() {
    return FoldersPageConfig._(
      defaultFolderStartupLocation: settings.defaultFolderStartupLocation,
      enableFoldersHierarchy: settings.enableFoldersHierarchy,
      onDefaultStartupFolderChanged: () {
        settings.save(
          defaultFolderStartupLocation: Folders.tracks.currentFolder.value?.path ?? '',
        );
      },
    );
  }
  factory FoldersPageConfig.videos() {
    return FoldersPageConfig._(
      defaultFolderStartupLocation: settings.defaultFolderStartupLocationVideos,
      enableFoldersHierarchy: settings.enableFoldersHierarchyVideos,
      onDefaultStartupFolderChanged: () {
        settings.save(
          defaultFolderStartupLocationVideos: Folders.videos.currentFolder.value?.path ?? '',
        );
      },
    );
  }
}
