// built by claude code
part of 'sync_manager.dart';

/// points at a single item of a [SyncBatch]. small enough to ride along manifest
/// requests & responses (origin -> peer -> origin), so when a round trip lands
/// back on the origin, it can resolve the batch that started it.
///
/// [batch] only resolves on the device that created the batch, it's null everywhere else.
class SyncBatchRef {
  final String batchId;
  final SyncDataItem item;

  const SyncBatchRef(this.batchId, this.item);

  static SyncBatchRef? fromMap(Object? map) {
    if (map is! Map) return null;
    final item = SyncDataItem.lookupMap[map['i']];
    if (item == null) return null;
    final batchId = map['b'];
    if (batchId is! String) return null;
    return SyncBatchRef(batchId, item);
  }

  Map<String, dynamic> toMap() => {
    'b': batchId,
    'i': item.name,
  };

  SyncBatch? get batch => SyncBatch._alive[batchId];

  /// marks the item as the one currently transferring.
  void markTransferring() => batch?.markItemActive(item);

  void markDone() => batch?.markItemDone(item);

  void setProgress({required int count, required int totalCount, int bytes = 0, int totalBytes = 0}) {
    batch?._setItemProgress(item, count: count, totalCount: totalCount, bytes: bytes, totalBytes: totalBytes);
  }
}

/// sub-progress inside a single sync item, ex: files of a directory item or
/// entries of a db item. [bytes] & [totalBytes] are 0 when sizes aren't known.
class SyncItemProgress {
  final SyncDataItem item;
  final int count;
  final int totalCount;
  final int bytes;
  final int totalBytes;

  const SyncItemProgress({
    required this.item,
    required this.count,
    required this.totalCount,
    required this.bytes,
    required this.totalBytes,
  });

  static SyncItemProgress? fromList(Object? list) {
    if (list is! List || list.length < 5) return null;
    final item = SyncDataItem.lookupMap[list[0]];
    if (item == null) return null;
    return SyncItemProgress(
      item: item,
      count: list[1] as int,
      totalCount: list[2] as int,
      bytes: list[3] as int,
      totalBytes: list[4] as int,
    );
  }

  List<Object> toList() => [item.name, count, totalCount, bytes, totalBytes];

  /// 0..1 of this item alone, null when it can't be told.
  double? get fraction {
    if (totalBytes > 0) return (bytes / totalBytes).clampDouble(0.0, 1.0);
    if (totalCount > 0) return (count / totalCount).clampDouble(0.0, 1.0);
    return null;
  }
}

/// progress tracker of one [SyncSender.sendItemsToDevice] run.
///
/// items don't complete in order: manifest-based ones (dir files, db entries,
/// playlists) only finish after a request/response round trip, while plain data
/// items finish inline. so progress is the *set* of completed items instead of a
/// running index, and only the origin device ever computes it.
///
/// the peer never reconstructs anything, it just renders the last
/// [BatchInfoMessage] snapshot it received. snapshots travel on the same socket
/// so they always arrive in order, which is what makes out-of-order completion
/// a non-issue.
class SyncBatch {
  /// batches created by us & still running, keyed by [id]. see [SyncBatchRef.batch].
  static final _alive = <String, SyncBatch>{};
  static int _idCounter = 0;

  /// snapshots are throttled to this while an item reports sub-progress,
  /// item start/finish always send immediately.
  static const _kMinSendIntervalMS = 200;

  /// a batch that got no update for this long is considered dead & gets
  /// finalized, so a peer that went silent mid round trip can't hang it forever.
  static const _kInactivityTimeout = Duration(minutes: 2);

  final String id;
  final String deviceId;
  final List<SyncDataItem> items;
  final BaseMessageInfo _messageInfo;

  final _doneItems = <SyncDataItem>{};

  /// insertion ordered, the last one is the item currently transferring.
  final _activeItems = <SyncDataItem>{};

  SyncItemProgress? _itemProgress;
  bool _finished = false;

  final _completer = Completer<void>();

  /// completes once every item finished, or the batch got aborted.
  Future<void> get completion => _completer.future;

  SyncBatch._({
    required this.id,
    required this.deviceId,
    required this.items,
    required this._messageInfo,
  });

  static Future<SyncBatch> start(String deviceId, List<SyncDataItem> items) async {
    final messageInfo = await SyncUtils.createMessageInfo(.manifest);
    final batch = SyncBatch._(
      id: '${messageInfo.senderDeviceId}_${currentTimeMS}_${_idCounter++}',
      deviceId: deviceId,
      // -- progress is a done-set, a duplicated item would make it never reach the total
      items: items.toSet().toFixedList(),
      messageInfo: messageInfo,
    );
    _alive[batch.id] = batch;
    batch._notify(force: true);
    return batch;
  }

  /// batches we started towards [deviceId], ex: it just disconnected.
  static void abortForDevice(String deviceId) {
    final toAbort = _alive.values.where((e) => e.deviceId == deviceId).toFixedList();
    toAbort.loop((batch) => batch.finish(notifyPeer: false));
  }

  SyncBatchRef refFor(SyncDataItem item) => SyncBatchRef(id, item);

  void markItemActive(SyncDataItem item) {
    if (_finished) return;
    // -- re-inserted so it becomes the last (== currently transferring) one
    _activeItems.remove(item);
    _activeItems.add(item);
    _notify(force: true);
  }

  void markItemDone(SyncDataItem item) {
    if (_finished) return;
    _activeItems.remove(item);
    if (_itemProgress?.item == item) _itemProgress = null;
    if (!_doneItems.add(item)) return; // -- already counted
    if (_doneItems.length >= items.length) return finish();
    _notify(force: true);
  }

  void _setItemProgress(SyncDataItem item, {required int count, required int totalCount, required int bytes, required int totalBytes}) {
    if (_finished) return;
    _itemProgress = SyncItemProgress(item: item, count: count, totalCount: totalCount, bytes: bytes, totalBytes: totalBytes);
    _notify();
  }

  /// finalizes the batch, hiding it here & on the peer.
  void finish({bool notifyPeer = true}) {
    if (_finished) return;
    _finished = true;
    _alive.remove(id);
    _activeItems.clear();
    _itemProgress = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _queuedSnapshot = null;

    // -- another batch towards the same device could have taken over the slot
    if (SyncDiscovery.batchProgressOutgoingRx[deviceId]?.batchId == id) SyncDiscovery.batchProgressOutgoingRx[deviceId] = null;
    if (notifyPeer) _send(_buildSnapshot());

    if (!_completer.isCompleted) _completer.complete();
  }

  BatchInfoMessage _buildSnapshot() => BatchInfoMessage(
    messageInfo: _messageInfo,
    batchId: id,
    progress: _doneItems.length,
    total: items.length,
    activeItems: _activeItems.toFixedList(),
    itemProgress: _itemProgress,
    finished: _finished,
  );

  // ==================== notifying ====================

  Timer? _inactivityTimer;
  Timer? _throttleTimer;
  int _lastPushMS = 0;

  void _notify({bool force = false}) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_kInactivityTimeout, () => finish(notifyPeer: false));

    if (force) {
      _throttleTimer?.cancel();
      _throttleTimer = null;
      _push();
      return;
    }

    if (_throttleTimer != null) return; // -- a push is already scheduled, it will carry the latest state
    final remainingMS = _kMinSendIntervalMS - (currentTimeMS - _lastPushMS);
    if (remainingMS <= 0) {
      _push();
    } else {
      _throttleTimer = Timer(Duration(milliseconds: remainingMS), () {
        _throttleTimer = null;
        if (!_finished) _push();
      });
    }
  }

  void _push() {
    _lastPushMS = currentTimeMS;
    final snapshot = _buildSnapshot();
    SyncDiscovery.batchProgressOutgoingRx[deviceId] = snapshot;
    _send(snapshot);
  }

  bool _sendInFlight = false;
  BatchInfoMessage? _queuedSnapshot;

  /// fire & forget, only the latest snapshot is worth sending so older
  /// ones get dropped instead of queuing up behind a slow socket.
  void _send(BatchInfoMessage snapshot) {
    if (_sendInFlight) {
      _queuedSnapshot = snapshot;
      return;
    }
    _sendInFlight = true;
    unawaited(
      SyncDiscovery.sendMessage(snapshot, deviceId).catchError((_) {}).whenComplete(() {
        _sendInFlight = false;
        final queued = _queuedSnapshot;
        if (queued != null) {
          _queuedSnapshot = null;
          _send(queued);
        }
      }),
    );
  }
}
