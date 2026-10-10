import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/iso639.dart';
import 'package:namida/youtube/class/download_task_base.dart';

import 'lrc_search_utils_base.dart';

class LrcSearchUtilsSelectable extends LrcSearchUtils {
  final TrackExtended trackExt;
  final Track track;
  const LrcSearchUtilsSelectable(this.trackExt, this.track);

  @override
  String? get pickFileInitialDirectory => track.isNetwork ? null : track.path.getDirectoryPath;

  @override
  String get initialSearchTextHint => '${trackExt.originalArtist} - ${trackExt.title}';

  @override
  String get embeddedLyrics => trackExt.lyrics;

  @override
  File get cachedTxtFile => File(p.join(mainLyricsCacheDirectory, "${track.rawCacheKey(mainLyricsCacheDirectory)}.txt"));

  @override
  File get cachedLRCFile => File(p.join(mainLyricsCacheDirectory, "${track.rawCacheKey(mainLyricsCacheDirectory)}.lrc"));

  LyricsLocations getLocations() => LyricsLocations.fromSettings();

  @override
  bool shouldPreferDeviceFiles() => settings.lyricsSaveLocation.value != LyricsSaveLocation.cache;

  @override
  Future<LyricsFiles> firstDeviceFiles() async {
    final path = this.track.path;

    // -- network track
    if (path.startsWith('http')) return kNoLyricsFiles;

    final filenameWOExt = path.getFilenameWOExt;
    final filename = path.getFilename;
    final trackDirPath = path.getDirectoryPath;
    final locations = getLocations();
    final directories = locations.directoriesFor(trackDirPath);
    File? txt;
    for (final dirPath in directories) {
      final listing = await _LrcSidecarFinder.listingOf(dirPath);
      if (listing == null || listing.isEmpty) continue;

      final lrcFilenames = listing.filenamesFor(filenameWOExt, filename, _LrcSidecarFinder.syncedExtensions);
      final lrc = await _LrcSidecarFinder.firstValid(dirPath, lrcFilenames);
      if (lrc != null) return (lrc: lrc, txt: null);

      if (txt != null) continue;
      final txtFilenames = listing.filenamesFor(filenameWOExt, filename, _LrcSidecarFinder.plainExtensions);
      txt = await _LrcSidecarFinder.firstValid(dirPath, txtFilenames);
    }
    return (lrc: null, txt: txt);
  }

  LyricsFiles firstDeviceFilesSync() {
    final path = this.track.path;

    // -- network track
    if (path.startsWith('http')) return kNoLyricsFiles;

    final filenameWOExt = path.getFilenameWOExt;
    final filename = path.getFilename;
    final trackDirPath = path.getDirectoryPath;
    final locations = getLocations();
    final directories = locations.directoriesFor(trackDirPath);
    File? txt;
    for (final dirPath in directories) {
      final listing = _LrcSidecarFinder.listingOfSync(dirPath);
      if (listing.isEmpty) continue;

      final lrcFilenames = listing.filenamesFor(filenameWOExt, filename, _LrcSidecarFinder.syncedExtensions);
      final lrc = _LrcSidecarFinder.firstValidSync(dirPath, lrcFilenames);
      if (lrc != null) return (lrc: lrc, txt: null);

      if (txt != null) continue;
      final txtFilenames = listing.filenamesFor(filenameWOExt, filename, _LrcSidecarFinder.plainExtensions);
      txt = _LrcSidecarFinder.firstValidSync(dirPath, txtFilenames);
    }
    return (lrc: null, txt: txt);
  }

  @override
  Future<List<File>> allDeviceLyricsFiles() async {
    final path = this.track.path;
    if (path.startsWith('http')) return const [];

    final filenameWOExt = path.getFilenameWOExt;
    final filename = path.getFilename;
    final trackDirPath = path.getDirectoryPath;
    final locations = getLocations();
    final directories = locations.directoriesFor(trackDirPath);
    final allFiles = <File>[];
    final addedPaths = <String>{};
    for (final dirPath in directories) {
      final listing = await _LrcSidecarFinder.listingOf(dirPath);
      if (listing == null || listing.isEmpty) continue;

      final filenames = listing.filenamesFor(filenameWOExt, filename, _LrcSidecarFinder.allExtensions);
      for (final sidecarFilename in filenames) {
        final file = FileParts.join(dirPath, sidecarFilename);
        if (!addedPaths.add(file.path)) continue;
        final isValid = await file.existsAndValid();
        if (isValid) allFiles.add(file);
      }
    }
    return allFiles;
  }

  @override
  Future<File?> saveLyricsToDevice(String formatted, bool isSynced, {void Function(File deviceFile)? onFailed}) async {
    final path = this.track.path;
    if (path.startsWith('http')) return null;

    final trackDirPath = path.getDirectoryPath;
    final locations = getLocations();
    final dirPath = locations.directoryForSaving(trackDirPath);
    if (dirPath == null) return null;

    final filenameWOExt = path.getFilenameWOExt;
    final extension = isSynced ? 'lrc' : 'txt';
    final file = FileParts.join(dirPath, '$filenameWOExt.$extension');
    try {
      await file.create(recursive: true);
      await file.writeAsString(formatted);
    } catch (_) {
      // -- not writable, the cache takes it
      onFailed?.call(file);
      return null;
    }
    _LrcSidecarFinder.forget(dirPath);
    return file;
  }

  /// lyrics that a track in [libraryPaths] still matches are kept.
  static Future<void> deleteLyricsOfDeletedTracks(
    List<String> deletedPaths,
    List<String> libraryPaths,
    Set<LyricsSaveLocation> deleteIn, {
    String? cacheDirectory,
    LyricsLocations? locations,
  }) {
    final params = _LyricsDeleteParams(
      deletedPaths: deletedPaths,
      libraryPaths: libraryPaths,
      deleteIn: deleteIn,
      cacheDirectory: cacheDirectory ?? AppDirs.LYRICS,
      locations: locations ?? LyricsLocations.fromSettings(),
    );
    return Isolate.run(() => _deleteLyricsOfDeletedTracksSync(params));
  }

  static void _deleteLyricsOfDeletedTracksSync(_LyricsDeleteParams params) {
    final cacheDirectory = params.cacheDirectory;
    final locations = params.locations;
    final deletedPaths = params.deletedPaths.toSet();
    final shouldDeleteInCache = params.deleteIn.contains(LyricsSaveLocation.cache);
    final shouldDeleteInTrackFolder = params.deleteIn.contains(LyricsSaveLocation.trackFolder);
    final shouldDeleteInLyricsFolders = params.deleteIn.contains(LyricsSaveLocation.customFolder);

    // -- the cache and what is right inside a lyrics folder are matched by name only, no matter where the track is
    final namesInLibrary = <String>{};
    final pathsInLibrary = <String>{};
    for (final path in params.libraryPaths) {
      if (deletedPaths.contains(path)) continue;
      final names = _LyricsTrackNames.fromPath(path);
      namesInLibrary.add(names.filename);
      namesInLibrary.add(names.filenameWOExt);
      pathsInLibrary.add(names.directoryWithSeparator + names.filename);
      pathsInLibrary.add(names.directoryWithSeparator + names.filenameWOExt);
    }

    for (final path in deletedPaths) {
      if (path.startsWith('http')) continue;
      if (File(path).existsSync()) continue;

      final names = _LyricsTrackNames.fromPath(path);
      final nameKeys = [names.filenameWOExt, names.filename];
      final unusedInDirectory = <String>[];
      final unusedInLibrary = <String>[];
      for (final nameKey in nameKeys) {
        final pathKey = names.directoryWithSeparator + nameKey;
        if (!pathsInLibrary.contains(pathKey)) unusedInDirectory.add(nameKey);
        if (!namesInLibrary.contains(nameKey)) unusedInLibrary.add(nameKey);
      }

      final isCacheKeyUnused = !namesInLibrary.contains(names.filename);
      if (shouldDeleteInCache && isCacheKeyUnused) {
        final cacheKey = path.getFilename;
        _tryDeletingSync(FileParts.join(cacheDirectory, '$cacheKey.lrc'));
        _tryDeletingSync(FileParts.join(cacheDirectory, '$cacheKey.txt'));
      }

      final trackDirPath = path.getDirectoryPath;
      if (shouldDeleteInTrackFolder) _LrcSidecarFinder.deleteSync(trackDirPath, unusedInDirectory);
      if (!shouldDeleteInLyricsFolders) continue;

      final subdirectories = locations.subdirectoriesFor(trackDirPath);
      for (final dirPath in subdirectories) {
        _LrcSidecarFinder.deleteSync(dirPath, unusedInDirectory);
      }
      for (final dirPath in locations.folders) {
        _LrcSidecarFinder.deleteSync(dirPath, unusedInLibrary);
      }
    }
  }

  static void _tryDeletingSync(File file) {
    try {
      file.deleteSync();
    } catch (_) {}
  }

  // -- replaced by [_LrcSidecarFinder], which lists the directory once instead of probing each name.
  // static List<File Function()> _buildDeviceLRCFilesCallbacks(String localTrackPath) {
  //   final dirPath = localTrackPath.getDirectoryPath;
  //   final fwoe = localTrackPath.getFilenameWOExt;
  //   final fwe = localTrackPath.getFilename;
  //   return [
  //     () => File(p.join(dirPath, "$fwoe.lrc")),
  //     () => File(p.join(dirPath, "$fwe.lrc")),
  //     () => File(p.join(dirPath, "$fwoe.ttml")),
  //     () => File(p.join(dirPath, "$fwe.ttml")),
  //     () => File(p.join(dirPath, "$fwoe.LRC")),
  //     () => File(p.join(dirPath, "$fwe.LRC")),
  //     () => File(p.join(dirPath, "$fwoe.srt")),
  //     () => File(p.join(dirPath, "$fwoe.vtt")),
  //     () => File(p.join(dirPath, "$fwoe.sbv")),
  //     () => File(p.join(dirPath, "$fwoe.ssa")),
  //     () => File(p.join(dirPath, "$fwoe.ass")),
  //   ];
  // }

  @override
  Future<int> getItemDurationMS() async => trackExt.durationMS;

  @override
  bool isInstrumental() {
    final isInstrumentalLanguage = trackExt.languagesList.contains(Iso639.instrumentalLabel);
    if (isInstrumentalLanguage) return true;
    return LrcSearchUtils.isInstrumentalTitle(trackExt.title);
  }

  @override
  Future<bool> hasLyrics() async {
    return track.lyrics != '' || await super.hasLyrics();
  }

  static final _durationModifiedRegex = RegExp('nightcore|sped up|slowed', caseSensitive: false);
  static bool _checkIsDurationModified(String property) {
    return _durationModifiedRegex.firstMatch(property) != null;
  }

  @override
  List<LRCSearchDetails> searchDetailsQueries() {
    final durMS = trackExt.durationMS;
    final isDurationModified = _checkIsDurationModified(trackExt.originalGenre) || _checkIsDurationModified(trackExt.title) || _checkIsDurationModified(trackExt.originalArtist);
    return [
      LRCSearchDetails(
        title: trackExt.title,
        artist: trackExt.originalArtist,
        album: '',
        durationMS: durMS,
        isDurationModified: isDurationModified,
      ),
      LRCSearchDetails(
        title: trackExt.title,
        artist: trackExt.originalArtist,
        album: trackExt.originalAlbum,
        durationMS: durMS,
        isDurationModified: isDurationModified,
      ),
      if (trackExt.artistsList.isNotEmpty)
        LRCSearchDetails(
          title: trackExt.title,
          artist: trackExt.artistsList.first,
          album: '',
          durationMS: durMS,
          isDurationModified: isDurationModified,
        ),
      if (trackExt.artistsList.isNotEmpty)
        LRCSearchDetails(
          title: trackExt.title,
          artist: trackExt.artistsList.first,
          album: trackExt.originalAlbum,
          durationMS: durMS,
          isDurationModified: isDurationModified,
        ),
    ];
  }

  @override
  List<String> searchQueriesGoogle() {
    final title = trackExt.title;
    final artist = trackExt.originalArtist;
    return <String>[
      '$title by $artist lyrics',
      '${title.splitFirst("-")} by $artist lyrics',
      '$title by $artist song lyrics',
    ];
  }
}

class LrcSearchUtilsSelectableIsolate extends LrcSearchUtilsSelectable {
  @override
  final String mainLyricsCacheDirectory;
  final LyricsLocations locations;

  const LrcSearchUtilsSelectableIsolate(
    super.trackExt,
    super.track, {
    required this.mainLyricsCacheDirectory,
    required this.locations,
  });

  @override
  LyricsLocations getLocations() => locations;

  @override
  bool shouldPreferDeviceFiles() => locations.saveLocation != LyricsSaveLocation.cache;
}

class LrcSearchUtilsSelectableFromNetwork extends LrcSearchUtilsSelectable {
  const LrcSearchUtilsSelectableFromNetwork(super.trackExt, super.track);

  @override
  File get cachedTxtFile => File(
    p.join(
      mainLyricsCacheDirectory,
      "${DownloadTaskFilename.cleanupFilename(
        track.rawCacheKey(mainLyricsCacheDirectory),
        parentDirPath: mainLyricsCacheDirectory,
      )}.txt",
    ),
  );

  @override
  File get cachedLRCFile => File(
    p.join(
      mainLyricsCacheDirectory,
      "${DownloadTaskFilename.cleanupFilename(
        track.rawCacheKey(mainLyricsCacheDirectory),
        parentDirPath: mainLyricsCacheDirectory,
      )}.lrc",
    ),
  );
}

// by claude
class LyricsLocations {
  final LyricsSaveLocation saveLocation;
  final List<String> folders;
  final List<String> libraryDirectories;

  const LyricsLocations({
    required this.saveLocation,
    required this.folders,
    required this.libraryDirectories,
  });

  factory LyricsLocations.fromSettings() {
    final folders = settings.lyricsFolders.value;
    final libraryDirectories = folders.isEmpty ? const <String>[] : <String>[];
    if (folders.isNotEmpty) {
      for (final dir in settings.directoriesToScan.value) {
        if (dir is DirectoryIndexLocal) libraryDirectories.add(dir.sourceRaw);
      }
    }
    return LyricsLocations(
      saveLocation: settings.lyricsSaveLocation.value,
      folders: folders,
      libraryDirectories: libraryDirectories,
    );
  }

  /// a lyrics folder is looked up in the same subfolders the library has, then directly inside.
  List<String> directoriesFor(String trackDirPath) {
    if (folders.isEmpty) return [trackDirPath];

    final subdirectory = _subdirectoryInLibrary(trackDirPath);
    final isCustomFolderFirst = saveLocation == LyricsSaveLocation.customFolder;
    final directories = <String>[];
    if (!isCustomFolderFirst) directories.add(trackDirPath);
    for (final folder in folders) {
      if (subdirectory != null) directories.add(FileParts.joinPath(folder, subdirectory));
      directories.add(folder);
    }
    if (isCustomFolderFirst) directories.add(trackDirPath);
    return directories;
  }

  /// lyrics in these are only matched by tracks of [trackDirPath], unlike the ones right inside a lyrics folder.
  List<String> subdirectoriesFor(String trackDirPath) {
    final subdirectory = _subdirectoryInLibrary(trackDirPath);
    if (subdirectory == null) return const [];
    return [
      for (final folder in folders) FileParts.joinPath(folder, subdirectory),
    ];
  }

  /// null when lyrics belong in the cache.
  String? directoryForSaving(String trackDirPath) {
    switch (saveLocation) {
      case LyricsSaveLocation.cache:
        return null;
      case LyricsSaveLocation.trackFolder:
        return trackDirPath;
      case LyricsSaveLocation.customFolder:
        if (folders.isEmpty) return null;
        final folder = folders.first;
        final subdirectory = _subdirectoryInLibrary(trackDirPath);
        if (subdirectory == null) return folder;
        return FileParts.joinPath(folder, subdirectory);
    }
  }

  /// null when outside the library, or right inside a library directory.
  String? _subdirectoryInLibrary(String trackDirPath) {
    final separator = Platform.pathSeparator;
    String? subdirectory;
    for (final libraryDir in libraryDirectories) {
      if (libraryDir.isEmpty) continue;
      if (!trackDirPath.startsWith(libraryDir)) continue;
      final isWholeFolderName = libraryDir.endsWith(separator) || trackDirPath.startsWith(separator, libraryDir.length);
      if (!isWholeFolderName) continue;

      int start = libraryDir.length;
      while (trackDirPath.startsWith(separator, start)) {
        start += separator.length;
      }
      if (start >= trackDirPath.length) return null;

      // -- nested library directories, the deepest one leaves the shortest path
      final candidate = trackDirPath.substring(start);
      if (subdirectory == null || candidate.length < subdirectory.length) subdirectory = candidate;
    }
    return subdirectory;
  }
}

// by claude
/// Finds lyrics files by listing a directory once, the listing is reused as long as the directory wasn't modified.
/// Most directories have none, which makes every lookup after the first a single stat.
class _LrcSidecarFinder {
  static const syncedExtensions = ['lrc', 'ttml', 'srt', 'vtt', 'sbv', 'ssa', 'ass'];
  static const plainExtensions = ['txt'];
  static const allExtensions = [...syncedExtensions, ...plainExtensions];
  static const _allExtensionsSet = {...allExtensions};

  static final _listings = <String, _LrcDirectoryListing>{};

  /// modification times can be as coarse as 2 seconds (FAT), a directory modified this recently can change again without its time changing.
  static const _kModifiedGranularityMS = 2000;
  static const _kNotReusable = -1;

  static void forget(String dirPath) => _listings.remove(dirPath);

  /// null when the directory doesn't exist.
  static Future<_LrcDirectoryListing?> listingOf(String dirPath) async {
    final stat = await FileStat.stat(dirPath);
    if (stat.type != FileSystemEntityType.directory) return null;

    final modifiedMS = stat.modified.millisecondsSinceEpoch;
    final reusable = _listings[dirPath];
    if (reusable != null && reusable.modifiedMS == modifiedMS) return reusable;

    final sidecars = await Isolate.run(() => _listSidecars(dirPath));
    final nowMS = DateTime.now().millisecondsSinceEpoch;
    final canReuse = nowMS - modifiedMS > _kModifiedGranularityMS;
    final reusableModifiedMS = canReuse ? modifiedMS : _kNotReusable;
    final listing = _LrcDirectoryListing(reusableModifiedMS, sidecars);
    _listings[dirPath] = listing;
    return listing;
  }

  /// trusts a listing made earlier without checking the directory again, only for short lived isolates.
  static _LrcDirectoryListing listingOfSync(String dirPath) {
    final reusable = _listings[dirPath];
    if (reusable != null) return reusable;

    final sidecars = _listSidecars(dirPath);
    final listing = _LrcDirectoryListing(_kNotReusable, sidecars);
    _listings[dirPath] = listing;
    return listing;
  }

  static Future<File?> firstValid(String dirPath, List<String> filenames) async {
    for (final filename in filenames) {
      final file = FileParts.join(dirPath, filename);
      final isValid = await file.existsAndValid();
      if (isValid) return file;
    }
    return null;
  }

  static void deleteSync(String dirPath, List<String> nameKeys) {
    if (nameKeys.isEmpty) return;
    final listing = listingOfSync(dirPath);
    if (listing.isEmpty) return;
    for (final nameKey in nameKeys) {
      final filenames = listing.filenamesNamed(nameKey, allExtensions);
      for (final filename in filenames) {
        final file = FileParts.join(dirPath, filename);
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }

  static File? firstValidSync(String dirPath, List<String> filenames) {
    for (final filename in filenames) {
      final file = FileParts.join(dirPath, filename);
      if (file.existsAndValidSync()) return file;
    }
    return null;
  }

  /// null when it can't be listed, which is the case for paths longer than 260 characters on windows.
  static Map<String, List<_LrcSidecar>>? _listSidecars(String dirPath) {
    final directory = Directory(dirPath);
    final List<FileSystemEntity> entities;
    try {
      entities = directory.listSync();
    } catch (_) {
      final isThere = directory.existsSync();
      return isThere ? null : const {};
    }
    final sidecars = <String, List<_LrcSidecar>>{};
    for (final entity in entities) {
      final filename = entity.path.getFilename;
      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex <= 0) continue;
      final extension = filename.substring(dotIndex + 1).toLowerCase();
      if (!_allExtensionsSet.contains(extension)) continue;
      final nameKey = filename.substring(0, dotIndex).toLowerCase();
      final sidecar = (filename: filename, extension: extension);
      (sidecars[nameKey] ??= []).add(sidecar);
    }
    return sidecars;
  }
}

class _LrcDirectoryListing {
  final int modifiedMS;

  /// null when the directory couldn't be listed, names are tried one by one then.
  final Map<String, List<_LrcSidecar>>? _sidecars;

  const _LrcDirectoryListing(this.modifiedMS, this._sidecars);

  bool get isEmpty => _sidecars?.isEmpty == true;

  /// lyrics are named after the track with or without its extension, ex: `song.lrc` or `song.flac.lrc`.
  List<String> filenamesFor(String filenameWOExt, String filename, List<String> extensions) {
    final sidecars = _sidecars;
    if (sidecars == null) {
      return [
        for (final extension in extensions) ...['$filenameWOExt.$extension', '$filename.$extension'],
      ];
    }

    final sidecarsWOExt = sidecars[filenameWOExt.toLowerCase()];
    final sidecarsWithExt = sidecars[filename.toLowerCase()];
    if (sidecarsWOExt == null && sidecarsWithExt == null) return const [];

    final filenames = <String>[];
    for (final extension in extensions) {
      _addMatching(filenames, sidecarsWOExt, extension);
      _addMatching(filenames, sidecarsWithExt, extension);
    }
    return filenames;
  }

  List<String> filenamesNamed(String nameKey, List<String> extensions) {
    final sidecars = _sidecars;
    if (sidecars == null) {
      return [
        for (final extension in extensions) '$nameKey.$extension',
      ];
    }

    final sidecarsNamed = sidecars[nameKey];
    if (sidecarsNamed == null) return const [];
    return [
      for (final sidecar in sidecarsNamed) sidecar.filename,
    ];
  }

  static void _addMatching(List<String> filenames, List<_LrcSidecar>? sidecars, String extension) {
    if (sidecars == null) return;
    for (final sidecar in sidecars) {
      if (sidecar.extension == extension) filenames.add(sidecar.filename);
    }
  }
}

/// names are lowercased.
class _LyricsTrackNames {
  final String directoryWithSeparator;
  final String filename;
  final String filenameWOExt;

  const _LyricsTrackNames._(this.directoryWithSeparator, this.filename, this.filenameWOExt);

  factory _LyricsTrackNames.fromPath(String path) {
    final filenameStart = path.lastIndexOf(Platform.pathSeparator) + 1;
    final directoryWithSeparator = path.substring(0, filenameStart);
    final filename = path.substring(filenameStart).toLowerCase();
    final dotIndex = filename.lastIndexOf('.');
    final filenameWOExt = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
    return _LyricsTrackNames._(directoryWithSeparator, filename, filenameWOExt);
  }
}

class _LyricsDeleteParams {
  final List<String> deletedPaths;
  final List<String> libraryPaths;
  final Set<LyricsSaveLocation> deleteIn;
  final String cacheDirectory;
  final LyricsLocations locations;

  const _LyricsDeleteParams({
    required this.deletedPaths,
    required this.libraryPaths,
    required this.deleteIn,
    required this.cacheDirectory,
    required this.locations,
  });
}

typedef _LrcSidecar = ({String filename, String extension});
