/// built by claude code
part of 'sync_manager.dart';

enum SyncActionType { sent, received }

enum SyncActionStatus { inProgress, success, failed }

class SyncActionEntry {
  final SyncActionType type;
  final String deviceId;
  final int timeMS;

  /// distinct items this transfer carried, for display. internal
  /// transfers (like tracks db fingerprints) don't get tagged.
  final items = <SyncDataItem>{};

  int sizeBytes = 0;
  int count = 0;
  int lastActivityMS;
  SyncActionStatus status = SyncActionStatus.inProgress;

  SyncActionEntry({
    required this.type,
    required this.deviceId,
    required this.timeMS,
  }) : lastActivityMS = timeMS;
}

/// in-memory log of recent sync transfers. messages flowing rapidly to/from the
/// same device get merged into a single entry (ex: dir files arriving one by one),
/// which completes as successful after a short quiet period with no activity.
class SyncActionsLog extends RxNotifier {
  static final inst = SyncActionsLog._();
  SyncActionsLog._();

  static const _kMaxEntries = 100;
  static const _kShrinkBlock = 10;
  static const _kQuietPeriodToCompleteMS = 4000;
  static const _kMinRefreshInterval = Duration(milliseconds: 200);

  final entries = <SyncActionEntry>[];

  final _activeEntries = <(SyncActionType, String), SyncActionEntry>{};

  Timer? _sweepTimer;

  int _lastRefreshMS = 0;
  Timer? _refreshTimer;

  /// [isExtraPayload] marks bytes belonging to an already counted message
  /// (like binary payload frames), so only the size gets accumulated.
  void onMessageActivity(SyncActionType type, BaseMessage message, String deviceId, int sizeBytes, {bool isExtraPayload = false}) {
    if (!message.type.isDataTransfer) return;
    final key = (type, deviceId);
    var entry = _activeEntries[key];
    if (entry == null) {
      entry = _addNewEntry(type, deviceId);
      _activeEntries[key] = entry;
      _ensureSweepTimer();
    }
    final item = _itemOfMessage(message);
    if (item != null) entry.items.add(item);
    entry.sizeBytes += sizeBytes;
    if (!isExtraPayload) entry.count++;
    entry.status = SyncActionStatus.inProgress;
    entry.lastActivityMS = currentTimeMS;
    _refreshThrottled();
  }

  static final _itemBySubtype = <AppPathsBackupEnum, SyncDataItem>{
    for (final item in SyncDataItem.values)
      for (final subtype in item.backupPaths) subtype: item,
  };

  /// the sync item a message belongs to, null for internal transfers.
  static SyncDataItem? _itemOfMessage(BaseMessage message) {
    return switch (message) {
      DirFileMessage m => _itemBySubtype[m.subtype],
      DbFileMessage m => _itemBySubtype[m.subtype],
      DbEntriesMessage m => _itemBySubtype[m.subtype],
      HistoryListensMessage() => SyncDataItem.history,
      YTHistoryListensMessage() => SyncDataItem.historyYt,
      PlaylistsMessage() => SyncDataItem.playlists,
      YTPlaylistsMessage() => SyncDataItem.playlistsYt,
      FavouritesMessage() => SyncDataItem.favourites,
      YTLikesMessage() => SyncDataItem.favouritesYt,
      TrackStatsMessage() => SyncDataItem.stats,
      LatestPlayedForSourceMessage() => SyncDataItem.latestPlayedForSource,
      PlayerQueueMessage() => SyncDataItem.playerQueue,
      PlaybackStateMessage() => SyncDataItem.playback,
      AudioConfigsMessage() => SyncDataItem.audioConfigs,
      SmartPlaylistsMessage() => SyncDataItem.smartPlaylists,
      YTSubscriptionsMessage() || YTSubscriptionsGroupsMessage() => SyncDataItem.subscriptionsYt,
      PingMessage() ||
      ConnectionRequestMessage() ||
      RequestMessage() ||
      BatchInfoMessage() ||
      SyncItemsRequestMessage() ||
      TracksDbFingerprintsMessage() ||
      PlaylistsManifestResponseMessage() ||
      YTPlaylistsManifestResponseMessage() ||
      DirFilesManifestRequestMessage() ||
      DirFilesManifestResponseMessage() ||
      DbManifestRequestMessage() ||
      DbManifestResponseMessage() ||
      BinaryPayloadMessage() => null,
    };
  }

  void markFailed(SyncActionType type, String deviceId) {
    final key = (type, deviceId);
    if (_activeEntries[key] == null) {
      // -- failed before any activity got logged, add an entry so the failure is visible
      _addNewEntry(type, deviceId).status = SyncActionStatus.failed;
      _refreshThrottled();
      return;
    }
    _complete(key, SyncActionStatus.failed);
  }

  /// connection dropped, anything still in progress with this device has failed.
  void onDeviceDisconnected(String deviceId) {
    _complete((SyncActionType.sent, deviceId), SyncActionStatus.failed);
    _complete((SyncActionType.received, deviceId), SyncActionStatus.failed);
  }

  SyncActionEntry _addNewEntry(SyncActionType type, String deviceId) {
    final entry = SyncActionEntry(type: type, deviceId: deviceId, timeMS: currentTimeMS);
    entries.add(entry);
    _ensureListTrimmed();
    return entry;
  }

  void _ensureListTrimmed() {
    if (entries.length >= _kMaxEntries + _kShrinkBlock) {
      for (int i = 0; i < _kShrinkBlock; i++) {
        final removed = entries[i];
        final removedKey = (removed.type, removed.deviceId);
        if (identical(_activeEntries[removedKey], removed)) _activeEntries.remove(removedKey);
      }
      entries.removeRange(0, _kShrinkBlock);
    }
  }

  void _complete((SyncActionType, String) key, SyncActionStatus status) {
    final entry = _activeEntries.remove(key);
    if (entry == null) return;
    entry.status = status;
    if (_activeEntries.isEmpty) _stopSweepTimer();
    _refreshThrottled();
  }

  void _ensureSweepTimer() {
    _sweepTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _sweep());
  }

  void _stopSweepTimer() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  void _sweep() {
    final now = currentTimeMS;
    bool anyCompleted = false;
    _activeEntries.removeWhere((key, entry) {
      if (now - entry.lastActivityMS >= _kQuietPeriodToCompleteMS) {
        entry.status = SyncActionStatus.success;
        anyCompleted = true;
        return true;
      }
      return false;
    });
    if (_activeEntries.isEmpty) _stopSweepTimer();
    if (anyCompleted) _refreshThrottled();
  }

  void _refreshThrottled() {
    final now = currentTimeMS;
    if (now - _lastRefreshMS >= _kMinRefreshInterval.inMilliseconds) {
      _lastRefreshMS = now;
      refresh();
    } else {
      _refreshTimer ??= Timer(_kMinRefreshInterval, () {
        _refreshTimer = null;
        _lastRefreshMS = currentTimeMS;
        refresh();
      });
    }
  }
}
