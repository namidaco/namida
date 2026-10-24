/// fingerprint logic is built by claude code
part of 'sync_manager.dart';

/// - [fullOf]: all stable tag info, preferred exact match.
/// - [coreOf]: title + artist + album + duration only, as a fallback.
///
/// volatile or per-device fields (path, dateAdded/dateModified, size,
/// bitrate/format/channels, rating) are excluded so the same audio content
/// hashes identically on both devices even if re-encoded or moved.
abstract final class SyncTrackFingerprint {
  /// mask to 2^53-1 to keep hashes exactly representable in json doubles.
  static const _kHashMask = 0x1FFFFFFFFFFFFF;

  static const _kFieldSeparator = '\x00';

  /// FNV-1a 64-bit, stable across platforms unlike [String.hashCode].
  static int _fnv1a(String input) {
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash *= 0x100000001b3;
    }
    return hash & _kHashMask;
  }

  static void _writeText(StringBuffer buffer, String value) {
    buffer
      ..write(value.trim().toLowerCase())
      ..write(_kFieldSeparator);
  }

  static void _writeNum(StringBuffer buffer, int value) {
    buffer
      ..write(value)
      ..write(_kFieldSeparator);
  }

  static int fullOf(TrackExtended tr) {
    final b = StringBuffer();
    _writeText(b, tr.title);
    _writeText(b, tr.originalArtist);
    _writeText(b, tr.originalAlbum);
    _writeText(b, tr.albumArtist);
    _writeText(b, tr.originalGenre);
    _writeText(b, tr.originalMood);
    _writeText(b, tr.composer);
    _writeText(b, tr.label);
    _writeText(b, tr.language);
    _writeNum(b, tr.trackNo);
    _writeNum(b, tr.trackTo);
    _writeNum(b, tr.discNo);
    _writeNum(b, tr.discTo);
    _writeNum(b, tr.year);
    _writeNum(b, tr.durationMS ~/ 1000);
    return _fnv1a(b.toString());
  }

  static int coreOf(TrackExtended tr) {
    final b = StringBuffer();
    _writeText(b, tr.title);
    _writeText(b, tr.originalArtist);
    _writeText(b, tr.originalAlbum);
    _writeNum(b, tr.durationMS ~/ 1000);
    return _fnv1a(b.toString());
  }
}

abstract final class SyncPathResolver {
  static _LocalFingerprintIndex? _localIndex;
  static Future<_LocalFingerprintIndex>? _localIndexBuild;

  static List<List<Object>>? _localEntriesCache;
  static Future<List<List<Object>>>? _localEntriesBuild;
  static int _localEntriesCacheSourceId = 0;
  static int _localEntriesCacheCount = -1;

  /// `{senderDeviceId: {senderPath: localTrack}}`, only differing paths are kept.
  static final _deviceMaps = <String, Map<String, Track>>{};

  static Future<_LocalFingerprintIndex> _ensureLocalIndex() {
    final source = Indexer.inst.allTracksMappedByPath;
    final current = _localIndex;
    if (current != null && current.isBuiltFor(source)) return Future.value(current);

    return _localIndexBuild ??= Isolate.run(() => _buildLocalIndexSync(source)).then(
      (index) {
        _localIndex = index;
        _localIndexBuild = null;
        return index;
      },
    );
  }

  /// `{coreFingerprint: localTrack}` of the local library.
  static Future<Map<int, Track>> localCoreIndex() => _ensureLocalIndex().then((index) => index.core);

  static _LocalFingerprintIndex _buildLocalIndexSync(Map<String, TrackExtended> source) {
    final full = <int, Track>{};
    final core = <int, Track>{};
    final uniqueByFileName = <String, Track>{};
    final duplicatesByFileName = <String, List<Track>>{};
    for (final trExt in source.values) {
      if (trExt.isNetwork) continue; // network paths are universal, no matching needed
      final track = trExt.asTrack();
      full[SyncTrackFingerprint.fullOf(trExt)] ??= track;
      core[SyncTrackFingerprint.coreOf(trExt)] ??= track;

      final fileName = _LocalFingerprintIndex.fileNameKeyOf(track.path);
      final duplicates = duplicatesByFileName[fileName];
      if (duplicates != null) {
        duplicates.add(track);
        continue;
      }
      final existing = uniqueByFileName[fileName];
      if (existing == null) {
        uniqueByFileName[fileName] = track;
      } else {
        uniqueByFileName.remove(fileName);
        duplicatesByFileName[fileName] = [existing, track];
      }
    }
    return _LocalFingerprintIndex(
      full: full,
      core: core,
      uniqueByFileName: uniqueByFileName,
      duplicatesByFileName: duplicatesByFileName,
      builtForSourceId: identityHashCode(source),
      builtForCount: source.length,
    );
  }

  /// entries of the local library to be sent to other devices, each as `[path, fullHash, coreHash]`.
  static Future<List<List<Object>>> buildLocalEntries() {
    final source = Indexer.inst.allTracksMappedByPath;
    final cached = _localEntriesCache;
    final sourceId = identityHashCode(source);
    final sourceCount = source.length;
    if (cached != null && _localEntriesCacheSourceId == sourceId && _localEntriesCacheCount == sourceCount) return Future.value(cached);

    return _localEntriesBuild ??= Isolate.run(() => _buildLocalEntriesSync(source)).then(
      (entries) {
        _localEntriesCache = entries;
        _localEntriesCacheSourceId = sourceId;
        _localEntriesCacheCount = sourceCount;
        _localEntriesBuild = null;
        return entries;
      },
    );
  }

  /// entries of another tracks db (ex: an extracted backup) like [buildLocalEntries], [oldJsonFilePath] is its pre-db json if any.
  static Future<List<List<Object>>> buildEntriesFromDb(DbWrapperFileInfo dbInfo, String oldJsonFilePath) {
    final splitConfig = SplitArtistGenreConfigsWrapper.settings();
    return _buildEntriesFromDbSync.thready((dbInfo: dbInfo, oldJsonFilePath: oldJsonFilePath, splitConfig: splitConfig));
  }

  static List<List<Object>> _buildEntriesFromDbSync(({DbWrapperFileInfo dbInfo, String oldJsonFilePath, SplitArtistGenreConfigsWrapper splitConfig}) params) {
    final splitConfig = params.splitConfig;
    final source = <String, TrackExtended>{};
    if (params.dbInfo.file.existsSync()) {
      final db = DBWrapper.openFromInfoSync(fileInfo: params.dbInfo, config: const DBConfig(autoDisposeTimerDuration: null));
      db.loadEverythingKeyed(
        (path, item) {
          try {
            source[path] = TrackExtended.fromJson(path, item, splitConfig: splitConfig);
          } catch (_) {}
        },
      );
      db.close();
    }
    final oldJsonFile = File(params.oldJsonFilePath);
    if (oldJsonFile.existsSync()) {
      final list = oldJsonFile.readAsJsonSync() as List?;
      for (final item in list ?? const []) {
        try {
          final path = item['path'] as String;
          source[path] ??= TrackExtended.fromJson(path, item, splitConfig: splitConfig);
        } catch (_) {}
      }
    }
    return _buildLocalEntriesSync(source);
  }

  static List<List<Object>> _buildLocalEntriesSync(Map<String, TrackExtended> source) {
    final entries = <List<Object>>[];
    for (final e in source.entries) {
      final trExt = e.value;
      if (trExt.isNetwork) continue;
      entries.add([e.key, SyncTrackFingerprint.fullOf(trExt), SyncTrackFingerprint.coreOf(trExt)]);
    }
    return entries;
  }

  /// builds & caches the senderPath -> localTrack map for [senderDeviceId],
  /// then replays any messages that were stashed waiting for it.
  static Future<void> buildForDevice(String senderDeviceId, List<dynamic> entries) async {
    final index = await _ensureLocalIndex();
    final map = <String, Track>{};
    for (final entry in entries) {
      final list = entry as List;
      final senderPath = list[0] as String;
      final local = index.full[list[1] as int] ?? index.core[list[2] as int] ?? index.byPathEnd(senderPath);
      if (local != null && local.path != senderPath) map[senderPath] = local;
    }
    _deviceMaps[senderDeviceId] = map;
    _unresolvedPathsByDevice.remove(senderDeviceId);

    final pending = _pendingMessagesByDevice.remove(senderDeviceId);
    if (pending != null) {
      for (final msg in pending) {
        try {
          await msg.executeOnReceived();
        } catch (e, st) {
          logger.error('Error executing stashed message ${msg.runtimeType}', e: e, st: st);
        }
      }
    }
  }

  static void clearForDevice(String deviceId) {
    _deviceMaps.remove(deviceId);
    _unresolvedPathsByDevice.remove(deviceId);
    _pendingMessagesByDevice.remove(deviceId);
  }

  static bool hasFingerprintsFor(String senderDeviceId) => _deviceMaps.containsKey(senderDeviceId);

  /// `{senderPath: localTrack}` of [senderDeviceId], only paths that differ here.
  static Map<String, Track> resolvedTracksFor(String senderDeviceId) => _deviceMaps[senderDeviceId] ?? const {};

  static final _pendingMessagesByDevice = <String, List<BaseMessage>>{};

  static void stashUntilFingerprints(BaseMessage msg) {
    final senderDeviceId = msg.messageInfo.senderDeviceId;
    final pending = _pendingMessagesByDevice[senderDeviceId];
    if (pending != null) {
      pending.add(msg);
      return;
    }
    _pendingMessagesByDevice[senderDeviceId] = [msg];
    _requestFingerprints(senderDeviceId);
  }

  static void _requestFingerprints(String senderDeviceId) async {
    try {
      final msg = RequestMessage(
        msgRequestType: .tracksDbFingerprints,
        messageInfo: await SyncUtils.createMessageInfo(.manifest),
        batchRef: null,
      );
      await SyncDiscovery.sendMessage(msg, senderDeviceId);
    } catch (e, st) {
      logger.error('Error requesting fingerprints', e: e, st: st);
    }
  }

  static Track? resolveTrackByPath(String senderDeviceId, String senderPath) {
    final map = _deviceMaps[senderDeviceId];
    if (map == null) return null;
    return map[senderPath] ?? _resolveByPathEnd(senderDeviceId, map, senderPath);
  }

  /// sender paths [_resolveByPathEnd] matched nothing for, so they aren't looked up again.
  static final _unresolvedPathsByDevice = <String, Set<String>>{};

  /// sender paths missing from its fingerprints (ex: listens of a file it no longer has), or that the fingerprints didn't match.

  static Track? _resolveByPathEnd(String senderDeviceId, Map<String, Track> map, String senderPath) {
    if (Indexer.inst.allTracksMappedByPath.containsKey(senderPath)) return null;
    final unresolvedPaths = _unresolvedPathsByDevice[senderDeviceId] ??= <String>{};
    if (unresolvedPaths.contains(senderPath)) return null;
    final local = _localIndex?.byPathEnd(senderPath);
    if (local == null) {
      unresolvedPaths.add(senderPath);
      return null;
    }
    map[senderPath] = local;
    return local;
  }

  static String? resolvePath(String senderDeviceId, String senderPath) => resolveTrackByPath(senderDeviceId, senderPath)?.path;

  static Track? resolveTrack(String senderDeviceId, Track track) {
    if (track.isNetwork) return null;
    return resolveTrackByPath(senderDeviceId, track.path);
  }

  static TrackWithDate resolveTrackWithDate(String senderDeviceId, TrackWithDate twd) {
    final local = resolveTrack(senderDeviceId, twd.track);
    if (local == null) return twd;
    return TrackWithDate(
      dateAdded: twd.dateAdded,
      track: local,
      queueSource: twd.queueSource,
      source: twd.sourceNull,
    );
  }
}

class _LocalFingerprintIndex {
  final Map<int, Track> full;
  final Map<int, Track> core;

  /// lowercase file name keys, see [byPathEnd].
  final Map<String, Track> uniqueByFileName;
  final Map<String, List<Track>> duplicatesByFileName;

  final int builtForSourceId;
  final int builtForCount;

  const _LocalFingerprintIndex({
    required this.full,
    required this.core,
    required this.uniqueByFileName,
    required this.duplicatesByFileName,
    required this.builtForSourceId,
    required this.builtForCount,
  });

  /// file name + parent folder at least.
  static const _kMinSharedSegments = 2;

  /// the local track whose path ends like [path] (ex: same folders inside a synced music folder), for tracks the fingerprints miss.
  /// the most shared trailing folders win, a tie matches nothing.
  Track? byPathEnd(String path) {
    final fileName = fileNameKeyOf(path);
    final unique = uniqueByFileName[fileName];
    if (unique != null) {
      final sharedSegments = _sharedTrailingSegments(path, unique.path);
      return sharedSegments >= _kMinSharedSegments ? unique : null;
    }
    final duplicates = duplicatesByFileName[fileName];
    if (duplicates == null) return null;
    Track? best;
    int bestSharedSegments = _kMinSharedSegments - 1;
    bool isTie = false;
    for (final track in duplicates) {
      final sharedSegments = _sharedTrailingSegments(path, track.path);
      if (sharedSegments > bestSharedSegments) {
        best = track;
        bestSharedSegments = sharedSegments;
        isTie = false;
      } else if (sharedSegments == bestSharedSegments) {
        isTie = true;
      }
    }
    return isTie ? null : best;
  }

  static String fileNameKeyOf(String path) {
    final slashIndex = path.lastIndexOf('/');
    final backslashIndex = path.lastIndexOf('\\');
    final separatorIndex = slashIndex > backslashIndex ? slashIndex : backslashIndex;
    return path.substring(separatorIndex + 1).toLowerCase();
  }

  /// whole path segments [a] and [b] end with, ignoring ascii case and separator kind.
  static int _sharedTrailingSegments(String a, String b) {
    int i = a.length - 1;
    int j = b.length - 1;
    int segments = 0;
    while (i >= 0 && j >= 0) {
      final charA = a.codeUnitAt(i);
      final charB = b.codeUnitAt(j);
      final isSeparatorA = _isSeparator(charA);
      if (isSeparatorA != _isSeparator(charB)) return segments;
      if (isSeparatorA) {
        segments++;
      } else if (_toLowerAscii(charA) != _toLowerAscii(charB)) {
        return segments;
      }
      i--;
      j--;
    }
    final isBoundaryA = i < 0 || _isSeparator(a.codeUnitAt(i));
    final isBoundaryB = j < 0 || _isSeparator(b.codeUnitAt(j));
    return isBoundaryA && isBoundaryB ? segments + 1 : segments;
  }

  static bool _isSeparator(int char) => char == 0x2F || char == 0x5C;

  static int _toLowerAscii(int char) => char >= 0x41 && char <= 0x5A ? char + 0x20 : char;

  /// the library map gets replaced on a reload, a same sized one can still hold other tracks.
  bool isBuiltFor(Map<String, TrackExtended> source) => builtForSourceId == identityHashCode(source) && builtForCount == source.length;
}
