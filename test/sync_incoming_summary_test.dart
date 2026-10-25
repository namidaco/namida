// by claude
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/sync_manager/sync_manager.dart';

void main() {
  const deviceId = 'sender';
  const messageInfo = BaseMessageInfo(action: MessageActionType.add, senderDeviceId: deviceId);

  BatchInfoMessage batchInfo(String batchId, {required bool finished, bool isManual = true}) => BatchInfoMessage(
    messageInfo: messageInfo,
    batchId: batchId,
    progress: 0,
    total: 1,
    activeItems: const [],
    itemProgress: null,
    finished: finished,
    isManual: isManual,
  );

  BaseMessage settingsMessage() => const SettingsMessage(item: SyncDataItem.settingsGeneral, delta: {}, messageInfo: messageInfo);

  late List<List<int>> shown;
  late SyncIncomingSummary summary;

  setUp(() {
    shown = [];
    summary = SyncIncomingSummary.test((_, changedCounts) => shown.add(changedCounts));
  });

  int countOf(List<int> changedCounts, SyncDataItem item) => changedCounts[item.index];

  test('a manual batch shows once it finished and its messages got applied', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false));
    final applying = Completer<int>();
    summary.onMessageApplying(settingsMessage(), applying.future);
    summary.onBatchInfo(batchInfo('b1', finished: true));
    await pumpEventQueue();
    expect(shown, isEmpty, reason: 'still applying');

    applying.complete(3);
    await pumpEventQueue();
    expect(shown, hasLength(1));
    expect(countOf(shown.single, SyncDataItem.settingsGeneral), 3);
  });

  test('a manual batch that changed nothing still shows, with no changes', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false));
    summary.onMessageApplying(settingsMessage(), Future.value(0));
    summary.onBatchInfo(batchInfo('b1', finished: true));
    await pumpEventQueue();
    expect(shown, hasLength(1));
    expect(shown.single.every((count) => count == 0), isTrue);
  });

  test('an auto batch stays silent', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false, isManual: false));
    summary.onMessageApplying(settingsMessage(), Future.value(5));
    summary.onBatchInfo(batchInfo('b1', finished: true, isManual: false));
    await pumpEventQueue();
    expect(shown, isEmpty);
  });

  test('messages outside a batch are not counted', () async {
    summary.onMessageApplying(settingsMessage(), Future.value(5));
    summary.onBatchInfo(batchInfo('b1', finished: false));
    summary.onBatchInfo(batchInfo('b1', finished: true));
    await pumpEventQueue();
    expect(countOf(shown.single, SyncDataItem.settingsGeneral), 0);
  });

  test('overlapping manual batches merge into one summary after the last one ends', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false));
    summary.onBatchInfo(batchInfo('b2', finished: false));
    summary.onMessageApplying(settingsMessage(), Future.value(2));
    summary.onBatchInfo(batchInfo('b1', finished: true));
    await pumpEventQueue();
    expect(shown, isEmpty);

    summary.onMessageApplying(settingsMessage(), Future.value(4));
    summary.onBatchInfo(batchInfo('b2', finished: true));
    await pumpEventQueue();
    expect(countOf(shown.single, SyncDataItem.settingsGeneral), 6);
  });

  test('an auto batch ending does not end a manual one running next to it', () async {
    summary.onBatchInfo(batchInfo('auto', finished: false, isManual: false));
    summary.onBatchInfo(batchInfo('manual', finished: false));
    summary.onBatchInfo(batchInfo('auto', finished: true, isManual: false));
    await pumpEventQueue();
    expect(shown, isEmpty);

    summary.onBatchInfo(batchInfo('manual', finished: true));
    await pumpEventQueue();
    expect(shown, hasLength(1));
  });

  test('a manual batch starting while the last one still applies joins its summary', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false));
    final applying = Completer<int>();
    summary.onMessageApplying(settingsMessage(), applying.future);
    summary.onBatchInfo(batchInfo('b1', finished: true));
    summary.onBatchInfo(batchInfo('b2', finished: false));
    applying.complete(1);
    await pumpEventQueue();
    expect(shown, isEmpty);

    summary.onMessageApplying(settingsMessage(), Future.value(2));
    summary.onBatchInfo(batchInfo('b2', finished: true));
    await pumpEventQueue();
    expect(countOf(shown.single, SyncDataItem.settingsGeneral), 3);
  });

  test('a disconnect drops the summary even if messages finish applying later', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false));
    final applying = Completer<int>();
    summary.onMessageApplying(settingsMessage(), applying.future);
    summary.onBatchInfo(batchInfo('b1', finished: true));
    summary.clearForDevice(deviceId);
    applying.complete(3);
    await pumpEventQueue();
    expect(shown, isEmpty);
  });

  test('a new batch after a dropped one starts clean', () async {
    summary.onBatchInfo(batchInfo('b1', finished: false));
    final applying = Completer<int>();
    summary.onMessageApplying(settingsMessage(), applying.future);
    summary.clearForDevice(deviceId);

    summary.onBatchInfo(batchInfo('b2', finished: false));
    summary.onBatchInfo(batchInfo('b2', finished: true));
    applying.complete(3);
    await pumpEventQueue();
    expect(shown, hasLength(1));
    expect(countOf(shown.single, SyncDataItem.settingsGeneral), 0);
  });
}
