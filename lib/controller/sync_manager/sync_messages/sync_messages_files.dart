/// built by claude code
part of '../sync_manager.dart';

/// Raw file syncing for directory-based [AppPathsBackupEnum] items,
/// using manifest diffing so only missing/newer files get sent:
///
/// 1. A -> B: [DirFilesManifestRequestMessage] asking for B's files info.
/// 2. B -> A: [DirFilesManifestResponseMessage] with `{name: [size, mtime]}` of B's existing files.
/// 3. A -> B: [DirFileMessage] per required file (missing on B, or differing in size while newer on A).
///    the file bytes travel in a raw binary frame right after the json frame, see [BinaryPayloadMessage].
abstract final class _DirFilesSyncUtils {
  /// keeps memory bounded, the whole file is buffered on both sides.
  static const kMaxFileSize = 200 * 1024 * 1024;

  static bool isAllowedSubtype(AppPathsBackupEnum subtype) => subtype.isDir && subtype.supportsSync() == true;

  /// prevents path traversal outside the target dir.
  static bool isSafeFileName(String name) => name.isNotEmpty && !name.contains('/') && !name.contains('\\') && !name.contains('..');

  /// `{fileName: [size, mtimeMS]}` for top-level files of the dir.
  static Future<Map<String, dynamic>> buildManifest(AppPathsBackupEnum subtype) async {
    final result = <String, dynamic>{};
    final dir = Directory(subtype.resolve());
    if (!await dir.exists()) return result;
    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      try {
        final stat = await e.stat();
        result[e.path.getFilename] = [stat.size, stat.modified.millisecondsSinceEpoch];
      } catch (_) {}
    }
    return result;
  }
}

class DirFilesManifestRequestMessage extends BaseMessage {
  final AppPathsBackupEnum subtype;
  final BatchInfoMessage batchInfoMessage;

  const DirFilesManifestRequestMessage({
    required this.subtype,
    required this.batchInfoMessage,
    required super.messageInfo,
  }) : super(MessageType.dirFilesManifestRequest);

  static Future<DirFilesManifestRequestMessage> create(AppPathsBackupEnum subtype, BatchInfoMessage batchInfoMessage) async {
    return DirFilesManifestRequestMessage(
      subtype: subtype,
      batchInfoMessage: batchInfoMessage,
      messageInfo: await SyncUtils.createMessageInfo(.manifest),
    );
  }

  factory DirFilesManifestRequestMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DirFilesManifestRequestMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      batchInfoMessage: BatchInfoMessage.fromMap(map['bim'], messageInfo),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'bim': batchInfoMessage._encodeToMap(),
    'st': subtype.name,
  };

  @override
  FutureOr<void> executeOnReceived() async {
    if (!_DirFilesSyncUtils.isAllowedSubtype(subtype)) return;
    final manifest = await _DirFilesSyncUtils.buildManifest(subtype);
    final msg = DirFilesManifestResponseMessage(
      subtype: subtype,
      batchInfoMessage: batchInfoMessage,
      files: manifest,
      messageInfo: await SyncUtils.createMessageInfo(.manifest),
    );
    await SyncDiscovery.sendMessage(msg, messageInfo.senderDeviceId);
  }
}

class DirFilesManifestResponseMessage extends BaseMessage {
  final AppPathsBackupEnum subtype;
  final BatchInfoMessage batchInfoMessage;

  /// `{fileName: [size, mtimeMS]}` of the files already existing on the other device.
  final Map<String, dynamic> files;

  const DirFilesManifestResponseMessage({
    required this.subtype,
    required this.batchInfoMessage,
    required this.files,
    required super.messageInfo,
  }) : super(MessageType.dirFilesManifestResponse);

  factory DirFilesManifestResponseMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DirFilesManifestResponseMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      batchInfoMessage: BatchInfoMessage.fromMap(map['bim'], messageInfo),
      files: (map['f'] as Map).cast<String, dynamic>(),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'st': subtype.name,
    'bim': batchInfoMessage._encodeToMap(),
    'f': files,
  };

  @override
  String toRawInfo() => 'DirFilesManifestResponse(${subtype.name}: ${files.length} files)';

  /// we requested this manifest earlier, now send the files the other device needs.
  @override
  FutureOr<void> executeOnReceived() async {
    if (!_DirFilesSyncUtils.isAllowedSubtype(subtype)) return;

    final receiverDeviceId = messageInfo.senderDeviceId;
    final dir = Directory(subtype.resolve());
    if (!await dir.exists()) return;

    // -- cache videos get their info piggybacked, so the receiver doesn't re-extract it.
    // -- only the sent file's own info travels, the map is a local by-filename lookup
    // -- (the cache map is keyed by id), built lazily when a file actually gets sent.
    final isVideosCache = subtype == AppPathsBackupEnum.VIDEOS_CACHE;
    Map<String, Map<String, dynamic>>? cacheVideosInfo;

    int sentCount = 0;
    int skippedLargeCount = 0;

    try {
      final batchInfoMessageModified = BatchInfoMessage(
        // -- new msg info so that progress applies to correct device
        messageInfo: await SyncUtils.createMessageInfo(batchInfoMessage.messageInfo.action),
        progressItem: batchInfoMessage.progressItem,
        progress: batchInfoMessage.progress,
        total: batchInfoMessage.total,
      );
      await SyncDiscovery.sendAndUpdateBatchProgress(receiverDeviceId, batchInfoMessageModified);
    } catch (_) {}

    await for (final e in dir.list(followLinks: false)) {
      if (e is! File) continue;
      final name = e.path.getFilename;
      if (!_DirFilesSyncUtils.isSafeFileName(name)) continue;

      final FileStat stat;
      try {
        stat = await e.stat();
      } catch (_) {
        continue;
      }
      if (stat.size > _DirFilesSyncUtils.kMaxFileSize) {
        skippedLargeCount++;
        continue;
      }

      final other = files[name];
      if (other is List && other.length >= 2) {
        final otherSize = other[0] as int? ?? -1;
        final otherMtime = other[1] as int? ?? 0;
        if (otherSize == stat.size) continue; // -- same file
        if (stat.modified.millisecondsSinceEpoch <= otherMtime) continue; // -- theirs is newer
      }

      final Uint8List bytes;
      try {
        bytes = await e.readAsBytes();
      } catch (_) {
        continue;
      }

      if (isVideosCache) cacheVideosInfo ??= VideoController.inst.buildCacheVideosSyncInfoByFilename();

      final msg = DirFileMessage(
        subtype: subtype,
        fileName: name,
        mtime: stat.modified.millisecondsSinceEpoch,
        info: cacheVideosInfo?[name],
        bytes: bytes,
        messageInfo: await SyncUtils.createMessageInfo(.add),
      );
      await SyncDiscovery.sendMessage(msg, receiverDeviceId);
      sentCount++;
    }

    if (_kEnableSyncDebug) _debugNotify('==> dir files sent[${subtype.name}]: $sentCount, skipped large: $skippedLargeCount');
  }
}

/// Raw database file syncing for [DBWrapper]-based [AppPathsBackupEnum] items.
/// the sender checkpoints (merging wal journal contents) & sends the whole db
/// file as a binary frame, skipping any db load/encode. the receiver writes it
/// to a temp file next to its own db and merges entries inside an isolate.
class DbFileMessage extends BaseMessage with BinaryPayloadMessage {
  final AppPathsBackupEnum subtype;

  DbFileMessage({
    required this.subtype,
    Uint8List? bytes,
    required super.messageInfo,
  }) : super(MessageType.dbFile) {
    binaryPayload = bytes;
  }

  static bool isAllowedSubtype(AppPathsBackupEnum subtype) => switch (subtype) {
    AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO || AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => true,
    _ => false,
  };

  /// returns null when the local db file doesn't exist.
  static Future<DbFileMessage?> create(AppPathsBackupEnum subtype) async {
    final bytes = await switch (subtype) {
      AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => YoutubeController.inst.statsManager.buildSyncDbBytes(),
      AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => VideoController.inst.videosPriorityManager.buildSyncDbBytes(),
      _ => Future<Uint8List?>.value(null),
    };
    if (bytes == null) return null;
    return DbFileMessage(
      subtype: subtype,
      bytes: bytes,
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
  }

  factory DbFileMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DbFileMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'st': subtype.name,
  };

  @override
  String toRawInfo() {
    final bytes = binaryPayload;
    return 'DbFile(${subtype.name}, ${bytes == null ? '?' : bytes.length.fileSizeFormatted})';
  }

  @override
  FutureOr<void> executeOnReceived() async {
    final bytes = binaryPayload;
    if (bytes == null) return; // -- binary payload frame never arrived
    if (!isAllowedSubtype(subtype)) return;

    if (!SyncUtils.kAllowModification) {
      snackyy(message: 'Importing db file ${subtype.name} (${bytes.length.fileSizeFormatted})');
      return;
    }

    final tempFile = File('${subtype.resolve()}.sync_incoming');
    try {
      await tempFile.writeAsBytes(bytes);
      final changed = await switch (subtype) {
        AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => YoutubeController.inst.statsManager.importFromSyncDb(tempFile),
        AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => VideoController.inst.videosPriorityManager.importFromSyncDb(tempFile),
        _ => Future.value(0),
      };
      if (_kEnableSyncDebug) _debugNotify('==> db file merged[${subtype.name}]: $changed entries');
    } catch (e, st) {
      logger.error('Error merging synced db file ${subtype.name}', e: e, st: st);
    } finally {
      for (final suffix in const ['', '-wal', '-wal2', '-shm', '-journal']) {
        await File('${tempFile.path}$suffix').tryDeleting();
      }
    }
  }
}

/// Db entries syncing with manifest diffing so only missing/newer entries get sent
/// (the whole-db alternative is [DbFileMessage], see [SyncUtils.kUseDbEntriesSync]):
///
/// 1. A -> B: [DbManifestRequestMessage] asking for B's entries info.
/// 2. B -> A: [DbManifestResponseMessage] with `{key: token}` of B's entries.
///    the token meaning is per subtype (stats: modified date, priority: priority index).
/// 3. A -> B: [DbEntriesMessage] chunks with the entries B is missing or would replace.
class DbManifestRequestMessage extends BaseMessage {
  final AppPathsBackupEnum subtype;

  const DbManifestRequestMessage({
    required this.subtype,
    required super.messageInfo,
  }) : super(MessageType.dbManifestRequest);

  static Future<DbManifestRequestMessage> create(AppPathsBackupEnum subtype) async {
    return DbManifestRequestMessage(
      subtype: subtype,
      messageInfo: await SyncUtils.createMessageInfo(.manifest),
    );
  }

  factory DbManifestRequestMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DbManifestRequestMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'st': subtype.name,
  };

  @override
  FutureOr<void> executeOnReceived() async {
    if (!DbFileMessage.isAllowedSubtype(subtype)) return;
    final manifest = await switch (subtype) {
      AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => YoutubeController.inst.statsManager.buildSyncManifest(),
      AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => VideoController.inst.videosPriorityManager.buildSyncManifest(),
      _ => Future.value(<String, int>{}),
    };
    final msg = DbManifestResponseMessage(
      subtype: subtype,
      manifest: manifest,
      messageInfo: await SyncUtils.createMessageInfo(.manifest),
    );
    await SyncDiscovery.sendMessage(msg, messageInfo.senderDeviceId);
  }
}

class DbManifestResponseMessage extends BaseMessage {
  final AppPathsBackupEnum subtype;

  /// `{key: token}` of the entries already existing on the other device.
  final Map<String, dynamic> manifest;

  const DbManifestResponseMessage({
    required this.subtype,
    required this.manifest,
    required super.messageInfo,
  }) : super(MessageType.dbManifestResponse);

  /// keeps single messages bounded, big diffs stream chunk by chunk.
  static const _kEntriesChunkSize = 500;

  factory DbManifestResponseMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DbManifestResponseMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      manifest: (map['m'] as Map).cast<String, dynamic>(),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'st': subtype.name,
    'm': manifest,
  };

  @override
  String toRawInfo() => 'DbManifestResponse(${subtype.name}: ${manifest.length} entries)';

  /// we requested this manifest earlier, now send the entries the other device needs.
  @override
  FutureOr<void> executeOnReceived() async {
    if (!DbFileMessage.isAllowedSubtype(subtype)) return;

    final receiverDeviceId = messageInfo.senderDeviceId;
    final entries = await switch (subtype) {
      AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => YoutubeController.inst.statsManager.buildSyncEntriesToSend(manifest),
      AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => VideoController.inst.videosPriorityManager.buildSyncEntriesToSend(manifest),
      _ => Future.value(<String, Map<String, dynamic>>{}),
    };
    if (entries.isEmpty) return;

    var chunk = <String, dynamic>{};
    for (final e in entries.entries) {
      chunk[e.key] = e.value;
      if (chunk.length >= _kEntriesChunkSize) {
        await _sendChunk(chunk, receiverDeviceId);
        chunk = {};
      }
    }
    if (chunk.isNotEmpty) await _sendChunk(chunk, receiverDeviceId);
  }

  Future<void> _sendChunk(Map<String, dynamic> chunk, String receiverDeviceId) async {
    final msg = DbEntriesMessage(
      subtype: subtype,
      entries: chunk,
      messageInfo: await SyncUtils.createMessageInfo(.add),
    );
    await SyncDiscovery.sendMessage(msg, receiverDeviceId);
  }
}

class DbEntriesMessage extends BaseMessage {
  final AppPathsBackupEnum subtype;

  /// `{key: valueMap}` entries to merge into the receiver's db.
  final Map<String, dynamic> entries;

  const DbEntriesMessage({
    required this.subtype,
    required this.entries,
    required super.messageInfo,
  }) : super(MessageType.dbEntries);

  factory DbEntriesMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DbEntriesMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      entries: (map['e'] as Map).cast<String, dynamic>(),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'st': subtype.name,
    'e': entries,
  };

  @override
  String toRawInfo() => 'DbEntries(${subtype.name}: ${entries.length} entries)';

  @override
  FutureOr<void> executeOnReceived() async {
    if (!DbFileMessage.isAllowedSubtype(subtype)) return;

    if (!SyncUtils.kAllowModification) {
      snackyy(message: 'Importing ${entries.length} db entries [${subtype.name}]');
      return;
    }

    final changed = await switch (subtype) {
      AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => YoutubeController.inst.statsManager.importSyncEntries(entries),
      AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => VideoController.inst.videosPriorityManager.importSyncEntries(entries),
      _ => Future.value(0),
    };
    if (_kEnableSyncDebug) _debugNotify('==> db entries merged[${subtype.name}]: $changed/${entries.length}');
  }
}

class DirFileMessage extends BaseMessage with BinaryPayloadMessage {
  final AppPathsBackupEnum subtype;
  final String fileName;
  final int mtime;

  /// extra info attached to the file, interpreted per subtype. currently
  /// [AppPathsBackupEnum.VIDEOS_CACHE] video info, saving the receiver
  /// an ffmpeg extraction for the synced file.
  final Map<String, dynamic>? info;

  DirFileMessage({
    required this.subtype,
    required this.fileName,
    required this.mtime,
    this.info,
    Uint8List? bytes,
    required super.messageInfo,
  }) : super(MessageType.dirFile) {
    binaryPayload = bytes;
  }

  factory DirFileMessage.fromMap(Map<String, dynamic> map, BaseMessageInfo messageInfo) {
    return DirFileMessage(
      subtype: AppPathsBackupEnum.values.getEnum(map['st'] as String)!,
      fileName: map['n'] as String,
      mtime: map['mt'] as int? ?? 0,
      info: (map['i'] as Map?)?.cast<String, dynamic>(),
      messageInfo: messageInfo,
    );
  }

  @override
  Map<String, dynamic> _encodeToMap() => {
    'st': subtype.name,
    'n': fileName,
    'mt': mtime,
    'i': ?info,
  };

  @override
  String toRawInfo() {
    final bytes = binaryPayload;
    return 'DirFile(${subtype.name}/$fileName, ${bytes == null ? '?' : bytes.length.fileSizeFormatted})';
  }

  @override
  FutureOr<void> executeOnReceived() async {
    final bytes = binaryPayload;
    if (bytes == null) return; // -- binary payload frame never arrived

    if (!_DirFilesSyncUtils.isAllowedSubtype(subtype)) return;
    if (!_DirFilesSyncUtils.isSafeFileName(fileName)) return;

    if (!SyncUtils.kAllowModification) {
      // snackyy(message: 'Importing file ${subtype.name}/$fileName (${bytes.length.fileSizeFormatted})');
      return;
    }

    try {
      final file = FileParts.join(subtype.resolve(), fileName);
      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size == bytes.length) return; // -- same file
        if (stat.modified.millisecondsSinceEpoch >= mtime) return; // -- ours is newer
      }
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      // -- keep the sender's mtime so future manifests compare correctly
      await file.setLastModified(DateTime.fromMillisecondsSinceEpoch(mtime));

      final info = this.info;
      if (info != null) {
        switch (subtype) {
          case AppPathsBackupEnum.VIDEOS_CACHE:
            VideoController.inst.importSyncedCacheVideoInfo(fileName, info);
          case AppPathsBackupEnum.QUEUES:
            QueueController.inst.prepareAllQueuesFile();
          default:
            null;
        }
      }
    } catch (e, st) {
      logger.error('Error writing synced file ${subtype.name}/$fileName', e: e, st: st);
    }
  }
}
