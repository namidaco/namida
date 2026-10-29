// by claude
import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/controller/search_ports_provider.dart';
import 'package:namida/core/enums.dart';

void main() {
  const tempAbc = (text: 'abc', temp: true, isVideo: null);
  const tabX = (text: 'x', temp: false, isVideo: null);

  test('request waiting on a starting port is sent to the reopened one', () async {
    final provider = _FakeSearchPortsProvider();
    final firstPortGate = provider.preparedGate = Completer<void>();
    provider.request(MediaType.track, tempAbc);
    await pumpEventQueue();

    provider.preparedGate = null;
    provider.refreshPortsIfNecessary();
    firstPortGate.complete();
    await pumpEventQueue();

    expect(provider.received, [(2, tempAbc)]);
  });

  test('only the newest request of each kind is sent once the port is ready', () async {
    final provider = _FakeSearchPortsProvider();
    final gate = provider.preparedGate = Completer<void>();
    provider.request(MediaType.track, (text: 'a', temp: true, isVideo: null));
    provider.request(MediaType.track, tabX);
    provider.request(MediaType.track, tempAbc);
    gate.complete();
    await pumpEventQueue();

    expect(provider.received, unorderedEquals([(1, tempAbc), (1, tabX)]));
  });

  test('reopen sends the latest global and tab requests again, without closePorts()', () async {
    final provider = _FakeSearchPortsProvider();
    provider.request(MediaType.track, tempAbc);
    provider.request(MediaType.track, tabX);
    await pumpEventQueue();

    provider.refreshPortsIfNecessary();
    await pumpEventQueue();

    expect(provider.received, unorderedEquals([(1, tempAbc), (1, tabX), (2, tempAbc), (2, tabX)]));
    expect(provider.closePortsCount, 0);
  });

  test('disposing drops pending requests', () async {
    final provider = _FakeSearchPortsProvider();
    final gate = provider.preparedGate = Completer<void>();
    provider.request(MediaType.track, tempAbc);
    await pumpEventQueue();

    await provider.dispose();
    gate.complete();
    provider.refreshPortsIfNecessary();
    await pumpEventQueue();

    expect(provider.received, isEmpty);
  });
}

/// each port is a [ReceivePort] in the test isolate, recording what it got along with its spawn number.
class _FakeSearchPortsProvider extends SearchPortsProvider {
  final received = <(int, SearchRequest)>[];
  int spawnedCount = 0;

  /// delays the next ports from reporting ready, like a slow isolate startup.
  Completer<void>? preparedGate;

  void request(MediaType type, SearchRequest request) {
    final prepareFn = mediaTypeToPrepareFn(type);
    sendRequest(type, prepareFn(), request);
  }

  Future<void> dispose() => disposeAll();

  int closePortsCount = 0;

  @override
  Future<void> closePorts(MediaType type) {
    closePortsCount++;
    return super.closePorts(type);
  }

  @override
  Future<SendPort?> Function() mediaTypeToPrepareFn(MediaType type) {
    return () => preparePorts(
      type: type,
      onResult: (_) {},
      isolateFunction: (itemsSendPort) async {
        final portNumber = ++spawnedCount;
        final requestsPort = ReceivePort();
        requestsPort.listen((p) {
          if (p == PortsProviderMessages.disposed) {
            requestsPort.close();
            return;
          }
          received.add((portNumber, p as SearchRequest));
        });
        itemsSendPort.send(requestsPort.sendPort);
        final gate = preparedGate;
        if (gate == null) {
          itemsSendPort.send(PortsProviderMessages.prepared);
        } else {
          gate.future.then((_) => itemsSendPort.send(PortsProviderMessages.prepared));
        }
      },
    );
  }
}
