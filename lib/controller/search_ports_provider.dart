import 'dart:async';
import 'dart:isolate';

import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

typedef _PortsComm = ({ReceivePort items, Completer<SendPort> search});

class SearchPortsProvider {
  static final SearchPortsProvider inst = SearchPortsProvider._internal();
  SearchPortsProvider._internal();

  final _ports = <MediaType, _PortsComm?>{};

  Future<void> _disposePort(_PortsComm port) async {
    port.items.close();
    (await port.search.future).send('dispose');
  }

  void disposeAll() {
    for (final p in _ports.values) {
      if (p != null) _disposePort(p);
    }
    _ports.clear();
  }

  Future<void> closePorts(MediaType type) async {
    final port = _ports[type];
    if (port != null) {
      await _disposePort(port);
      _ports[type] = null;
    }
  }

  Future<SendPort> preparePorts({
    required MediaType type,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    final portC = _ports[type];
    if (portC != null && !force) return await portC.search.future;

    await closePorts(type);
    _ports[type] = (items: ReceivePort(), search: Completer<SendPort>());
    final port = _ports[type];
    port!.items.listen((result) {
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
