// all merge restore logic by claude
part of 'backup_controller.dart';

/// merges a backup extracted into [_rootPath] into the live data, nothing local gets removed.
/// an entry both sides have takes the backup's value, except listen time (the bigger count) and youtube metadata cache (the newest).
class _BackupMerger {
  final String _rootPath;
  final String _userDataPath;

  _BackupMerger(this._rootPath) : _userDataPath = AppDirs.USER_DATA.endsWith(Platform.pathSeparator) ? AppDirs.USER_DATA : '${AppDirs.USER_DATA}${Platform.pathSeparator}';

  /// paths of the backup resolve to this device's under this sender, see [SyncPathResolver].
  static const _kSenderId = '_backup_restore_';

  /// where [livePath] (inside [AppDirs.USER_DATA]) is inside the extracted backup.
  String pathOf(String livePath) {
    final relativePath = livePath.length > _userDataPath.length ? livePath.substring(_userDataPath.length) : '';
    return '$_rootPath$relativePath';
  }

  File _fileOf(String livePath) => File(pathOf(livePath));

  DbWrapperFileInfo _dbInfoOf(DbWrapperFileInfo liveInfo) => DbWrapperFileInfo(directory: pathOf(liveInfo.directory), dbName: liveInfo.dbName);

  /// returns the items that failed, the rest still get merged.
  Future<List<AppPathsBackupEnum>> merge() async {
    final failedSteps = <_BackupMergeStep>{};
    try {
      await _resolveTracksPaths();
    } catch (e, st) {
      failedSteps.add(_BackupMergeStep.tracksDb);
      logger.error('Error resolving backup tracks paths', e: e, st: st);
    }
    for (final step in _BackupMergeStep.values) {
      try {
        await _mergeStep(step);
      } catch (e, st) {
        failedSteps.add(step);
        logger.error('Error merging backup step ${step.name}', e: e, st: st);
      }
    }
    SyncPathResolver.clearForDevice(_kSenderId);
    return AppPathsBackupEnum.values.where((e) => failedSteps.contains(e.toMergeStep())).toFixedList();
  }

  Future<void> _mergeStep(_BackupMergeStep step) {
    return switch (step) {
      _BackupMergeStep.settings => _mergeSettings(),
      _BackupMergeStep.trackStats => _mergeTrackStats(),
      _BackupMergeStep.latestPlayed => _mergeLatestPlayed(),
      _BackupMergeStep.audioConfigs => _mergeAudioConfigs(),
      _BackupMergeStep.smartPlaylists => _mergeSmartPlaylists(),
      _BackupMergeStep.history => _mergeHistory(),
      _BackupMergeStep.youtubeHistory => _mergeYoutubeHistory(),
      _BackupMergeStep.playlists => _mergePlaylists(),
      _BackupMergeStep.youtubePlaylists => _mergeYoutubePlaylists(),
      _BackupMergeStep.youtubeIdStats => _mergeYoutubeIdStats(),
      _BackupMergeStep.videosPriority => _mergeVideosPriority(),
      _BackupMergeStep.subscriptions => _mergeSubscriptions(),
      _BackupMergeStep.youtubeStats => _mergeYoutubeStats(),
      _BackupMergeStep.downloadTasks => _mergeDownloadTasks(),
      _BackupMergeStep.youtipieCache => _mergeYoutipieCache(),
      _BackupMergeStep.listenTime => _mergeListenTime(),
      _BackupMergeStep.files => _moveFilesDirs(),
      _BackupMergeStep.videosDbs => _mergeVideosDbs(),
      _BackupMergeStep.queues => _mergeQueues(),
      _BackupMergeStep.tracksDb => _mergeTracksDb(),
    };
  }

  Future<void> _mergeSettings() => settings.applyBackupFiles(pathOf);

  Future<void> _resolveTracksPaths() async {
    final dbInfo = _dbInfoOf(AppPaths.TRACKS_DB_INFO);
    final oldJsonPath = pathOf(AppPaths.TRACKS_OLD);
    final entries = await SyncPathResolver.buildEntriesFromDb(dbInfo, oldJsonPath);
    if (entries.isNotEmpty) await SyncPathResolver.buildForDevice(_kSenderId, entries);
  }

  /// tracks under paths that matched none of ours are added too, ex: files of a removed storage.
  Future<void> _mergeTracksDb() async {
    final backupDbInfo = _dbInfoOf(AppPaths.TRACKS_DB_INFO);
    final backupOldJsonFile = _fileOf(AppPaths.TRACKS_OLD);
    final hasDb = await backupDbInfo.file.exists();
    final hasOldJson = await backupOldJsonFile.exists();
    if (!hasDb && !hasOldJson) return;
    if (hasDb) {
      final matchedPaths = SyncPathResolver.resolvedTracksFor(_kSenderId).keys.toSet();
      await _mergeTracksDbSync.thready((backup: backupDbInfo.file, live: AppPaths.TRACKS_DB_INFO, matchedPaths: matchedPaths));
    }
    // -- loading migrates the pre-db json into the db
    if (hasOldJson) await backupOldJsonFile.rename(AppPaths.TRACKS_OLD);
    // -- returns once the library is loaded, sorting it continues in the background
    await Indexer.inst.prepareTracksFile(startupBoost: true);
  }

  static void _mergeTracksDbSync(({File backup, DbWrapperFileInfo live, Set<String> matchedPaths}) params) {
    const config = DBConfig(createIfNotExist: true, autoDisposeTimerDuration: null);
    final matchedPaths = params.matchedPaths;
    final backupDb = DBWrapper.openFromFileSync(params.backup, config: config);
    final liveDb = DBWrapper.openFromInfoSync(fileInfo: params.live, config: config);
    final entries = <MapEntry<String, Map<String, dynamic>?>>[];
    backupDb.loadEverythingKeyed(
      (path, value) {
        if (!matchedPaths.contains(path)) entries.add(MapEntry(path, value));
      },
    );
    liveDb.putAll(DBWriteList(entries));
    backupDb.close();
    liveDb.close();
  }

  Future<void> _mergeTrackStats() async {
    final dbInfo = _dbInfoOf(AppPaths.TRACKS_STATS_DB_INFO);
    final oldJsonPath = pathOf(AppPaths.TRACKS_STATS_OLD);
    final stats = await Indexer.readTrackStatsDb(dbInfo, oldJsonPath);
    if (stats.isNotEmpty) await Indexer.inst.importTrackStats(stats.values, _kSenderId, incomingWins: true);
  }

  Future<void> _mergeLatestPlayed() async {
    final rows = await _readDbRows(AppPaths.LATEST_PLAYED_FOR_SOURCE);
    if (rows.isNotEmpty) await QueueController.latestPlayedForSourceManager.import(rows.entries, _kSenderId, incomingWins: true);
  }

  Future<void> _mergeAudioConfigs() async {
    final rows = await _readDbRows(AppPaths.AUDIO_CONFIGS);
    final configs = <MapEntry<String, PlayerConfigOverrides>>[];
    for (final e in rows.entries) {
      try {
        configs.add(MapEntry(e.key, PlayerConfigOverrides.fromMap(e.value)));
      } catch (_) {}
    }
    if (configs.isNotEmpty) await Player.audioConfigs.import(configs, _kSenderId, incomingWins: true);
  }

  Future<void> _mergeSmartPlaylists() async {
    final rows = await _readDbRows(AppPaths.SMART_PLAYLISTS);
    if (rows.isNotEmpty) await SmartPlaylistsController.inst.importBackupDbRows(rows);
  }

  Future<void> _mergeHistory() async {
    final historyDirPath = pathOf(AppDirs.HISTORY_PLAYLIST);
    if (!await Directory(historyDirPath).exists()) return;
    final controller = HistoryController.inst;
    final res = await controller.prepareAllHistoryFilesFunction(historyDirPath);
    if (res.totalItemsCount == 0) return;
    final listens = res.historyMap.values.expand((dayListens) => dayListens);
    final resolvedListens = listens.map((twd) => SyncPathResolver.resolveTrackWithDate(_kSenderId, twd));
    await controller.addTracksToHistoryImportPreventDuplicates(resolvedListens);
    await Indexer.inst.sortMediaTracksAndSubListsAfterHistoryPrepared();
  }

  Future<void> _mergeYoutubeHistory() async {
    final historyDirPath = pathOf(AppDirs.YT_HISTORY_PLAYLIST);
    if (!await Directory(historyDirPath).exists()) return;
    final controller = YoutubeHistoryController.inst;
    final res = await controller.prepareAllHistoryFilesFunction(historyDirPath);
    if (res.totalItemsCount == 0) return;
    final listens = res.historyMap.values.expand((dayListens) => dayListens);
    await controller.addTracksToHistoryImportPreventDuplicates(listens);
  }

  Future<void> _mergePlaylists() async {
    final controller = PlaylistController.inst;
    final incomingPlaylists = await controller.readPlaylistsDirectory(pathOf(AppDirs.PLAYLISTS));
    final missingPlaylists = <LocalPlaylist>[];
    final edits = <String, PlaylistMetadataEdit>{};
    for (final incoming in incomingPlaylists.values) {
      final resolved = incoming.copyWithConvertedTracks((twd) => SyncPathResolver.resolveTrackWithDate(_kSenderId, twd));
      final local = controller.playlistsMap.value[resolved.name];
      if (local == null) {
        missingPlaylists.add(resolved);
      } else {
        await _mergeIntoPlaylist(controller, local, resolved, edits);
      }
    }
    if (missingPlaylists.isNotEmpty) await controller.importSyncedPlaylists(missingPlaylists);

    final metadataDirPath = pathOf(AppDirs.PLAYLISTS_METADATA);
    final m3uProperties = await controller.readM3UProperties(metadataDirPath);
    for (final properties in m3uProperties.values) {
      final local = controller.playlistsMap.value[properties.name];
      if (local != null) await _mergeIntoPlaylist(controller, local, properties, edits);
    }
    await controller.updatePlaylistsMetadata(edits);
    await controller.mergeMetadataFrom(metadataDirPath);

    final favourites = await controller.readFavouritesFile(pathOf(AppPaths.FAVOURITES_PLAYLIST));
    if (favourites != null) {
      final resolvedFavourites = favourites.tracks.map((twd) => SyncPathResolver.resolveTrackWithDate(_kSenderId, twd));
      await controller.importTracksToPlaylist(controller.favouritesPlaylist.value, resolvedFavourites);
    }
  }

  Future<void> _mergeYoutubePlaylists() async {
    final controller = YoutubePlaylistController.inst;
    final incomingPlaylists = await controller.readPlaylistsDirectory(pathOf(AppDirs.YT_PLAYLISTS));
    final missingPlaylists = <YoutubePlaylist>[];
    final edits = <String, PlaylistMetadataEdit>{};
    for (final incoming in incomingPlaylists.values) {
      final local = controller.playlistsMap.value[incoming.name];
      if (local == null) {
        missingPlaylists.add(incoming);
      } else {
        await _mergeIntoPlaylist(controller, local, incoming, edits);
      }
    }
    if (missingPlaylists.isNotEmpty) await controller.importPlaylistsIfNewer(missingPlaylists);
    await controller.updatePlaylistsMetadata(edits);
    await controller.mergeMetadataFrom(pathOf(AppDirs.YT_PLAYLISTS_METADATA));

    final likes = await controller.readFavouritesFile(pathOf(AppPaths.YT_LIKES_PLAYLIST));
    if (likes != null) await controller.importTracksToPlaylist(controller.favouritesPlaylist.value, likes.tracks);
  }

  /// tracks missing in [local] are added, its metadata goes to [edits] to be applied at once.
  Future<void> _mergeIntoPlaylist<T extends PlaylistItemWithDate, E, S>(
    PlaylistManager<T, E, S> manager,
    GeneralPlaylist<T, S> local,
    GeneralPlaylist<T, S> incoming,
    Map<String, PlaylistMetadataEdit> edits,
  ) async {
    if (local.isReadOnly) return;
    if (incoming.tracks.isNotEmpty) await manager.importTracksToPlaylist(local, incoming.tracks);
    if (incoming.isFav != local.isFav) await manager.updatePropertyInPlaylist(local.name, isFav: incoming.isFav);
    edits[local.name] = PlaylistMetadataEdit(
      moods: incoming.moods,
      tags: incoming.tags,
      isPinned: incoming.isPinned,
      comment: incoming.comment,
    );
  }

  Future<void> _mergeYoutubeIdStats() async {
    final dbFile = _fileOf(AppPaths.VIDEO_ID_STATS_DB_INFO.file.path);
    if (!await dbFile.exists()) return;
    final pair = (backup: dbFile, live: AppPaths.VIDEO_ID_STATS_DB_INFO);
    await _mergeDbsSync.thready((pairs: [pair], conflict: _BackupDbConflict.backupWins));
  }

  Future<void> _mergeVideosPriority() async {
    final dbFile = _fileOf(AppPaths.CACHE_VIDEOS_PRIORITY.file.path);
    if (await dbFile.exists()) await VideoController.inst.videosPriorityManager.importFromSyncDb(dbFile, incomingWins: true);
  }

  Future<void> _mergeSubscriptions() async {
    final controller = YoutubeSubscriptionsController.inst;
    final subscriptionsFile = _fileOf(AppPaths.YT_SUBSCRIPTIONS);
    if (await subscriptionsFile.exists()) {
      final channels = await controller.readSubscriptionsFile(subscriptionsFile);
      await controller.import(channels.values);
    }
    final groups = await controller.readGroupsFile(_fileOf(AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL));
    if (groups.isNotEmpty) await controller.importGroups(groups);
  }

  Future<void> _mergeYoutubeStats() async {
    final statsDirPath = pathOf(AppDirs.YT_STATS);
    if (!await Directory(statsDirPath).exists()) return;
    await JsonToHistoryParser.mergeYoutubeStatsDirectory(statsDirPath);
    YoutubeInfoController.utils.fillBackupInfoMap();
  }

  Future<void> _mergeDownloadTasks() async {
    final didMerge = await _mergeDbsDirectory(AppDirs.YT_DOWNLOAD_TASKS, _BackupDbConflict.backupWins);
    if (didMerge) await YoutubeController.inst.loadDownloadTasksInfoFileAsync();
  }

  Future<void> _mergeYoutipieCache() => _mergeDbsDirectory(AppDirs.YOUTIPIE_CACHE, _BackupDbConflict.newestGood);

  Future<void> _mergeListenTime() async {
    final rows = await _readDbRows(AppPaths.LISTEN_TIME_DAILY_DB_INFO);
    if (rows.isNotEmpty) await ListenTimeController.inst.importDbRows(rows);
    final totalListenTimeFile = _fileOf(AppPaths.TOTAL_LISTEN_TIME);
    if (await totalListenTimeFile.exists()) await Player.inst.importTotalListenTimeFile(totalListenTimeFile);
  }

  /// dirs whose files are only identified by their names, a backup's file replaces the one with the same name.
  static final _filesDirsPaths = AppPathsBackupEnum.values.where((e) => e.toMergeStep() == _BackupMergeStep.files).map((e) => e.resolve()).toFixedList();

  Future<void> _moveFilesDirs() async {
    final dirsPaths = _filesDirsPaths.map((dirPath) => (backup: pathOf(dirPath), live: dirPath)).toFixedList();
    final movedCount = await _moveFilesDirsSync.thready(dirsPaths);
    if (movedCount == 0) return;
    AudioCacheController.inst.updateAudioCacheMap();
    Indexer.inst.calculateAllImageSizesInStorage();
  }

  static int _moveFilesDirsSync(List<({String backup, String live})> dirsPaths) {
    int movedCount = 0;
    for (final dirPaths in dirsPaths) {
      final files = Directory(dirPaths.backup).listSyncSafe();
      if (files.isEmpty) continue;
      Directory(dirPaths.live).createSync(recursive: true);
      for (final f in files) {
        if (f is! File) continue;
        final livePath = FileParts.joinPath(dirPaths.live, f.path.getFilename);
        try {
          f.renameSync(livePath);
          movedCount++;
        } catch (_) {}
      }
    }
    return movedCount;
  }

  /// after [_moveFilesDirs], the cache entries point to the moved videos.
  Future<void> _mergeVideosDbs() async {
    final localVideosDb = _fileOf(AppPaths.VIDEOS_LOCAL_DB_INFO.file.path);
    final cacheVideosDb = _fileOf(AppPaths.VIDEOS_CACHE_DB_INFO.file.path);
    final localVideosOldJson = _fileOf(AppPaths.VIDEOS_LOCAL_OLD);
    final cacheVideosOldJson = _fileOf(AppPaths.VIDEOS_CACHE_OLD);
    final hasLocalVideosDb = await localVideosDb.exists();
    final hasCacheVideosDb = await cacheVideosDb.exists();
    final hasLocalVideosOldJson = await localVideosOldJson.exists();
    final hasCacheVideosOldJson = await cacheVideosOldJson.exists();
    if (!hasLocalVideosDb && !hasCacheVideosDb && !hasLocalVideosOldJson && !hasCacheVideosOldJson) return;
    if (hasLocalVideosDb) {
      final pair = (backup: localVideosDb, live: AppPaths.VIDEOS_LOCAL_DB_INFO);
      await _mergeDbsSync.thready((pairs: [pair], conflict: _BackupDbConflict.backupWins));
    }
    // -- loading migrates the pre-db jsons into the dbs
    if (hasLocalVideosOldJson) await localVideosOldJson.rename(AppPaths.VIDEOS_LOCAL_OLD);
    if (hasCacheVideosOldJson) await cacheVideosOldJson.rename(AppPaths.VIDEOS_CACHE_OLD);
    await VideoController.inst.importBackupCacheDb(hasCacheVideosDb ? cacheVideosDb : null);
  }

  Future<void> _mergeQueues() async {
    final queuesDirPath = pathOf(AppDirs.QUEUES);
    if (await Directory(queuesDirPath).exists()) {
      final resolvedTracks = SyncPathResolver.resolvedTracksFor(_kSenderId);
      await QueueController.inst.importQueuesDirectory(queuesDirPath, resolvedTracks);
    }
    final latestQueuePath = pathOf(AppPaths.LATEST_QUEUE);
    if (await File(latestQueuePath).exists()) await QueueController.inst.importLatestQueue(latestQueuePath, _kSenderId);
  }

  Future<Map<String, Map<String, dynamic>>> _readDbRows(DbWrapperFileInfo liveInfo) async {
    final dbInfo = _dbInfoOf(liveInfo);
    if (!await dbInfo.file.exists()) return {};
    return _readDbRowsSync.thready(dbInfo);
  }

  static Map<String, Map<String, dynamic>> _readDbRowsSync(DbWrapperFileInfo dbInfo) {
    final rows = <String, Map<String, dynamic>>{};
    final db = DBWrapper.openFromInfoSync(fileInfo: dbInfo, config: const DBConfig(autoDisposeTimerDuration: null));
    db.loadEverythingKeyed((key, value) => rows[key] = value);
    db.close();
    return rows;
  }

  /// merges each db of the backup's copy of [liveDirPath] into the live one with the same name, returns whether any existed.
  Future<bool> _mergeDbsDirectory(String liveDirPath, _BackupDbConflict conflict) async {
    final backupDirPath = pathOf(liveDirPath);
    final pairs = <({File backup, DbWrapperFileInfo live})>[];
    const dbExtension = '.db';
    for (final f in Directory(backupDirPath).listSyncSafe()) {
      if (f is! File) continue;
      final filename = f.path.getFilename;
      if (!filename.endsWith(dbExtension)) continue;
      // -- not [DbWrapperFileInfo.fromFile], a default group db is named `.db` with an empty db name
      final dbName = filename.substring(0, filename.length - dbExtension.length);
      final liveInfo = DbWrapperFileInfo(directory: liveDirPath, dbName: dbName);
      pairs.add((backup: f, live: liveInfo));
    }
    if (pairs.isEmpty) return false;
    await _mergeDbsSync.thready((pairs: pairs, conflict: conflict));
    return true;
  }

  static void _mergeDbsSync(({List<({File backup, DbWrapperFileInfo live})> pairs, _BackupDbConflict conflict}) params) {
    const config = DBConfig(createIfNotExist: true, autoDisposeTimerDuration: null);
    for (final pair in params.pairs) {
      final liveInfo = pair.live;
      try {
        final db = DBWrapper.openFromInfoSync(fileInfo: liveInfo, config: config);
        final sql = db.sql;
        if (sql == null) continue;
        sql.execute('ATTACH DATABASE ? AS backup', [pair.backup.path]);
        try {
          final tables = sql.select("SELECT 1 FROM backup.sqlite_master WHERE type = 'table' AND name = ?", [liveInfo.dbName]);
          if (tables.isNotEmpty) {
            final command = params.conflict.buildMergeCommand(liveInfo.dbTableName);
            sql.execute(command);
          }
        } finally {
          sql.execute('DETACH DATABASE backup');
          db.close();
        }
      } catch (_) {}
    }
  }
}

/// in the order they run: settings first, files before the video dbs pointing to them,
/// and the tracks db last since reloading the library replaces what the others resolved against.
enum _BackupMergeStep {
  settings,
  trackStats,
  latestPlayed,
  audioConfigs,
  smartPlaylists,
  history,
  youtubeHistory,
  playlists,
  youtubePlaylists,
  youtubeIdStats,
  videosPriority,
  subscriptions,
  youtubeStats,
  downloadTasks,
  youtipieCache,
  listenTime,
  files,
  videosDbs,
  queues,
  tracksDb,
  ;
}

extension _AppPathsBackupEnumMerge on AppPathsBackupEnum {
  _BackupMergeStep toMergeStep() {
    return switch (this) {
      AppPathsBackupEnum.SETTINGS ||
      AppPathsBackupEnum.SETTINGS_EQUALIZER ||
      AppPathsBackupEnum.SETTINGS_PLAYER ||
      AppPathsBackupEnum.SETTINGS_YOUTUBE ||
      AppPathsBackupEnum.SETTINGS_EXTRA ||
      AppPathsBackupEnum.SETTINGS_SYNC ||
      AppPathsBackupEnum.SETTINGS_PARTY ||
      AppPathsBackupEnum.SETTINGS_TUTORIAL ||
      AppPathsBackupEnum.SETTINGS_SHORTCUTS => _BackupMergeStep.settings,
      AppPathsBackupEnum.TRACKS_STATS_DB_INFO || AppPathsBackupEnum.TRACKS_STATS_OLD => _BackupMergeStep.trackStats,
      AppPathsBackupEnum.LATEST_PLAYED_FOR_SOURCE => _BackupMergeStep.latestPlayed,
      AppPathsBackupEnum.AUDIO_CONFIGS => _BackupMergeStep.audioConfigs,
      AppPathsBackupEnum.SMART_PLAYLISTS => _BackupMergeStep.smartPlaylists,
      AppPathsBackupEnum.HISTORY_PLAYLIST => _BackupMergeStep.history,
      AppPathsBackupEnum.YT_HISTORY_PLAYLIST => _BackupMergeStep.youtubeHistory,
      AppPathsBackupEnum.PLAYLISTS || AppPathsBackupEnum.PLAYLISTS_METADATA || AppPathsBackupEnum.FAVOURITES_PLAYLIST => _BackupMergeStep.playlists,
      AppPathsBackupEnum.YT_PLAYLISTS || AppPathsBackupEnum.YT_PLAYLISTS_METADATA || AppPathsBackupEnum.YT_LIKES_PLAYLIST => _BackupMergeStep.youtubePlaylists,
      AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO => _BackupMergeStep.youtubeIdStats,
      AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY => _BackupMergeStep.videosPriority,
      AppPathsBackupEnum.YT_SUBSCRIPTIONS || AppPathsBackupEnum.YT_SUBSCRIPTIONS_GROUPS_ALL => _BackupMergeStep.subscriptions,
      AppPathsBackupEnum.YT_STATS => _BackupMergeStep.youtubeStats,
      AppPathsBackupEnum.YT_DOWNLOAD_TASKS => _BackupMergeStep.downloadTasks,
      AppPathsBackupEnum.YOUTIPIE_CACHE => _BackupMergeStep.youtipieCache,
      AppPathsBackupEnum.LISTEN_TIME_DAILY_DB_INFO || AppPathsBackupEnum.TOTAL_LISTEN_TIME => _BackupMergeStep.listenTime,
      AppPathsBackupEnum.PLAYLISTS_ARTWORKS ||
      AppPathsBackupEnum.SMART_PLAYLISTS_ARTWORKS ||
      AppPathsBackupEnum.ARTWORKS ||
      AppPathsBackupEnum.ARTWORKS_ARTISTS ||
      AppPathsBackupEnum.ARTWORKS_ALBUMS ||
      AppPathsBackupEnum.PALETTES ||
      AppPathsBackupEnum.VIDEOS_CACHE ||
      AppPathsBackupEnum.AUDIOS_CACHE ||
      AppPathsBackupEnum.THUMBNAILS ||
      AppPathsBackupEnum.LYRICS ||
      AppPathsBackupEnum.M3UBackup ||
      AppPathsBackupEnum.RECENTLY_DELETED ||
      AppPathsBackupEnum.YT_PLAYLISTS_ARTWORKS ||
      AppPathsBackupEnum.YT_THUMBNAILS ||
      AppPathsBackupEnum.YT_THUMBNAILS_CHANNELS ||
      AppPathsBackupEnum.YT_PALETTES => _BackupMergeStep.files,
      AppPathsBackupEnum.VIDEOS_LOCAL_DB_INFO ||
      AppPathsBackupEnum.VIDEOS_CACHE_DB_INFO ||
      AppPathsBackupEnum.VIDEOS_LOCAL_OLD ||
      AppPathsBackupEnum.VIDEOS_CACHE_OLD => _BackupMergeStep.videosDbs,
      AppPathsBackupEnum.QUEUES || AppPathsBackupEnum.LATEST_QUEUE => _BackupMergeStep.queues,
      AppPathsBackupEnum.TRACKS_DB_INFO || AppPathsBackupEnum.TRACKS_OLD => _BackupMergeStep.tracksDb,
    };
  }
}

enum _BackupDbConflict {
  backupWins,

  /// rows carry their write time and dummy flag, see [MapSerializable]. a dummy row never replaces a good one.
  newestGood,
  ;

  String buildMergeCommand(String table) {
    const insert = 'INSERT INTO main.';
    return switch (this) {
      _BackupDbConflict.backupWins => '$insert$table (key, value) SELECT key, value FROM backup.$table WHERE true ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      _BackupDbConflict.newestGood => _buildNewestGoodCommand(insert, table),
    };
  }

  static String _buildNewestGoodCommand(String insert, String table) {
    const dummyPath = "'\$.${MapSerializable.dummyKey}'";
    const timestampPath = "'\$.${MapSerializable.timestampKey}'";
    String rankOf(String value) => '(json_extract($value, $dummyPath) IS NULL, coalesce(json_extract($value, $timestampPath), 0))';
    final backupRank = rankOf('excluded.value');
    final liveRank = rankOf('live.value');
    return '$insert$table AS live (key, value) SELECT key, value FROM backup.$table WHERE true ON CONFLICT(key) DO UPDATE SET value = excluded.value WHERE $backupRank > $liveRank';
  }
}
