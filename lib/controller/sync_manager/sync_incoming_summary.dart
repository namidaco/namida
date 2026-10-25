// by claude
part of 'sync_manager.dart';

/// collects what the manual batches of a device changed here, and shows one summary snackbar
/// once all of them ended & everything they carried got applied. auto syncs are not tracked at all.
class SyncIncomingSummary {
  static final inst = SyncIncomingSummary._(_showSnackbar);
  SyncIncomingSummary._(this._onManualSummary);

  /// [_onManualSummary] replaces the snackbar.
  @visibleForTesting
  SyncIncomingSummary.test(this._onManualSummary);

  /// [changedCounts] is indexed by [SyncDataItem.index].
  final void Function(String deviceId, List<int> changedCounts) _onManualSummary;

  final _summaryByDevice = <String, _IncomingSummary>{};

  void onBatchInfo(BatchInfoMessage info) {
    final deviceId = info.messageInfo.senderDeviceId;
    if (!info.finished) {
      if (!info.isManual) return;
      final summary = _summaryByDevice[deviceId] ??= _IncomingSummary();
      summary.openBatchIds.add(info.batchId);
      return;
    }
    final summary = _summaryByDevice[deviceId];
    if (summary == null) return;
    summary.openBatchIds.remove(info.batchId);
    _showIfDone(deviceId, summary);
  }

  /// [applying] completes with how many entries [msg] changed. messages outside a manual batch are ignored.
  void onMessageApplying(BaseMessage msg, Future<int> applying) {
    final deviceId = msg.messageInfo.senderDeviceId;
    final summary = _summaryByDevice[deviceId];
    if (summary == null) return;
    final item = msg._toSyncItem();
    if (item == null) return;
    summary.applyingCount++;
    _addWhenApplied(deviceId, summary, item, applying);
  }

  void clearForDevice(String deviceId) => _summaryByDevice.remove(deviceId);

  Future<void> _addWhenApplied(String deviceId, _IncomingSummary summary, SyncDataItem item, Future<int> applying) async {
    final changedCount = await applying;
    summary.applyingCount--;
    summary.changedCounts[item.index] += changedCount;
    _showIfDone(deviceId, summary);
  }

  void _showIfDone(String deviceId, _IncomingSummary summary) {
    if (summary.openBatchIds.isNotEmpty || summary.applyingCount > 0) return;
    if (!identical(_summaryByDevice[deviceId], summary)) return; // -- dropped meanwhile, ex: disconnected
    _summaryByDevice.remove(deviceId);
    _onManualSummary(deviceId, summary.changedCounts);
  }

  static void _showSnackbar(String deviceId, List<int> changedCounts) {
    final deviceName = settings.sync.deviceIdNames.value[deviceId] ?? deviceId;
    final changeTexts = SyncDataItem.values.where((item) => changedCounts[item.index] > 0).map((item) => _changeText(item, changedCounts[item.index])).toFixedList();
    final message = changeTexts.isEmpty ? lang.noChangesFound : changeTexts.join(', ');
    snackyy(
      icon: Broken.cloud_change,
      title: '${lang.synced} - $deviceName',
      message: message,
      isError: false,
      borderColor: Colors.green.withOpacityExt(0.25),
    );
  }

  static String _changeText(SyncDataItem item, int changedCount) {
    final itemText = item.toText();
    if (item.isPlaybackTakeover) return itemText;
    return '$itemText +${changedCount.formatDecimalShort()}';
  }
}

class _IncomingSummary {
  /// manual batches that started but didn't end yet, several can overlap.
  final openBatchIds = <String>{};

  int applyingCount = 0;

  /// indexed by [SyncDataItem.index].
  final changedCounts = List<int>.filled(SyncDataItem.values.length, 0);
}
