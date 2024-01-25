import 'dart:async';
import 'dart:isolate';

import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class SearchPortsProvider with PortsProvider {
  static final SearchPortsProvider inst = SearchPortsProvider._internal();
  SearchPortsProvider._internal();

  final _ports = <MediaType, PortsComm?>{};

  void disposeAll() {
    for (final p in _ports.values) {
      if (p != null) disposePort(p);
    }
    _ports.clear();
  }

  Future<void> closePorts(MediaType type) async {
    final port = _ports[type];
    if (port != null) {
      await disposePort(port);
      _ports[type] = null;
    }
  }

  Future<SendPort> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    return await preparePortRaw(
      portN: _ports[type],
      onPortNull: () async {
        await closePorts(type);
        _ports[type] = (items: ReceivePort(), search: Completer<SendPort>());
        return _ports[type]!;
      },
      onResult: onResult,
      isolateFunction: isolateFunction,
    );
  }
}

typedef PortsComm = ({ReceivePort items, Completer<SendPort> search});
mixin PortsProvider {
  Future<void> disposePort(PortsComm port) async {
    port.items.close();
    (await port.search.future).send('dispose');
  }

  Future<SendPort> preparePortRaw({
    required PortsComm? portN,
    required Future<PortsComm> Function() onPortNull,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    if (portN != null && !force) return await portN.search.future;

    final port = await onPortNull();
    port.items.listen((result) {
      if (result is SendPort) {
        port.search.completeIfWasnt(result);
      } else {
        onResult(result);
      }
    });
    await isolateFunction(port.items.sendPort);
    return await port.search.future;
  }
}
