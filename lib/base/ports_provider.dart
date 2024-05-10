import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:namida/core/extensions.dart';

typedef PortsComm = ({ReceivePort items, Completer<SendPort> search});

abstract class _PortsProviderDisposeMessage {}

mixin PortsProvider {
  PortsComm? port;
  StreamSubscription? _streamSub;

  static bool isDisposeMessage(dynamic message) => message == _PortsProviderDisposeMessage;

  @protected
  Future<void> disposePort() async {
    final port = this.port;
    if (port != null) {
      port.items.close();
      _streamSub?.cancel();
      (await port.search.future).send(_PortsProviderDisposeMessage);
      this.port = null;
    }
  }

  Future<SendPort> preparePortRaw({
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    final portN = this.port;
    if (portN != null && !force) return await portN.search.future;

    await disposePort();
    this.port = (items: ReceivePort(), search: Completer<SendPort>());
    final port = this.port!;
    _streamSub = port.items.listen((result) {
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

mixin PortsProviderBase {
  StreamSubscription? _streamSub;

  @protected
  Future<void> disposePort(PortsComm port) async {
    port.items.close();
    _streamSub?.cancel();
    (await port.search.future).send(_PortsProviderDisposeMessage);
  }

  Future<SendPort> preparePortBase({
    required PortsComm? portN,
    required Future<PortsComm> Function() onPortNull,
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
    bool force = false,
  }) async {
    if (portN != null && !force) return await portN.search.future;

    final port = await onPortNull();
    _streamSub = port.items.listen((result) {
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
