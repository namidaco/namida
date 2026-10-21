part of 'playlist_controller.dart';

/// reading and writing m3u files, the controller state stays in [PlaylistController].
abstract final class M3UFiles {
  /// the deepest folder holding all [tracks], null when they aren't all local files under one folder (a drive root doesn't count).
  static String? getCommonTracksDirectory(List<TrackWithDate> tracks, p.Context context) {
    String? commonDirectory;
    for (final item in tracks) {
      final track = item.track;
      if (track.isNetwork) return null;
      final path = track.path;
      if (commonDirectory == null) {
        commonDirectory = context.dirname(path);
        continue;
      }
      while (!context.isWithin(commonDirectory!, path)) {
        final parentDirectory = context.dirname(commonDirectory);
        if (parentDirectory == commonDirectory) return null;
        commonDirectory = parentDirectory;
      }
    }
    if (commonDirectory == null) return null;
    final isRoot = context.rootPrefix(commonDirectory) == commonDirectory;
    return isRoot ? null : commonDirectory;
  }

  @visibleForTesting
  static String getUniqueFilePath(
    String playlistName,
    String directory,
    p.Context context, {
    required bool shouldReplaceReservedChars,
    required bool Function(String path) isTaken,
  }) {
    final filename = _toSafeFilename(playlistName, shouldReplaceReservedChars);
    var path = context.join(directory, '$filename.m3u');
    int i = 2;
    while (isTaken(path)) {
      path = context.join(directory, '$filename ($i).m3u');
      i++;
    }
    return path;
  }

  static final _shouldReplaceReservedChars = Platform.isWindows || Platform.isAndroid; // -- android shared storage rejects them too
  static final _reservedFilenameCharsRegex = RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]');
  static final _posixUnsafeFilenameCharsRegex = RegExp(r'[/\x00]');

  static String _toSafeFilename(String playlistName, bool shouldReplaceReservedChars) {
    final unsafeCharsRegex = shouldReplaceReservedChars ? _reservedFilenameCharsRegex : _posixUnsafeFilenameCharsRegex;
    return playlistName.replaceAll(unsafeCharsRegex, '_');
  }

  /// {m3uPath: playlistName} of [m3uPaths] in [m3uProperties], a path saved under several names keeps the last one.
  @visibleForTesting
  static Map<String, String> getSavedNamesByPath(Map<String, Map<String, dynamic>> m3uProperties, Set<String> m3uPaths) {
    final namesByPath = <String, String>{};
    for (final e in m3uProperties.entries) {
      final m3uPath = e.value['m3uPath'];
      if (m3uPaths.contains(m3uPath)) namesByPath[m3uPath] = e.key;
    }
    return namesByPath;
  }

  static Future<_ParseM3UPlaylistFilesResult> _parseFiles(_ParseM3UPlaylistFilesParams params) async {
    final allm3uPaths = params.allm3uPaths;

    final backupDirPath = params.backupDirPath;

    final libraryTracksPaths = <String>[];

    bool didLoadTracksDb = false;
    Future<void> loadTracksDb() async {
      didLoadTracksDb = true;
      DBWrapperSync? tracksDBManager;
      try {
        tracksDBManager = await DBWrapper.openFromInfoSyncTry(
          fileInfo: params.tracksDbInfo,
          config: const DBConfig(
            createIfNotExist: true,
            autoDisposeTimerDuration: null, // we close manually
          ),
        );
        tracksDBManager?.loadAllKeys(libraryTracksPaths.add);
      } finally {
        tracksDBManager?.close();
      }
    }

    bool pathExists(String path) => File(path).existsSync();

    String closestPathBySuffix(List<String> candidates, String lowerPath) {
      if (candidates.length == 1) return candidates[0];
      var best = candidates[0];
      var bestMatchedLength = -1;
      for (final candidate in candidates) {
        final candidateLower = candidate.toLowerCase();
        var i = candidateLower.length;
        var j = lowerPath.length;
        while (i > 0 && j > 0 && candidateLower.codeUnitAt(i - 1) == lowerPath.codeUnitAt(j - 1)) {
          i--;
          j--;
        }
        final matchedLength = lowerPath.length - j;
        if (matchedLength > bestMatchedLength) {
          bestMatchedLength = matchedLength;
          best = candidate;
        }
      }
      return best;
    }

    late final libraryPathsByLowerFilename = () {
      final index = <String, List<String>>{};
      for (final trackPath in libraryTracksPaths) {
        (index[trackPath.getFilename.toLowerCase()] ??= []).add(trackPath);
      }
      return index;
    }();

    final context = p.context;

    final infoByPath = <String, _M3UPlaylistTempInfo>{};
    final headerNamesByPath = <String, String>{};
    final infoMap = <String, String?>{};
    for (final path in allm3uPaths) {
      final file = File(path);
      final fileParentDirectory = file.path.getDirectoryPath;
      final fullTracks = <Track>[];
      final headerLines = <String>[];
      bool isInHeader = true;
      String? latestInfo;
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith("#")) {
          if (isInHeader && !line.startsWith(_kEntryInfoPrefix)) {
            if (!_isOwnHeaderLine(line)) headerLines.add(line);
            continue;
          }
          isInHeader = false;
          latestInfo = line; // could be a comment, would get overriden by the next #EXTINF anyways
        } else if (line.isNotEmpty) {
          isInHeader = false;
          final entry = resolveEntryLine(line, fileParentDirectory, context, pathExists);
          var fullPath = entry.path;
          if (!entry.isResolved) {
            // no idea, trying to get from library
            if (!didLoadTracksDb) await loadTracksDb();
            final lowerPath = fullPath.toLowerCase();
            final candidates = libraryPathsByLowerFilename[lowerPath.getFilename];
            if (candidates != null) fullPath = closestPathBySuffix(candidates, lowerPath);
          }
          fullTracks.add(Track.orVideo(fullPath));
          infoMap[fullPath] = latestInfo;
          latestInfo = null; // resetting info between each line loop
        }
      }
      final header = parseHeaderLines(headerLines);
      final headerName = header.name;
      if (headerName != null && _isValidHeaderName(headerName)) headerNamesByPath[path] = headerName;
      infoByPath[path] = _M3UPlaylistTempInfo(path: path, header: header, headerLines: headerLines, tracks: fullTracks);

      latestInfo = null; // resetting info between each file looping
    }

    final namesByPath = allocatePlaylistNames(allm3uPaths, params.boundNamesByPath, context, headerNamesByPath: headerNamesByPath);
    final all = <String, _M3UPlaylistTempInfo>{};
    for (final e in infoByPath.entries) {
      final name = namesByPath[e.key]!;
      all[name] = e.value;
    }

    // -- copying newly found m3u files as a backup
    for (final m3u in all.entries) {
      final backupFilename = _toSafeFilename(m3u.key, _shouldReplaceReservedChars);
      final backupFile = FileParts.join(backupDirPath, "$backupFilename.m3u");
      if (!backupFile.existsSync()) {
        File(m3u.value.path).copySync(backupFile.path);
      }
    }

    return _ParseM3UPlaylistFilesResult(
      paths: all,
      infoMap: infoMap,
    );
  }

  static final _urlRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]+://');
  static final _pathSeparatorsRegex = RegExp(r'[\\/]');

  /// [line] resolved against [m3uDirectory], or against the root for posix lines that lost their leading slash.
  /// unresolved ones should be looked up in the library.
  @visibleForTesting
  static ({String path, bool isResolved}) resolveEntryLine(String line, String m3uDirectory, p.Context context, bool Function(String path) exists) {
    final localPath = _entryLineToLocalPath(line, context);
    if (localPath == null) return (path: line, isResolved: true);
    final joinedPath = context.join(m3uDirectory, localPath);
    final path = context.normalize(joinedPath);
    if (exists(path)) return (path: path, isResolved: true);
    final canBeRooted = context.style == p.Style.posix && context.isRelative(localPath);
    if (canBeRooted) {
      final rootedPath = context.normalize('/$localPath');
      if (exists(rootedPath)) return (path: rootedPath, isResolved: true);
    }
    return (path: path, isResolved: false);
  }

  /// null for urls other than file ones, they are kept as they are.
  static String? _entryLineToLocalPath(String line, p.Context context) {
    if (!_urlRegex.hasMatch(line)) {
      final unprefixedLine = line.startsWith('primary/') ? line.replaceFirst('primary/', '') : line;
      return unprefixedLine.replaceAll(_pathSeparatorsRegex, context.separator);
    }
    if (!line.startsWith('file:')) return null;
    try {
      final fileUri = Uri.parse(line);
      return context.fromUri(fileUri);
    } catch (_) {
      return null;
    }
  }

  /// same-named files get their folder name as a prefix, files in [boundNamesByPath] keep their names.
  /// [headerNamesByPath] (`#PLAYLIST:`) are used instead of the filenames.
  @visibleForTesting
  static Map<String, String> allocatePlaylistNames(
    Set<String> m3uPaths,
    Map<String, String> boundNamesByPath,
    p.Context context, {
    Map<String, String> headerNamesByPath = const {},
  }) {
    String getBaseName(String path) => headerNamesByPath[path] ?? context.basenameWithoutExtension(path);

    final filenamesCounts = <String, int>{};
    void countFilename(String path) {
      final filename = getBaseName(path);
      filenamesCounts.update(filename, (count) => count + 1, ifAbsent: () => 1);
    }

    for (final path in m3uPaths) {
      countFilename(path);
    }
    for (final path in boundNamesByPath.keys) {
      if (!m3uPaths.contains(path)) countFilename(path);
    }

    final takenNames = boundNamesByPath.values.toSet();
    final namesByPath = <String, String>{};
    for (final path in m3uPaths) {
      final boundName = boundNamesByPath[path];
      if (boundName != null) {
        namesByPath[path] = boundName;
        continue;
      }
      final filename = getBaseName(path);
      var name = filename;
      if (filenamesCounts[filename]! > 1 || takenNames.contains(name)) {
        final parentDirectory = context.dirname(path);
        final parent = context.basename(parentDirectory);
        name = '$parent - $filename';
        var i = 2;
        while (takenNames.contains(name)) {
          name = '$parent - $filename ($i)';
          i++;
        }
      }
      takenNames.add(name);
      namesByPath[path] = name;
    }
    return namesByPath;
  }

  static Future<void> _saveToFile(
    ({String path, List<_M3UEntry> entries, List<String> headerLines, bool relative}) params,
  ) async {
    final mainPath = params.path;
    final entries = params.entries;
    final headerLines = params.headerLines;
    final relative = params.relative;

    // String findCommonPath(List<TrackWithDate> tracks) {
    //   if (tracks.isEmpty) return '';

    //   // use absolute paths if playlist has network tracks
    //   if (tracks[0].track.isNetwork) return '';

    //   String res = "";
    //   final firstPath = tracks[0].track.path;
    //   for (int i = 0; i < firstPath.length; i++) {
    //     for (var twd in tracks) {
    //       var tr = twd.track;
    //       if (tr.isNetwork) return '';
    //       var s = tr.path;
    //       if (i >= s.length || firstPath[i] != s[i]) {
    //         return res;
    //       }
    //     }
    //     res += firstPath[i];
    //   }
    //   return res;
    // }

    final commonParent = relative ? p.dirname(mainPath) : '';
    final commonParentIsGood = commonParent.trim().isNotEmpty;
    final context = p.context;

    final file = File(mainPath);

    file.deleteIfExistsSync();
    file.createSync(recursive: true);
    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    sink.writeln(_kFileHeader);
    for (final line in headerLines) {
      sink.writeln(line);
    }
    sink.writeln();
    if (commonParentIsGood) {
      sink.writeln('$_kResolvedAgainstPrefix`$commonParent`');
      sink.writeln('$_kPutInFolderPrefix`$commonParent` or a folder with similar structure');
      sink.writeln();
    }
    for (final entry in entries) {
      final path = entry.path;
      final pathLine = commonParentIsGood ? toEntryLine(path, commonParent, context) : path;
      sink.writeln(entry.info);
      sink.writeln(pathLine);
    }

    await sink.flush();
    await sink.close();
  }

  /// relative to [m3uDirectory] when possible, urls and paths on other roots stay as they are.
  @visibleForTesting
  static String toEntryLine(String path, String m3uDirectory, p.Context context) {
    if (_urlRegex.hasMatch(path)) return path;
    return context.relative(path, from: m3uDirectory);
  }

  static const _kFileHeader = '#EXTM3U';
  static const _kEntryInfoPrefix = '#EXTINF';
  static const _kResolvedAgainstPrefix = '# resolved against ';
  static const _kPutInFolderPrefix = '# this file should be put in ';
  static const _kHeaderListSeparator = ';';

  static bool _isOwnHeaderLine(String line) {
    return line.trim() == _kFileHeader || line.startsWith(_kResolvedAgainstPrefix) || line.startsWith(_kPutInFolderPrefix);
  }

  static bool _isValidHeaderName(String name) {
    if (name == k_PLAYLIST_NAME_FAV || name == k_PLAYLIST_NAME_HISTORY || name == k_PLAYLIST_NAME_MOST_PLAYED) return false;
    return !DownloadTaskFilename.cleanupFilenameRegex.hasMatch(name);
  }

  /// `#TAGS:` are the playlist moods and `#CATEGORY:` are the playlist tags, both joined by `;`.
  @visibleForTesting
  static ({String? name, String? artUrl, List<String> moods, List<String> tags, String description}) parseHeaderLines(List<String> headerLines) {
    String? name;
    String? artUrl;
    var moods = const <String>[];
    var tags = const <String>[];
    var description = '';
    final parsedKeys = <_M3UHeaderKey>{};
    for (final headerLine in headerLines) {
      final key = _M3UHeaderKey.ofHeaderLine(headerLine);
      if (key == null || !parsedKeys.add(key)) continue;
      final value = headerLine.substring(key.prefix.length).trim();
      switch (key) {
        case _M3UHeaderKey.playlist:
          name = value.nullifyEmpty();
        case _M3UHeaderKey.tags:
          moods = value.split(_kHeaderListSeparator).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toFixedList();
        case _M3UHeaderKey.category:
          final tagsRaw = value.split(_kHeaderListSeparator);
          tags = PlaylistTagsFilter.normalizeTags(tagsRaw);
        case _M3UHeaderKey.description:
          description = value;
        case _M3UHeaderKey.albumArtUrl:
          artUrl = value.nullifyEmpty();
        case _M3UHeaderKey.playlistSize || _M3UHeaderKey.duration:
          break;
      }
    }
    return (name: name, artUrl: artUrl, moods: moods, tags: tags, description: description);
  }

  /// [headerLines] with the playlist values replaced in place, lines of other apps are kept as they are.
  @visibleForTesting
  static List<String> rewriteHeaderLines(
    List<String> headerLines, {
    required String name,
    required List<String> moods,
    required List<String> tags,
    required String description,
    required int tracksCount,
    required int Function() computeDurationMS,
  }) {
    String? getValue(_M3UHeaderKey key) => switch (key) {
      _M3UHeaderKey.playlist => name,
      _M3UHeaderKey.tags => moods.join(_kHeaderListSeparator),
      _M3UHeaderKey.category => tags.join(_kHeaderListSeparator),
      _M3UHeaderKey.description => description,
      _M3UHeaderKey.playlistSize => '$tracksCount',
      _M3UHeaderKey.duration => (computeDurationMS() / 1000).toStringAsFixed(2),
      _M3UHeaderKey.albumArtUrl => null,
    };

    final lines = <String>[];
    final writtenKeys = <_M3UHeaderKey>{};
    for (final headerLine in headerLines) {
      final key = _M3UHeaderKey.ofHeaderLine(headerLine);
      if (key == null) {
        lines.add(headerLine);
        continue;
      }
      if (!writtenKeys.add(key)) continue;
      final value = getValue(key);
      lines.add(value == null ? headerLine : '${key.prefix}$value');
    }
    for (final key in _M3UHeaderKey.values) {
      if (!key.isAddedWhenMissing || writtenKeys.contains(key)) continue;
      final value = getValue(key);
      if (value == null || value.isEmpty) continue;
      lines.add('${key.prefix}$value');
    }
    return lines;
  }

  /// edits of [header] since [baseline] (the header when last read or written) applied over [current], a null [baseline] joins both.
  /// null when [current] stays the same.
  @visibleForTesting
  static List<String>? mergeHeaderItems(List<String> current, List<String> header, List<String>? baseline) {
    List<String>? merged;
    if (baseline != null) {
      for (final item in baseline) {
        if (header.contains(item) || !current.contains(item)) continue;
        merged ??= [...current];
        merged.remove(item);
      }
    }
    for (final item in header) {
      if (baseline != null && baseline.contains(item)) continue;
      final items = merged ?? current;
      if (items.contains(item)) continue;
      merged ??= [...current];
      merged.add(item);
    }
    return merged;
  }

  /// same as [mergeHeaderItems], a null [baseline] fills [current] only when it's empty.
  @visibleForTesting
  static String? mergeHeaderText(String current, String header, String? baseline) {
    final isEditedInHeader = baseline == null ? current.isEmpty : header != baseline;
    if (!isEditedInHeader || header == current) return null;
    return header;
  }
}

// by claude
/// a json map saved to [_file], saves requested while one is running are merged into one.
class _M3UJsonMapFile {
  final File _file;
  _M3UJsonMapFile(this._file);

  var _entries = <String, Map<String, dynamic>>{};

  Future<void> load() async {
    final json = await _file.readAsJson();
    if (json is! Map) return;
    final entries = <String, Map<String, dynamic>>{};
    for (final e in json.entries) {
      final value = e.value;
      if (value is Map<String, dynamic>) entries[e.key] = value;
    }
    _entries = entries;
  }

  void update(String key, Map<String, dynamic> value) {
    final oldValue = _entries[key];
    if (oldValue != null && const DeepCollectionEquality().equals(oldValue, value)) return;
    _entries[key] = value;
    _save();
  }

  void remove(String key) {
    final removed = _entries.remove(key);
    if (removed != null) _save();
  }

  bool _isSaving = false;
  bool _hasNewerEntries = false;

  Future<void> _save() async {
    if (_isSaving) {
      _hasNewerEntries = true;
      return;
    }
    _isSaving = true;
    do {
      _hasNewerEntries = false;
      await _file.writeAsJson(_entries);
    } while (_hasNewerEntries);
    _isSaving = false;
  }
}

/// {playlistName: playlist json without the tracks}
class _M3UPlaylistsProperties extends _M3UJsonMapFile {
  _M3UPlaylistsProperties(super.file);

  /// the returned playlist has no tracks.
  LocalPlaylist? propertiesOf(String playlistName) {
    final json = _entries[playlistName];
    if (json == null) return null;
    try {
      return LocalPlaylist.fromJson(json, TrackWithDate.fromJson, SortType.sortListFromJsonList);
    } catch (_) {
      return null;
    }
  }

  bool isPathSavedByAnother(String m3uPath, String playlistName) {
    for (final e in _entries.entries) {
      if (e.key != playlistName && e.value['m3uPath'] == m3uPath) return true;
    }
    return false;
  }

  Map<String, String> getNamesByPath(Set<String> m3uPaths) => M3UFiles.getSavedNamesByPath(_entries, m3uPaths);

  Set<String> getSavedPaths() {
    final paths = <String>{};
    for (final properties in _entries.values) {
      final m3uPath = properties['m3uPath'];
      if (m3uPath is String) paths.add(m3uPath);
    }
    return paths;
  }
}

// by claude
/// {m3uPath: header values when the file was last read or written}, tells which header edits came from other apps.
class _M3UHeadersBaselines extends _M3UJsonMapFile {
  _M3UHeadersBaselines(super.file);

  _M3UHeaderValues? valuesOf(String m3uPath) {
    final json = _entries[m3uPath];
    if (json == null) return null;
    try {
      return _M3UHeaderValues.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void set(String m3uPath, _M3UHeaderValues values) {
    final oldValues = valuesOf(m3uPath);
    if (oldValues != null && oldValues.isSameAs(values)) return;
    _entries[m3uPath] = values.toJson();
    _save();
  }

  void retainOnly(bool Function(String m3uPath) test) {
    final lengthBefore = _entries.length;
    _entries.removeWhere((m3uPath, _) => !test(m3uPath));
    if (_entries.length != lengthBefore) _save();
  }
}

class _ParseM3UPlaylistFilesParams {
  final Set<String> allm3uPaths;
  final Map<String, String> boundNamesByPath;
  final DbWrapperFileInfo tracksDbInfo; // used as a fallback lookup
  final String backupDirPath; // used as a backup for newly found m3u files.

  const _ParseM3UPlaylistFilesParams({
    required this.allm3uPaths,
    required this.boundNamesByPath,
    required this.tracksDbInfo,
    required this.backupDirPath,
  });
}

class _ParseM3UPlaylistFilesResult {
  final Map<String, _M3UPlaylistTempInfo> paths;
  final Map<String, String?> infoMap;

  const _ParseM3UPlaylistFilesResult({
    required this.paths,
    required this.infoMap,
  });
}

class _M3UPlaylistTempInfo {
  final String path;
  final _M3UHeader header;
  final List<String> headerLines;
  final List<Track> tracks;

  const _M3UPlaylistTempInfo({
    required this.path,
    required this.header,
    required this.headerLines,
    required this.tracks,
  });
}

// by claude
/// the m3u header values namida edits, [description] is kept in one line.
class _M3UHeaderValues {
  final List<String> moods;
  final List<String> tags;
  final String description;

  const _M3UHeaderValues({
    required this.moods,
    required this.tags,
    required this.description,
  });

  static final _lineBreaksRegex = RegExp(r'[\r\n]+');

  factory _M3UHeaderValues.fromPlaylist(LocalPlaylist playlist) {
    return _M3UHeaderValues(
      moods: playlist.moods,
      tags: playlist.tags,
      description: playlist.comment.replaceAll(_lineBreaksRegex, ' ').trim(),
    );
  }

  factory _M3UHeaderValues.fromHeader(_M3UHeader header) {
    return _M3UHeaderValues(
      moods: header.moods,
      tags: header.tags,
      description: header.description,
    );
  }

  factory _M3UHeaderValues.fromJson(Map<String, dynamic> json) {
    return _M3UHeaderValues(
      moods: List<String>.from(json['moods'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moods': moods,
      'tags': tags,
      'description': description,
    };
  }

  bool isSameAs(_M3UHeaderValues other) {
    return description == other.description && listEquals(moods, other.moods) && listEquals(tags, other.tags);
  }

  /// edits of this header since [baseline] applied over [playlist], null fields stay as they are.
  ({List<String>? moods, List<String>? tags, String? comment}) mergeInto(LocalPlaylist playlist, _M3UHeaderValues? baseline) {
    return (
      moods: M3UFiles.mergeHeaderItems(playlist.moods, moods, baseline?.moods),
      tags: M3UFiles.mergeHeaderItems(playlist.tags, tags, baseline?.tags),
      comment: M3UFiles.mergeHeaderText(playlist.comment, description, baseline?.description),
    );
  }
}

enum _M3UHeaderKey {
  playlist('#PLAYLIST:', isAddedWhenMissing: true),
  tags('#TAGS:', isAddedWhenMissing: true),
  category('#CATEGORY:', isAddedWhenMissing: true),
  description('#DESCRIPTION:', isAddedWhenMissing: true),
  albumArtUrl('#EXTALBUMARTURL:'),
  playlistSize('#PLAYLISTSIZE:'),
  duration('#DURATION:'),
  ;

  final String prefix;
  final bool isAddedWhenMissing;
  const _M3UHeaderKey(this.prefix, {this.isAddedWhenMissing = false});

  static _M3UHeaderKey? ofHeaderLine(String headerLine) {
    for (final key in values) {
      if (headerLine.startsWith(key.prefix)) return key;
    }
    return null;
  }
}

typedef _M3UEntry = ({String path, String info});
typedef _M3UHeader = ({String? name, String? artUrl, List<String> moods, List<String> tags, String description});
