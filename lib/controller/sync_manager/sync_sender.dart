part of 'sync_manager.dart';

enum SyncDataItem {
  history(needsFingerprints: true, isHeavy: false),
  historyYt(needsFingerprints: false, isHeavy: false),
  playlists(needsFingerprints: true, isHeavy: false),
  playlistsYt(needsFingerprints: false, isHeavy: false),
  favourites(needsFingerprints: true, isHeavy: false),
  favouritesYt(needsFingerprints: false, isHeavy: false),
  stats(needsFingerprints: true, isHeavy: false),
  statsYt(needsFingerprints: false, isHeavy: false),
  latestPlayedForSource(needsFingerprints: true, isHeavy: false),
  audioConfigs(needsFingerprints: true, isHeavy: false),
  smartPlaylists(needsFingerprints: false, isHeavy: false),
  videosPriority(needsFingerprints: false, isHeavy: false),
  subscriptionsYt(needsFingerprints: false, isHeavy: false),
  queues(needsFingerprints: false, isHeavy: false),
  lyrics(needsFingerprints: false, isHeavy: true),
  videosCache(needsFingerprints: false, isHeavy: true),
  audiosCache(needsFingerprints: false, isHeavy: true),
  playlistsArtworks(needsFingerprints: false, isHeavy: true),
  smartPlaylistsArtworks(needsFingerprints: false, isHeavy: true),
  playlistsArtworksYt(needsFingerprints: false, isHeavy: true),
  artworksArtists(needsFingerprints: false, isHeavy: true),
  artworksAlbums(needsFingerprints: false, isHeavy: true),
  thumbnailsYt(needsFingerprints: false, isHeavy: true),
  thumbnailsChannelsYt(needsFingerprints: false, isHeavy: true),
  playerQueue(needsFingerprints: true, isHeavy: false),
  playback(needsFingerprints: false, isHeavy: false),
  ;

  /// wether local track paths get sent over, requiring our tracks db
  /// fingerprints to be sent beforehand so the receiver can translate them.
  final bool needsFingerprints;

  /// wether sending this item could be slow or affect performance
  /// (dir-based items loop all their files & can carry lots of data).
  final bool isHeavy;

  const SyncDataItem({
    required this.needsFingerprints,
    required this.isHeavy,
  });

  /// default items to sync. file-based items (except queues) are excluded,
  /// they have no cache map so building their manifests loops all files.
  /// playerQueue & playback are excluded too, they take over live playback.
  static final Set<SyncDataItem> essentialsSet =
      {
          ...SyncDataItem.values,
        }
        ..remove(SyncDataItem.lyrics)
        ..remove(SyncDataItem.videosCache)
        ..remove(SyncDataItem.audiosCache)
        ..remove(SyncDataItem.playlistsArtworks)
        ..remove(SyncDataItem.smartPlaylistsArtworks)
        ..remove(SyncDataItem.playlistsArtworksYt)
        ..remove(SyncDataItem.artworksArtists)
        ..remove(SyncDataItem.artworksAlbums)
        ..remove(SyncDataItem.thumbnailsYt)
        ..remove(SyncDataItem.thumbnailsChannelsYt)
        ..remove(SyncDataItem.playerQueue)
        ..remove(SyncDataItem.playback);

  static final lookupMap = values.asNameMap();

  List<AppPathsBackupEnum> get backupPaths => switch (this) {
    SyncDataItem.history => const [AppPathsBackupEnum.HISTORY_PLAYLIST],
    SyncDataItem.historyYt => const [AppPathsBackupEnum.YT_HISTORY_PLAYLIST],
    SyncDataItem.playlists => const [AppPathsBackupEnum.PLAYLISTS],
    SyncDataItem.playlistsYt => const [AppPathsBackupEnum.YT_PLAYLISTS],
    SyncDataItem.favourites => const [AppPathsBackupEnum.FAVOURITES_PLAYLIST],
    SyncDataItem.favouritesYt => const [AppPathsBackupEnum.YT_LIKES_PLAYLIST],
    SyncDataItem.stats => const [AppPathsBackupEnum.TRACKS_STATS_DB_INFO],
    SyncDataItem.statsYt => const [AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO],
    SyncDataItem.latestPlayedForSource => const [AppPathsBackupEnum.LATEST_PLAYED_FOR_SOURCE],
    SyncDataItem.audioConfigs => const [AppPathsBackupEnum.AUDIO_CONFIGS],
    SyncDataItem.smartPlaylists => const [AppPathsBackupEnum.SMART_PLAYLISTS],
    SyncDataItem.videosPriority => const [AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY],
    SyncDataItem.subscriptionsYt => const [AppPathsBackupEnum.YT_SUBSCRIPTIONS, AppPathsBackupEnum.YT_SUBSCRIPTIONS_GROUPS_ALL],
    SyncDataItem.queues => const [AppPathsBackupEnum.QUEUES],
    SyncDataItem.lyrics => const [AppPathsBackupEnum.LYRICS],
    SyncDataItem.videosCache => const [AppPathsBackupEnum.VIDEOS_CACHE, AppPathsBackupEnum.VIDEOS_CACHE_DB_INFO],
    SyncDataItem.audiosCache => const [AppPathsBackupEnum.AUDIOS_CACHE],
    SyncDataItem.playlistsArtworks => const [AppPathsBackupEnum.PLAYLISTS_ARTWORKS],
    SyncDataItem.smartPlaylistsArtworks => const [AppPathsBackupEnum.SMART_PLAYLISTS_ARTWORKS],
    SyncDataItem.playlistsArtworksYt => const [AppPathsBackupEnum.YT_PLAYLISTS_ARTWORKS],
    SyncDataItem.artworksArtists => const [AppPathsBackupEnum.ARTWORKS_ARTISTS],
    SyncDataItem.artworksAlbums => const [AppPathsBackupEnum.ARTWORKS_ALBUMS],
    SyncDataItem.thumbnailsYt => const [AppPathsBackupEnum.YT_THUMBNAILS],
    SyncDataItem.thumbnailsChannelsYt => const [AppPathsBackupEnum.YT_THUMBNAILS_CHANNELS],
    SyncDataItem.playerQueue => const [AppPathsBackupEnum.LATEST_QUEUE],
    SyncDataItem.playback => const [],
  };
}

class SyncSender extends RxNotifier {
  static final inst = SyncSender._();
  SyncSender._();

  final _fingerprintsSentTo = <String>{};
  final _sendingToDeviceIds = <String>{};

  bool isSendingTo(String deviceId) => _sendingToDeviceIds.contains(deviceId);
  bool get isSendingAny => _sendingToDeviceIds.isNotEmpty;

  void _refresh() => super.refresh();

  void onDeviceDisconnected(String deviceId) {
    _fingerprintsSentTo.remove(deviceId);
    SyncPathResolver.clearForDevice(deviceId);
    SyncActionsLog.inst.onDeviceDisconnected(deviceId);

    // -- just extra
    SyncDiscovery.batchProgressForDeviceIdRx[deviceId] = null;
  }

  /// sends local tracks db fingerprints once per connection, so the receiver
  /// can translate our paths into theirs. see [SyncPathResolver].
  Future<void> ensureFingerprintsSent(String deviceId) async {
    if (_fingerprintsSentTo.contains(deviceId)) return;
    await resendFingerprints(deviceId);
  }

  Future<void> resendFingerprints(String deviceId) async {
    _fingerprintsSentTo.add(deviceId);
    try {
      final msg = await TracksDbFingerprintsMessage.createForCurrentDevice();
      await SyncDiscovery.sendMessage(msg, deviceId);
    } catch (_) {
      _fingerprintsSentTo.remove(deviceId);
      rethrow;
    }
  }

  Future<void> sendItemsToAllConnected(List<SyncDataItem> items) async {
    final deviceIds = SyncDiscovery.getAllConnectedDeviceIdsSet();
    for (final deviceId in deviceIds) {
      await sendItemsToDevice(items, deviceId);
    }
  }

  /// asks [deviceId] to send us [items], see [SyncItemsRequestMessage].
  Future<void> requestItemsFromDevice(List<SyncDataItem> items, String deviceId) async {
    if (items.isEmpty) return;
    try {
      final msg = await SyncItemsRequestMessage.createForCurrentDevice(items);
      await SyncDiscovery.sendMessage(msg, deviceId);
    } catch (e, st) {
      final deviceName = settings.sync.deviceIdNames[deviceId] ?? deviceId;
      snackyy(message: '${lang.failed}: "$deviceName": $e', isError: true);
      logger.error('Error requesting items from "$deviceName"', e: e, st: st);
    }
  }

  /// both directions: requests [items] from the device first (so their sending
  /// overlaps ours), then sends our [items] to them.
  Future<void> syncWithDevice(List<SyncDataItem> items, String deviceId) async {
    await requestItemsFromDevice(items, deviceId);
    await sendItemsToDevice(items, deviceId);
  }

  // ==================== auto sync ====================

  Timer? _autoSyncTimer;

  void setupAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    final intervalMinutes = settings.sync.autoSyncIntervalMinutes.valueF;
    if (intervalMinutes <= 0) return;
    _autoSyncTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) => _autoSyncTick());
  }

  Future<void> _autoSyncTick() async {
    final deviceIds = SyncDiscovery.getAllConnectedDeviceIdsSet();
    if (deviceIds.isEmpty) return;
    final syncItems = settings.sync.syncItems.valueF;
    final items = SyncDataItem.values.where(syncItems.contains).toList();
    if (items.isEmpty) return;
    for (final deviceId in deviceIds) {
      if (isSendingTo(deviceId)) continue; // -- a manual send is already running
      await syncWithDevice(items, deviceId);
    }
  }

  Future<void> sendItemsToDevice(List<SyncDataItem> items, String deviceId) async {
    if (items.isEmpty) return;
    _sendingToDeviceIds.add(deviceId);
    _refresh();
    int itemProgress = 1;
    final totalItemsCount = items.length;
    final batchInfoMsgInfo = await SyncUtils.createMessageInfo(.manifest);
    try {
      for (final item in items) {
        // -- send batch info before actual info
        final batchInfo = BatchInfoMessage(
          messageInfo: batchInfoMsgInfo,
          progressItem: item,
          progress: itemProgress,
          total: totalItemsCount,
        );
        await SyncDiscovery.sendAndUpdateBatchProgress(deviceId, batchInfo);

        await _sendItem(item, deviceId, batchInfo);

        itemProgress++;
      }
      await SyncDiscovery.sendAndUpdateBatchProgress(deviceId, BatchInfoMessage.dummy(batchInfoMsgInfo));
    } catch (e, st) {
      final deviceName = settings.sync.deviceIdNames[deviceId] ?? deviceId;
      snackyy(message: '${lang.failed}: "$deviceName": $e', isError: true);
      logger.error('Error sending to "$deviceName"', e: e, st: st);
      try {
        await SyncDiscovery.sendAndUpdateBatchProgress(deviceId, BatchInfoMessage.dummy(batchInfoMsgInfo));
      } catch (_) {}
    } finally {
      _sendingToDeviceIds.remove(deviceId);
      _refresh();
    }
  }

  Future<void> _sendItem(SyncDataItem item, String deviceId, BatchInfoMessage batchInfoMessage) async {
    final BaseMessage? msg = switch (item) {
      SyncDataItem.history => HistoryListensMessage(
        tracks: HistoryController.inst.historyTracks,
        messageInfo: await SyncUtils.createMessageInfo(.add),
      ),
      SyncDataItem.historyYt => YTHistoryListensMessage(
        videos: YoutubeHistoryController.inst.historyTracks,
        messageInfo: await SyncUtils.createMessageInfo(.add),
      ),
      SyncDataItem.playlists => RequestMessage(
        msgRequestType: .playlistsManifest,
        messageInfo: await SyncUtils.createMessageInfo(.manifest),
      ),
      SyncDataItem.playlistsYt => RequestMessage(
        msgRequestType: .ytPlaylistsManifest,
        messageInfo: await SyncUtils.createMessageInfo(.manifest),
      ),
      SyncDataItem.favourites => FavouritesMessage(
        tracks: PlaylistController.inst.favouritesPlaylist.value.tracks,
        messageInfo: await SyncUtils.createMessageInfo(.add),
      ),
      SyncDataItem.favouritesYt => YTLikesMessage(
        videos: YoutubePlaylistController.inst.favouritesPlaylist.value.tracks,
        messageInfo: await SyncUtils.createMessageInfo(.add),
      ),
      SyncDataItem.stats => await TrackStatsMessage.createForCurrentDevice(),
      SyncDataItem.statsYt =>
        SyncUtils.kUseDbEntriesSync
            ? await DbManifestRequestMessage.create(AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO)
            : await DbFileMessage.create(AppPathsBackupEnum.VIDEO_ID_STATS_DB_INFO),
      SyncDataItem.latestPlayedForSource => await LatestPlayedForSourceMessage.createForCurrentDevice(),
      SyncDataItem.audioConfigs => await AudioConfigsMessage.createForCurrentDevice(),
      SyncDataItem.smartPlaylists => await SmartPlaylistsMessage.createForCurrentDevice(),
      SyncDataItem.videosPriority =>
        SyncUtils.kUseDbEntriesSync
            ? await DbManifestRequestMessage.create(AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY)
            : await DbFileMessage.create(AppPathsBackupEnum.CACHE_VIDEOS_PRIORITY),
      SyncDataItem.subscriptionsYt => await YTSubscriptionsMessage.createForCurrentDevice(),
      SyncDataItem.queues => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.QUEUES, batchInfoMessage),
      SyncDataItem.lyrics => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.LYRICS, batchInfoMessage),
      SyncDataItem.videosCache => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.VIDEOS_CACHE, batchInfoMessage),
      SyncDataItem.audiosCache => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.AUDIOS_CACHE, batchInfoMessage),
      SyncDataItem.playlistsArtworks => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.PLAYLISTS_ARTWORKS, batchInfoMessage),
      SyncDataItem.smartPlaylistsArtworks => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.SMART_PLAYLISTS_ARTWORKS, batchInfoMessage),
      SyncDataItem.playlistsArtworksYt => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.YT_PLAYLISTS_ARTWORKS, batchInfoMessage),
      SyncDataItem.artworksArtists => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.ARTWORKS_ARTISTS, batchInfoMessage),
      SyncDataItem.artworksAlbums => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.ARTWORKS_ALBUMS, batchInfoMessage),
      SyncDataItem.thumbnailsYt => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.YT_THUMBNAILS, batchInfoMessage),
      SyncDataItem.thumbnailsChannelsYt => await DirFilesManifestRequestMessage.create(AppPathsBackupEnum.YT_THUMBNAILS_CHANNELS, batchInfoMessage),
      SyncDataItem.playerQueue => await PlayerQueueMessage.createForCurrentDevice(),
      SyncDataItem.playback => await PlaybackStateMessage.createForCurrentDevice(),
    };

    if (msg == null) return; // -- nothing to send (ex: no latest queue)

    if (item.needsFingerprints) await ensureFingerprintsSent(deviceId);

    await SyncDiscovery.sendMessage(msg, deviceId);

    // -- companion messages
    if (item == SyncDataItem.subscriptionsYt) {
      final groupsMsg = await YTSubscriptionsGroupsMessage.createForCurrentDevice();
      await SyncDiscovery.sendMessage(groupsMsg, deviceId);
    }
  }
}
